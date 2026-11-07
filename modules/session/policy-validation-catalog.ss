;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: tool, memory, and diagnostic catalog checks for session policy validation.

(import (only-in :std/list/list fold)
        :agentic-ai-lab/modules/session/policy
        :agentic-ai-lab/modules/session/policy-validation-support
        :agentic-ai-lab/modules/session/policy-validation-communication)

(export agentic-ai-lab-session-agent-tool-attempt-allowed?
        agentic-ai-lab-session-hook-tool-attempt-allowed?
        agentic-ai-lab-session-tool-attempt-diagnostic
        agentic-ai-lab-session-tool-catalog-validation
        agentic-ai-lab-session-tool-catalog-validation-present?
        agentic-ai-lab-session-tool-catalog-validation-ref
        agentic-ai-lab-session-policy-attempt-tool-refs/rev
        agentic-ai-lab-session-policy-attempt-tool-refs
        agentic-ai-lab-session-policy-catalog-attempt-ref-partition
        agentic-ai-lab-session-memory-catalog-validation
        agentic-ai-lab-session-memory-catalog-validation-present?
        agentic-ai-lab-session-memory-catalog-validation-ref
        agentic-ai-lab-session-denied-ref-diagnostics/rev
        agentic-ai-lab-session-tool-attempt-diagnostics/rev
        agentic-ai-lab-session-communication-receipt-diagnostic
        agentic-ai-lab-session-communication-channel-receipt-diagnostic
        agentic-ai-lab-session-communication-channel-receipt-diagnostics/rev
        agentic-ai-lab-session-communication-channel-diagnostics/rev
        agentic-ai-lab-session-communication-target-diagnostics/rev
        agentic-ai-lab-session-hook-inheritance-diagnostics/rev)

;; : (-> PooSessionPolicy PooSessionToolAttempt Boolean)
(def (agentic-ai-lab-session-agent-tool-attempt-allowed? policy attempt)
  (agentic-ai-lab-session-tool-permission-policy-allows?
   policy
   (agentic-ai-lab-session-policy-tool-attempt-tool-ref attempt)
   (agentic-ai-lab-session-policy-tool-attempt-action attempt)))

;; : (-> PooSessionPolicy PooSessionToolAttempt Boolean)
(def (agentic-ai-lab-session-hook-tool-attempt-allowed? policy attempt)
  (agentic-ai-lab-session-hook-tool-permission-policy-allows?
   policy
   (agentic-ai-lab-session-policy-tool-attempt-trigger-ref attempt)
   (agentic-ai-lab-session-policy-tool-attempt-tool-ref attempt)
   (agentic-ai-lab-session-policy-tool-attempt-action attempt)))

;; : (-> Symbol PooSessionToolAttempt Alist)
(def (agentic-ai-lab-session-tool-attempt-diagnostic code attempt)
  (agentic-ai-lab-session-policy-diagnostic
   code
   (agentic-ai-lab-session-policy-tool-attempt-principal-ref attempt)
   (list (cons 'attempt-id
               (agentic-ai-lab-session-policy-tool-attempt-id attempt))
         (cons 'trigger-ref
               (agentic-ai-lab-session-policy-tool-attempt-trigger-ref attempt))
         (cons 'tool-ref
               (agentic-ai-lab-session-policy-tool-attempt-tool-ref attempt))
         (cons 'action
               (agentic-ai-lab-session-policy-tool-attempt-action attempt))
         (cons 'resource-ref
               (agentic-ai-lab-session-policy-tool-attempt-resource-ref attempt)))))

;; : (-> Alist MaybeToolCatalogValidationRow)
(def (agentic-ai-lab-session-tool-catalog-validation metadata)
  (agentic-ai-lab-session-validation-alist-ref metadata 'tool-catalog-validation #f))

;; : (-> MaybeToolCatalogValidationRow Boolean)
(def (agentic-ai-lab-session-tool-catalog-validation-present? validation-row)
  (if validation-row #t #f))

;; : (-> MaybeToolCatalogValidationRow Symbol Object)
(def (agentic-ai-lab-session-tool-catalog-validation-ref validation-row key default)
  (if (agentic-ai-lab-session-tool-catalog-validation-present? validation-row)
    (agentic-ai-lab-session-validation-row-ref validation-row key default)
    default))

;; : (-> [PooSessionToolAttempt] [Symbol] [Symbol])
(def (agentic-ai-lab-session-policy-attempt-tool-refs/rev attempts refs-rev)
  (cond
   ((null? attempts) refs-rev)
   (else
    (let (tool-ref
          (agentic-ai-lab-session-policy-tool-attempt-tool-ref (car attempts)))
      (agentic-ai-lab-session-policy-attempt-tool-refs/rev
       (cdr attempts)
       (if (member tool-ref refs-rev)
         refs-rev
         (cons tool-ref refs-rev)))))))

;; : (-> [PooSessionToolAttempt] [PooSessionToolAttempt] [Symbol])
(def (agentic-ai-lab-session-policy-attempt-tool-refs agent-attempts
                                                hook-attempts)
  (reverse
   (agentic-ai-lab-session-policy-attempt-tool-refs/rev
    hook-attempts
    (agentic-ai-lab-session-policy-attempt-tool-refs/rev agent-attempts '()))))

;; : (-> MaybeToolCatalogValidationRow [Symbol] SessionValidationPartition)
(def (agentic-ai-lab-session-policy-catalog-attempt-ref-partition
      tool-catalog-validation
      attempt-tool-refs)
  (if (agentic-ai-lab-session-tool-catalog-validation-present?
       tool-catalog-validation)
    (agentic-ai-lab-session-policy-partition-refs
     attempt-tool-refs
     (agentic-ai-lab-session-tool-catalog-validation-ref
      tool-catalog-validation
      'resolved-tool-refs
      '()))
    (list '() '())))

;; : (-> Alist MaybeMemoryCatalogValidationRow)
(def (agentic-ai-lab-session-memory-catalog-validation metadata)
  (agentic-ai-lab-session-validation-alist-ref metadata 'memory-catalog-validation #f))

;; : (-> MaybeMemoryCatalogValidationRow Boolean)
(def (agentic-ai-lab-session-memory-catalog-validation-present? validation-row)
  (if validation-row #t #f))

;; : (-> MaybeMemoryCatalogValidationRow Symbol Object)
(def (agentic-ai-lab-session-memory-catalog-validation-ref validation-row key default)
  (if (agentic-ai-lab-session-memory-catalog-validation-present? validation-row)
    (agentic-ai-lab-session-validation-row-ref validation-row key default)
    default))

;; : (forall (r d) (-> Symbol Symbol [r] [d] [d]))
;; : (-> Symbol Symbol [Symbol] [Alist] [Alist])
(def (agentic-ai-lab-session-denied-ref-diagnostics/rev code
                                                   scope-ref
                                                   refs
                                                   diagnostics-rev)
  (fold
   (lambda (ref diagnostics)
     (cons (agentic-ai-lab-session-policy-diagnostic
            code
            scope-ref
            (list (cons 'ref ref)))
           diagnostics))
   diagnostics-rev
   refs))

;; : (forall (a d) (-> Symbol [a] [d] [d]))
;; : (-> Symbol [PooSessionToolAttempt] [Alist] [Alist])
(def (agentic-ai-lab-session-tool-attempt-diagnostics/rev code
                                                     attempts
                                                     diagnostics-rev)
  (fold
   (lambda (attempt diagnostics)
     (cons (agentic-ai-lab-session-tool-attempt-diagnostic code attempt)
           diagnostics))
   diagnostics-rev
   attempts))

;; : (-> Symbol Symbol Alist Alist)
(def (agentic-ai-lab-session-communication-receipt-diagnostic code
                                                        scope-ref
                                                        row)
  (agentic-ai-lab-session-policy-diagnostic
   code
   scope-ref
   (list (cons 'relation-kind
               (agentic-ai-lab-session-validation-row-ref row 'relation-kind #f))
         (cons 'source-session-id
               (agentic-ai-lab-session-validation-row-ref row
                                                    'source-session-id
                                                    #f))
         (cons 'target-session-id
               (agentic-ai-lab-session-validation-row-ref row
                                                    'target-session-id
                                                    #f))
         (cons 'channel-id
               (agentic-ai-lab-session-validation-row-ref row 'channel-id #f))
         (cons 'message-kind
               (agentic-ai-lab-session-validation-row-ref row 'message-kind #f)))))

;; : (-> Symbol Symbol Alist Alist)
(def (agentic-ai-lab-session-communication-channel-receipt-diagnostic code
                                                                scope-ref
                                                                row)
  (agentic-ai-lab-session-policy-diagnostic
   code
   scope-ref
   (list (cons 'relation-kind
               (agentic-ai-lab-session-validation-row-ref row 'relation-kind #f))
         (cons 'source-session-id
               (agentic-ai-lab-session-validation-row-ref row
                                                    'source-session-id
                                                    #f))
         (cons 'target-session-id
               (agentic-ai-lab-session-validation-row-ref row
                                                    'target-session-id
                                                    #f))
         (cons 'channel-id
               (agentic-ai-lab-session-validation-row-ref row 'channel-id #f)))))

;; : (forall (r d) (-> Symbol PooSessionPolicy [r] [d] [d]))
;; : (-> Symbol PooSessionPolicy [Alist] [Alist] [Alist])
(def (agentic-ai-lab-session-communication-channel-receipt-diagnostics/rev
      scope-ref
      policy
      rows
      diagnostics-rev)
  (fold
   (lambda (row diagnostics)
     (if (agentic-ai-lab-session-policy-communication-channel-receipt-allowed?
          policy
          row)
       diagnostics
       (cons (agentic-ai-lab-session-communication-channel-receipt-diagnostic
              'communication-channel-receipt-not-granted
              scope-ref
              row)
             diagnostics)))
   diagnostics-rev
   rows))

;; : (forall (r d) (-> Symbol PooSessionPolicy [r] [d] [d]))
;; : (-> Symbol PooSessionPolicy [Alist] [Alist] [Alist])
(def (agentic-ai-lab-session-communication-channel-diagnostics/rev scope-ref
                                                             policy
                                                             rows
                                                             diagnostics-rev)
  (fold
   (lambda (row diagnostics)
     (if (agentic-ai-lab-session-policy-communication-receipt-channel-allowed?
          policy
          row)
       diagnostics
       (cons (agentic-ai-lab-session-communication-receipt-diagnostic
              'communication-receipt-channel-not-granted
              scope-ref
              row)
             diagnostics)))
   diagnostics-rev
   rows))

;; : (forall (r d) (-> Symbol PooSessionPolicy [r] [d] [d]))
;; : (-> Symbol PooSessionPolicy [Alist] [Alist] [Alist])
(def (agentic-ai-lab-session-communication-target-diagnostics/rev scope-ref
                                                            policy
                                                            rows
                                                            diagnostics-rev)
  (fold
   (lambda (row diagnostics)
     (if (agentic-ai-lab-session-policy-communication-receipt-target-allowed?
          policy
          row)
       diagnostics
       (cons (agentic-ai-lab-session-communication-receipt-diagnostic
              'communication-receipt-target-not-granted
              scope-ref
              row)
             diagnostics)))
   diagnostics-rev
   rows))

;; : (forall (a d) (-> PooSessionPolicy [a] [d] [d]))
;; : (-> PooSessionPolicy [PooSessionToolAttempt] [Alist] [Alist])
(def (agentic-ai-lab-session-hook-inheritance-diagnostics/rev agent-tool-policy
                                                        denied-hook-attempts
                                                        diagnostics-rev)
  (fold
   (lambda (attempt diagnostics)
     (if (agentic-ai-lab-session-agent-tool-attempt-allowed?
          agent-tool-policy
          attempt)
       (cons (agentic-ai-lab-session-tool-attempt-diagnostic
              'hook-tool-agent-permission-not-inherited
              attempt)
             diagnostics)
       diagnostics))
   diagnostics-rev
   denied-hook-attempts))
