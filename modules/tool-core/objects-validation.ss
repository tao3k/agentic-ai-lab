;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: pure catalog and policy validation.

(import :poo-flow/modules/session/objects
        :poo-flow/modules/session/policy
        :poo-flow/modules/tool-core/objects-catalog
        :poo-flow/modules/tool-core/objects-policy-refs
        :poo-flow/modules/tool-core/objects-spec
        :core/utilities/functional)

(export poo-flow-tool-action-mismatch-bundle
        poo-flow-tool-policy-catalog-validation-summary)

;; : (-> Symbol Symbol Alist)
(def (poo-flow-tool-diagnostic code tool-ref)
  (list (cons 'kind 'poo-flow.tool-core.diagnostic)
        (cons 'schema 'poo-flow.modules.tool-core.diagnostic.v1)
        (cons 'code code) (cons 'tool-ref tool-ref)
        (cons 'severity 'error) (cons 'runtime-executed #f)))

;; : (forall (a) (-> (List a) (List a) (List a)))
;; : (-> [Symbol] [Symbol] [Symbol])
(def (poo-flow-tool-unsupported-actions requested supported)
  (cond ((null? requested) '())
        ((or (member (car requested) supported) (member '* supported))
         (poo-flow-tool-unsupported-actions (cdr requested) supported))
        (else (cons (car requested)
                    (poo-flow-tool-unsupported-actions (cdr requested)
                                                       supported)))))

;; : (-> PooSessionToolGrant PooToolSpec MaybeAlist)
(def (poo-flow-tool-action-mismatch-row grant spec)
  (let* ((requested (poo-flow-session-tool-grant-actions grant))
         (supported (poo-flow-tool-spec-actions spec))
         (unsupported (poo-flow-tool-unsupported-actions requested supported)))
    (and (not (null? unsupported))
         (list (cons 'grant-id (poo-flow-session-tool-grant-id grant))
               (cons 'tool-ref (poo-flow-session-tool-grant-tool-ref grant))
               (cons 'requested-actions requested)
               (cons 'supported-actions supported)
               (cons 'unsupported-actions unsupported)))))

;; : (-> Alist Alist)
(def (poo-flow-tool-action-diagnostic row)
  (list (cons 'kind 'poo-flow.tool-core.diagnostic)
        (cons 'schema 'poo-flow.modules.tool-core.diagnostic.v1)
        (cons 'code 'tool-grant-action-not-supported)
        (cons 'grant-id (poo-flow-session-alist-ref row 'grant-id #f))
        (cons 'tool-ref (poo-flow-session-alist-ref row 'tool-ref #f))
        (cons 'requested-actions
              (poo-flow-session-alist-ref row 'requested-actions '()))
        (cons 'supported-actions
              (poo-flow-session-alist-ref row 'supported-actions '()))
        (cons 'unsupported-actions
              (poo-flow-session-alist-ref row 'unsupported-actions '()))
        (cons 'severity 'error) (cons 'runtime-executed #f)))

;; : (-> PooToolCatalog [PooSessionToolGrant] [Alist] [Alist] (Values [Alist] [Alist]))
(def (poo-flow-tool-action-mismatch-fold catalog grants rows-rev diagnostics-rev)
  (match grants
    ([] (values rows-rev diagnostics-rev))
    ([grant . rest]
         (let* (
                (spec (poo-flow-tool-catalog-find
                       catalog (poo-flow-session-tool-grant-tool-ref grant)))
                (row (and spec (poo-flow-tool-action-mismatch-row grant spec))))
           (if row
             (poo-flow-tool-action-mismatch-fold catalog rest
                                                  (cons row rows-rev)
                                                  (cons (poo-flow-tool-action-diagnostic row)
                                                        diagnostics-rev))
             (poo-flow-tool-action-mismatch-fold catalog rest
                                                  rows-rev diagnostics-rev))))))

;; : (-> PooToolCatalog [PooSessionToolGrant] [PooSessionToolGrant] Alist)
(def (poo-flow-tool-action-mismatch-bundle catalog agent-grants hook-grants)
  (let-values (((agent-rows-rev agent-diagnostics-rev)
                (poo-flow-tool-action-mismatch-fold
                 catalog agent-grants '() '())))
    (let-values (((rows-rev diagnostics-rev)
                  (poo-flow-tool-action-mismatch-fold
                   catalog hook-grants
                   agent-rows-rev agent-diagnostics-rev)))
      (list (cons 'rows (reverse rows-rev))
            (cons 'diagnostics (reverse diagnostics-rev))))))

;; : (forall (a) (-> (List a) (List a) (List a)))
;; : (-> List List List)
(def (poo-flow-tool-reverse-onto values tail)
  (if (null? values) tail
      (poo-flow-tool-reverse-onto (cdr values) (cons (car values) tail))))

;; : (-> [Symbol] [Symbol] [Symbol] [Alist] [Alist] Alist)
(def (poo-flow-tool-validation-summary-finish resolved-rev unresolved-rev
                                                sandbox-rev unresolved-diagnostics-rev
                                                sandbox-diagnostics-rev)
  (list
   (cons 'resolved-tool-refs (reverse resolved-rev))
   (cons 'unresolved-tool-refs (reverse unresolved-rev))
   (cons 'sandbox-required-tool-refs (reverse sandbox-rev))
   (cons 'unresolved-diagnostics-rev unresolved-diagnostics-rev)
   (cons 'sandbox-diagnostics-rev sandbox-diagnostics-rev)
   (cons 'diagnostics
         (poo-flow-tool-reverse-onto
          unresolved-diagnostics-rev
          (poo-flow-tool-reverse-onto sandbox-diagnostics-rev '())))))

;; : (-> PooToolCatalog Symbol ToolValidationFoldState ToolValidationFoldState)
(def (poo-flow-tool-validation-summary-step catalog tool-ref state)
  (let* ((resolved-rev (list-ref state 0))
         (unresolved-rev (list-ref state 1))
         (sandbox-rev (list-ref state 2))
         (unresolved-diagnostics-rev (list-ref state 3))
         (sandbox-diagnostics-rev (list-ref state 4))
         (spec (poo-flow-tool-catalog-find catalog tool-ref)))
    (if spec
      (let* ((sandbox-required? (poo-flow-tool-spec-sandbox-required? spec))
             (sandbox-profile-ref
              (poo-flow-tool-spec-sandbox-profile-ref spec)))
        (list (cons tool-ref resolved-rev)
              unresolved-rev
              (if sandbox-required? (cons tool-ref sandbox-rev) sandbox-rev)
              unresolved-diagnostics-rev
              (if (and sandbox-required? (not (symbol? sandbox-profile-ref)))
                (cons (poo-flow-tool-diagnostic
                       'tool-spec-missing-sandbox-profile tool-ref)
                      sandbox-diagnostics-rev)
                sandbox-diagnostics-rev)))
      (list resolved-rev
            (cons tool-ref unresolved-rev)
            sandbox-rev
            (cons (poo-flow-tool-diagnostic 'tool-spec-not-in-catalog tool-ref)
                  unresolved-diagnostics-rev)
            sandbox-diagnostics-rev))))

;; : (-> PooToolCatalog [Symbol] ToolValidationFoldState ToolValidationFoldState)
(def (poo-flow-tool-validation-summary-fold catalog tool-refs state)
  (if (null? tool-refs)
    state
    (poo-flow-tool-validation-summary-fold
     catalog
     (cdr tool-refs)
     (poo-flow-tool-validation-summary-step catalog (car tool-refs) state))))

;; : (forall (a) (-> PooToolCatalog (List a) Alist))
;; : (-> PooToolCatalog [Symbol] Alist)
(def (poo-flow-tool-policy-catalog-validation-summary catalog tool-refs)
  (match (poo-flow-tool-validation-summary-fold
          catalog
          tool-refs
          (list '() '() '() '() '()))
    ([resolved-rev unresolved-rev sandbox-rev
      unresolved-diagnostics-rev sandbox-diagnostics-rev]
     (poo-flow-tool-validation-summary-finish
      resolved-rev
      unresolved-rev
      sandbox-rev
      unresolved-diagnostics-rev
      sandbox-diagnostics-rev))))
