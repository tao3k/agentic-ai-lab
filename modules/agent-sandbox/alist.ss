;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Owner: shared agent-sandbox alist combinators live in this utility module.
;;; Boundary: profile, request, and bridge modules reuse these helpers only.
;;; Runtime contract: this module performs no backend selection or execution.
;;; Policy evidence: larger extension owners should import these helpers.

(import :core/utilities/functional)

(export agent-sandbox-option
        agent-sandbox-alist-ref
        agent-sandbox-merge-alists
        agent-sandbox-override)

;;; Run-config and profile options stay alist-shaped so bridge commands can pass
;;; metadata without adding Scheme structs at every extension boundary.
;; : (-> AgentSandboxOptionRows Symbol DefaultOptionValue AgentSandboxOptionValue)
(def (agent-sandbox-option options key default)
  (agent-sandbox-alist-ref options key default))

;;; Optional extension metadata sometimes crosses owner boundaries as `#f`,
;;; symbolic policy names, or partial rows before a validator normalizes it.
;;; Lookup treats those values as absent so validators can report field-level
;;; errors instead of leaking a generic `assoc` exception from this helper.
;; agent-sandbox-alist-ref
;;   : (-> MaybeAgentSandboxOptionRows Symbol DefaultOptionValue AgentSandboxOptionValue)
;;   | contract: lookup a key in optional alist-shaped extension metadata
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agent-sandbox-alist-ref '((network . blocked)) 'network 'missing)
;;       ;; => blocked
;;       ```
;;     %
(def (agent-sandbox-alist-ref alist key default)
  (poo-flow-alist-ref/default
   (agent-sandbox-normalize-alist alist)
   key
   default))

;;; Normalization is intentionally lossy for non-pair fragments: callers use
;;; this utility when they need alist semantics, not raw user syntax recovery.
;; : (-> MaybeAgentSandboxOptionRows AgentSandboxOptionRows)
(def (agent-sandbox-normalize-alist alist)
  (if (list? alist)
    (poo-flow-filter-map
     (lambda (entry)
       (and (pair? entry) entry))
     alist)
    '()))

;;; Alist merge keeps task-local policy first. Downstream bridges that use
;;; assoc get task overrides before profile defaults.
;; : (-> MaybeAgentSandboxOptionRows MaybeAgentSandboxOptionRows AgentSandboxOptionRows)
(def (agent-sandbox-merge-alists primary secondary)
  (poo-flow-append-map
   agent-sandbox-normalize-alist
   (list primary secondary)))

;;; False means "use profile default".
;;; An empty alist is still an explicit task-level override.
;; : (-> MaybeTaskOverrideValue ProfileDefaultValue EffectiveSandboxValue)
(def (agent-sandbox-override value default)
  (if value value default))
