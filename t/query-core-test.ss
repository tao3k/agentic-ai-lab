;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test check check-exception test-suite)
        (only-in :clan/poo/object .o .ref)
        (only-in :clan/poo/mop validate)
        :agentic-ai-lab/modules/query/interface
        :yuanxu/poo-clos/interface
        (only-in :agentic-ai-lab/modules/temporal-causality/candidates/interface
                 agentic-ai-lab-candidate-scope agentic-ai-lab-candidate-exchange
                 agentic-ai-lab-gql-candidate-receipt
                 agentic-ai-lab-gql-candidate-row-check))

(export query-core-test)

(def QueryResult
  (agentic-ai-lab-query-result-contract
   'healthcare/query-result 'relation-row
   '(source target evidence) 32))

(def QuerySpace
  (agentic-ai-lab-query-element-space
   'healthcare/case-space "sha256:space-v1"
   '(case-1 profile-1 source-1) #t))

;;; Scheme is the concise host notation.  The value itself is one GQL-aligned
;;; POO AST, so inheritance and slot algebra remain available without creating
;;; a second Scheme Query language.
(def CaseProfileProgram
  (.o (:: @ AgenticAILabGqlQueryProgram.)
      identity: 'healthcare-case-profile-relations
      match:
      (.o (:: @ GraphSyntaxPath.)
          start: (.o (:: @ GraphSyntaxNode.) binding: 's label: 'Scenario)
          next:
          (.o (:: @ GraphSyntaxStep.)
              relation: 'HAS_CASE
              target: (.o (:: @ GraphSyntaxNode.) binding: 'c label: 'Case)
              next:
              (.o (:: @ GraphSyntaxStep.)
                  relation: 'HAS_EFFECTIVE_PROFILE
                  target:
                  (.o (:: @ GraphSyntaxNode.) binding: 'p label: 'Profile))))
      where:
      (.o (:: @ GraphSyntaxEquals.)
          left:
          (.o (:: @ GraphSyntaxProperty.) binding: 's property: 'identity)
          right:
          (.o (:: @ GraphSyntaxLiteral.)
              literal-kind: 'string value: "healthcare"))
      project:
      (.o (:: @ GraphSyntaxProjection.)
          expression:
          (.o (:: @ GraphSyntaxProperty.) binding: 's property: 'identity)
          next:
          (.o (:: @ GraphSyntaxProjection.)
              expression:
              (.o (:: @ GraphSyntaxProperty.) binding: 'c property: 'id)
              next:
              (.o (:: @ GraphSyntaxProjection.)
                  expression:
                  (.o (:: @ GraphSyntaxProperty.)
                      binding: 'p property: 'identity))))))

(def Query
  (validate
   AgenticAILabQuery
   (.o (:: @ AgenticAILabQuery.)
       identity: 'healthcare/case-profile-relations
       version: "1"
       semantic-revision: "sha256:space-v1"
       element-space-identity: 'healthcare/case-space
       selected-element-identities: '(case-1 profile-1)
       language: AgenticAILabGqlQueryLanguage.
       program: CaseProfileProgram
       result-bound: 16
       completeness-requirement: 'complete
       evidence-requirements: '(provenance-root result-digest)
       visibility-request: 'organization
       result-contract: QueryResult)))

(def TestQueryExecutor
  (poo-clos-class 'query/test-receipt-executor
                  direct-superclasses: (list QueryReceiptBindingExecutor)))
(def TestQueryProvider
  (agentic-ai-lab-query-provider 'test '(gql) 'test
                           (poo-clos-make-instance TestQueryExecutor)))
(def TestQueryBindingMethod
  (poo-clos-method
   'query/test-receipt-binding
   (list (poo-clos-class-specializer TestQueryExecutor)
         (poo-clos-eql-specializer TestQueryProvider)
         (poo-clos-prototype-specializer AgenticAILabQuery.)
         (poo-clos-any-specializer)
         (poo-clos-any-specializer))
   (lambda (_frame _executor provider query admission candidate)
     (agentic-ai-lab-query-bind-execution-receipt/default
      provider query admission candidate))))
(.defmethod-bundle TestQueryBindingMethods
  QueryReceiptBindingProtocol TestQueryBindingMethod)
(poo-clos-compose-method-bundle
 QueryReceiptBindingGeneric TestQueryBindingMethods)

(def query-core-test
  (test-suite
   "canonical Query core"

   (yuanxu-test-case "publishes one semantic language with two surfaces"
     (check (.ref AgenticAILabQueryModule. 'query) => AgenticAILabQuery.)
     (check (.ref (.ref AgenticAILabQueryModule. 'languages) 'gql)
            => AgenticAILabGqlQueryLanguage.)
     (check (.ref AgenticAILabGqlQueryLanguage. 'authoring-surface)
            => 'scheme-poo)
     (check (.ref AgenticAILabGqlQueryLanguage. 'source-surface) => 'gql)
     (check (.ref AgenticAILabGqlQueryLanguage. 'parser-owner)
            => 'gerbil-parser)
     (check (.ref AgenticAILabQueryModule. 'element-space)
            => AgenticAILabQueryElementSpace.)
     (check (.ref AgenticAILabQueryModule. 'result-contract)
            => AgenticAILabQueryResultContract.)
     (check (.ref AgenticAILabQueryModule. 'result-cell)
            => AgenticAILabQueryResultCell.)
     (check (.ref AgenticAILabQueryModule. 'result-row)
            => AgenticAILabQueryResultRow.)
     (check (.ref AgenticAILabQueryModule. 'result-set)
            => AgenticAILabQueryResultSet.))

   (yuanxu-test-case "projects the POO AST deterministically to standard GQL"
     (check
      (agentic-ai-lab-query->gql Query)
      =>
      (string-append
       "MATCH (s:Scenario)-[:HAS_CASE]->(c:Case)-[:HAS_EFFECTIVE_PROFILE]->(p:Profile)\n"
       "WHERE s.identity = 'healthcare'\n"
       "RETURN s.identity, c.id, p.identity\n")))

   (yuanxu-test-case "selects POO nodes with the Scheme GQL syntax slice"
     (let* ((scheme-program
             (.o (:: @ AgenticAILabGqlQueryProgram.)
                 identity: 'signal-selection
                 match:
                 (.o (:: @ GraphSyntaxPath.)
                     start: (.o (:: @ GraphSyntaxNode.)
                                binding: 'signal label: 'Signal))
                 project:
                 (.o (:: @ GraphSyntaxProjection.)
                     expression:
                     (.o (:: @ GraphSyntaxProperty.)
                         binding: 'signal property: 'identity))))
            (scheme-query
             (.o (:: @ Query)
                 language: AgenticAILabSchemeGqlQueryLanguage.
                 program: scheme-program))
            (result
             (agentic-ai-lab-query-select-scheme-nodes
              scheme-query
              (list (.o label: 'Signal identity: 'record)
                    (.o label: 'Other identity: 'ignored)))))
       (check (.ref result 'rows) => '((record)))
       (check (.ref result 'executed-in-scheme?) => #t)
       (check (.ref result 'external-provenance-verified?) => #f)
       (check-exception
        (agentic-ai-lab-query-select-scheme-nodes
         (.o (:: @ Query)
             language: AgenticAILabSchemeGqlQueryLanguage.)
         (list (.o label: 'Scenario identity: "healthcare")))
        true)
       (check-exception
        (agentic-ai-lab-query-select-scheme-nodes
         (.o (:: @ scheme-query) result-bound: 1)
         (list (.o label: 'Signal identity: 'first)
               (.o label: 'Signal identity: 'second)))
        true)))

   (yuanxu-test-case "escapes GQL string literals without transferring parser ownership"
     (let (escaped
           (.o (:: @ CaseProfileProgram)
               where:
               (.o (:: @ GraphSyntaxEquals.)
                   left:
                   (.o (:: @ GraphSyntaxProperty.)
                       binding: 's property: 'identity)
                   right:
                   (.o (:: @ GraphSyntaxLiteral.)
                       literal-kind: 'string value: "patient's-case"))))
       (check
        (agentic-ai-lab-query-program->gql escaped)
        =>
        (string-append
         "MATCH (s:Scenario)-[:HAS_CASE]->(c:Case)-[:HAS_EFFECTIVE_PROFILE]->(p:Profile)\n"
         "WHERE s.identity = 'patient''s-case'\n"
         "RETURN s.identity, c.id, p.identity\n"))))

   (yuanxu-test-case "admits a bounded read-only Query against its ElementSpace"
     (let (receipt (agentic-ai-lab-query-admit Query QuerySpace))
       (check (agentic-ai-lab-query-admission-receipt? receipt) => #t)
       (check (.ref receipt 'accepted?) => #t)
       (check (.ref receipt 'diagnostics) => '())
       (check (.ref receipt 'semantic-revision) => "sha256:space-v1")
       (check (.ref receipt 'language-identity) => 'gql)
       (check (.ref receipt 'mutation-authority?) => #f)
       (check (.ref receipt 'action-authority?) => #f)
       (check (.ref receipt 'runtime-executed?) => #f)))

   (yuanxu-test-case "binds an admitted test candidate through Provider x Query dispatch"
     (let* ((admission (agentic-ai-lab-query-admit Query QuerySpace))
            (candidate
             (agentic-ai-lab-query-execution-candidate
              'test
              'healthcare/case-profile-relations
              "1"
              "sha256:space-v1"
              (agentic-ai-lab-query-source-content-identity Query)
              'gerbil-parser
              "sha256:provenance-v1"
              "sha256:result-v1"
              3
              #t))
            (receipt
             (agentic-ai-lab-query-bind-execution-receipt
              TestQueryProvider Query admission candidate)))
       (check (agentic-ai-lab-source-query-receipt? receipt) => #t)
       (check (.ref receipt 'admitted?) => #t)
       (check (.ref receipt 'diagnostics) => '())
       (check (.ref receipt 'provider-identity) => 'test)
       (check (.ref receipt 'result-contract-identity)
              => 'healthcare/query-result)
       (check (.ref receipt 'runtime-executed?) => #t)
       (check (.ref receipt 'mutation-authority?) => #f)
       (check (.ref receipt 'action-authority?) => #f)))

   (yuanxu-test-case "does not reuse another Query's admission receipt"
     (let* ((admission (agentic-ai-lab-query-admit Query QuerySpace))
            (wrong-admission
             (.o (:: @ admission) query-identity: 'other-query))
            (candidate
             (agentic-ai-lab-query-execution-candidate
              'test 'healthcare/case-profile-relations "1"
              "sha256:space-v1"
              (agentic-ai-lab-query-source-content-identity Query)
              'gerbil-parser "sha256:provenance-v1"
              "sha256:result-v1" 3 #t))
            (receipt
             (agentic-ai-lab-query-bind-execution-receipt
              TestQueryProvider Query wrong-admission candidate)))
       (check (.ref receipt 'admitted?) => #f)
       (check (.ref receipt 'diagnostics)
              => '((query-admission-identity-mismatch)))))

   (yuanxu-test-case "rejects drifted or over-bound Provider evidence"
     (let* ((admission (agentic-ai-lab-query-admit Query QuerySpace))
            (candidate
             (agentic-ai-lab-query-execution-candidate
              'test
              'healthcare/case-profile-relations
              "1"
              "sha256:space-v2"
              "sha256:wrong-source"
              'other-parser
              "sha256:provenance-v1"
              "sha256:result-v1"
              17
              #f))
            (receipt
             (agentic-ai-lab-query-bind-execution-receipt
              TestQueryProvider Query admission candidate)))
       (check (.ref receipt 'admitted?) => #f)
       (check (map car (.ref receipt 'diagnostics))
              => '(semantic-revision-mismatch
                   source-content-identity-mismatch
                   parser-identity-mismatch
                   query-result-bound-exceeded
                   incomplete-query-result))
       (check (.ref receipt 'action-authority?) => #f)))

   (yuanxu-test-case "GQL receipt binds one Temporal cut but supplies no check"
     (let* ((admission (agentic-ai-lab-query-admit Query QuerySpace))
            (provider-candidate
             (agentic-ai-lab-query-execution-candidate
              'test 'healthcare/case-profile-relations "1" "sha256:space-v1"
              (agentic-ai-lab-query-source-content-identity Query)
              'gerbil-parser "sha256:provenance-v1" "sha256:result-v1"
              3 #t))
            (source-receipt
             (agentic-ai-lab-query-bind-execution-receipt
              TestQueryProvider Query admission provider-candidate))
            (scope
             (agentic-ai-lab-candidate-scope
              "scope" "sha256:space-v1" 0 "sha256:coverage"
              '(gql ascent)))
            (gql-receipt
             (agentic-ai-lab-gql-candidate-receipt
              "gql-receipt" "candidate" scope Query QuerySpace
              TestQueryProvider
              source-receipt))
            (exchange
             (agentic-ai-lab-candidate-exchange
              "exchange" "candidate" scope (list gql-receipt) '())))
       (check (.ref gql-receipt 'provider-identity) => 'gql)
       (check (.ref gql-receipt 'result-digest) => "sha256:result-v1")
       (check (.ref gql-receipt 'result-count) => 3)
       (check (.ref exchange 'status) => 'pending)
       (check (.ref exchange 'missing-providers) => '(ascent))
       (check (.ref exchange 'unchecked-receipts) => '("gql-receipt"))
       (check (.ref exchange 'admitted?) => #f)
       (check-exception
        (agentic-ai-lab-gql-candidate-receipt
         "stale" "candidate"
         (agentic-ai-lab-candidate-scope
          "scope" "sha256:space-v2" 1 "sha256:coverage" '(gql ascent))
         Query QuerySpace TestQueryProvider source-receipt)
        true)
       (check-exception
        (agentic-ai-lab-gql-candidate-receipt
         "forged" "candidate" scope Query QuerySpace
         TestQueryProvider
         (validate AgenticAILabSourceQueryReceipt
                   (.o (:: @ source-receipt)
                       result-digest: "sha256:other"
                       source-content-identity: "sha256:other-source")))
        true)))

   (yuanxu-test-case "scalar rows replay and check a declared GQL result"
     (let* ((cells
             (list (agentic-ai-lab-query-result-cell 'source "source-1")
                   (agentic-ai-lab-query-result-cell 'target "profile-1")
                   (agentic-ai-lab-query-result-cell 'evidence #t)))
            (row (agentic-ai-lab-query-result-row 'row-1 cells))
            (reordered
             (agentic-ai-lab-query-result-row 'row-1 (reverse cells)))
            (rows
             (agentic-ai-lab-query-result-set
              "result-set" QueryResult (.ref Query 'identity)
              (.ref Query 'version) (.ref Query 'semantic-revision)
              (list row) #t))
            (admission (agentic-ai-lab-query-admit Query QuerySpace))
            (provider-candidate
             (agentic-ai-lab-query-execution-candidate
              'test (.ref Query 'identity) (.ref Query 'version)
              (.ref Query 'semantic-revision)
              (agentic-ai-lab-query-source-content-identity Query)
              'gerbil-parser "sha256:provenance-v1"
              (.ref rows 'result-digest) 1 #t))
            (source-receipt
             (agentic-ai-lab-query-bind-execution-receipt
              TestQueryProvider Query admission provider-candidate))
            (scope
             (agentic-ai-lab-candidate-scope
              "scope" "sha256:space-v1" 0 "sha256:coverage" '(gql)))
            (candidate-receipt
             (agentic-ai-lab-gql-candidate-receipt
              "gql" "candidate" scope Query QuerySpace
              TestQueryProvider source-receipt))
            (row-check
             (agentic-ai-lab-gql-candidate-row-check
              "rows" candidate-receipt Query rows))
            (exchange
             (agentic-ai-lab-candidate-exchange
              "exchange" "candidate" scope (list candidate-receipt)
              (list row-check))))
       (check (.ref row 'semantic-digest)
              => (.ref reordered 'semantic-digest))
       (check (.ref rows 'result-count) => 1)
       (check (substring (.ref rows 'result-digest) 0 29)
              => "agentic-ai-lab.query.scalar-row-v1:")
       (check (.ref row-check 'verdict) => 'valid)
       (check (.ref exchange 'status) => 'reviewable)
       (check (.ref exchange 'admitted?) => #f)
       (check-exception
        (agentic-ai-lab-query-result-set-replay
         (.o (:: @ rows) result-count: 2) QueryResult)
        true)
       (check-exception
        (agentic-ai-lab-query-result-row 'duplicate
                                   (list (car cells) (car cells)))
        true)
       (check-exception
        (agentic-ai-lab-query-result-set
         "missing-field" QueryResult (.ref Query 'identity)
         (.ref Query 'version) (.ref Query 'semantic-revision)
         (list (agentic-ai-lab-query-result-row
                'missing (list (car cells)))) #t)
        true)
       (let* ((other-rows
               (agentic-ai-lab-query-result-set
                "other" QueryResult (.ref Query 'identity)
                (.ref Query 'version) (.ref Query 'semantic-revision)
                (list (agentic-ai-lab-query-result-row
                       'row-1
                       (list (agentic-ai-lab-query-result-cell 'source "different")
                             (cadr cells) (caddr cells)))) #t))
              (invalid
               (agentic-ai-lab-gql-candidate-row-check
                "invalid" candidate-receipt Query other-rows)))
         (check (.ref invalid 'verdict) => 'invalid))))

   (yuanxu-test-case "rejects undeclared Elements without widening the space"
     (let* ((query
             (validate
              AgenticAILabQuery
              (.o (:: @ Query)
                  selected-element-identities: '(case-1 missing-profile))))
            (receipt (agentic-ai-lab-query-admit query QuerySpace)))
       (check (.ref receipt 'accepted?) => #f)
       (check (.ref receipt 'diagnostics)
              => '((undeclared-selected-elements (missing-profile))))
       (check (.ref receipt 'action-authority?) => #f)))

   (yuanxu-test-case "rejects raw GQL and arbitrary Scheme programs"
     (check
      (agentic-ai-lab-query?
       (.o (:: @ Query) program: "MATCH (n) RETURN n"))
      => #f)
     (check
      (agentic-ai-lab-query?
       (.o (:: @ Query) program: (lambda (_) #t)))
      => #f))

   (yuanxu-test-case "rejects revision drift and incomplete complete-space claims"
     (let* ((space
             (agentic-ai-lab-query-element-space
              'healthcare/case-space "sha256:space-v2"
              '(case-1 profile-1 source-1) #f))
            (receipt (agentic-ai-lab-query-admit Query space)))
       (check (.ref receipt 'accepted?) => #f)
       (check (map car (.ref receipt 'diagnostics))
              => '(semantic-revision-mismatch incomplete-element-space))
       (check (.ref receipt 'runtime-executed?) => #f)))))
