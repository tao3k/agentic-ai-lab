;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Owner: agent-sandbox named request macro lives here.
;;; Boundary:
;;; - This module owns syntax sugar only.
;;; - Request builder functions own all runtime validation.
;;; Import contract:
;;; - The facade re-exports this macro with the request builders.
;;; Runtime contract:
;;; - Macro expansion creates a field thunk, not a backend request.
;;; - Real request assembly stays in =make-agent-sandbox-request-with=.
;;; Policy evidence:
;;; - Profile tests assert named-field construction and typo failures.

(import :agentic-ai-lab/modules/agent-sandbox/request-builder)

(export agent-sandbox-request)

;;; Request macro boundary:
;;; - The macro turns named fields into a thunk and performs no runtime work.
;;; - Executable contract logic lives in =make-agent-sandbox-request-with=.
;;; Call-backed evidence:
;;; - Expansion calls =make-agent-sandbox-request-with= with a field thunk.
;;; - The thunk is the only generated runtime value.
;;; Expansion boundary:
;;; - Field names become quoted symbols in a generated request field alist.
;;; - Field values remain caller expressions evaluated by the thunk.
;;; Macro governance witness:
;;; - gerbil.pkg records =search runtime-source macro sugar module-sugar=.
;;; - This macro follows the same =defrules= naming-sugar pattern as profile builders.
;; agent-sandbox-request
;;   : (-> NamedAgentSandboxRequestSyntax AgentSandboxRequestExpansion)
;;   | doc m%
;;       `agent-sandbox-request` documents the sandbox boundary that the Gerbil
;;       policy harness treats as agent-facing behavior. The example keeps the
;;       call shape visible without duplicating implementation details.
;;
;;       # Examples
;;       ```scheme
;;       (agent-sandbox-request ...)
;;       ;; => policy-visible result
;;       ```
;;     %
(defrules agent-sandbox-request ()
  ((_ profile (field value) ...)
   (make-agent-sandbox-request-with
    profile
    (lambda ()
      (list (cons 'field value) ...)))))
