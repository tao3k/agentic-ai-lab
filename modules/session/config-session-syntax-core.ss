;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: config-session core syntax owns the shared macro substrate for the
;;; session module category and its feature-level expansions.
;;; Invariant: core expansions must stay deterministic for loader and policy
;;; diagnostics.
(import :agentic-ai-lab/modules/session/config-session-runtime)

(export session
        session-graph
        session-registry-entry
        session-registry)

;; session
;;   : (-> Syntax PooSessionValue)
;;   | doc m%
;;       `session` keeps user-facing session declarations close to the
;;       OpenRath tutorial shape while expanding to ordinary POO session
;;       objects.
;;
;;       # Examples
;;       ```scheme
;;       (session custom/root
;;         (chunk request user "Run checks.")
;;         (lineage root)
;;         (placement agent/nono)
;;         (metadata (source . user-interface)))
;;       ;; => poo-session-value
;;       ```
;;     %
(defrules session (chunk lineage placement metadata)
  ((_ session-id
      (chunk chunk-id role content)
      ...
      (lineage branch-kind parent-id ...)
      (placement profile-ref)
      (metadata metadata-entry ...))
   (agentic-ai-lab-session-syntax-value
    'session-id
    (list (agentic-ai-lab-session-syntax-chunk 'chunk-id 'role content) ...)
    (agentic-ai-lab-session-syntax-lineage
     'session-id
     '(parent-id ...)
     'branch-kind)
    (agentic-ai-lab-session-syntax-default-placement
     'profile-ref
     '(metadata-entry ...))
    '(metadata-entry ...)))
  ((_ session-id
      (chunk chunk-id role content)
      ...
      (lineage branch-kind parent-id ...)
      (placement profile-ref))
   (agentic-ai-lab-session-syntax-value
    'session-id
    (list (agentic-ai-lab-session-syntax-chunk 'chunk-id 'role content) ...)
    (agentic-ai-lab-session-syntax-lineage
     'session-id
     '(parent-id ...)
     'branch-kind)
    (agentic-ai-lab-session-syntax-default-placement 'profile-ref))))

;; session-graph
;;   : (-> PooSessionValue ... PooSessionGraphPresentation)
;;   | doc m%
;;       `session-graph` mirrors the declaration form: users list session values
;;       and receive the existing report-only graph receipt.
;;
;;       # Examples
;;       ```scheme
;;       (session-graph root-session branch-session)
;;       ;; => agenticAiLabSessionGraphPresentation receipt
;;       ```
;;     %
(def (session-graph . session-values)
  (agentic-ai-lab-session-syntax-graph-presentation session-values))

;; session-registry-entry
;;   : (-> Syntax PooSessionRegistryEntry)
;;   | doc m%
;;       User-facing registry entries describe the session address space without
;;       exposing the lower-level registry constructor.
;;     %
;; session-registry-entry
;; : (-> SessionRegistryEntrySyntax SessionRegistryEntryObject)
;; | doc m%
;;   Build one session registry row that connects a session value with its
;;   owning agent, communication channels, policy summaries, and metadata.
;;   # Examples
;;   ```scheme
;;   (session-registry-entry root (agent planner) (channels inbox) (policies))
;;   ;; => session-registry-entry object
;;   ```
(defrules session-registry-entry (agent channels policies metadata)
  ((_ session-value
      (agent agent-id)
      (channels channel-id ...)
      (policies (policy-kind policy-summary) ...)
      (metadata metadata-entry ...))
   (agentic-ai-lab-session-syntax-registry-entry
    session-value
    'agent-id
    '(channel-id ...)
    '((policy-kind . policy-summary) ...)
    '(metadata-entry ...)))
  ((_ session-value
      (agent agent-id)
      (channels channel-id ...)
      (policies (policy-kind policy-summary) ...))
   (agentic-ai-lab-session-syntax-registry-entry
    session-value
    'agent-id
    '(channel-id ...)
    '((policy-kind . policy-summary) ...))))

;; session-registry
;;   : (-> Syntax PooSessionRegistryReceipt)
;;   | doc m%
;;       Registry declarations keep project/root/child topology visible at the
;;       module facade and leave live runtime state to Marlin.
;;     %
;; session-registry
;; : (-> SessionRegistrySyntax SessionRegistryObject)
;; | doc m%
;;   Build the project-level session registry receipt that records root,
;;   child, active, and entry relationships for durable routing.
;;   # Examples
;;   ```scheme
;;   (session-registry project (roots root) (children worker) (active root) (entries))
;;   ;; => session-registry object
;;   ```
(defrules session-registry (roots children active entries metadata)
  ((_ project-id
      (roots root-session-id ...)
      (children child-session-id ...)
      (active active-session-ref)
      (entries entry ...)
      (metadata metadata-entry ...))
   (agentic-ai-lab-session-syntax-registry
    'project-id
    '(root-session-id ...)
    '(child-session-id ...)
    'active-session-ref
    (list entry ...)
    '(metadata-entry ...)))
  ((_ project-id
      (roots root-session-id ...)
      (children child-session-id ...)
      (active active-session-ref)
      (entries entry ...))
   (agentic-ai-lab-session-syntax-registry
    'project-id
    '(root-session-id ...)
    '(child-session-id ...)
    'active-session-ref
    (list entry ...))))
