;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-governor tests cover multi-loop policy projection only.
;;; Invariant: runtime state is passed as inert facts and is never mutated.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check
                 check-eq?
                 check-equal?
                 check-false
                 check-not-equal?
                 check-output
                 check-true
                 test-error
                 test-suite)
        :yuanxu/modules/funflow/control-plane/api
        :agentic-ai-lab/modules/loop-engine/control/agent)

(export loop-governor-test)

;;; Local lookup keeps governor assertions about receipts explicit and stable.
;; : (-> Alist Symbol Value)
(def (test-ref alist key)
  (cdr (assoc key alist)))

;;; Field projection lets tests compare ordered governor decisions without
;;; coupling to the full receipt shape.
;; : (-> [Alist] Symbol [Value])
(def (test-field-values alists key)
  (map (lambda (alist) (test-ref alist key))
       alists))

;; : (-> Symbol [Symbol] Boolean)
(def (test-symbol-member? needle values)
  (cond
   ((null? values) #f)
   ((eq? needle (car values)) #t)
   (else (test-symbol-member? needle (cdr values)))))

;;; Failure capture keeps invalid-governor assertions in structured data form.
;; : (-> Thunk Value)
(def (capture-control-plane-failure thunk)
  (with-catch (lambda (failure) failure)
              thunk))

;;; Pattern construction keeps priority and action keys visible at each call
;;; site so selection behavior remains auditable.
;; : (-> Symbol Symbol Integer ActionKey LoopPatternDescriptor)
(def (governor-test-pattern name level priority action-key)
  (make-loop-pattern-descriptor
   name
   "Exercise loop governor policy projection."
   (list (cons 'level level)
         (cons 'priority priority)
         (cons 'metadata
               (list (cons 'acting_on action-key))))))

;;; Fixture construction keeps priorities and action keys visible in tests.
;;; The governor can then be checked without depending on hidden runtime state.
;; : (-> Unit LoopGovernor)
(def (make-governor-fixture)
  (let* ((triage (governor-test-pattern 'triage 'l1 1 "repo"))
         (repair-a (governor-test-pattern 'repair-a 'l2 10 "src/a"))
         (repair-b (governor-test-pattern 'repair-b 'l2 20 "src/b"))
         (repair-c (governor-test-pattern 'repair-c 'l2 30 "src/c"))
         (strategy
          (make-loop-strategy-plan
           'maintenance
           (list repair-c repair-b repair-a triage)
           (list (cons 'level-ceiling 'l2)))))
    (make-loop-governor
     'repo-governor
     strategy
     (list (cons 'shared-denylist '("src/b"))
           (cons 'agent-judges
                 '((mode . multi-agent-governance)
                   (judge-mode . mutual-review)
                   (human-intervention . #f)
                   (participants . ((auditor . repo-audit-agent)
                                    (verifier . repo-verifier-agent)
                                    (governor . repo-governor)))))
           (cons 'agent-judge-nodes
                 (list
                  (make-loop-governor-agent-node
                   'repo-audit-agent
                   'audit)
                  (make-loop-governor-agent-node
                   'repo-verifier-agent
                   'verify)
                  (make-loop-governor-agent-node
                   'repo-governor
                   'govern)))
           (cons 'aggregate-budget
                 '((max-actionable . 1)
                   (max-attempts . 2)))
           (cons 'metadata '((source . loop-engineering)))))))

;;; State fixtures stay compact so aggregate-budget tests can focus on matching
;;; policy instead of unrelated loop metadata.
;; : (-> Unit [Alist])
(def (governor-test-states)
  (list '((loop . other-loop)
          (acting_on . "src/a"))))

;;; This suite protects governor decisions as deterministic control-plane data
;;; before any runtime adapter interprets them.
;; : TestSuite
(def loop-governor-test
  (test-suite "loop governor policy descriptors"
    (yuanxu-test-case "projects open, conflicting, and denied loop patterns"
      (let* ((governor (make-governor-fixture))
             (states (governor-test-states))
             (contract (loop-governor->contract governor states)))
        (check-equal? (loop-governor? governor) #t)
        (check-equal? (loop-governor-state-field governor) 'acting_on)
        (check-equal? (loop-governor-budget-limit governor) 1)
        (check-equal? (map loop-pattern-name
                           (loop-governor-conflicting-patterns
                            governor
                            states))
                      '(repair-a))
        (check-equal? (map loop-pattern-name
                           (loop-governor-denied-patterns governor))
                      '(repair-b))
        (check-equal? (map loop-pattern-name
                           (loop-governor-open-patterns governor states))
                      '(repair-c))
        (check-equal? (test-ref contract 'open-patterns) '(repair-c))
        (check-equal? (test-ref contract 'conflicting-patterns) '(repair-a))
        (check-equal? (test-ref contract 'denied-patterns) '(repair-b))
        (check-equal? (test-ref (loop-governor-agent-judges governor)
                                'judge-mode)
                      'mutual-review)
        (check-equal? (test-ref (test-ref contract 'agent-judges)
                                'human-intervention)
                      #f)
        (check-equal? (test-field-values
                       (test-ref contract 'agent-judge-nodes)
                       'name)
                      '(repo-audit-agent repo-verifier-agent repo-governor))
        (check-equal? (test-field-values
                       (test-ref contract 'agent-judge-nodes)
                       'governance-responsibility)
                      '(audit verify govern))
        (check-equal? (test-field-values
                       (test-ref contract 'agent-judge-nodes)
                       'human-intervention)
                      '(#f #f #f))
        (check-equal? (test-ref (test-ref contract 'runtime-boundary)
                                'agent-governance)
                      'loop-governor)
        (check-equal? (test-ref (test-ref contract 'runtime-boundary)
                                'human-intervention)
                      'human-audit-loop)
        (check-equal? (test-field-values
                       (test-ref contract 'human-inbox-items)
                       'reason)
                      '(shared-denylist acting-on-conflict))
        (check-equal? (test-ref (test-ref contract 'handoff) 'target)
                      'marlin-agent-core)
        (check-equal? (test-ref (test-ref contract 'runtime-boundary)
                                'local-execution)
                      'validation-only)))
    (yuanxu-test-case "uses descriptor metadata as the acting_on action key"
      (let* ((descriptor
              (governor-test-pattern 'repair-a 'l2 10 "src/a"))
             (governor (make-governor-fixture)))
        (check-equal? (loop-governor-pattern-action-key descriptor)
                      "src/a")
        (check-equal? (loop-governor-pattern-conflicted?
                       governor
                       (governor-test-states)
                       descriptor)
                      #t)))
    (yuanxu-test-case "publishes Marlin ABI manifest for governor requests"
      (let (manifest (loop-governor-marlin-abi-manifest))
        (check-equal? (test-ref manifest 'schema)
                      +loop-governor-marlin-abi-schema+)
        (check-equal? (test-ref manifest 'request-schema)
                      +loop-governor-marlin-request-schema+)
        (check-equal? (test-ref manifest 'governor-schema)
                      +loop-governor-schema+)
        (check-equal? (test-ref manifest 'producer) 'agentic-ai-lab)
        (check-equal? (test-ref manifest 'consumer) 'marlin-agent-core)
        (check-equal? (test-ref manifest 'operation) 'govern-loop)
        (check-equal? (test-ref manifest 'required-fields)
                      '(schema governor-schema operation target transport
                        governor))
        (check-equal? (test-ref (test-ref manifest 'runtime-boundary)
                                'production-execution)
                      'marlin-agent-core)))
    (yuanxu-test-case "projects Marlin request envelopes without execution"
      (let* ((governor (make-governor-fixture))
             (states (governor-test-states))
             (envelope
              (loop-governor->marlin-request-envelope
               governor
               states
               'request-1))
             (contract (test-ref envelope 'governor))
             (manifest (test-ref envelope 'abi-manifest)))
        (check-equal? (test-ref envelope 'schema)
                      +loop-governor-marlin-request-schema+)
        (check-equal? (test-ref envelope 'governor-schema)
                      +loop-governor-schema+)
        (check-equal? (test-ref manifest 'schema)
                      +loop-governor-marlin-abi-schema+)
        (check-equal? (test-ref (test-ref manifest 'loop-engine-discovery)
                                'schema)
                      +loop-governor-marlin-loop-engine-discovery-schema+)
        (check-equal? (test-ref (test-ref
                                  (test-ref manifest 'loop-engine-discovery)
                                  'receipt-contracts)
                                'memory-receipt)
                      'agentic-ai-lab.loop-engine.memory-receipt.v1)
        (check-equal? (test-ref manifest 'required-fields)
                      '(schema governor-schema operation target transport
                        governor))
        (check-equal? (test-ref envelope 'operation) 'govern-loop)
        (check-equal? (test-ref (test-ref envelope 'loop-engine-discovery)
                                'runtime-command-name)
                      'loop-engine-runtime-handoff)
        (check-equal? (test-ref envelope 'request-id) 'request-1)
        (check-equal? (test-ref envelope 'target) 'marlin-agent-core)
        (check-equal? (test-ref envelope 'transport) 'scheme-abi)
        (check-equal? (test-ref envelope 'open-patterns) '(repair-c))
        (check-equal? (test-ref envelope 'blocked-patterns)
                      '(repair-a repair-b))
        (check-equal? (test-ref (test-ref envelope 'agent-judges)
                                'judge-mode)
                      'mutual-review)
        (check-equal? (test-field-values
                       (test-ref envelope 'agent-judge-nodes)
                       'governance-node-kind)
                      '(agent agent agent))
        (check-equal? (test-ref contract 'open-patterns) '(repair-c))
        (check-equal? (test-ref (test-ref envelope 'runtime-boundary)
                                'production-execution)
                      'marlin-agent-core)))
    (yuanxu-test-case "projects L1 report-only handoff receipts without writes"
      (let* ((governor (make-governor-fixture))
             (states (governor-test-states))
             (receipt
              (loop-governor->l1-run-receipt
               governor
               states
               'receipt-1))
             (envelope (test-ref receipt 'request-envelope)))
        (check-equal? (test-ref receipt 'schema)
                      +loop-governor-l1-run-receipt-schema+)
        (check-equal? (test-ref receipt 'level) 'l1)
        (check-equal? (test-ref receipt 'mode) 'report-only)
        (check-equal? (test-ref receipt 'status) 'handoff-ready)
        (check-equal? (test-ref receipt 'state-writes) '())
        (check-equal? (test-ref receipt 'effects) '())
        (check-equal? (test-ref receipt 'schedules) '())
        (check-equal? (test-ref envelope 'schema)
                      +loop-governor-marlin-request-schema+)
        (check-equal? (test-ref (test-ref receipt 'agent-judges)
                                'human-intervention)
                      #f)
        (check-equal? (test-field-values
                       (test-ref receipt 'agent-judge-nodes)
                       'name)
                      '(repo-audit-agent repo-verifier-agent repo-governor))
        (check-equal? (test-ref envelope 'operation) 'govern-loop)))
    (yuanxu-test-case "publishes runtime manifest discovery for Marlin governor requests"
      (let* ((governor (make-governor-fixture))
             (states (governor-test-states))
             (manifest
              (loop-governor->marlin-runtime-manifest
               governor
               states
               'manifest-1))
             (envelope (test-ref manifest 'request-envelope))
             (abi (test-ref manifest 'abi-manifest))
             (discovery (test-ref manifest 'loop-engine-discovery)))
        (check-equal? (test-ref manifest 'schema)
                      +loop-governor-marlin-runtime-manifest-schema+)
        (check-equal? (test-ref manifest 'bridge) 'runtime-manifest)
        (check-equal? (test-ref manifest 'operation) 'govern-loop)
        (check-equal? (test-ref manifest 'request-schema)
                      +loop-governor-marlin-request-schema+)
        (check-equal? (test-ref manifest 'receipt-schema)
                      +loop-governor-l1-run-receipt-schema+)
        (check-equal? (test-ref manifest 'runtime-command-contract)
                      'agentic-ai-lab.loop-governor.runtime-command-manifest.v1)
        (check-equal? (test-ref manifest 'receipt-contracts)
                      (test-ref discovery 'receipt-contracts))
        (check-equal? (test-ref (test-ref manifest 'receipt-contracts)
                                'memory-receipt)
                      'agentic-ai-lab.loop-engine.memory-receipt.v1)
        (check-equal?
         (test-symbol-member? 'memory-receipt
                              (test-ref manifest 'object-families))
         #t)
        (check-equal? (test-ref discovery 'runtime-command-executable)
                      "marlin-agent-core")
        (check-equal? (test-ref discovery 'runtime-executed) #f)
        (check-equal? (test-ref manifest 'target) 'marlin-agent-core)
        (check-equal? (test-ref envelope 'request-id) 'manifest-1)
        (check-equal? (test-ref abi 'schema)
                      +loop-governor-marlin-abi-schema+)
        (check-equal? (test-ref abi 'loop-engine-discovery)
                      discovery)))
    (yuanxu-test-case "rejects invalid Marlin request envelopes"
      (let (failure
            (capture-control-plane-failure
             (lambda ()
               (validate-loop-governor-marlin-request-envelope
                '((schema . wrong))))))
        (check-equal? (execution-failure? failure) #t)
        (check-equal? (execution-failure-owner failure) 'loop-governor)
        (check-equal? (execution-failure-code failure)
                      'invalid-loop-governor-marlin-request-envelope)))
    (yuanxu-test-case "rejects invalid governor state-key fields"
      (let* ((strategy
              (make-loop-strategy-plan
               'maintenance
               (list (governor-test-pattern 'repair 'l2 1 "src/a"))))
             (governor
              (make-loop-governor
               'bad-state-key
               strategy
               (list (cons 'state-key
                           '((field . "acting_on"))))))
             (failure
              (capture-control-plane-failure
               (lambda ()
                 (loop-governor->contract governor '())))))
        (check-equal? (execution-failure? failure) #t)
        (check-equal? (execution-failure-owner failure) 'loop-governor)
        (check-equal? (execution-failure-code failure)
                      'invalid-loop-governor)))))
