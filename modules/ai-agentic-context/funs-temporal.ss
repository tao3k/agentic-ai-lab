;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Pure Context lifecycle window policy over existing Temporal primitives.
(import (only-in :clan/poo/object .o .ref)
        (only-in :std/list/list every delete-duplicates/hash)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/types agentic-ai-lab-temporal-interval?)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/objects agentic-ai-lab-temporal-instant agentic-ai-lab-temporal-interval)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/funs agentic-ai-lab-temporal-interval-contains?)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/uncertainty-funs agentic-ai-lab-temporal-bounded-observation-replay)
        "types.ss" "objects.ss" "funs-scope.ss")
(export agentic-ai-lab-ai-agentic-context-temporal-policy
        agentic-ai-lab-ai-agentic-context-temporal-policy-replay
        agentic-ai-lab-ai-agentic-context-temporal-assess)
(def (instant-row value)
  (map (lambda (key) (.ref value key)) '(identity domain-identity coordinate provenance-identity modality)))
(def (copy-instant value)
  (apply agentic-ai-lab-temporal-instant
    (map (lambda (value) (if (string? value) (string-copy value) value)) (instant-row value))))
(def (agentic-ai-lab-ai-agentic-context-temporal-policy policy-id policy-revision interval-value role-value purpose-values)
  (unless (and (string? policy-id) (< 0 (string-length policy-id) 257)
               (exact-integer? policy-revision) (<= 0 policy-revision 65535)
               (agentic-ai-lab-temporal-interval? interval-value) (symbol? role-value)
               (list? purpose-values) (<= 1 (length purpose-values) 5)
               (every (lambda (purpose) (memq purpose '(prepare disclose accept-result publish-memory revisit))) purpose-values)) (error "Invalid Context temporal policy inputs"))
  (let* ((window-value (agentic-ai-lab-temporal-interval (string-copy (.ref interval-value 'identity))
               (copy-instant (.ref interval-value 'start)) (copy-instant (.ref interval-value 'end))
               (.ref interval-value 'start-closed?) (.ref interval-value 'end-closed?)))
         (purposes-value (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b))) purpose-values))
         (digest-value (agentic-ai-lab-ai-agentic-context-digest
           (list 'context-temporal-policy-v1 policy-id policy-revision (.ref window-value 'identity)
                 (instant-row (.ref window-value 'start)) (instant-row (.ref window-value 'end))
                 (.ref window-value 'start-closed?) (.ref window-value 'end-closed?) role-value purposes-value)))
         (value (.o (:: @ AiAgenticContextTemporalPolicy.) identity: (string-copy policy-id)
              revision: policy-revision window: window-value clock-role: role-value purposes: purposes-value
              semantic-digest: digest-value)))
    (unless (and (agentic-ai-lab-ai-agentic-context-temporal-policy-shape? value)
                 (= (length purposes-value) (length (delete-duplicates/hash purposes-value))))
      (error "Invalid Context temporal policy")) value))
(def (agentic-ai-lab-ai-agentic-context-temporal-policy-replay policy)
  (unless (agentic-ai-lab-ai-agentic-context-temporal-policy-shape? policy) (error "Invalid Context temporal policy proposal"))
  (let (fresh (agentic-ai-lab-ai-agentic-context-temporal-policy (.ref policy 'identity) (.ref policy 'revision)
                 (.ref policy 'window) (.ref policy 'clock-role) (.ref policy 'purposes)))
    (unless (equal? (.ref fresh 'semantic-digest) (.ref policy 'semantic-digest))
      (error "Context temporal policy substitution")) fresh))
(def (agentic-ai-lab-ai-agentic-context-temporal-assess policy observation purpose-value)
  (let* ((policy-value (agentic-ai-lab-ai-agentic-context-temporal-policy-replay policy))
         (clock-value (agentic-ai-lab-temporal-bounded-observation-replay observation))
         (window-value (.ref policy-value 'window)) (earliest-value (.ref clock-value 'earliest))
         (latest-value (.ref clock-value 'latest))
         (left (agentic-ai-lab-temporal-interval-contains? window-value earliest-value))
         (right (agentic-ai-lab-temporal-interval-contains? window-value latest-value))
         (status-value
          (cond ((not (memq purpose-value (.ref policy-value 'purposes))) 'purpose-denied)
                ((not (eq? (.ref clock-value 'clock-role) (.ref policy-value 'clock-role))) 'unsupported-clock)
                ((or (eq? left 'incomparable) (eq? right 'incomparable)) 'incomparable)
                ((or (eq? left 'unknown) (eq? right 'unknown)) 'unknown)
                ((and (eq? left #t) (eq? right #t)) 'eligible)
                ((< (.ref latest-value 'coordinate) (.ref (.ref window-value 'start) 'coordinate)) 'not-yet-effective)
                ((>= (.ref earliest-value 'coordinate) (.ref (.ref window-value 'end) 'coordinate)) 'expired)
                (else 'uncertain)))
         (policy-digest-value (.ref policy-value 'semantic-digest))
         (clock-digest-value (string-copy (.ref clock-value 'semantic-digest)))
         (assessment-digest-value (agentic-ai-lab-ai-agentic-context-digest
                  (list 'context-temporal-assessment-v1 policy-digest-value clock-digest-value purpose-value status-value))))
    (.o kind: 'agentic-ai-lab.ai-agentic-context.temporal-assessment.v1 policy-digest: policy-digest-value
        clock-digest: clock-digest-value purpose: purpose-value status: status-value semantic-digest: assessment-digest-value
        source-authenticated?: #f action-authorized?: #f runtime-published?: #f durable?: #f)))
