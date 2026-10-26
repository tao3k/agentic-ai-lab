;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; POO-native service over the existing Context owner. This module owns no
;;; foreign runtime or transport protocol; observations stay native capabilities.
(import (only-in :clan/poo/object .o .ref .call)
        :agentic-ai-lab/modules/temporal-causality/runtime/policy-clock
        "session-host.ss" "use-host.ss" "durable-owner.ss")
(export context-runtime-service context-service-resource context-service-command
        context-service-grant-command context-service-bind-observation!
        context-service-dispatch! context-service-close!)
(defstruct service-state (clock observations lock closed))

(def (text? value) (and (string? value) (< 0 (string-length value) 257)))
(def (revision? value) (and (exact-integer? value) (<= 0 value 9223372036854775807)))
(def (context-service-resource host-value grants-value policies-value durability-value)
  (.o kind: 'context.service-resource.v1 host: host-value grants: grants-value
      policies: policies-value durability: durability-value))
(def (context-runtime-service clock-value)
  (unless (eq? (.ref clock-value 'kind) 'temporal.policy-clock-owner.v1)
    (error "Expected native Context owner"))
  (let (state-value (make-service-state clock-value (make-hash-table) (make-mutex 'context-service) #f))
    (.o kind: 'context.runtime-service.v1 private-service: state-value)))

(def (context-service-command id-value operation-value session-value revision-value generation-value epoch-value observation-value)
  (unless (and (text? id-value) (memq operation-value '(result cancel recover inspect))
               (text? session-value) (revision? revision-value) (revision? generation-value)
               (and (revision? epoch-value) (> epoch-value 0))
               (or (not observation-value) (text? observation-value)))
    (error "Invalid native Context service command"))
  (.o kind: 'context.service-command.v1 identity: (string-copy id-value)
      operation: operation-value session: (string-copy session-value)
      revision: revision-value generation: generation-value owner-epoch: epoch-value
      observation: (and observation-value (string-copy observation-value))))

(def (context-service-grant-command id-value grant-value digest-value epoch-value)
  (unless (and (text? id-value) (text? grant-value) (text? digest-value)
               (revision? epoch-value) (> epoch-value 0))
    (error "Invalid native service grant command"))
  (.o kind: 'context.service-command.v1 identity: (string-copy id-value)
      operation: 'grant-revocation session: #f observation: #f
      grant: (string-copy grant-value) expected: (string-copy digest-value)
      owner-epoch: epoch-value))

(def (service-locked state operation)
  (mutex-lock! (service-state-lock state))
  (dynamic-wind void operation (lambda () (mutex-unlock! (service-state-lock state)))))

;; Only trusted native application wiring calls this function. An observation
;; reference never reconstructs an observation capability from its identifier.
(def (context-service-bind-observation! service id-value session-value observation-value)
  (unless (and (text? id-value) (text? session-value)) (error "Invalid observation reference"))
  (let (state (.ref service 'private-service))
    (policy-clock-call! (service-state-clock state)
      (lambda (resource)
        (context-observation-evidence (.ref resource 'host) session-value observation-value)))
    (service-locked state (lambda ()
      (when (or (service-state-closed state) (>= (hash-length (service-state-observations state)) 256)
                (hash-get (service-state-observations state) id-value))
        (error "Observation reference already bound, full or closed"))
      (hash-put! (service-state-observations state) (string-copy id-value)
                 (cons (string-copy session-value) observation-value))
      #t))))

(def (decision id-value accepted-value published-value reason-value)
  (.o kind: 'context.service-decision.v1 identity: id-value accepted?: accepted-value
      native-result-published?: published-value reason: reason-value historical?: #f
      context-state: 'none revision: -1 terminal-count: 0 action-authorized?: #f))

(def (intent-for resource command)
  (let* ((adapter (.ref resource 'durability)) (id (.ref command 'identity))
         (previous
           (if (= (.ref command 'owner-epoch) (.call adapter .epoch adapter))
             (.call adapter .service-input adapter id command)
             (.o kind: 'context.service-stale-owner.v1))))
    ;; Reject a stale claimed owner before the inbox can retain an intent.
    ;; Recovery may re-admit already accepted controls, never turn a rejected
    ;; future/old epoch into authority just because its number later matches.
    (or previous
      (if (eq? (.ref command 'operation) 'grant-revocation)
        (let* ((grant (agentic-ai-lab-context-use-host-current (.ref resource 'grants) (.ref command 'grant) #f)))
          (and grant
            (let* ((canonical (context-durable-revoke-command id grant))
                   (body-value (.ref canonical 'body)) (expected-value (.ref command 'expected)))
              ;; Keep the caller's exact expected cut and epoch in the
              ;; existing canonical command, including across retries/restart.
              (.o (:: @ canonical)
                body: (.o (:: @ body-value) expected: expected-value service-command: command)))))
        (.o kind: 'context.durable-command.v1 identity: id
            operation: (.ref command 'operation) body: command)))))

(def (apply-command resource command intent observation)
  (let* ((adapter (.ref resource 'durability)) (host (.ref resource 'host))
         (id (.ref command 'identity)) (sid (.ref command 'session))
         (operation (.ref command 'operation))
         (current-epoch (.call adapter .epoch adapter)))
    (cond
      ((not (= (.ref command 'owner-epoch) current-epoch)) (decision id #f #f 'stale-owner))
      ((and sid (not (context-host-session? host sid))) (decision id #f #f 'unknown-session))
      ((eq? operation 'grant-revocation)
       (let (native (.call adapter .revoke-grant! adapter intent))
         (decision id (.ref native 'accepted?) #f 'native-grant-cas)))
      (else
       (let (native
              (case operation
                ((result)
                 (agentic-ai-lab-ai-agentic-context-session-host-commit-result!
                   host sid (.ref command 'revision) (.ref command 'generation) (cdr observation)))
                ((cancel)
                 (agentic-ai-lab-ai-agentic-context-session-host-cancel!
                   host sid (.ref command 'revision) (.ref command 'generation)))
                ((recover)
                 (agentic-ai-lab-ai-agentic-context-session-host-recover!
                   host sid (.ref command 'revision) (.ref command 'generation)))))
         (decision id (.ref native 'accepted?)
           (and (eq? operation 'result) (.ref native 'accepted?) (.ref native 'native-result-published?)) 'native-session-cas))))))

(def (context-service-dispatch! service command)
  (unless (eq? (.ref command 'kind) 'context.service-command.v1) (error "Expected POO service command"))
  (let* ((state (.ref service 'private-service)) (clock (service-state-clock state))
         (id (.ref command 'identity)) (operation (.ref command 'operation))
         (sid (.ref command 'session)) (observation-id (.ref command 'observation))
         (observation
           (service-locked state (lambda ()
             (when (service-state-closed state) (error "Context service closed"))
             (and observation-id (hash-get (service-state-observations state) observation-id))))))
    (cond
      ((eq? operation 'inspect)
       (policy-clock-call! clock (lambda (resource)
         (let (host (.ref resource 'host))
           (if (context-host-session? host sid)
             (let* ((row (agentic-ai-lab-ai-agentic-context-session-host-current host sid))
                    (state-value (.ref row 'context-state))
                    (revision-value (.ref (.ref row 'schedule) 'revision))
                    (count-value (length (agentic-ai-lab-ai-agentic-context-session-host-outcomes host sid))))
               (.o (:: @ (decision id #t #f 'snapshot)) context-state: state-value
                   revision: revision-value terminal-count: count-value))
             (decision id #f #f 'unknown-session))))))
      (else
       (let* ((prepared
                (policy-clock-call! clock (lambda (resource)
                  (let* ((adapter (.ref resource 'durability))
                         (intent (intent-for resource command))
                         (old (.call adapter .service-decision adapter id)))
                    (list intent old)))))
              (intent (car prepared)) (historical (cadr prepared)))
         (cond
           ((not intent) (decision id #f #f 'unknown-grant))
           ((eq? (.ref intent 'kind) 'context.service-stale-owner.v1)
            (decision id #f #f 'stale-owner))
           ((eq? (.ref intent 'kind) 'context.service-input-conflict.v1)
            (decision id #f #f 'identity-conflict))
           (historical (.o (:: @ historical) historical?: #t))
           ((and (eq? operation 'result) (not (and observation (equal? (car observation) sid))))
            (decision id #f #f 'unknown-observation))
           (else
            (let (answer #f)
              (policy-clock-command! clock intent (lambda (resource)
                (let* ((adapter (.ref resource 'durability))
                       (value (apply-command resource command intent observation)))
                  (.call adapter .service-decision! adapter id value)
                  (set! answer value)
                  value)))
              (or answer
                (policy-clock-call! clock (lambda (resource)
                  (let* ((adapter (.ref resource 'durability))
                         (original (.call adapter .service-decision adapter id)))
                    (unless original (error "Missing original durable service decision"))
                    (.o (:: @ original) historical?: #t)))))))))))))

(def (context-service-close! service)
  (let (state (.ref service 'private-service))
    (unless (service-state-closed state)
      (policy-clock-stop! (service-state-clock state))
      (service-locked state (lambda ()
        (hash-clear! (service-state-observations state))
        (set! (service-state-closed state) #t))))
    #t))
