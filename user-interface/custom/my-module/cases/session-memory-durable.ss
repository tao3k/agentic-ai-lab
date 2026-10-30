;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: downstream durable memory job case.
;;; Invariant: this is durable job handoff data only; Scheme does not recall,
;;; commit, consolidate, persist, or repair memory stores.

(import :agentic-ai-lab/modules/session/syntax
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/config)

(export agentic-ai-lab-custom-my-module-session-memory-durable-case)

(def agentic-ai-lab-custom-my-module-session-memory-durable-case
  (agentic-ai-lab-session-cases
  (session-case custom-session-memory-durable-case
    (metadata (source . user-interface)
              (case . session-memory-durable))
    (objects
     (durable-policy
      (agentic-ai-lab-durable-policy
       'durable/custom-memory
       'objects.shared.memory
       '((journal-owner . runtime/fact-log)
         (checkpoint-store . runtime/checkpoint-store)
         (resume-identity . session-id)
         (repair-mode . rebuild)
         (action-classes . (replayable idempotent compensatable)))))
     (parent-summary
      (session-memory-intent parent-summary
        (store memory/durable-project)
        (scope parent-summary)
        (recall parent-summary)
        (commit review-only)
        (metadata (source . user-interface)
                  (case . session-memory-durable))))
     (child-write-back
      (session-memory-intent child-write-back
        (store memory/durable-project)
        (scope current-session)
        (recall)
        (commit append)
        (metadata (source . user-interface)
                  (case . session-memory-durable))))
     (bounded-transcript
      (session-memory-intent bounded-transcript
        (store memory/durable-project)
        (scope project)
        (recall "last-40-turns")
        (commit review-only)
        (metadata (source . user-interface)
                  (case . session-memory-durable))))
     (durable-options
      (list (cons 'durable-policy durable-policy)
            (cons 'source-watermark 'turn/40)
            (cons 'target-watermark 'memory/index/40)
            (cons 'usage-counter 1)
            (cons 'metadata '((source . user-interface)
                              (case . session-memory-durable)))))
     (jobs
      (list
       (agentic-ai-lab-memory-recall-job-receipt
        'memory-job/custom-parent-summary
        'custom/project
        'custom/root-session
        'custom/audit-session
        'agent/audit
        agentic-ai-lab-ai-agentic-context-memory-default-catalog
        parent-summary
        durable-options)
       (agentic-ai-lab-memory-write-job-receipt
        'memory-job/custom-child-write-back
        'custom/project
        'custom/root-session
        'custom/audit-session
        'agent/audit
        agentic-ai-lab-ai-agentic-context-memory-default-catalog
        child-write-back
        durable-options)
       (agentic-ai-lab-memory-recall-job-receipt
        'memory-job/custom-bounded-transcript
        'custom/project
        'custom/root-session
        'custom/audit-session
        'agent/audit
        agentic-ai-lab-ai-agentic-context-memory-default-catalog
        bounded-transcript
        durable-options)
       (agentic-ai-lab-memory-consolidation-job-receipt
        'memory-job/custom-consolidate
        'custom/project
        'custom/root-session
        'custom/audit-session
        #f
        agentic-ai-lab-ai-agentic-context-memory-default-catalog
        bounded-transcript
        durable-options)
       (agentic-ai-lab-memory-stale-source-job-receipt
        'memory-job/custom-stale-source
        'custom/project
        'custom/root-session
        'custom/audit-session
        #f
        agentic-ai-lab-ai-agentic-context-memory-default-catalog
        bounded-transcript
        (cons (cons 'stale-source? #t) durable-options))
       (agentic-ai-lab-memory-repair-job-receipt
        'memory-job/custom-repair
        'custom/project
        'custom/root-session
        'custom/audit-session
        #f
        agentic-ai-lab-ai-agentic-context-memory-default-catalog
        bounded-transcript
        (cons (cons 'job-state 'repair-required) durable-options)))))
    (rows)
    (row-groups (agentic-ai-lab-memory-durable-job-receipts->alists jobs)))))
