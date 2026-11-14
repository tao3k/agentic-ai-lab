;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: functional runtime helpers for session receipt projections.
;;; Invariant: helpers only transform inert receipt values; they never execute
;;; agent runtime behavior or mutate session state.

(export agentic-ai-lab-session-receipt-projection-batch)

;; : (-> List Procedure String List)
(def (agentic-ai-lab-session-receipt-projection-batch items projector error-message)
  (if (list? items)
    (map projector items)
    (error error-message items)))
