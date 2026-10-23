;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-engine to session-agent graph projection performance gate.
;;; Invariant: projection stays report-only and does not duplicate topology
;;; outside the session module graph owner.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run/result)
        (only-in :agentic-ai-lab/modules/loop-engine/runtime-agent
                 agentic-ai-lab-user-loop-engine-intent-session-agent-topology-trace)
        (only-in :agentic-ai-lab/modules/loop-engine/session-agent-graph
                 agentic-ai-lab-user-loop-engine-intent-session-agent-graph))

(export loop-engine-session-agent-graph-performance-test)

(def loop-engine-session-agent-graph-performance-fixture-path
  "t/scenarios/performance/loop-engine-session-agent-graph/benchmark.ss")

(def loop-engine-session-agent-graph-performance-fixture
  (call-with-input-file
   loop-engine-session-agent-graph-performance-fixture-path
   read))

;; : (-> Alist Symbol MaybeValue)
(def (loop-engine-session-agent-graph-performance-ref row key)
  (let (entry (assoc key row))
    (if entry (cdr entry) #f)))

;; : (-> Alist Void)
(def (loop-engine-session-agent-graph-performance-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] loop-engine-session-agent-graph ")
  (write receipt)
  (newline)
  (force-output))

;; : Alist
(def loop-engine-session-agent-graph-performance-intent
  '((use-case . (current-system-build-loop
                 (workflow . funflow-cicd)))
    (use-cases . ((current-system-recovery-loop
                   (workflow . funflow-cicd))))
    (agent-judges . ((auditor . ci-audit-agent)
                     (verifier . build-verifier-agent)
                     (governor . ci-loop-governor)))
    (human-audit . ((actions . (+manual-gate +changes-requested))))
    (lineage-policy . ((parent-session-refs . (incoming-ci-request-session))
                       (lineage-kind . guarded-handoff)
                       (lineage-operator . current-system-build-loop)))
    (resource-policy . ((tool-refs . (run-shell-command
                                      write-workspace-file
                                      read-workspace-file))))
    (sandbox-profile-refs . (ci/build))
    (memory-policies . (((use-case . current-system-build-loop)
                         (store . project-memory))))
    (result . ((default . agentic-ai-lab.loop-governor.node-result.v1)
               (auditor . agentic-ai-lab.loop-governor.audit-result.v1)
               (verifier . agentic-ai-lab.loop-governor.review-result.v1)
               (governor . agentic-ai-lab.loop-governor.governor-result.v1)
               (human-audit
                . agentic-ai-lab.loop-governor.human-audit-decision.v1)))
    (runtime-owner . "marlin-agent-core")
    (runtime-executed . #f)))

;; : (-> Alist)
(def (loop-engine-session-agent-graph-performance-summary)
  (let* ((graph
          (agentic-ai-lab-user-loop-engine-intent-session-agent-graph
           loop-engine-session-agent-graph-performance-intent))
         (topology-trace
          (agentic-ai-lab-user-loop-engine-intent-session-agent-topology-trace
           loop-engine-session-agent-graph-performance-intent)))
    (list
     (cons 'agent-count
           (loop-engine-session-agent-graph-performance-ref graph
                                                            'agent-count))
     (cons 'session-count
           (loop-engine-session-agent-graph-performance-ref graph
                                                            'session-count))
     (cons 'registry-entry-count
           (loop-engine-session-agent-graph-performance-ref
            (loop-engine-session-agent-graph-performance-ref
             graph
             'registry-receipt)
            'entry-count))
     (cons 'communication-receipt-count
           (loop-engine-session-agent-graph-performance-ref
            graph
            'communication-receipt-count))
     (cons 'topology-trace-session-count
           (length
            (loop-engine-session-agent-graph-performance-ref
             topology-trace
             'graph-session-ids)))
     (cons 'topology-trace-channel-count
           (length
            (loop-engine-session-agent-graph-performance-ref
             topology-trace
             'graph-channel-refs)))
     (cons 'topology-trace-communication-channel-count
           (length
            (loop-engine-session-agent-graph-performance-ref
             topology-trace
             'communication-channel-refs)))
     (cons 'topology-trace-valid?
           (loop-engine-session-agent-graph-performance-ref topology-trace
                                                            'valid?))
     (cons 'topology-trace-diagnostic-count
           (loop-engine-session-agent-graph-performance-ref
            topology-trace
            'diagnostic-count))
     (cons 'projection-count 2)
     (cons 'runtime-executed
           (loop-engine-session-agent-graph-performance-ref
            graph
            'runtime-executed)))))

(def loop-engine-session-agent-graph-performance-test
  (test-suite "loop-engine session-agent graph performance"
    (yuanxu-test-case "keeps loop-engine topology projection inside benchmark contract"
      (let-values (((receipt summary)
                    (benchmark-run/result
                     loop-engine-session-agent-graph-performance-fixture
                     loop-engine-session-agent-graph-performance-summary)))
        (check-equal?
         (benchmark-fixture-contract-pass?
          loop-engine-session-agent-graph-performance-fixture)
         #t)
        (check-equal?
         (loop-engine-session-agent-graph-performance-ref summary
                                                          'agent-count)
         4)
        (check-equal?
         (loop-engine-session-agent-graph-performance-ref summary
                                                          'session-count)
         6)
        (check-equal?
         (loop-engine-session-agent-graph-performance-ref
          summary
          'registry-entry-count)
         6)
        (check-equal?
         (loop-engine-session-agent-graph-performance-ref
          summary
          'communication-receipt-count)
         8)
        (check-equal?
         (loop-engine-session-agent-graph-performance-ref
          summary
          'topology-trace-session-count)
         6)
        (check-equal?
         (loop-engine-session-agent-graph-performance-ref
          summary
          'topology-trace-channel-count)
         4)
        (check-equal?
         (loop-engine-session-agent-graph-performance-ref
          summary
          'topology-trace-communication-channel-count)
         4)
        (check-equal?
         (loop-engine-session-agent-graph-performance-ref
          summary
          'topology-trace-valid?)
         #t)
        (check-equal?
         (loop-engine-session-agent-graph-performance-ref
          summary
          'topology-trace-diagnostic-count)
         0)
        (check-equal?
         (loop-engine-session-agent-graph-performance-ref
          summary
          'projection-count)
         2)
        (check-equal?
         (loop-engine-session-agent-graph-performance-ref
          summary
          'runtime-executed)
         #f)
        (loop-engine-session-agent-graph-performance-display-receipt
         receipt)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
