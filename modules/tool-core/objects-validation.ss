;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: pure catalog and policy validation.

(import :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/session/policy
        :agentic-ai-lab/modules/tool-core/objects-catalog
        :agentic-ai-lab/modules/tool-core/objects-policy-refs
        :agentic-ai-lab/modules/tool-core/objects-spec
        :yuanxu/utilities/functional)

(export agentic-ai-lab-tool-action-mismatch-bundle
        agentic-ai-lab-tool-policy-catalog-validation-summary)

;; : (-> Symbol Symbol Alist)
(def (agentic-ai-lab-tool-diagnostic code tool-ref)
  (list (cons 'kind 'agentic-ai-lab.tool-core.diagnostic)
        (cons 'schema 'agentic-ai-lab.modules.tool-core.diagnostic.v1)
        (cons 'code code) (cons 'tool-ref tool-ref)
        (cons 'severity 'error) (cons 'runtime-executed #f)))

;; : (forall (a) (-> (List a) (List a) (List a)))
;; : (-> [Symbol] [Symbol] [Symbol])
(def (agentic-ai-lab-tool-unsupported-actions requested supported)
  (cond ((null? requested) '())
        ((or (member (car requested) supported) (member '* supported))
         (agentic-ai-lab-tool-unsupported-actions (cdr requested) supported))
        (else (cons (car requested)
                    (agentic-ai-lab-tool-unsupported-actions (cdr requested)
                                                       supported)))))

;; : (-> PooSessionToolGrant PooToolSpec MaybeAlist)
(def (agentic-ai-lab-tool-action-mismatch-row grant spec)
  (let* ((requested (agentic-ai-lab-session-tool-grant-actions grant))
         (supported (agentic-ai-lab-tool-spec-actions spec))
         (unsupported (agentic-ai-lab-tool-unsupported-actions requested supported)))
    (and (not (null? unsupported))
         (list (cons 'grant-id (agentic-ai-lab-session-tool-grant-id grant))
               (cons 'tool-ref (agentic-ai-lab-session-tool-grant-tool-ref grant))
               (cons 'requested-actions requested)
               (cons 'supported-actions supported)
               (cons 'unsupported-actions unsupported)))))

;; : (-> Alist Alist)
(def (agentic-ai-lab-tool-action-diagnostic row)
  (list (cons 'kind 'agentic-ai-lab.tool-core.diagnostic)
        (cons 'schema 'agentic-ai-lab.modules.tool-core.diagnostic.v1)
        (cons 'code 'tool-grant-action-not-supported)
        (cons 'grant-id (agentic-ai-lab-session-alist-ref row 'grant-id #f))
        (cons 'tool-ref (agentic-ai-lab-session-alist-ref row 'tool-ref #f))
        (cons 'requested-actions
              (agentic-ai-lab-session-alist-ref row 'requested-actions '()))
        (cons 'supported-actions
              (agentic-ai-lab-session-alist-ref row 'supported-actions '()))
        (cons 'unsupported-actions
              (agentic-ai-lab-session-alist-ref row 'unsupported-actions '()))
        (cons 'severity 'error) (cons 'runtime-executed #f)))

;; : (-> PooToolCatalog [PooSessionToolGrant] [Alist] [Alist] (Values [Alist] [Alist]))
(def (agentic-ai-lab-tool-action-mismatch-fold catalog grants rows-rev diagnostics-rev)
  (match grants
    ([] (values rows-rev diagnostics-rev))
    ([grant . rest]
         (let* (
                (spec (agentic-ai-lab-tool-catalog-find
                       catalog (agentic-ai-lab-session-tool-grant-tool-ref grant)))
                (row (and spec (agentic-ai-lab-tool-action-mismatch-row grant spec))))
           (if row
             (agentic-ai-lab-tool-action-mismatch-fold catalog rest
                                                  (cons row rows-rev)
                                                  (cons (agentic-ai-lab-tool-action-diagnostic row)
                                                        diagnostics-rev))
             (agentic-ai-lab-tool-action-mismatch-fold catalog rest
                                                  rows-rev diagnostics-rev))))))

;; : (-> PooToolCatalog [PooSessionToolGrant] [PooSessionToolGrant] Alist)
(def (agentic-ai-lab-tool-action-mismatch-bundle catalog agent-grants hook-grants)
  (let-values (((agent-rows-rev agent-diagnostics-rev)
                (agentic-ai-lab-tool-action-mismatch-fold
                 catalog agent-grants '() '())))
    (let-values (((rows-rev diagnostics-rev)
                  (agentic-ai-lab-tool-action-mismatch-fold
                   catalog hook-grants
                   agent-rows-rev agent-diagnostics-rev)))
      (list (cons 'rows (reverse rows-rev))
            (cons 'diagnostics (reverse diagnostics-rev))))))

;; : (forall (a) (-> (List a) (List a) (List a)))
;; : (-> List List List)
(def (agentic-ai-lab-tool-reverse-onto values tail)
  (if (null? values) tail
      (agentic-ai-lab-tool-reverse-onto (cdr values) (cons (car values) tail))))

;; : (-> [Symbol] [Symbol] [Symbol] [Alist] [Alist] Alist)
(def (agentic-ai-lab-tool-validation-summary-finish resolved-rev unresolved-rev
                                                sandbox-rev unresolved-diagnostics-rev
                                                sandbox-diagnostics-rev)
  (list
   (cons 'resolved-tool-refs (reverse resolved-rev))
   (cons 'unresolved-tool-refs (reverse unresolved-rev))
   (cons 'sandbox-required-tool-refs (reverse sandbox-rev))
   (cons 'unresolved-diagnostics-rev unresolved-diagnostics-rev)
   (cons 'sandbox-diagnostics-rev sandbox-diagnostics-rev)
   (cons 'diagnostics
         (agentic-ai-lab-tool-reverse-onto
          unresolved-diagnostics-rev
          (agentic-ai-lab-tool-reverse-onto sandbox-diagnostics-rev '())))))

;; : (-> PooToolCatalog Symbol ToolValidationFoldState ToolValidationFoldState)
(def (agentic-ai-lab-tool-validation-summary-step catalog tool-ref state)
  (let* ((resolved-rev (list-ref state 0))
         (unresolved-rev (list-ref state 1))
         (sandbox-rev (list-ref state 2))
         (unresolved-diagnostics-rev (list-ref state 3))
         (sandbox-diagnostics-rev (list-ref state 4))
         (spec (agentic-ai-lab-tool-catalog-find catalog tool-ref)))
    (if spec
      (let* ((sandbox-required? (agentic-ai-lab-tool-spec-sandbox-required? spec))
             (sandbox-profile-ref
              (agentic-ai-lab-tool-spec-sandbox-profile-ref spec)))
        (list (cons tool-ref resolved-rev)
              unresolved-rev
              (if sandbox-required? (cons tool-ref sandbox-rev) sandbox-rev)
              unresolved-diagnostics-rev
              (if (and sandbox-required? (not (symbol? sandbox-profile-ref)))
                (cons (agentic-ai-lab-tool-diagnostic
                       'tool-spec-missing-sandbox-profile tool-ref)
                      sandbox-diagnostics-rev)
                sandbox-diagnostics-rev)))
      (list resolved-rev
            (cons tool-ref unresolved-rev)
            sandbox-rev
            (cons (agentic-ai-lab-tool-diagnostic 'tool-spec-not-in-catalog tool-ref)
                  unresolved-diagnostics-rev)
            sandbox-diagnostics-rev))))

;; : (-> PooToolCatalog [Symbol] ToolValidationFoldState ToolValidationFoldState)
(def (agentic-ai-lab-tool-validation-summary-fold catalog tool-refs state)
  (if (null? tool-refs)
    state
    (agentic-ai-lab-tool-validation-summary-fold
     catalog
     (cdr tool-refs)
     (agentic-ai-lab-tool-validation-summary-step catalog (car tool-refs) state))))

;; : (forall (a) (-> PooToolCatalog (List a) Alist))
;; : (-> PooToolCatalog [Symbol] Alist)
(def (agentic-ai-lab-tool-policy-catalog-validation-summary catalog tool-refs)
  (match (agentic-ai-lab-tool-validation-summary-fold
          catalog
          tool-refs
          (list '() '() '() '() '()))
    ([resolved-rev unresolved-rev sandbox-rev
      unresolved-diagnostics-rev sandbox-diagnostics-rev]
     (agentic-ai-lab-tool-validation-summary-finish
      resolved-rev
      unresolved-rev
      sandbox-rev
      unresolved-diagnostics-rev
      sandbox-diagnostics-rev))))
