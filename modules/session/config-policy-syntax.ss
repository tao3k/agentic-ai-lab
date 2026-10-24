;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: user-facing session policy and transform facade forms.
;;; Invariant: forms create POO policy, validation, memory, and transform
;;; values only; runtime execution remains outside Scheme.

(import :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/policy
        (only-in :agentic-ai-lab/modules/session/config-session-syntax
                 agentic-ai-lab-session-syntax-chunk)
        :agentic-ai-lab/modules/session/policy
        :agentic-ai-lab/modules/session/policy-validation
        :agentic-ai-lab/modules/session/transform)

(export session-tool-grant
        session-tool-policy
        session-hook-tool-policy
        session-model-policy
        session-prompt-policy
        session-isolation-policy
        session-sandbox-policy
        session-context-policy
        session-history-policy
        session-communication-policy
        session-sharing-policy
        session-resource-policy
        session-resource-sharing-policy
        session-agent-execution-policy
        session-policy-with-durable
        session-policy-row
        session-policy-tool-attempt
        session-policy-validation
        session-policy-validation-row
        session-memory-intent
        session-transform
        transform-session)

;; session-tool-grant
;;   : (-> Syntax PooSessionToolGrant)
;;   | doc m%
;;       Tool grants are declaration rows. They name actions, resources, and
;;       triggers only; tool-core owns concrete tool specs.
;;       # Examples
;;       ```scheme
;;       (session-tool-grant build shell (read write) (workspace) (manual) (ci))
;;       ;; => agentic-ai-lab-session-tool-grant
;;       ```
;;     %
(defrules session-tool-grant ()
  ((_ grant-id tool-ref
      (action ...)
      (resource-ref ...)
      (trigger-ref ...)
      (metadata-entry ...))
   (agentic-ai-lab-session-tool-grant
    'grant-id
    'tool-ref
    '(action ...)
    '(resource-ref ...)
    '(trigger-ref ...)
    '(metadata-entry ...))))

;; session-tool-policy
;;   : (-> Syntax PooSessionPolicy)
;;   | doc m%
;;       Tool policy rows bind grants and denied refs to a scope. They do not
;;       inspect tool implementations or execute grants.
;;       # Examples
;;       ```scheme
;;       (session-tool-policy default project (build) (dangerous-tool) deny (ci))
;;       ;; => agentic-ai-lab-session-tool-permission-policy
;;       ```
;;     %
(defrules session-tool-policy ()
  ((_ policy-name scope-ref
      (grant ...)
      (denied-tool-ref ...)
      default-action
      (metadata-entry ...))
   (agentic-ai-lab-session-tool-permission-policy
    'policy-name
    'scope-ref
    (list grant ...)
    '(denied-tool-ref ...)
    'default-action
    '(metadata-entry ...))))

;; session-hook-tool-policy
;;   : (-> Syntax PooSessionPolicy)
;;   | doc m%
;;       Hook tool policy rows describe escalation and default actions for hook
;;       events. Runtime hook dispatch remains outside this facade.
;;       # Examples
;;       ```scheme
;;       (session-hook-tool-policy hooks project (pre-run) (build) review deny (ci))
;;       ;; => agentic-ai-lab-session-hook-tool-permission-policy
;;       ```
;;     %
(defrules session-hook-tool-policy ()
  ((_ policy-name scope-ref
      (hook-event ...)
      (grant ...)
      escalation-policy
      default-action
      (metadata-entry ...))
   (agentic-ai-lab-session-hook-tool-permission-policy
    'policy-name
    'scope-ref
    '(hook-event ...)
    (list grant ...)
    'escalation-policy
    'default-action
    '(metadata-entry ...))))

;; session-model-policy
;;   : (-> Syntax PooSessionPolicy)
;;   | doc m%
;;       Model policy rows name provider/model refs and budget metadata only.
;;       Provider routing and inference are runtime-owned.
;;       # Examples
;;       ```scheme
;;       (session-model-policy default project openai gpt (tool-use) budget (ci))
;;       ;; => agentic-ai-lab-session-model-policy
;;       ```
;;     %
(defrules session-model-policy ()
  ((_ policy-name scope-ref provider-ref model-ref
      (model-capability ...)
      budget-ref
      (metadata-entry ...))
   (agentic-ai-lab-session-model-policy
    'policy-name
    'scope-ref
    'provider-ref
    'model-ref
    '(model-capability ...)
    'budget-ref
    '(metadata-entry ...))))

;; session-prompt-policy
;;   : (-> Syntax PooSessionPolicy)
;;   | doc m%
;;       Prompt policy rows select prompt session/chunk refs. They do not fetch,
;;       compose, or mutate prompt content.
;;       # Examples
;;       ```scheme
;;       (session-prompt-policy default project prompt-session (system) scoped (ci))
;;       ;; => agentic-ai-lab-session-prompt-policy
;;       ```
;;     %
(defrules session-prompt-policy ()
  ((_ policy-name scope-ref prompt-session-ref
      (prompt-chunk-ref ...)
      context-mode
      (metadata-entry ...))
   (agentic-ai-lab-session-prompt-policy
    'policy-name
    'scope-ref
    'prompt-session-ref
    '(prompt-chunk-ref ...)
    'context-mode
    '(metadata-entry ...))))

;; session-isolation-policy
;;   : (-> Syntax PooSessionPolicy)
;;   | doc m%
;;       Isolation policy rows describe context and communication boundaries.
;;       They are validated as policy data before runtime handoff.
;;       # Examples
;;       ```scheme
;;       (session-isolation-policy strict project private deny gated (ci))
;;       ;; => agentic-ai-lab-session-isolation-policy
;;       ```
;;     %
(defrules session-isolation-policy ()
  ((_ policy-name scope-ref mode sibling-context parent-write
      peer-communication
      (metadata-entry ...))
   (agentic-ai-lab-session-isolation-policy
    'policy-name
    'scope-ref
    'mode
    'sibling-context
    'parent-write
    'peer-communication
    '(metadata-entry ...))))

;; session-sandbox-policy
;;   : (-> Syntax PooSessionPolicy)
;;   | doc m%
;;       Sandbox policy rows name profile refs and inheritance modes. Sandbox
;;       realization belongs to runtime/sandbox owners.
;;       # Examples
;;       ```scheme
;;       (session-sandbox-policy nono project nono-default inherit isolated (ci))
;;       ;; => agentic-ai-lab-session-sandbox-policy
;;       ```
;;     %
(defrules session-sandbox-policy ()
  ((_ policy-name scope-ref profile-ref inheritance-mode sharing-mode
      (metadata-entry ...))
   (agentic-ai-lab-session-sandbox-policy
    'policy-name
    'scope-ref
    'profile-ref
    'inheritance-mode
    'sharing-mode
    '(metadata-entry ...))))

;; session-context-policy
;;   : (-> Syntax PooSessionPolicy)
;;   | doc m%
;;       Context policy rows make visible which sessions can be read. The form
;;       is policy data and never opens a context store.
;;       # Examples
;;       ```scheme
;;       (session-context-policy default project parent-only (root) (ci))
;;       ;; => agentic-ai-lab-session-context-policy
;;       ```
;;     %
(defrules session-context-policy ()
  ((_ policy-name scope-ref visibility
      (allowed-session-ref ...)
      (metadata-entry ...))
   (agentic-ai-lab-session-context-policy
    'policy-name
    'scope-ref
    'visibility
    '(allowed-session-ref ...)
    '(metadata-entry ...))))

;; session-history-policy
;;   : (-> Syntax PooSessionPolicy)
;;   | doc m%
;;       History policy rows declare retention and allowed record kinds. They do
;;       not read or write history stores.
;;       # Examples
;;       ```scheme
;;       (session-history-policy default project durable (plan checkpoint) (ci))
;;       ;; => agentic-ai-lab-session-history-policy
;;       ```
;;     %
(defrules session-history-policy ()
  ((_ policy-name scope-ref retention
      (allowed-record ...)
      (metadata-entry ...))
   (agentic-ai-lab-session-history-policy
    'policy-name
    'scope-ref
    'retention
    '(allowed-record ...)
    '(metadata-entry ...))))

;; session-communication-policy
;;   : (-> Syntax PooSessionPolicy)
;;   | doc m%
;;       Communication policy rows name channels and targets. Message delivery
;;       stays runtime-owned.
;;       # Examples
;;       ```scheme
;;       (session-communication-policy default project (inbox) (worker) (ci))
;;       ;; => agentic-ai-lab-session-communication-policy
;;       ```
;;     %
(defrules session-communication-policy ()
  ((_ policy-name scope-ref
      (channel-ref ...)
      (target-session-ref ...)
      (metadata-entry ...))
   (agentic-ai-lab-session-communication-policy
    'policy-name
    'scope-ref
    '(channel-ref ...)
    '(target-session-ref ...)
    '(metadata-entry ...))))

;; session-sharing-policy
;;   : (-> Syntax PooSessionPolicy)
;;   | doc m%
;;       Sharing policy rows list memory, artifact, tool-result, and workspace
;;       handles. They remain handles until a runtime consumes them.
;;       # Examples
;;       ```scheme
;;       (session-sharing-policy default project (mem) (artifact) (tool) (workspace) (ci))
;;       ;; => agentic-ai-lab-session-sharing-policy
;;       ```
;;     %
(defrules session-sharing-policy ()
  ((_ policy-name scope-ref
      (memory-ref ...)
      (artifact-ref ...)
      (tool-result-ref ...)
      (workspace-path ...)
      (metadata-entry ...))
   (agentic-ai-lab-session-sharing-policy
    'policy-name
    'scope-ref
    '(memory-ref ...)
    '(artifact-ref ...)
    '(tool-result-ref ...)
    '(workspace-path ...)
    '(metadata-entry ...))))

;; session-resource-policy
;;   : (-> Syntax PooSessionPolicy)
;;   | doc m%
;;       Resource policy rows identify budget and capability refs. Accounting
;;       owners perform real metering outside this form.
;;       # Examples
;;       ```scheme
;;       (session-resource-policy default project (tokens) (network) accountant (ci))
;;       ;; => agentic-ai-lab-session-resource-policy
;;       ```
;;     %
(defrules session-resource-policy ()
  ((_ policy-name scope-ref
      (budget-ref ...)
      (capability-ref ...)
      accounting-owner
      (metadata-entry ...))
   (agentic-ai-lab-session-resource-policy
    'policy-name
    'scope-ref
    '(budget-ref ...)
    '(capability-ref ...)
    'accounting-owner
    '(metadata-entry ...))))

;; session-resource-sharing-policy
;;   : (-> Syntax PooSessionPolicy)
;;   | doc m%
;;       Resource sharing rows bind grants and default behavior. They do not
;;       allocate or release resources in Scheme.
;;       # Examples
;;       ```scheme
;;       (session-resource-sharing-policy default project (network) deny (ci))
;;       ;; => agentic-ai-lab-session-resource-sharing-policy
;;       ```
;;     %
(defrules session-resource-sharing-policy ()
  ((_ policy-name scope-ref
      (resource-grant ...)
      default-action
      (metadata-entry ...))
   (agentic-ai-lab-session-resource-sharing-policy
    'policy-name
    'scope-ref
    '(resource-grant ...)
    'default-action
    '(metadata-entry ...))))

;; session-agent-execution-policy
;;   : (-> Syntax PooSessionPolicy)
;;   | doc m%
;;       Agent execution policy rows connect model, prompt, tool, context, and
;;       resource policy refs for one agent/session pair.
;;       # Examples
;;       ```scheme
;;       (session-agent-execution-policy default agent session model prompt tools hooks context resources (ci))
;;       ;; => agentic-ai-lab-session-agent-execution-policy
;;       ```
;;     %
(defrules session-agent-execution-policy ()
  ((_ policy-name agent-ref session-ref model-policy-ref prompt-policy-ref
      tool-policy-ref hook-policy-ref context-policy-ref resource-policy-ref
      (metadata-entry ...))
   (agentic-ai-lab-session-agent-execution-policy
    'policy-name
    'agent-ref
    'session-ref
    'model-policy-ref
    'prompt-policy-ref
    'tool-policy-ref
    'hook-policy-ref
    'context-policy-ref
    'resource-policy-ref
    '(metadata-entry ...))))

;; : (-> PooSessionPolicy PooDurablePolicy PooSessionPolicy)
(def (session-policy-with-durable policy durable-policy)
  (agentic-ai-lab-session-policy-attach-durable policy durable-policy))

;; : (-> PooSessionPolicy Alist)
(def (session-policy-row policy)
  (agentic-ai-lab-session-policy->alist policy))

;; session-policy-tool-attempt
;;   : (-> Syntax PooSessionToolAttempt)
;;   | doc m%
;;       Tool attempts are validation inputs. They describe a requested action
;;       and principal without running the tool.
;;       # Examples
;;       ```scheme
;;       (session-policy-tool-attempt build hook shell read workspace agent (ci))
;;       ;; => agentic-ai-lab-session-policy-tool-attempt
;;       ```
;;     %
(defrules session-policy-tool-attempt ()
  ((_ attempt-id trigger-ref tool-ref action resource-ref principal-ref
      (metadata-entry ...))
   (agentic-ai-lab-session-policy-tool-attempt
    'attempt-id
    'trigger-ref
    'tool-ref
    'action
    'resource-ref
    'principal-ref
    '(metadata-entry ...)))
  ((_ attempt-id trigger-ref tool-ref action resource-ref principal-ref)
   (agentic-ai-lab-session-policy-tool-attempt
    'attempt-id
    'trigger-ref
    'tool-ref
    'action
    'resource-ref
    'principal-ref)))

;; session-policy-validation
;;   : (-> Syntax PooSessionPolicyValidationReceipt)
;;   | doc m%
;;       Validation receipts bind effective policy, requested refs, attempts,
;;       and owner metadata. They never execute the allowed operation.
;;       # Examples
;;       ```scheme
;;       (session-policy-validation v project model prompt iso sandbox context history comm sharing resources tools hooks () () () () () () ())
;;       ;; => agentic-ai-lab-session-policy-validation-receipt
;;       ```
;;     %
(defrules session-policy-validation ()
  ((_ validation-id scope-ref
      model-policy prompt-policy isolation-policy sandbox-policy
      context-policy history-policy communication-policy
      sharing-policy resource-policy agent-tool-policy hook-tool-policy
      (requested-context-ref ...)
      (requested-history-record ...)
      (requested-channel-ref ...)
      (requested-resource-ref ...)
      (agent-tool-attempt ...)
      (hook-tool-attempt ...)
      metadata)
   (agentic-ai-lab-session-policy-validation-receipt
    'validation-id
    'scope-ref
    model-policy
    prompt-policy
    isolation-policy
    sandbox-policy
    context-policy
    history-policy
    communication-policy
    sharing-policy
    resource-policy
    agent-tool-policy
    hook-tool-policy
    '(requested-context-ref ...)
    '(requested-history-record ...)
    '(requested-channel-ref ...)
    '(requested-resource-ref ...)
    (list agent-tool-attempt ...)
    (list hook-tool-attempt ...)
    metadata)))

;; : (-> PooSessionPolicyValidationReceipt Alist)
(def (session-policy-validation-row receipt)
  (agentic-ai-lab-session-policy-validation-receipt->alist receipt))

;; session-memory-intent
;;   : (-> Syntax PooSessionMemoryIntent)
;;   | doc m%
;;       `session-memory-intent` describes runtime memory recall or commit
;;       requests without reaching into a memory backend from Scheme.
;;
;;       # Examples
;;       ```scheme
;;       (session-memory-intent recall-plan
;;         (store session-store)
;;         (scope current-session)
;;         (recall prior-task)
;;         (commit review-only))
;;       ;; => agentic-ai-lab-session-memory-intent
;;       ```
;;     %
(defrules session-memory-intent (store scope recall commit metadata)
  ((_ intent-name
      (store store-ref)
      (scope scope-value)
      (recall recall-key ...)
      (commit commit-policy)
      (metadata metadata-entry ...))
   (agentic-ai-lab-session-memory-intent
    'intent-name
    'store-ref
    'scope-value
    '(recall-key ...)
    'commit-policy
    '(metadata-entry ...)))
  ((_ intent-name
      (store store-ref)
      (scope scope-value)
      (recall recall-key ...)
      (commit commit-policy))
   (agentic-ai-lab-session-memory-intent
    'intent-name
    'store-ref
    'scope-value
    '(recall-key ...)
    'commit-policy)))

;; session-transform
;;   : (-> Syntax PooSessionTransform)
;;   | doc m%
;;       `session-transform` keeps the agent-flow layer declarative. It creates
;;       a POO transform spec and never invokes a provider.
;;
;;       # Examples
;;       ```scheme
;;       (session-transform review
;;         (intent review-session)
;;         (description "Review the session")
;;         (capabilities search query))
;;       ;; => agentic-ai-lab-session-transform
;;       ```
;;     %
(defrules session-transform (intent description capabilities memory-intents metadata)
  ((_ transform-name
      (intent intent-value)
      (description description-value)
      (capabilities capability ...)
      (memory-intents memory-intent ...)
      (metadata metadata-entry ...))
   (agentic-ai-lab-session-transform
    'transform-name
    'intent-value
    description-value
    '(capability ...)
    '(metadata-entry ...)
    (list memory-intent ...)))
  ((_ transform-name
      (intent intent-value)
      (description description-value)
      (capabilities capability ...)
      (memory-intents memory-intent ...))
   (agentic-ai-lab-session-transform
    'transform-name
    'intent-value
    description-value
    '(capability ...)
    (list memory-intent ...)))
  ((_ transform-name
      (intent intent-value)
      (description description-value)
      (capabilities capability ...)
      (metadata metadata-entry ...))
   (agentic-ai-lab-session-transform
    'transform-name
    'intent-value
    description-value
    '(capability ...)
    '(metadata-entry ...)))
  ((_ transform-name
      (intent intent-value)
      (description description-value)
      (capabilities capability ...))
   (agentic-ai-lab-session-transform
    'transform-name
    'intent-value
    description-value
    '(capability ...))))

;; transform-session
;;   : (-> Syntax PooSessionTransformReceipt)
;;   | doc m%
;;       `transform-session` derives a new session value and receipt. Runtime
;;       work remains in the handoff intent emitted by the receipt.
;;
;;       # Examples
;;       ```scheme
;;       (transform-session review root-session reviewed-session
;;         (chunk review assistant "Reviewed."))
;;       ;; => agentic-ai-lab-session-transform-receipt
;;       ```
;;     %
(defrules transform-session (chunk metadata)
  ((_ transform source-session derived-session-id
      (chunk chunk-id role content)
      ...
      (metadata metadata-entry ...))
   (agentic-ai-lab-session-transform-apply
    transform
    source-session
    'derived-session-id
    (list (agentic-ai-lab-session-syntax-chunk 'chunk-id 'role content) ...)
    '(metadata-entry ...)))
  ((_ transform source-session derived-session-id
      (chunk chunk-id role content)
      ...)
   (agentic-ai-lab-session-transform-apply
    transform
    source-session
    'derived-session-id
    (list (agentic-ai-lab-session-syntax-chunk 'chunk-id 'role content) ...))))
