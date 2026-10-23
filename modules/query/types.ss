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

(export agentic-ai-lab-query-kind
        agentic-ai-lab-query-language-kind
        agentic-ai-lab-query-program-kind
        agentic-ai-lab-query-element-space-kind
        agentic-ai-lab-query-result-contract-kind
        agentic-ai-lab-query-admission-receipt-kind
        agentic-ai-lab-query-provider-kind
        agentic-ai-lab-query-execution-candidate-kind
        agentic-ai-lab-source-query-receipt-kind
        AgenticAILabQuery
        AgenticAILabQueryLanguage
        AgenticAILabQueryProgram
        AgenticAILabQueryElementSpace
        AgenticAILabQueryResultContract
        AgenticAILabQueryAdmissionReceipt
        AgenticAILabQueryProvider
        AgenticAILabQueryExecutionCandidate
        AgenticAILabSourceQueryReceipt
        agentic-ai-lab-query?
        agentic-ai-lab-query-language?
        agentic-ai-lab-query-program?
        agentic-ai-lab-query-element-space?
        agentic-ai-lab-query-result-contract?
        agentic-ai-lab-query-admission-receipt?
        agentic-ai-lab-query-provider?
        agentic-ai-lab-query-execution-candidate?
        agentic-ai-lab-source-query-receipt?)

(def agentic-ai-lab-query-kind 'agentic-ai-lab.query)
(def agentic-ai-lab-query-language-kind 'agentic-ai-lab.query.language)
(def agentic-ai-lab-query-program-kind 'agentic-ai-lab.query.program)
(def agentic-ai-lab-query-element-space-kind 'agentic-ai-lab.query.element-space)
(def agentic-ai-lab-query-result-contract-kind 'agentic-ai-lab.query.result-contract)
(def agentic-ai-lab-query-admission-receipt-kind 'agentic-ai-lab.query.admission-receipt)
(def agentic-ai-lab-query-provider-kind 'agentic-ai-lab.query.provider)
(def agentic-ai-lab-query-execution-candidate-kind
  'agentic-ai-lab.query.execution-candidate)
(def agentic-ai-lab-source-query-receipt-kind 'agentic-ai-lab.query.source-receipt)

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
       (eq? (.ref value 'kind) agentic-ai-lab-query-result-contract-kind)
       (query-stable-identity? (.ref value 'identity))
       (symbol? (.ref value 'result-kind))
       (query-symbol-list? (.ref value 'required-fields))
       (exact-integer? (.ref value 'max-results))
       (> (.ref value 'max-results) 0)
       (eq? (.ref value 'immutable?) #t)))

(define-type (AgenticAILabQueryResultContract @ Type.)
  .element?: query-result-contract-shape?)

(def (query-element-space-shape? value)
  (and (query-has-slots?
        value '(kind identity semantic-revision element-identities complete?
                     immutable? runtime-executed?))
       (eq? (.ref value 'kind) agentic-ai-lab-query-element-space-kind)
       (query-stable-identity? (.ref value 'identity))
       (query-revision? (.ref value 'semantic-revision))
       (query-identity-list? (.ref value 'element-identities))
       (query-unique-identities? (.ref value 'element-identities))
       (boolean? (.ref value 'complete?))
       (eq? (.ref value 'immutable?) #t)
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabQueryElementSpace @ Type.)
  .element?: query-element-space-shape?)

(def (query-language-shape? value)
  (and (query-has-slots?
        value '(kind identity representation authoring-surface source-surface
                     execution-boundary runtime-owner parser-owner syntax-contract .program?
                     raw-source-allowed? action-authority? runtime-executed?))
       (eq? (.ref value 'kind) agentic-ai-lab-query-language-kind)
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

(define-type (AgenticAILabQueryLanguage @ Type.)
  .element?: query-language-shape?)

(def (query-program-shape? value)
  (and (query-has-slots?
        value '(kind identity language-identity representation immutable?))
       (eq? (.ref value 'kind) agentic-ai-lab-query-program-kind)
       (query-stable-identity? (.ref value 'identity))
       (symbol? (.ref value 'language-identity))
       (symbol? (.ref value 'representation))
       (eq? (.ref value 'immutable?) #t)))

(define-type (AgenticAILabQueryProgram @ Type.)
  .element?: query-program-shape?)

(def (query-shape? value)
  (and (query-has-slots?
        value '(kind identity version semantic-revision
                     element-space-identity selected-element-identities
                     language program
                     result-bound completeness-requirement
                     evidence-requirements visibility-request result-contract
                     mutation-authority? action-authority? runtime-executed?))
       (eq? (.ref value 'kind) agentic-ai-lab-query-kind)
       (query-stable-identity? (.ref value 'identity))
       (query-revision? (.ref value 'version))
       (query-revision? (.ref value 'semantic-revision))
       (query-stable-identity? (.ref value 'element-space-identity))
       (query-identity-list? (.ref value 'selected-element-identities))
       (query-unique-identities? (.ref value 'selected-element-identities))
       (element? AgenticAILabQueryLanguage (.ref value 'language))
       (element? AgenticAILabQueryProgram (.ref value 'program))
       (eq? (.ref (.ref value 'program) 'language-identity)
            (.ref (.ref value 'language) 'identity))
       ((.ref (.ref value 'language) '.program?) (.ref value 'program))
       (exact-integer? (.ref value 'result-bound))
       (> (.ref value 'result-bound) 0)
       (memq (.ref value 'completeness-requirement)
             '(complete bounded partial-allowed))
       (query-symbol-list? (.ref value 'evidence-requirements))
       (symbol? (.ref value 'visibility-request))
       (element? AgenticAILabQueryResultContract (.ref value 'result-contract))
       (<= (.ref value 'result-bound)
           (.ref (.ref value 'result-contract) 'max-results))
       (eq? (.ref value 'mutation-authority?) #f)
       (eq? (.ref value 'action-authority?) #f)
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabQuery @ Type.)
  .element?: query-shape?)

(def (query-admission-receipt-shape? value)
  (and (query-has-slots?
        value '(kind query-identity query-version semantic-revision
                     element-space-identity language-identity
                     accepted? diagnostics
                     mutation-authority? action-authority? runtime-executed?))
       (eq? (.ref value 'kind) agentic-ai-lab-query-admission-receipt-kind)
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

(define-type (AgenticAILabQueryAdmissionReceipt @ Type.)
  .element?: query-admission-receipt-shape?)

(def (query-provider-shape? value)
  (and (query-has-slots?
        value '(kind identity supported-languages runtime-owner
                     receipt-executor runtime-executed? action-authority?))
       (eq? (.ref value 'kind) agentic-ai-lab-query-provider-kind)
       (query-stable-identity? (.ref value 'identity))
       (query-symbol-list? (.ref value 'supported-languages))
       (query-unique-identities? (.ref value 'supported-languages))
       (symbol? (.ref value 'runtime-owner))
       (poo-clos-instance? (.ref value 'receipt-executor))
       (eq? (.ref value 'runtime-executed?) #f)
       (eq? (.ref value 'action-authority?) #f)))

(define-type (AgenticAILabQueryProvider @ Type.)
  .element?: query-provider-shape?)

(def (query-execution-candidate-shape? value)
  (and (query-has-slots?
        value '(kind provider-identity query-identity query-version
                     semantic-revision source-content-identity parser-identity
                     provenance-root result-digest result-count complete?
                     runtime-executed? mutation-authority? action-authority?))
       (eq? (.ref value 'kind) agentic-ai-lab-query-execution-candidate-kind)
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

(define-type (AgenticAILabQueryExecutionCandidate @ Type.)
  .element?: query-execution-candidate-shape?)

(def (source-query-receipt-shape? value)
  (and (query-has-slots?
        value '(kind provider-identity query-identity query-version
                     semantic-revision source-content-identity parser-identity
                     provenance-root result-digest result-count complete?
                     result-contract-identity admitted? diagnostics
                     runtime-executed? mutation-authority? action-authority?))
       (eq? (.ref value 'kind) agentic-ai-lab-source-query-receipt-kind)
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

(define-type (AgenticAILabSourceQueryReceipt @ Type.)
  .element?: source-query-receipt-shape?)

(def (agentic-ai-lab-query? value)
  (element? AgenticAILabQuery value))

(def (agentic-ai-lab-query-language? value)
  (element? AgenticAILabQueryLanguage value))

(def (agentic-ai-lab-query-program? value)
  (element? AgenticAILabQueryProgram value))

(def (agentic-ai-lab-query-element-space? value)
  (element? AgenticAILabQueryElementSpace value))

(def (agentic-ai-lab-query-result-contract? value)
  (element? AgenticAILabQueryResultContract value))

(def (agentic-ai-lab-query-admission-receipt? value)
  (element? AgenticAILabQueryAdmissionReceipt value))

(def (agentic-ai-lab-query-provider? value)
  (element? AgenticAILabQueryProvider value))

(def (agentic-ai-lab-query-execution-candidate? value)
  (element? AgenticAILabQueryExecutionCandidate value))

(def (agentic-ai-lab-source-query-receipt? value)
  (element? AgenticAILabSourceQueryReceipt value))
