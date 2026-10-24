;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: admit an external Provider candidate against one admitted Query.
;;; Invariant: binding evidence never executes a Provider or grants authority.
(import (only-in :clan/poo/object .ref)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :std/list/list filter-map)
        :yuanxu/poo-clos/interface
        (only-in "types.ss"
                 agentic-ai-lab-query?
                 agentic-ai-lab-query-provider?
                 agentic-ai-lab-query-admission-receipt?
                 agentic-ai-lab-query-execution-candidate?)
        (only-in "objects.ss"
                 AgenticAILabQuery.
                 QueryReceiptBindingExecutor
                 agentic-ai-lab-source-query-receipt)
        (only-in "gql.ss" agentic-ai-lab-query->gql))

(export QueryReceiptBindingProtocol
        QueryReceiptBindingGeneric
        QueryReceiptBindingCoreMethods
        agentic-ai-lab-query-source-content-identity
        agentic-ai-lab-query-bind-execution-receipt/default
        agentic-ai-lab-query-bind-execution-receipt)

(def (agentic-ai-lab-query-source-content-identity query)
  (unless (agentic-ai-lab-query? query)
    (error "source identity requires a canonical Query" query))
  (string-append
   "sha256:"
   (hex-encode (sha256 (string->utf8 (agentic-ai-lab-query->gql query))))))

(def (candidate-evidence-present? candidate requirement)
  (case requirement
    ((source-content-identity)
     (> (string-length (.ref candidate 'source-content-identity)) 0))
    ((provenance-root)
     (> (string-length (.ref candidate 'provenance-root)) 0))
    ((result-digest)
     (> (string-length (.ref candidate 'result-digest)) 0))
    (else #f)))

(def (agentic-ai-lab-query-bind-execution-receipt/default
      provider query admission candidate)
  (unless (agentic-ai-lab-query-provider? provider)
    (error "Query receipt binding requires a Provider" provider))
  (unless (agentic-ai-lab-query? query)
    (error "Query receipt binding requires a Query" query))
  (unless (agentic-ai-lab-query-admission-receipt? admission)
    (error "Query receipt binding requires an admission receipt" admission))
  (unless (agentic-ai-lab-query-execution-candidate? candidate)
    (error "Query receipt binding requires an execution candidate" candidate))
  (let* ((language (.ref query 'language))
         (result-contract (.ref query 'result-contract))
         (diagnostics
          (filter-map
           values
           (list
            (and (not (.ref admission 'accepted?))
                 '(query-admission-rejected))
            (and (not (equal? (.ref admission 'query-identity)
                              (.ref query 'identity)))
                 '(query-admission-identity-mismatch))
            (and (not (equal? (.ref admission 'query-version)
                              (.ref query 'version)))
                 '(query-admission-version-mismatch))
            (and (not (equal? (.ref admission 'semantic-revision)
                              (.ref query 'semantic-revision)))
                 '(query-admission-revision-mismatch))
            (and (not (equal? (.ref admission 'element-space-identity)
                              (.ref query 'element-space-identity)))
                 '(query-admission-element-space-mismatch))
            (and (not (equal? (.ref admission 'language-identity)
                              (.ref language 'identity)))
                 '(query-admission-language-mismatch))
            (and (not (equal? (.ref candidate 'provider-identity)
                              (.ref provider 'identity)))
                 (list 'provider-identity-mismatch
                       (.ref candidate 'provider-identity)
                       (.ref provider 'identity)))
            (and (not (memq (.ref language 'identity)
                            (.ref provider 'supported-languages)))
                 (list 'unsupported-query-language
                       (.ref language 'identity)))
            (and (not (equal? (.ref candidate 'query-identity)
                              (.ref query 'identity)))
                 (list 'query-identity-mismatch
                       (.ref candidate 'query-identity)
                       (.ref query 'identity)))
            (and (not (equal? (.ref candidate 'query-version)
                              (.ref query 'version)))
                 (list 'query-version-mismatch
                       (.ref candidate 'query-version)
                       (.ref query 'version)))
            (and (not (equal? (.ref candidate 'semantic-revision)
                              (.ref query 'semantic-revision)))
                 (list 'semantic-revision-mismatch
                       (.ref candidate 'semantic-revision)
                       (.ref query 'semantic-revision)))
            (and (not (equal? (.ref candidate 'source-content-identity)
                              (agentic-ai-lab-query-source-content-identity query)))
                 '(source-content-identity-mismatch))
            (and (not (equal? (.ref candidate 'parser-identity)
                              (.ref language 'parser-owner)))
                 (list 'parser-identity-mismatch
                       (.ref candidate 'parser-identity)
                       (.ref language 'parser-owner)))
            (and (> (.ref candidate 'result-count)
                    (.ref query 'result-bound))
                 (list 'query-result-bound-exceeded
                       (.ref candidate 'result-count)
                       (.ref query 'result-bound)))
            (and (> (.ref candidate 'result-count)
                    (.ref result-contract 'max-results))
                 (list 'result-contract-bound-exceeded
                       (.ref candidate 'result-count)
                       (.ref result-contract 'max-results)))
            (and (eq? (.ref query 'completeness-requirement) 'complete)
                 (not (.ref candidate 'complete?))
                 '(incomplete-query-result))
            (let (missing
                  (filter-map
                   (lambda (requirement)
                     (and (not (candidate-evidence-present?
                                candidate requirement))
                          requirement))
                   (.ref query 'evidence-requirements)))
              (and (pair? missing) (list 'missing-required-evidence missing)))))))
    (agentic-ai-lab-source-query-receipt
     candidate (.ref result-contract 'identity) diagnostics)))

;;; Provider and Query are independently extensible.  The core method fails
;;; closed; Provider packages own concrete method bundles.
(def QueryReceiptBindingProtocol
  (poo-clos-generic-protocol 'query/receipt-binding))

(def QueryReceiptBindingGeneric
  (poo-clos-generic-function
   'query-bind-execution-receipt 5
   protocol: QueryReceiptBindingProtocol))

(def QueryUnsupportedReceiptBindingMethod
  (poo-clos-method
   'query/unsupported-receipt-binding
   (list
    (poo-clos-class-specializer QueryReceiptBindingExecutor)
    (poo-clos-any-specializer)
    (poo-clos-prototype-specializer AgenticAILabQuery.)
    (poo-clos-any-specializer)
    (poo-clos-any-specializer))
   (lambda (_frame _executor provider _query _admission _candidate)
     (error "Query Provider lacks a receipt binding method"
            (.ref provider 'identity)))))

(.defmethod-bundle QueryReceiptBindingCoreMethods
  QueryReceiptBindingProtocol
  QueryUnsupportedReceiptBindingMethod)

(poo-clos-compose-method-bundle
 QueryReceiptBindingGeneric
 QueryReceiptBindingCoreMethods)

(def (agentic-ai-lab-query-bind-execution-receipt
      provider query admission candidate)
  (unless (agentic-ai-lab-query-provider? provider)
    (error "Query receipt binding requires a Provider" provider))
  (poo-clos-call QueryReceiptBindingGeneric
                 (.ref provider 'receipt-executor)
                 provider query admission candidate))
