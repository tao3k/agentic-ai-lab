;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Owns the validation receipt record and pure admission construction.
;;; ABI/report projection is isolated in policy-validation-receipt-projection.ss.
(import :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/session/policy
        :agentic-ai-lab/modules/session/policy-validation-support
        :agentic-ai-lab/modules/session/policy-validation-communication
        :agentic-ai-lab/modules/session/policy-validation-catalog)

(export (struct-out agentic-ai-lab-session-policy-validation-receipt-record)
        agentic-ai-lab-session-policy-validation-receipt
        agentic-ai-lab-session-policy-validation-receipt?
        agentic-ai-lab-session-policy-validation-receipt-validation-id
        agentic-ai-lab-session-policy-validation-receipt-effective-model-ref
        agentic-ai-lab-session-policy-validation-receipt-effective-prompt-session-ref
        agentic-ai-lab-session-policy-validation-receipt-effective-prompt-chunk-refs
        agentic-ai-lab-session-policy-validation-receipt-effective-isolation-mode
        agentic-ai-lab-session-policy-validation-receipt-effective-sandbox-profile-ref
        agentic-ai-lab-session-policy-validation-receipt-tool-catalog-ref
        agentic-ai-lab-session-policy-validation-receipt-tool-catalog-valid?
        agentic-ai-lab-session-policy-validation-receipt-tool-catalog-policy-tool-refs
        agentic-ai-lab-session-policy-validation-receipt-tool-catalog-resolved-tool-refs
        agentic-ai-lab-session-policy-validation-receipt-tool-catalog-unresolved-tool-refs
        agentic-ai-lab-session-policy-validation-receipt-tool-catalog-allowed-attempt-tool-refs
        agentic-ai-lab-session-policy-validation-receipt-tool-catalog-unresolved-attempt-tool-refs
        agentic-ai-lab-session-policy-validation-receipt-memory-catalog-ref
        agentic-ai-lab-session-policy-validation-receipt-memory-catalog-valid?
        agentic-ai-lab-session-policy-validation-receipt-memory-catalog-resolved-store-refs
        agentic-ai-lab-session-policy-validation-receipt-memory-catalog-unresolved-store-refs
        agentic-ai-lab-session-policy-validation-receipt-allowed-communication-channel-receipts
        agentic-ai-lab-session-policy-validation-receipt-denied-communication-channel-receipts
        agentic-ai-lab-session-policy-validation-receipt-allowed-communication-receipts
        agentic-ai-lab-session-policy-validation-receipt-denied-communication-receipts
        agentic-ai-lab-session-policy-validation-receipt-valid?
        agentic-ai-lab-session-policy-validation-receipt-diagnostic-count
        agentic-ai-lab-session-policy-validation-receipt-diagnostics
        agentic-ai-lab-session-policy-validation-receipt-runtime-executed?)

(defstruct agentic-ai-lab-session-policy-validation-receipt-record
  (validation-id
   scope-ref
   valid?
   effective-model-ref
   effective-prompt-session-ref
   effective-prompt-chunk-refs
   effective-isolation-mode
   isolation-sibling-context
   isolation-parent-write
   isolation-peer-communication
   effective-sandbox-profile-ref
   sandbox-inheritance-mode
   sandbox-sharing-mode
   allowed-context-refs
   denied-context-refs
   allowed-history-records
   denied-history-records
   allowed-communication-channels
   denied-communication-channels
   allowed-communication-channel-receipts
   denied-communication-channel-receipts
   allowed-communication-receipts
   denied-communication-receipts
   allowed-resource-refs
   denied-resource-refs
   allowed-agent-tool-attempts
   denied-agent-tool-attempts
   allowed-hook-tool-attempts
   denied-hook-tool-attempts
   tool-catalog-validation-id
   tool-catalog-ref
   tool-catalog-valid?
   tool-catalog-policy-tool-refs
   tool-catalog-resolved-tool-refs
   tool-catalog-unresolved-tool-refs
   tool-catalog-sandbox-required-tool-refs
   tool-catalog-action-mismatch-grants
   tool-catalog-allowed-attempt-tool-refs
   tool-catalog-unresolved-attempt-tool-refs
   memory-catalog-validation-id
   memory-catalog-ref
   memory-catalog-valid?
   memory-catalog-store-count
   memory-catalog-store-refs
   memory-catalog-intent-count
   memory-catalog-intent-store-refs
   memory-catalog-resolved-store-refs
   memory-catalog-unresolved-store-refs
   shared-resource-grants
   diagnostic-count
   diagnostics
   runtime-owner
   runtime-executed?
   metadata)
  transparent: #t)

;;; Admission boundary: partition every requested capability and retain both allowed and denied evidence.
;;; Invariant: construction records runtime ownership but never executes the runtime.
;; : (forall (p s a m) (-> Symbol Symbol p p p p p p p p p p p [s] [s] [s] [s] [a] [a] [m] PooSessionPolicyValidationReceipt))
;; : (-> Symbol Symbol PooSessionPolicy PooSessionPolicy PooSessionPolicy PooSessionPolicy PooSessionPolicy PooSessionPolicy PooSessionPolicy PooSessionPolicy PooSessionPolicy PooSessionPolicy PooSessionPolicy [Symbol] [Symbol] [Symbol] [Symbol] [PooSessionToolAttempt] [PooSessionToolAttempt] [Alist] PooSessionPolicyValidationReceipt)
(def (agentic-ai-lab-session-policy-validation-receipt validation-id
                                                scope-ref
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
                                                requested-context-refs
                                                requested-history-records
                                                requested-channel-refs
                                                requested-resource-refs
                                                agent-tool-attempts
                                                hook-tool-attempts
                                                . maybe-metadata)
  (agentic-ai-lab-session-require "session policy validation id must be a symbol"
                            (symbol? validation-id)
                            validation-id)
  (agentic-ai-lab-session-require "session policy validation scope must be a symbol"
                            (symbol? scope-ref)
                            scope-ref)
  (agentic-ai-lab-session-require "session policy validation model policy required"
                            (agentic-ai-lab-session-policy? model-policy)
                            model-policy)
  (agentic-ai-lab-session-require "session policy validation prompt policy required"
                            (agentic-ai-lab-session-policy? prompt-policy)
                            prompt-policy)
  (agentic-ai-lab-session-require "session policy validation isolation policy required"
                            (agentic-ai-lab-session-policy? isolation-policy)
                            isolation-policy)
  (agentic-ai-lab-session-require "session policy validation sandbox policy required"
                            (agentic-ai-lab-session-policy? sandbox-policy)
                            sandbox-policy)
  (agentic-ai-lab-session-require "session policy validation context policy required"
                            (agentic-ai-lab-session-policy? context-policy)
                            context-policy)
  (agentic-ai-lab-session-require "session policy validation history policy required"
                            (agentic-ai-lab-session-policy? history-policy)
                            history-policy)
  (agentic-ai-lab-session-require "session policy validation communication policy required"
                            (agentic-ai-lab-session-policy? communication-policy)
                            communication-policy)
  (agentic-ai-lab-session-require "session policy validation sharing policy required"
                            (agentic-ai-lab-session-policy? sharing-policy)
                            sharing-policy)
  (agentic-ai-lab-session-require "session policy validation resource policy required"
                            (agentic-ai-lab-session-policy? resource-policy)
                            resource-policy)
  (agentic-ai-lab-session-require "session policy validation agent tool policy required"
                            (agentic-ai-lab-session-policy? agent-tool-policy)
                            agent-tool-policy)
  (agentic-ai-lab-session-require "session policy validation hook tool policy required"
                            (agentic-ai-lab-session-policy? hook-tool-policy)
                            hook-tool-policy)
  (agentic-ai-lab-session-require "session policy validation agent attempts must be attempts"
                            (agentic-ai-lab-session-every?
                             agentic-ai-lab-session-policy-tool-attempt?
                             agent-tool-attempts)
                            agent-tool-attempts)
  (agentic-ai-lab-session-require "session policy validation hook attempts must be attempts"
                            (agentic-ai-lab-session-every?
                             agentic-ai-lab-session-policy-tool-attempt?
                             hook-tool-attempts)
                            hook-tool-attempts)
  (let* ((context-ref-partition
          (agentic-ai-lab-session-policy-partition-refs
           requested-context-refs
           (agentic-ai-lab-session-policy-context-allowed context-policy)))
         (allowed-context-refs
          (agentic-ai-lab-session-validation-partition-accepted
           context-ref-partition))
         (denied-context-refs
          (agentic-ai-lab-session-validation-partition-rejected
           context-ref-partition))
         (history-record-partition
          (agentic-ai-lab-session-policy-partition-refs
           requested-history-records
           (agentic-ai-lab-session-policy-history-allowed history-policy)))
         (allowed-history-records
          (agentic-ai-lab-session-validation-partition-accepted
           history-record-partition))
         (denied-history-records
          (agentic-ai-lab-session-validation-partition-rejected
           history-record-partition))
         (communication-channel-partition
          (agentic-ai-lab-session-policy-partition-refs
           requested-channel-refs
           (agentic-ai-lab-session-policy-channel-allowed communication-policy)))
         (allowed-communication-channels
          (agentic-ai-lab-session-validation-partition-accepted
           communication-channel-partition))
         (denied-communication-channels
          (agentic-ai-lab-session-validation-partition-rejected
           communication-channel-partition))
         (resource-ref-partition
          (agentic-ai-lab-session-policy-partition-refs
           requested-resource-refs
           (agentic-ai-lab-session-policy-resource-capabilities resource-policy)))
         (allowed-resource-refs
          (agentic-ai-lab-session-validation-partition-accepted
           resource-ref-partition))
         (denied-resource-refs
          (agentic-ai-lab-session-validation-partition-rejected
           resource-ref-partition))
         (agent-tool-attempt-partition
          (agentic-ai-lab-session-validation-partition/with-context
           agentic-ai-lab-session-agent-tool-attempt-allowed?
           agent-tool-policy
           agent-tool-attempts))
         (allowed-agent-tool-attempts
          (agentic-ai-lab-session-validation-partition-accepted
           agent-tool-attempt-partition))
         (denied-agent-tool-attempts
          (agentic-ai-lab-session-validation-partition-rejected
           agent-tool-attempt-partition))
         (hook-tool-attempt-partition
          (agentic-ai-lab-session-validation-partition/with-context
           agentic-ai-lab-session-hook-tool-attempt-allowed?
           hook-tool-policy
           hook-tool-attempts))
         (allowed-hook-tool-attempts
          (agentic-ai-lab-session-validation-partition-accepted
           hook-tool-attempt-partition))
         (denied-hook-tool-attempts
          (agentic-ai-lab-session-validation-partition-rejected
           hook-tool-attempt-partition))
         (metadata
          (match maybe-metadata
            ([] '())
            ([value . _] value)))
         (communication-channel-receipt-rows
          (agentic-ai-lab-session-policy-communication-channel-receipt-rows
           (agentic-ai-lab-session-policy-communication-channel-receipts metadata)))
         (communication-channel-receipt-partition
          (agentic-ai-lab-session-validation-partition/with-context
           agentic-ai-lab-session-policy-communication-channel-receipt-allowed?
           communication-policy
           communication-channel-receipt-rows))
         (allowed-communication-channel-receipts
          (agentic-ai-lab-session-validation-partition-accepted
           communication-channel-receipt-partition))
         (denied-communication-channel-receipts
          (agentic-ai-lab-session-validation-partition-rejected
           communication-channel-receipt-partition))
         (communication-receipt-rows
          (agentic-ai-lab-session-policy-communication-receipt-rows
           (agentic-ai-lab-session-policy-communication-receipts metadata)))
         (communication-receipt-partition
          (agentic-ai-lab-session-validation-partition/with-context
           agentic-ai-lab-session-policy-communication-receipt-allowed?
           communication-policy
           communication-receipt-rows))
         (allowed-communication-receipts
          (agentic-ai-lab-session-validation-partition-accepted
           communication-receipt-partition))
         (denied-communication-receipts
          (agentic-ai-lab-session-validation-partition-rejected
           communication-receipt-partition))
         (tool-catalog-validation
          (agentic-ai-lab-session-tool-catalog-validation metadata))
         (tool-catalog-diagnostics
          (agentic-ai-lab-session-tool-catalog-validation-ref
           tool-catalog-validation
           'diagnostics
           '()))
         (allowed-attempt-tool-refs
          (agentic-ai-lab-session-policy-attempt-tool-refs
           allowed-agent-tool-attempts
           allowed-hook-tool-attempts))
         (catalog-attempt-ref-partition
          (agentic-ai-lab-session-policy-catalog-attempt-ref-partition
           tool-catalog-validation
           allowed-attempt-tool-refs))
         (tool-catalog-allowed-attempt-tool-refs
          (agentic-ai-lab-session-validation-partition-accepted
           catalog-attempt-ref-partition))
         (tool-catalog-unresolved-attempt-tool-refs
          (agentic-ai-lab-session-validation-partition-rejected
           catalog-attempt-ref-partition))
         (memory-catalog-validation
          (agentic-ai-lab-session-memory-catalog-validation metadata))
         (memory-catalog-diagnostics
          (agentic-ai-lab-session-memory-catalog-validation-ref
           memory-catalog-validation
           'diagnostics
           '()))
         (sibling-session-refs
          (agentic-ai-lab-session-validation-alist-ref
           metadata
           'sibling-session-refs
           '()))
         (denied-sibling-context-refs
          (agentic-ai-lab-session-policy-denied-sibling-context-refs
           requested-context-refs
           sibling-session-refs
           isolation-policy))
         (diagnostics
          (let* ((diagnostics0
                  (agentic-ai-lab-session-denied-ref-diagnostics/rev
                   'context-session-not-granted
                   scope-ref
                   denied-context-refs
                   '()))
                 (diagnostics1
                  (agentic-ai-lab-session-denied-ref-diagnostics/rev
                   'history-record-not-granted
                   scope-ref
                   denied-history-records
                   diagnostics0))
                 (diagnostics2
                  (agentic-ai-lab-session-denied-ref-diagnostics/rev
                   'communication-channel-not-granted
                   scope-ref
                   denied-communication-channels
                   diagnostics1))
                 (diagnostics2channel
                  (agentic-ai-lab-session-communication-channel-receipt-diagnostics/rev
                   scope-ref
                   communication-policy
                   communication-channel-receipt-rows
                   diagnostics2))
                 (diagnostics2a
                  (agentic-ai-lab-session-communication-channel-diagnostics/rev
                   scope-ref
                   communication-policy
                   communication-receipt-rows
                   diagnostics2channel))
                 (diagnostics2b
                  (agentic-ai-lab-session-communication-target-diagnostics/rev
                   scope-ref
                   communication-policy
                   communication-receipt-rows
                   diagnostics2a))
                 (diagnostics3
                  (agentic-ai-lab-session-denied-ref-diagnostics/rev
                   'resource-capability-not-granted
                   scope-ref
                   denied-resource-refs
                   diagnostics2b))
                 (diagnostics4
                  (agentic-ai-lab-session-tool-attempt-diagnostics/rev
                   'agent-tool-attempt-not-granted
                   denied-agent-tool-attempts
                   diagnostics3))
                 (diagnostics5
                  (agentic-ai-lab-session-tool-attempt-diagnostics/rev
                   'hook-tool-attempt-not-granted
                   denied-hook-tool-attempts
                   diagnostics4))
                 (diagnostics6
                  (agentic-ai-lab-session-hook-inheritance-diagnostics/rev
                   agent-tool-policy
                   denied-hook-tool-attempts
                   diagnostics5))
                 (diagnostics7
                  (agentic-ai-lab-session-denied-ref-diagnostics/rev
                   'sibling-context-not-granted
                   scope-ref
                   denied-sibling-context-refs
                   diagnostics6))
                 (diagnostics8
                  (if (agentic-ai-lab-session-resource-policy-accounted?
                       sharing-policy)
                    diagnostics7
                    (cons (agentic-ai-lab-session-policy-diagnostic
                           'resource-sharing-missing-accounting-owner
                           scope-ref
                           (agentic-ai-lab-session-policy-resource-grants
                            sharing-policy))
                          diagnostics7)))
                 (diagnostics9
                  (agentic-ai-lab-session-validation-reverse-onto
                   tool-catalog-diagnostics
                   diagnostics8))
                 (diagnostics9a
                  (agentic-ai-lab-session-denied-ref-diagnostics/rev
                   'tool-attempt-not-in-catalog
                   scope-ref
                   tool-catalog-unresolved-attempt-tool-refs
                   diagnostics9))
                 (diagnostics10
                  (agentic-ai-lab-session-validation-reverse-onto
                   memory-catalog-diagnostics
                   diagnostics9a)))
            (reverse diagnostics10))))
    (make-agentic-ai-lab-session-policy-validation-receipt-record
     validation-id
     scope-ref
     (null? diagnostics)
     (agentic-ai-lab-session-policy-slot-value model-policy 'model-ref #f)
     (agentic-ai-lab-session-policy-slot-value
      prompt-policy
      'prompt-session-ref
      #f)
     (agentic-ai-lab-session-policy-slot-value
      prompt-policy
      'prompt-chunk-refs
      '())
     (agentic-ai-lab-session-policy-isolation-mode isolation-policy)
     (agentic-ai-lab-session-policy-isolation-sibling-context isolation-policy)
     (agentic-ai-lab-session-policy-isolation-parent-write isolation-policy)
     (agentic-ai-lab-session-policy-isolation-peer-communication isolation-policy)
     (agentic-ai-lab-session-policy-sandbox-profile-ref sandbox-policy)
     (agentic-ai-lab-session-policy-sandbox-inheritance-mode sandbox-policy)
     (agentic-ai-lab-session-policy-sandbox-sharing-mode sandbox-policy)
     allowed-context-refs
     denied-context-refs
     allowed-history-records
     denied-history-records
     allowed-communication-channels
     denied-communication-channels
     allowed-communication-channel-receipts
     denied-communication-channel-receipts
     allowed-communication-receipts
     denied-communication-receipts
     allowed-resource-refs
     denied-resource-refs
     allowed-agent-tool-attempts
     denied-agent-tool-attempts
     allowed-hook-tool-attempts
     denied-hook-tool-attempts
     (agentic-ai-lab-session-tool-catalog-validation-ref
      tool-catalog-validation
      'validation-id
      #f)
     (agentic-ai-lab-session-tool-catalog-validation-ref
      tool-catalog-validation
      'catalog-ref
      #f)
     (agentic-ai-lab-session-tool-catalog-validation-ref
      tool-catalog-validation
      'valid?
      #f)
     (agentic-ai-lab-session-tool-catalog-validation-ref
      tool-catalog-validation
      'policy-tool-refs
      '())
     (agentic-ai-lab-session-tool-catalog-validation-ref
      tool-catalog-validation
      'resolved-tool-refs
      '())
     (agentic-ai-lab-session-tool-catalog-validation-ref
      tool-catalog-validation
      'unresolved-tool-refs
      '())
     (agentic-ai-lab-session-tool-catalog-validation-ref
      tool-catalog-validation
      'sandbox-required-tool-refs
      '())
     (agentic-ai-lab-session-tool-catalog-validation-ref
      tool-catalog-validation
      'action-mismatch-grants
      '())
     tool-catalog-allowed-attempt-tool-refs
     tool-catalog-unresolved-attempt-tool-refs
     (agentic-ai-lab-session-memory-catalog-validation-ref
      memory-catalog-validation
      'validation-id
      #f)
     (agentic-ai-lab-session-memory-catalog-validation-ref
      memory-catalog-validation
      'catalog-ref
      #f)
     (agentic-ai-lab-session-memory-catalog-validation-ref
      memory-catalog-validation
      'valid?
      #f)
     (agentic-ai-lab-session-memory-catalog-validation-ref
      memory-catalog-validation
      'catalog-store-count
      0)
     (agentic-ai-lab-session-memory-catalog-validation-ref
      memory-catalog-validation
      'catalog-store-refs
      '())
     (agentic-ai-lab-session-memory-catalog-validation-ref
      memory-catalog-validation
      'intent-count
      0)
     (agentic-ai-lab-session-memory-catalog-validation-ref
      memory-catalog-validation
      'intent-store-refs
      '())
     (agentic-ai-lab-session-memory-catalog-validation-ref
      memory-catalog-validation
      'resolved-store-refs
      '())
     (agentic-ai-lab-session-memory-catalog-validation-ref
      memory-catalog-validation
      'unresolved-store-refs
      '())
     (agentic-ai-lab-session-policy-resource-grants sharing-policy)
     (length diagnostics)
     diagnostics
     "marlin-agent-core"
     #f
     metadata)))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-session-policy-validation-receipt? value)
  (agentic-ai-lab-session-policy-validation-receipt-record? value))

;;; Keep these as named definitions so policy reports attach diagnostics to
;;; stable runtime bindings rather than a top-level accessor macro call.
;; : (-> PooSessionPolicyValidationReceipt Symbol)
(def (agentic-ai-lab-session-policy-validation-receipt-validation-id receipt)
  (agentic-ai-lab-session-policy-validation-receipt-record-validation-id receipt))

;; : (-> PooSessionPolicyValidationReceipt Object)
(def (agentic-ai-lab-session-policy-validation-receipt-effective-model-ref receipt)
  (agentic-ai-lab-session-policy-validation-receipt-record-effective-model-ref
   receipt))

;; : (-> PooSessionPolicyValidationReceipt Object)
(def (agentic-ai-lab-session-policy-validation-receipt-effective-prompt-session-ref
      receipt)
  (agentic-ai-lab-session-policy-validation-receipt-record-effective-prompt-session-ref
   receipt))

;; : (-> PooSessionPolicyValidationReceipt [Symbol])
(def (agentic-ai-lab-session-policy-validation-receipt-effective-prompt-chunk-refs
      receipt)
  (agentic-ai-lab-session-policy-validation-receipt-record-effective-prompt-chunk-refs
   receipt))

;; : (-> PooSessionPolicyValidationReceipt Object)
(def (agentic-ai-lab-session-policy-validation-receipt-effective-isolation-mode
      receipt)
  (agentic-ai-lab-session-policy-validation-receipt-record-effective-isolation-mode
   receipt))

;; : (-> PooSessionPolicyValidationReceipt Object)
(def (agentic-ai-lab-session-policy-validation-receipt-effective-sandbox-profile-ref
      receipt)
  (agentic-ai-lab-session-policy-validation-receipt-record-effective-sandbox-profile-ref
   receipt))

;; : (-> PooSessionPolicyValidationReceipt Object)
(def (agentic-ai-lab-session-policy-validation-receipt-tool-catalog-ref receipt)
  (agentic-ai-lab-session-policy-validation-receipt-record-tool-catalog-ref receipt))

;; : (-> PooSessionPolicyValidationReceipt Boolean)
(def (agentic-ai-lab-session-policy-validation-receipt-tool-catalog-valid? receipt)
  (agentic-ai-lab-session-policy-validation-receipt-record-tool-catalog-valid?
   receipt))

;; : (-> PooSessionPolicyValidationReceipt [Symbol])
(def (agentic-ai-lab-session-policy-validation-receipt-tool-catalog-policy-tool-refs
      receipt)
  (agentic-ai-lab-session-policy-validation-receipt-record-tool-catalog-policy-tool-refs
   receipt))

;; : (-> PooSessionPolicyValidationReceipt [Symbol])
(def (agentic-ai-lab-session-policy-validation-receipt-tool-catalog-resolved-tool-refs
      receipt)
  (agentic-ai-lab-session-policy-validation-receipt-record-tool-catalog-resolved-tool-refs
   receipt))

;; : (-> PooSessionPolicyValidationReceipt [Symbol])
(def (agentic-ai-lab-session-policy-validation-receipt-tool-catalog-unresolved-tool-refs
      receipt)
  (agentic-ai-lab-session-policy-validation-receipt-record-tool-catalog-unresolved-tool-refs
   receipt))

;; : (-> PooSessionPolicyValidationReceipt [Symbol])
(def (agentic-ai-lab-session-policy-validation-receipt-tool-catalog-allowed-attempt-tool-refs
      receipt)
  (agentic-ai-lab-session-policy-validation-receipt-record-tool-catalog-allowed-attempt-tool-refs
   receipt))

;; : (-> PooSessionPolicyValidationReceipt [Symbol])
(def (agentic-ai-lab-session-policy-validation-receipt-tool-catalog-unresolved-attempt-tool-refs
      receipt)
  (agentic-ai-lab-session-policy-validation-receipt-record-tool-catalog-unresolved-attempt-tool-refs
   receipt))

;; : (-> PooSessionPolicyValidationReceipt Object)
(def (agentic-ai-lab-session-policy-validation-receipt-memory-catalog-ref receipt)
  (agentic-ai-lab-session-policy-validation-receipt-record-memory-catalog-ref
   receipt))

;; : (-> PooSessionPolicyValidationReceipt Boolean)
(def (agentic-ai-lab-session-policy-validation-receipt-memory-catalog-valid? receipt)
  (agentic-ai-lab-session-policy-validation-receipt-record-memory-catalog-valid?
   receipt))

;; : (-> PooSessionPolicyValidationReceipt [Symbol])
(def (agentic-ai-lab-session-policy-validation-receipt-memory-catalog-resolved-store-refs
      receipt)
  (agentic-ai-lab-session-policy-validation-receipt-record-memory-catalog-resolved-store-refs
   receipt))

;; : (-> PooSessionPolicyValidationReceipt [Symbol])
(def (agentic-ai-lab-session-policy-validation-receipt-memory-catalog-unresolved-store-refs
      receipt)
  (agentic-ai-lab-session-policy-validation-receipt-record-memory-catalog-unresolved-store-refs
   receipt))

;; : (-> PooSessionPolicyValidationReceipt [Alist])
(def (agentic-ai-lab-session-policy-validation-receipt-allowed-communication-channel-receipts
      receipt)
  (agentic-ai-lab-session-policy-validation-receipt-record-allowed-communication-channel-receipts
   receipt))

;; : (-> PooSessionPolicyValidationReceipt [Alist])
(def (agentic-ai-lab-session-policy-validation-receipt-denied-communication-channel-receipts
      receipt)
  (agentic-ai-lab-session-policy-validation-receipt-record-denied-communication-channel-receipts
   receipt))

;; : (-> PooSessionPolicyValidationReceipt [Alist])
(def (agentic-ai-lab-session-policy-validation-receipt-allowed-communication-receipts
      receipt)
  (agentic-ai-lab-session-policy-validation-receipt-record-allowed-communication-receipts
   receipt))

;; : (-> PooSessionPolicyValidationReceipt [Alist])
(def (agentic-ai-lab-session-policy-validation-receipt-denied-communication-receipts
      receipt)
  (agentic-ai-lab-session-policy-validation-receipt-record-denied-communication-receipts
   receipt))

;; : (-> PooSessionPolicyValidationReceipt Boolean)
(def (agentic-ai-lab-session-policy-validation-receipt-valid? receipt)
  (agentic-ai-lab-session-policy-validation-receipt-record-valid? receipt))

;; : (-> PooSessionPolicyValidationReceipt Integer)
(def (agentic-ai-lab-session-policy-validation-receipt-diagnostic-count receipt)
  (agentic-ai-lab-session-policy-validation-receipt-record-diagnostic-count receipt))

;; : (-> PooSessionPolicyValidationReceipt [Alist])
(def (agentic-ai-lab-session-policy-validation-receipt-diagnostics receipt)
  (agentic-ai-lab-session-policy-validation-receipt-record-diagnostics receipt))

;; : (-> PooSessionPolicyValidationReceipt Boolean)
(def (agentic-ai-lab-session-policy-validation-receipt-runtime-executed? receipt)
  (agentic-ai-lab-session-policy-validation-receipt-record-runtime-executed? receipt))
