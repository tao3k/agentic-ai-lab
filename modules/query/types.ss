;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: canonical read-only Query, ElementSpace and admission contracts.
;;; Invariant: a Query can select evidence but cannot mutate or authorize.
(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :clan/poo/mop Type. define-type element?)
        (only-in :gerbil/core hash-get hash-put!)
        (only-in :std/list/list every)
        (only-in :yuanxu/poo-clos/interface
                 poo-clos-instance?))

(export poo-flow-query-kind
        poo-flow-query-language-kind
        poo-flow-query-program-kind
        poo-flow-query-element-space-kind
        poo-flow-query-result-contract-kind
        poo-flow-query-admission-receipt-kind
        poo-flow-query-provider-kind
        poo-flow-query-execution-candidate-kind
        poo-flow-source-query-receipt-kind
        PooFlowQuery
        PooFlowQueryLanguage
        PooFlowQueryProgram
        PooFlowQueryElementSpace
        PooFlowQueryResultContract
        PooFlowQueryAdmissionReceipt
        PooFlowQueryProvider
        PooFlowQueryExecutionCandidate
        PooFlowSourceQueryReceipt
        poo-flow-query?
        poo-flow-query-language?
        poo-flow-query-program?
        poo-flow-query-element-space?
        poo-flow-query-result-contract?
        poo-flow-query-admission-receipt?
        poo-flow-query-provider?
        poo-flow-query-execution-candidate?
        poo-flow-source-query-receipt?)

(def poo-flow-query-kind 'poo-flow.query)
(def poo-flow-query-language-kind 'poo-flow.query.language)
(def poo-flow-query-program-kind 'poo-flow.query.program)
(def poo-flow-query-element-space-kind 'poo-flow.query.element-space)
(def poo-flow-query-result-contract-kind 'poo-flow.query.result-contract)
(def poo-flow-query-admission-receipt-kind 'poo-flow.query.admission-receipt)
(def poo-flow-query-provider-kind 'poo-flow.query.provider)
(def poo-flow-query-execution-candidate-kind
  'poo-flow.query.execution-candidate)
(def poo-flow-source-query-receipt-kind 'poo-flow.query.source-receipt)

(def (query-stable-identity? value)
  (or (symbol? value)
      (and (string? value) (> (string-length value) 0))))

(def (query-revision? value)
  (and (string? value) (> (string-length value) 0)))

(def (query-symbol-list? value)
  (and (list? value) (every symbol? value)))

(def (query-identity-list? value)
  (and (list? value) (every query-stable-identity? value)))

(def (query-unique-identities? values)
  (let (seen (make-hash-table))
    (every
     (lambda (value)
       (if (hash-get seen value)
         #f
         (begin (hash-put! seen value #t) #t)))
     values)))

(def (query-has-slots? value slots)
  (and (object? value)
       (every (lambda (slot) (.slot? value slot)) slots)))

(def (query-result-contract-shape? value)
  (and (query-has-slots?
        value '(kind identity result-kind required-fields max-results
                     immutable?))
       (eq? (.ref value 'kind) poo-flow-query-result-contract-kind)
       (query-stable-identity? (.ref value 'identity))
       (symbol? (.ref value 'result-kind))
       (query-symbol-list? (.ref value 'required-fields))
       (exact-integer? (.ref value 'max-results))
       (> (.ref value 'max-results) 0)
       (eq? (.ref value 'immutable?) #t)))

(define-type (PooFlowQueryResultContract @ Type.)
  .element?: query-result-contract-shape?)

(def (query-element-space-shape? value)
  (and (query-has-slots?
        value '(kind identity semantic-revision element-identities complete?
                     immutable? runtime-executed?))
       (eq? (.ref value 'kind) poo-flow-query-element-space-kind)
       (query-stable-identity? (.ref value 'identity))
       (query-revision? (.ref value 'semantic-revision))
       (query-identity-list? (.ref value 'element-identities))
       (query-unique-identities? (.ref value 'element-identities))
       (boolean? (.ref value 'complete?))
       (eq? (.ref value 'immutable?) #t)
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (PooFlowQueryElementSpace @ Type.)
  .element?: query-element-space-shape?)

(def (query-language-shape? value)
  (and (query-has-slots?
        value '(kind identity representation authoring-surface source-surface
                     execution-boundary runtime-owner parser-owner syntax-contract .program?
                     raw-source-allowed? action-authority? runtime-executed?))
       (eq? (.ref value 'kind) poo-flow-query-language-kind)
       (symbol? (.ref value 'identity))
       (symbol? (.ref value 'representation))
       (symbol? (.ref value 'authoring-surface))
       (symbol? (.ref value 'source-surface))
       (memq (.ref value 'execution-boundary)
             '(pure-control-plane external-provider))
       (symbol? (.ref value 'runtime-owner))
       (or (not (.ref value 'parser-owner))
           (symbol? (.ref value 'parser-owner)))
       (or (not (.ref value 'syntax-contract))
           (query-revision? (.ref value 'syntax-contract)))
       (procedure? (.ref value '.program?))
       (eq? (.ref value 'raw-source-allowed?) #f)
       (eq? (.ref value 'action-authority?) #f)
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (PooFlowQueryLanguage @ Type.)
  .element?: query-language-shape?)

(def (query-program-shape? value)
  (and (query-has-slots?
        value '(kind identity language-identity representation immutable?))
       (eq? (.ref value 'kind) poo-flow-query-program-kind)
       (query-stable-identity? (.ref value 'identity))
       (symbol? (.ref value 'language-identity))
       (symbol? (.ref value 'representation))
       (eq? (.ref value 'immutable?) #t)))

(define-type (PooFlowQueryProgram @ Type.)
  .element?: query-program-shape?)

(def (query-shape? value)
  (and (query-has-slots?
        value '(kind identity version semantic-revision
                     element-space-identity selected-element-identities
                     language program
                     result-bound completeness-requirement
                     evidence-requirements visibility-request result-contract
                     mutation-authority? action-authority? runtime-executed?))
       (eq? (.ref value 'kind) poo-flow-query-kind)
       (query-stable-identity? (.ref value 'identity))
       (query-revision? (.ref value 'version))
       (query-revision? (.ref value 'semantic-revision))
       (query-stable-identity? (.ref value 'element-space-identity))
       (query-identity-list? (.ref value 'selected-element-identities))
       (query-unique-identities? (.ref value 'selected-element-identities))
       (element? PooFlowQueryLanguage (.ref value 'language))
       (element? PooFlowQueryProgram (.ref value 'program))
       (eq? (.ref (.ref value 'program) 'language-identity)
            (.ref (.ref value 'language) 'identity))
       ((.ref (.ref value 'language) '.program?) (.ref value 'program))
       (exact-integer? (.ref value 'result-bound))
       (> (.ref value 'result-bound) 0)
       (memq (.ref value 'completeness-requirement)
             '(complete bounded partial-allowed))
       (query-symbol-list? (.ref value 'evidence-requirements))
       (symbol? (.ref value 'visibility-request))
       (element? PooFlowQueryResultContract (.ref value 'result-contract))
       (<= (.ref value 'result-bound)
           (.ref (.ref value 'result-contract) 'max-results))
       (eq? (.ref value 'mutation-authority?) #f)
       (eq? (.ref value 'action-authority?) #f)
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (PooFlowQuery @ Type.)
  .element?: query-shape?)

(def (query-admission-receipt-shape? value)
  (and (query-has-slots?
        value '(kind query-identity query-version semantic-revision
                     element-space-identity language-identity
                     accepted? diagnostics
                     mutation-authority? action-authority? runtime-executed?))
       (eq? (.ref value 'kind) poo-flow-query-admission-receipt-kind)
       (query-stable-identity? (.ref value 'query-identity))
       (query-revision? (.ref value 'query-version))
       (query-revision? (.ref value 'semantic-revision))
       (query-stable-identity? (.ref value 'element-space-identity))
       (symbol? (.ref value 'language-identity))
       (boolean? (.ref value 'accepted?))
       (list? (.ref value 'diagnostics))
       (eq? (.ref value 'accepted?) (null? (.ref value 'diagnostics)))
       (eq? (.ref value 'mutation-authority?) #f)
       (eq? (.ref value 'action-authority?) #f)
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (PooFlowQueryAdmissionReceipt @ Type.)
  .element?: query-admission-receipt-shape?)

(def (query-provider-shape? value)
  (and (query-has-slots?
        value '(kind identity supported-languages runtime-owner
                     receipt-executor runtime-executed? action-authority?))
       (eq? (.ref value 'kind) poo-flow-query-provider-kind)
       (query-stable-identity? (.ref value 'identity))
       (query-symbol-list? (.ref value 'supported-languages))
       (query-unique-identities? (.ref value 'supported-languages))
       (symbol? (.ref value 'runtime-owner))
       (poo-clos-instance? (.ref value 'receipt-executor))
       (eq? (.ref value 'runtime-executed?) #f)
       (eq? (.ref value 'action-authority?) #f)))

(define-type (PooFlowQueryProvider @ Type.)
  .element?: query-provider-shape?)

(def (query-execution-candidate-shape? value)
  (and (query-has-slots?
        value '(kind provider-identity query-identity query-version
                     semantic-revision source-content-identity parser-identity
                     provenance-root result-digest result-count complete?
                     runtime-executed? mutation-authority? action-authority?))
       (eq? (.ref value 'kind) poo-flow-query-execution-candidate-kind)
       (query-stable-identity? (.ref value 'provider-identity))
       (query-stable-identity? (.ref value 'query-identity))
       (query-revision? (.ref value 'query-version))
       (query-revision? (.ref value 'semantic-revision))
       (query-revision? (.ref value 'source-content-identity))
       (query-stable-identity? (.ref value 'parser-identity))
       (query-revision? (.ref value 'provenance-root))
       (query-revision? (.ref value 'result-digest))
       (exact-integer? (.ref value 'result-count))
       (>= (.ref value 'result-count) 0)
       (boolean? (.ref value 'complete?))
       (eq? (.ref value 'runtime-executed?) #t)
       (eq? (.ref value 'mutation-authority?) #f)
       (eq? (.ref value 'action-authority?) #f)))

(define-type (PooFlowQueryExecutionCandidate @ Type.)
  .element?: query-execution-candidate-shape?)

(def (source-query-receipt-shape? value)
  (and (query-has-slots?
        value '(kind provider-identity query-identity query-version
                     semantic-revision source-content-identity parser-identity
                     provenance-root result-digest result-count complete?
                     result-contract-identity admitted? diagnostics
                     runtime-executed? mutation-authority? action-authority?))
       (eq? (.ref value 'kind) poo-flow-source-query-receipt-kind)
       (query-stable-identity? (.ref value 'provider-identity))
       (query-stable-identity? (.ref value 'query-identity))
       (query-revision? (.ref value 'query-version))
       (query-revision? (.ref value 'semantic-revision))
       (query-revision? (.ref value 'source-content-identity))
       (query-stable-identity? (.ref value 'parser-identity))
       (query-revision? (.ref value 'provenance-root))
       (query-revision? (.ref value 'result-digest))
       (exact-integer? (.ref value 'result-count))
       (>= (.ref value 'result-count) 0)
       (boolean? (.ref value 'complete?))
       (query-stable-identity? (.ref value 'result-contract-identity))
       (boolean? (.ref value 'admitted?))
       (list? (.ref value 'diagnostics))
       (eq? (.ref value 'admitted?) (null? (.ref value 'diagnostics)))
       (eq? (.ref value 'runtime-executed?) #t)
       (eq? (.ref value 'mutation-authority?) #f)
       (eq? (.ref value 'action-authority?) #f)))

(define-type (PooFlowSourceQueryReceipt @ Type.)
  .element?: source-query-receipt-shape?)

(def (poo-flow-query? value)
  (element? PooFlowQuery value))

(def (poo-flow-query-language? value)
  (element? PooFlowQueryLanguage value))

(def (poo-flow-query-program? value)
  (element? PooFlowQueryProgram value))

(def (poo-flow-query-element-space? value)
  (element? PooFlowQueryElementSpace value))

(def (poo-flow-query-result-contract? value)
  (element? PooFlowQueryResultContract value))

(def (poo-flow-query-admission-receipt? value)
  (element? PooFlowQueryAdmissionReceipt value))

(def (poo-flow-query-provider? value)
  (element? PooFlowQueryProvider value))

(def (poo-flow-query-execution-candidate? value)
  (element? PooFlowQueryExecutionCandidate value))

(def (poo-flow-source-query-receipt? value)
  (element? PooFlowSourceQueryReceipt value))
