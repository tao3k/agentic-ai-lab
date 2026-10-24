;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: canonical prototypes and validated value constructors.
;;; Invariant: ordinary authors derive Query values through native slot algebra.
(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :clan/poo/mop validate)
        (only-in :std/list/list every)
        (only-in :gerbil-parser/src/modules/parser/graph-syntax
                 GraphSyntaxNode.
                 GraphSyntaxStep.
                 GraphSyntaxPath.
                 GraphSyntaxProperty.
                 GraphSyntaxLiteral.
                 GraphSyntaxEquals.
                 GraphSyntaxProjection.
                 GraphSyntaxProgram.
                 graph-syntax-program?)
        (only-in "types.ss"
                 agentic-ai-lab-query-kind
                 agentic-ai-lab-query-language-kind
                 agentic-ai-lab-query-program-kind
                 agentic-ai-lab-query-element-space-kind
                 agentic-ai-lab-query-result-contract-kind
                 agentic-ai-lab-query-provider-kind
                 agentic-ai-lab-query-execution-candidate-kind
                 agentic-ai-lab-source-query-receipt-kind
                 AgenticAILabQuery AgenticAILabQueryLanguage AgenticAILabQueryProgram
                 AgenticAILabQueryElementSpace
                 AgenticAILabQueryResultContract
                 AgenticAILabQueryProvider
                 AgenticAILabQueryExecutionCandidate
                 AgenticAILabSourceQueryReceipt)
        :yuanxu/poo-clos/interface)

(export AgenticAILabQuery.
        AgenticAILabQueryLanguage.
        AgenticAILabGqlQueryLanguage.
        AgenticAILabSchemeGqlQueryLanguage.
        AgenticAILabQueryProgram.
        GraphSyntaxNode.
        GraphSyntaxStep.
        GraphSyntaxPath.
        GraphSyntaxProperty.
        GraphSyntaxLiteral.
        GraphSyntaxEquals.
        GraphSyntaxProjection.
        GraphSyntaxProgram.
        AgenticAILabGqlQueryProgram.
        AgenticAILabQueryElementSpace.
        AgenticAILabQueryResultContract.
        QueryReceiptBindingExecutor
        agentic-ai-lab-query-element-space
        agentic-ai-lab-gql-query-program?
        agentic-ai-lab-query-result-contract
        agentic-ai-lab-query-provider
        agentic-ai-lab-query-execution-candidate
        agentic-ai-lab-source-query-receipt)

;;; Provider packages specialize this executor class and publish their binding
;;; methods through an owned bundle.  The Query core never invokes a runtime.
(def QueryReceiptBindingExecutor
  (poo-clos-class 'query/receipt-binding-executor))

(def (query-program-has-slots? value slots)
  (and (object? value)
       (every (lambda (slot) (.slot? value slot)) slots)))

(def (agentic-ai-lab-gql-query-program? value)
  (and (graph-syntax-program? value)
       (query-program-has-slots?
        value '(kind identity language-identity representation
                     immutable?))
       (eq? (.ref value 'kind) agentic-ai-lab-query-program-kind)
       (eq? (.ref value 'language-identity) 'gql)
       (eq? (.ref value 'representation) 'poo-gql-ast)
       (eq? (.ref value 'immutable?) #t)))

(def AgenticAILabQueryProgram.
  (.o kind: agentic-ai-lab-query-program-kind
      identity: #f
      language-identity: #f
      representation: 'poo-object
      immutable?: #t))

(def AgenticAILabGqlQueryProgram.
  (.o (:: @ GraphSyntaxProgram.)
      kind: agentic-ai-lab-query-program-kind
      identity: #f
      language-identity: 'gql
      representation: 'poo-gql-ast
      immutable?: #t))

(def AgenticAILabQueryResultContract.
  (.o kind: agentic-ai-lab-query-result-contract-kind
      identity: #f
      result-kind: 'query-result
      required-fields: '()
      max-results: 1
      immutable?: #t))

(def AgenticAILabQueryElementSpace.
  (.o kind: agentic-ai-lab-query-element-space-kind
      identity: #f
      semantic-revision: #f
      element-identities: '()
      complete?: #f
      immutable?: #t
      runtime-executed?: #f))

(def AgenticAILabQueryLanguage.
  (.o kind: agentic-ai-lab-query-language-kind
      identity: #f
      representation: 'poo-object
      authoring-surface: 'scheme-poo
      source-surface: 'unbound
      execution-boundary: 'external-provider
      runtime-owner: 'unbound
      parser-owner: #f
      syntax-contract: #f
      .program?: (lambda (_) #f)
      raw-source-allowed?: #f
      action-authority?: #f
      runtime-executed?: #f))

;;; There is one semantic language.  Scheme is the host syntax used to author
;;; this GQL-aligned POO AST; it is not a competing Query language.
(def AgenticAILabGqlQueryLanguage.
  (.o (:: @ AgenticAILabQueryLanguage.)
      identity: 'gql
      representation: 'poo-gql-ast
      authoring-surface: 'scheme-poo
      source-surface: 'gql
      execution-boundary: 'external-provider
      runtime-owner: 'mrr
      parser-owner: 'gerbil-parser
      syntax-contract: "iso-iec-39075-2024.opengql-1.9.0-syntax.v1"
      .program?: agentic-ai-lab-gql-query-program?))

(def AgenticAILabSchemeGqlQueryLanguage.
  (.o (:: @ AgenticAILabGqlQueryLanguage.)
      execution-boundary: 'pure-control-plane
      runtime-owner: 'agentic-ai-lab))

(def AgenticAILabQuery.
  (.o kind: agentic-ai-lab-query-kind
      identity: #f
      version: #f
      semantic-revision: #f
      element-space-identity: #f
      selected-element-identities: '()
      language: AgenticAILabGqlQueryLanguage.
      program:
      (.o (:: @ AgenticAILabGqlQueryProgram.)
          identity: 'unbound-query-program
          match:
          (.o (:: @ GraphSyntaxPath.)
              start: (.o (:: @ GraphSyntaxNode.) binding: 'x label: 'Element))
          project:
          (.o (:: @ GraphSyntaxProjection.)
              expression:
              (.o (:: @ GraphSyntaxProperty.) binding: 'x property: 'identity)))
      result-bound: 1
      completeness-requirement: 'bounded
      evidence-requirements: '()
      visibility-request: 'restricted
      result-contract: AgenticAILabQueryResultContract.
      mutation-authority?: #f
      action-authority?: #f
      runtime-executed?: #f))

(def (agentic-ai-lab-query-element-space identity-value semantic-revision-value
                                   element-identities-value complete?-value)
  (validate
   AgenticAILabQueryElementSpace
   (.o (:: @ AgenticAILabQueryElementSpace.)
       identity: identity-value
       semantic-revision: semantic-revision-value
       element-identities: element-identities-value
       complete?: complete?-value)))

(def (agentic-ai-lab-query-result-contract identity-value result-kind-value
                                     required-fields-value max-results-value)
  (validate
   AgenticAILabQueryResultContract
   (.o (:: @ AgenticAILabQueryResultContract.)
       identity: identity-value
       result-kind: result-kind-value
       required-fields: required-fields-value
       max-results: max-results-value)))

(def (agentic-ai-lab-query-provider identity-value supported-languages-value
                              runtime-owner-value receipt-executor-value)
  (validate
   AgenticAILabQueryProvider
   (.o kind: agentic-ai-lab-query-provider-kind
       identity: identity-value
       supported-languages: supported-languages-value
       runtime-owner: runtime-owner-value
       receipt-executor: receipt-executor-value
       runtime-executed?: #f
       action-authority?: #f)))

(def (agentic-ai-lab-query-execution-candidate
      provider-identity-value query-identity-value query-version-value
      semantic-revision-value source-content-identity-value
      parser-identity-value provenance-root-value result-digest-value
      result-count-value complete?-value)
  (validate
   AgenticAILabQueryExecutionCandidate
   (.o kind: agentic-ai-lab-query-execution-candidate-kind
       provider-identity: provider-identity-value
       query-identity: query-identity-value
       query-version: query-version-value
       semantic-revision: semantic-revision-value
       source-content-identity: source-content-identity-value
       parser-identity: parser-identity-value
       provenance-root: provenance-root-value
       result-digest: result-digest-value
       result-count: result-count-value
       complete?: complete?-value
       runtime-executed?: #t
       mutation-authority?: #f
       action-authority?: #f)))

(def (agentic-ai-lab-source-query-receipt candidate result-contract-identity-value
                                    diagnostic-values)
  (validate
   AgenticAILabSourceQueryReceipt
   (.o kind: agentic-ai-lab-source-query-receipt-kind
       provider-identity: (.ref candidate 'provider-identity)
       query-identity: (.ref candidate 'query-identity)
       query-version: (.ref candidate 'query-version)
       semantic-revision: (.ref candidate 'semantic-revision)
       source-content-identity: (.ref candidate 'source-content-identity)
       parser-identity: (.ref candidate 'parser-identity)
       provenance-root: (.ref candidate 'provenance-root)
       result-digest: (.ref candidate 'result-digest)
       result-count: (.ref candidate 'result-count)
       complete?: (.ref candidate 'complete?)
       result-contract-identity: result-contract-identity-value
       admitted?: (null? diagnostic-values)
       diagnostics: diagnostic-values
       runtime-executed?: #t
       mutation-authority?: #f
       action-authority?: #f)))
