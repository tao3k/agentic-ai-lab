;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; POO service over the existing Context owner. This module owns no
;;; foreign runtime or transport protocol; observations stay runtime capabilities.
(import (only-in :clan/poo/object .o .ref .call .slot?)
        (only-in :tao3k/agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
                 journal-hash journal-open journal-close!)
        :tao3k/agentic-ai-lab/modules/temporal-causality/runtime/policy-clock
        "session-host.ss" "use-host.ss" "durable-owner.ss")
(export context-runtime-service context-service-resource context-service-command
        context-start-durable-service context-service-agenda!
        context-service-grant-command context-service-bind-observation!
        context-service-dispatch! context-service-prepare-workspace! context-service-complete-workspace!
        context-service-start-workspace!
        context-service-assess-workspace!
        context-service-workspace-recovery-projection context-service-workspace-retry-command
        context-service-workspace-authorization-request
        context-service-issue-workspace-retry!
        context-service-retry-workspace!
        context-service-close!)
(defstruct service-state (clock observations lock closed))

(def (text? value) (and (string? value) (< 0 (string-length value) 257)))
(def (revision? value) (and (exact-integer? value) (<= 0 value 9223372036854775807)))
(def (context-service-resource host-value grants-value policies-value durability-value)
  (.o kind: 'context.service-resource.v1 host: host-value grants: grants-value
      policies: policies-value durability: durability-value))
(def (context-runtime-service clock-value)
  (unless (eq? (.ref clock-value 'kind) 'temporal.policy-clock-owner.v1)
    (error "Expected runtime Context owner"))
  (let (state-value (make-service-state clock-value (make-hash-table) (make-mutex 'context-service) #f))
    (.o kind: 'context.runtime-service.v1 private-service: state-value)))

;; The deployment supplies its Context inputs on the serialized owner.
;; The service owns journal acquisition, restoration and clock lifecycle.
(def (context-start-durable-service deployment)
  (let* ((path (.ref deployment 'journal-path))
         (profile (.ref deployment 'clock))
         (clock (policy-clock-owner
                  (lambda ()
                    (let ((journal (journal-open path)) (inputs #f))
                      (def (release-inputs!)
                        (when (and inputs (.slot? inputs '.close!))
                          (.call inputs .close! inputs)))
                      (with-catch
                        (lambda (failure)
                          (dynamic-wind void release-inputs! (lambda () (journal-close! journal)))
                          (raise failure))
                        (lambda ()
                          (set! inputs (.call deployment .initialize deployment journal))
                          (let* ((host (.ref inputs 'host))
                                 (grants (.ref inputs 'grants))
                                 (policies (.ref inputs 'policies))
                                 (recovery (.ref inputs 'recovery))
                                 (adapter (context-durable-adapter journal host grants policies
                                            (.ref inputs 'proof-resolver) (.ref inputs 'query-provider)
                                            recovery))
                                 (owned (.o (:: @ adapter)
                                          .close!: (lambda (self)
                                            (dynamic-wind void
                                              (lambda () (.call adapter .close! adapter))
                                              release-inputs!))))
                                 (effect-host-value (and recovery (.slot? recovery 'effect-host)
                                                         (.ref recovery 'effect-host))))
                            (values (.o (:: @ (context-service-resource host grants policies owned))
                                        effect-host: effect-host-value
                                        agenda: (and (.slot? inputs 'agenda) (.ref inputs 'agenda)))
                                    policies owned))))))
                  (.ref profile 'domain) (.ref profile 'origin) (.ref profile 'tick-seconds))))
    (context-runtime-service clock)))

(def (context-service-command id-value operation-value session-value revision-value generation-value epoch-value observation-value)
  (unless (and (text? id-value) (memq operation-value '(result cancel recover inspect))
               (text? session-value) (revision? revision-value) (revision? generation-value)
               (and (revision? epoch-value) (> epoch-value 0))
               (or (not observation-value) (text? observation-value)))
    (error "Invalid runtime Context service command"))
  (.o kind: 'context.service-command.v1 identity: (string-copy id-value)
      operation: operation-value session: (string-copy session-value)
      revision: revision-value generation: generation-value owner-epoch: epoch-value
      observation: (and observation-value (string-copy observation-value))))

(def (context-service-grant-command id-value grant-value digest-value epoch-value)
  (unless (and (text? id-value) (text? grant-value) (text? digest-value)
               (revision? epoch-value) (> epoch-value 0))
    (error "Invalid runtime service grant command"))
  (.o kind: 'context.service-command.v1 identity: (string-copy id-value)
      operation: 'grant-revocation session: #f observation: #f
      grant: (string-copy grant-value) expected: (string-copy digest-value)
      owner-epoch: epoch-value))

(def (service-locked state operation)
  (mutex-lock! (service-state-lock state))
  (dynamic-wind void operation (lambda () (mutex-unlock! (service-state-lock state)))))

;; Only trusted runtime application wiring calls this function. An observation
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
      runtime-result-published?: published-value reason: reason-value historical?: #f
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
       (let (runtime (.call adapter .revoke-grant! adapter intent))
         (decision id (.ref runtime 'accepted?) #f 'runtime-grant-cas)))
      (else
       (let (runtime
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
         (decision id (.ref runtime 'accepted?)
           (and (eq? operation 'result) (.ref runtime 'accepted?) (.ref runtime 'runtime-result-published?)) 'runtime-session-cas))))))

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

;; The existing workspace handoff now has a normal trusted service entry.
;; Only a fresh successful command yields its detached intent to the caller.
(def (context-service-prepare-workspace! service intent capability)
  (unless (and (eq? (.ref intent 'kind) 'context.durable-command.v1)
               (eq? (.ref intent 'operation) 'workspace-effect))
    (error "Expected a workspace effect intent"))
  (let* ((state (.ref service 'private-service))
         (clock (service-state-clock state))
         (result #f))
    (service-locked state
      (lambda () (when (service-state-closed state) (error "Context service closed"))))
    (policy-clock-command! clock intent
      (lambda (resource)
        (let (adapter (.ref resource 'durability))
          (set! result (.call adapter .workspace-prepare! adapter intent capability)))))
    result))

;; Release a real Session worker only after its original handoff commits.
;; Awaiting the worker and committing its result are separate operations.
(def (workspace-result-command id-value effect-value)
  (unless (and (text? id-value) (text? effect-value))
    (error "Expected workspace result and effect identities"))
  (.o kind: 'context.durable-command.v1 identity: (string-copy id-value)
      operation: 'workspace-result
      body: (.o effect: (string-copy effect-value))))

(def (context-service-start-workspace! service intent endpoint)
  (unless (and (eq? (.ref intent 'kind) 'context.durable-command.v1)
               (eq? (.ref intent 'operation) 'workspace-effect))
    (error "Expected a workspace effect intent"))
  (let* ((state (.ref service 'private-service))
         (clock (service-state-clock state))
         (effect-id (.ref intent 'identity))
         (session-id (.ref (.ref (.ref intent 'body) 'attempt) 'session))
         (worker-token #f)
         (prepared #f))
    (service-locked state
      (lambda () (when (service-state-closed state) (error "Context service closed"))))
    (let (worker (thread-start! (make-thread
                   (lambda ()
                     (let (command (thread-receive))
                       (and command (.call endpoint .apply! endpoint command)))))))
      (with-catch
        (lambda (failure) (thread-send worker #f) (raise failure))
        (lambda ()
          (policy-clock-command! clock intent
            (lambda (resource)
              (let* ((adapter (.ref resource 'durability))
                     (host (.ref resource 'host))
                     (answer (.call adapter .workspace-prepare! adapter intent endpoint)))
                (when (.ref answer 'accepted?)
                  (let (row (agentic-ai-lab-ai-agentic-context-session-host-current host session-id))
                    (set! worker-token
                      (agentic-ai-lab-ai-agentic-context-session-host-attach-worker!
                        host session-id (.ref (.ref row 'schedule) 'revision)
                        (.ref row 'source-generation) worker))
                    (set! prepared (.ref answer 'intent)))))))))
      (thread-send worker prepared)
      (and prepared
           (.o kind: 'context.live-workspace-worker.v1
               .await: (lambda (self) (thread-join! worker))
               .commit!: (lambda (self result-id)
                 (thread-join! worker)
                 (let (command (workspace-result-command result-id effect-id))
                   (policy-clock-command! clock command
                     (lambda (resource)
                       (let ((adapter (.ref resource 'durability))
                             (observation
                               (agentic-ai-lab-ai-agentic-context-session-host-observe-worker!
                                 (.ref resource 'host) session-id worker-token)))
                         (.call adapter .workspace-complete! adapter command observation)))))))))))

;; A real joined Session observation is required by the durable adapter.
;; Only the result command identity and original effect enter the inbox.
(def (context-service-complete-workspace! service id-value effect-value observation)
  (unless (and (text? id-value) (text? effect-value) observation)
    (error "Expected a workspace result and live Session observation"))
  (let* ((state (.ref service 'private-service))
         (clock (service-state-clock state))
         (command (workspace-result-command id-value effect-value)))
    (service-locked state
      (lambda () (when (service-state-closed state) (error "Context service closed"))))
    (policy-clock-command! clock command
      (lambda (resource)
        (let (adapter (.ref resource 'durability))
          (.call adapter .workspace-complete! adapter command observation))))))

;; Trusted embedding entry. The live reader stays outside the durable command.
(def (context-service-assess-workspace! service id-value effect-id epoch-value reader)
  (unless (and (text? id-value) (text? effect-id) (revision? epoch-value) (> epoch-value 0))
    (error "Invalid workspace recovery assessment"))
  (let* ((state (.ref service 'private-service))
         (clock (service-state-clock state))
         (command (.o kind: 'context.durable-command.v1 identity: (string-copy id-value)
                      operation: 'workspace-recovery-assess
                      body: (.o effect: (string-copy effect-id) owner-epoch: epoch-value))))
    (service-locked state
      (lambda () (when (service-state-closed state) (error "Context service closed"))))
    (policy-clock-command! clock command
      (lambda (resource)
        (let (adapter (.ref resource 'durability))
          (.call adapter .workspace-recovery-assess! adapter command reader))))
    ;; Read only after the command's transaction has committed. Historical
    ;; acknowledgments expose the original decision, never renewed authority.
    (policy-clock-call! clock
      (lambda (resource)
        (let* ((adapter (.ref resource 'durability))
               (receipt (.call adapter .service-decision adapter (.ref command 'identity))))
          (unless (and receipt
                       (.call adapter .applied? adapter (.ref command 'identity))
                       (eq? (.ref receipt 'kind) 'context.workspace-recovery-decision.v1))
            (error "Missing committed workspace recovery decision"))
          receipt)))))

;; Export the exact current committed receipt for independent proof checking.
(def (context-service-workspace-recovery-projection service id-value (digest-value #f))
  (unless (and (text? id-value) (or (not digest-value) (text? digest-value)))
    (error "Invalid recovery projection reference"))
  (let* ((state (.ref service 'private-service))
         (clock (service-state-clock state)))
    (service-locked state
      (lambda () (when (service-state-closed state) (error "Context service closed"))))
    (policy-clock-call! clock
      (lambda (resource)
        (let (adapter (.ref resource 'durability))
          (.call adapter .workspace-recovery-current adapter id-value digest-value))))))

(def (context-service-workspace-retry-command id-value effect-value decision-value digest-value epoch-value)
  (unless (and (text? id-value) (text? effect-value) (text? decision-value)
               (text? digest-value) (revision? epoch-value) (> epoch-value 0))
    (error "Invalid workspace retry command"))
  (.o kind: 'context.durable-command.v1 identity: (string-copy id-value)
      operation: 'workspace-retry-consume
      body: (.o effect: (string-copy effect-value) decision: (string-copy decision-value)
                decision-digest: (string-copy digest-value) owner-epoch: epoch-value)))

(def (workspace-retry-command-copy intent)
  (unless (and (eq? (.ref intent 'kind) 'context.durable-command.v1)
               (eq? (.ref intent 'operation) 'workspace-retry-consume))
    (error "Expected an exact workspace retry command"))
  (let (body (.ref intent 'body))
    (context-service-workspace-retry-command
      (.ref intent 'identity) (.ref body 'effect) (.ref body 'decision)
      (.ref body 'decision-digest) (.ref body 'owner-epoch))))

(def (context-service-workspace-authorization-request service intent)
  (let* ((command (workspace-retry-command-copy intent))
         (state (.ref service 'private-service)))
    (service-locked state
      (lambda () (when (service-state-closed state) (error "Context service closed"))))
    (policy-clock-call! (service-state-clock state)
      (lambda (resource)
        (let (adapter (.ref resource 'durability))
          (.call adapter .workspace-authorization-request adapter command))))))

;; Issuance is outside the journal transaction. The returned live grant
;; remains subject to the existing owner checks at consumption and dispatch.
(def (context-service-issue-workspace-retry! service intent)
  (let* ((command (workspace-retry-command-copy intent))
         (state (.ref service 'private-service))
         (issuance
           (policy-clock-call! (service-state-clock state)
             (lambda (resource)
               (let ((adapter (.ref resource 'durability))
                     (host (and (.slot? resource 'effect-host) (.ref resource 'effect-host))))
                 (and host (.slot? host '.issue-retry!)
                      (let (request (.call adapter .workspace-authorization-request adapter command))
                        (and request (cons host request)))))))))
    (and issuance (.call (car issuance) .issue-retry! (car issuance) (cdr issuance)))))

;; A process-local handoff exists only for the fresh consumption call.
;; An ACK from a prior call or owner cannot recreate this continuation.
(def (context-service-retry-workspace! service intent token)
  (let* ((command (workspace-retry-command-copy intent))
         (state (.ref service 'private-service))
         (clock (service-state-clock state))
         (fresh? #f))
    (service-locked state
      (lambda () (when (service-state-closed state) (error "Context service closed"))))
    (policy-clock-command! clock command
      (lambda (resource)
        (let (adapter (.ref resource 'durability))
          (set! fresh? (.call adapter .workspace-retry-consume! adapter command token)))))
    (and fresh?
         (let* ((command-id (.ref command 'identity))
                (dispatch-id (string-append "workspace-retry-dispatch:" (journal-hash command-id)))
                (dispatch (.o kind: 'context.durable-command.v1 identity: dispatch-id
                             operation: 'workspace-retry-dispatch
                             body: (.o consumption: command-id)))
                (dispatched? #f))
           (policy-clock-command! clock dispatch
             (lambda (resource)
               (let (adapter (.ref resource 'durability))
                 (set! dispatched?
                   (.call adapter .workspace-retry-dispatch! adapter dispatch command token)))))
           dispatched?))))

(def (context-service-agenda! service operation)
  (let (state (.ref service 'private-service))
    (policy-clock-call! (service-state-clock state)
      (lambda (resource)
        (let (agenda (.ref resource 'agenda))
          (unless agenda (error "Agenda is not installed on this Context owner"))
          (operation agenda))))))

(def (context-service-close! service)
  (let (state (.ref service 'private-service))
    (unless (service-state-closed state)
      (policy-clock-stop! (service-state-clock state))
      (service-locked state (lambda ()
        (hash-clear! (service-state-observations state))
        (set! (service-state-closed state) #t))))
    #t))
