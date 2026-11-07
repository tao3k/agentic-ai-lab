;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: downstream session transform case.
;;; Invariant: importing this module derives session receipts only.

(import :agentic-ai-lab/modules/session/syntax)

(export agentic-ai-lab-custom-my-module-session-transform-case)

(def agentic-ai-lab-custom-my-module-session-transform-case
  (agentic-ai-lab-session-cases
  (session-case custom-session-transform-case
    (metadata (source . user-interface)
              (case . session-transform))
    (objects
     (custom-session-review-memory
      (session-memory-intent custom/review-memory
        (store session/memory)
        (scope project-workspace)
        (recall repository-summary review-notes)
        (commit commit-derived-session)
        (metadata (source . user-interface)
                  (case . session-transform))))
     (custom-session-review-transform
      (session-transform custom-review-agent
        (intent review)
        (description "Review a custom session and derive a follow-up session.")
        (capabilities +provider-handoff +receipt-only +session-derivation)
        (memory-intents custom-session-review-memory)
        (metadata (source . user-interface)
                  (case . session-transform))))
     (custom-session-transform-root
      (session custom/session-transform-root
        (chunk request user
               "Create a report-only custom session transform receipt.")
        (lineage root)
        (placement agent/nono)
        (metadata (source . user-interface)
                  (case . session-transform))))
     (custom-session-transform-receipt
      (transform-session custom-session-review-transform
                         custom-session-transform-root
                         custom/session-transform-review
        (chunk review assistant
               "Review the custom session transform receipt.")
        (metadata (source . user-interface)
                  (case . session-transform)
                  (stage . review)))))
    (rows custom-session-review-memory
          custom-session-review-transform
          custom-session-transform-root
          custom-session-transform-receipt))))
