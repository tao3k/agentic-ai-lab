;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test check check-exception test-suite)
        (only-in :clan/poo/object .o .ref)
        (only-in :clan/poo/mop validate)
        :poo-flow/modules/query/interface
        :yuanxu/poo-clos/interface
        (only-in :poo-flow/modules/temporal-causality/candidates/interface
                 poo-flow-candidate-scope poo-flow-candidate-exchange
                 poo-flow-gql-candidate-receipt
                 poo-flow-gql-candidate-row-check))

(export query-core-test)

(def QueryResult
  (poo-flow-query-result-contract
   'healthcare/query-result 'relation-row
   '(source target evidence) 32))

(def QuerySpace
  (poo-flow-query-element-space
   'healthcare/case-space "sha256:space-v1"
   '(case-1 profile-1 source-1) #t))

;;; Scheme is the concise host notation.  The value itself is one GQL-aligned
;;; POO AST, so inheritance and slot algebra remain available without creating
;;; a second Scheme Query language.
(def CaseProfileProgram
  (.o (:: @ PooFlowGqlQueryProgram.)
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
   PooFlowQuery
   (.o (:: @ PooFlowQuery.)
       identity: 'healthcare/case-profile-relations
       version: "1"
       semantic-revision: "sha256:space-v1"
       element-space-identity: 'healthcare/case-space
       selected-element-identities: '(case-1 profile-1)
       language: PooFlowGqlQueryLanguage.
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
  (poo-flow-query-provider 'test '(gql) 'test
                           (poo-clos-make-instance TestQueryExecutor)))
(def TestQueryBindingMethod
  (poo-clos-method
   'query/test-receipt-binding
   (list (poo-clos-class-specializer TestQueryExecutor)
         (poo-clos-eql-specializer TestQueryProvider)
         (poo-clos-prototype-specializer PooFlowQuery.)
         (poo-clos-any-specializer)
         (poo-clos-any-specializer))
   (lambda (_frame _executor provider query admission candidate)
     (poo-flow-query-bind-execution-receipt/default
      provider query admission candidate))))
(.defmethod-bundle TestQueryBindingMethods
  QueryReceiptBindingProtocol TestQueryBindingMethod)
(poo-clos-compose-method-bundle
 QueryReceiptBindingGeneric TestQueryBindingMethods)

(def query-core-test
  (test-suite
   "canonical Query core"

   (yuanxu-test-case "publishes one semantic language with two surfaces"
     (check (.ref PooFlowQueryModule. 'query) => PooFlowQuery.)
     (check (.ref (.ref PooFlowQueryModule. 'languages) 'gql)
            => PooFlowGqlQueryLanguage.)
     (check (.ref PooFlowGqlQueryLanguage. 'authoring-surface)
            => 'scheme-poo)
     (check (.ref PooFlowGqlQueryLanguage. 'source-surface) => 'gql)
     (check (.ref PooFlowGqlQueryLanguage. 'parser-owner)
            => 'gerbil-parser)
     (check (.ref PooFlowQueryModule. 'element-space)
            => PooFlowQueryElementSpace.)
     (check (.ref PooFlowQueryModule. 'result-contract)
            => PooFlowQueryResultContract.)
     (check (.ref PooFlowQueryModule. 'result-cell)
            => PooFlowQueryResultCell.)
     (check (.ref PooFlowQueryModule. 'result-row)
            => PooFlowQueryResultRow.)
     (check (.ref PooFlowQueryModule. 'result-set)
            => PooFlowQueryResultSet.))

   (yuanxu-test-case "projects the POO AST deterministically to standard GQL"
     (check
      (poo-flow-query->gql Query)
      =>
      (string-append
       "MATCH (s:Scenario)-[:HAS_CASE]->(c:Case)-[:HAS_EFFECTIVE_PROFILE]->(p:Profile)\n"
       "WHERE s.identity = 'healthcare'\n"
       "RETURN s.identity, c.id, p.identity\n")))

   (yuanxu-test-case "selects POO nodes with the Scheme GQL syntax slice"
     (let* ((scheme-program
             (.o (:: @ PooFlowGqlQueryProgram.)
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
                 language: PooFlowSchemeGqlQueryLanguage.
                 program: scheme-program))
            (result
             (poo-flow-query-select-scheme-nodes
              scheme-query
              (list (.o label: 'Signal identity: 'record)
                    (.o label: 'Other identity: 'ignored)))))
       (check (.ref result 'rows) => '((record)))
       (check (.ref result 'executed-in-scheme?) => #t)
       (check (.ref result 'external-provenance-verified?) => #f)
       (check-exception
        (poo-flow-query-select-scheme-nodes
         (.o (:: @ Query)
             language: PooFlowSchemeGqlQueryLanguage.)
         (list (.o label: 'Scenario identity: "healthcare")))
        true)
       (check-exception
        (poo-flow-query-select-scheme-nodes
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
        (poo-flow-query-program->gql escaped)
        =>
        (string-append
         "MATCH (s:Scenario)-[:HAS_CASE]->(c:Case)-[:HAS_EFFECTIVE_PROFILE]->(p:Profile)\n"
         "WHERE s.identity = 'patient''s-case'\n"
         "RETURN s.identity, c.id, p.identity\n"))))

   (yuanxu-test-case "admits a bounded read-only Query against its ElementSpace"
     (let (receipt (poo-flow-query-admit Query QuerySpace))
       (check (poo-flow-query-admission-receipt? receipt) => #t)
       (check (.ref receipt 'accepted?) => #t)
       (check (.ref receipt 'diagnostics) => '())
       (check (.ref receipt 'semantic-revision) => "sha256:space-v1")
       (check (.ref receipt 'language-identity) => 'gql)
       (check (.ref receipt 'mutation-authority?) => #f)
       (check (.ref receipt 'action-authority?) => #f)
       (check (.ref receipt 'runtime-executed?) => #f)))

   (yuanxu-test-case "binds an admitted test candidate through Provider x Query dispatch"
     (let* ((admission (poo-flow-query-admit Query QuerySpace))
            (candidate
             (poo-flow-query-execution-candidate
              'test
              'healthcare/case-profile-relations
              "1"
              "sha256:space-v1"
              (poo-flow-query-source-content-identity Query)
              'gerbil-parser
              "sha256:provenance-v1"
              "sha256:result-v1"
              3
              #t))
            (receipt
             (poo-flow-query-bind-execution-receipt
              TestQueryProvider Query admission candidate)))
       (check (poo-flow-source-query-receipt? receipt) => #t)
       (check (.ref receipt 'admitted?) => #t)
       (check (.ref receipt 'diagnostics) => '())
       (check (.ref receipt 'provider-identity) => 'test)
       (check (.ref receipt 'result-contract-identity)
              => 'healthcare/query-result)
       (check (.ref receipt 'runtime-executed?) => #t)
       (check (.ref receipt 'mutation-authority?) => #f)
       (check (.ref receipt 'action-authority?) => #f)))

   (yuanxu-test-case "does not reuse another Query's admission receipt"
     (let* ((admission (poo-flow-query-admit Query QuerySpace))
            (wrong-admission
             (.o (:: @ admission) query-identity: 'other-query))
            (candidate
             (poo-flow-query-execution-candidate
              'test 'healthcare/case-profile-relations "1"
              "sha256:space-v1"
              (poo-flow-query-source-content-identity Query)
              'gerbil-parser "sha256:provenance-v1"
              "sha256:result-v1" 3 #t))
            (receipt
             (poo-flow-query-bind-execution-receipt
              TestQueryProvider Query wrong-admission candidate)))
       (check (.ref receipt 'admitted?) => #f)
       (check (.ref receipt 'diagnostics)
              => '((query-admission-identity-mismatch)))))

   (yuanxu-test-case "rejects drifted or over-bound Provider evidence"
     (let* ((admission (poo-flow-query-admit Query QuerySpace))
            (candidate
             (poo-flow-query-execution-candidate
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
             (poo-flow-query-bind-execution-receipt
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
     (let* ((admission (poo-flow-query-admit Query QuerySpace))
            (provider-candidate
             (poo-flow-query-execution-candidate
              'test 'healthcare/case-profile-relations "1" "sha256:space-v1"
              (poo-flow-query-source-content-identity Query)
              'gerbil-parser "sha256:provenance-v1" "sha256:result-v1"
              3 #t))
            (source-receipt
             (poo-flow-query-bind-execution-receipt
              TestQueryProvider Query admission provider-candidate))
            (scope
             (poo-flow-candidate-scope
              "scope" "sha256:space-v1" 0 "sha256:coverage"
              '(gql ascent)))
            (gql-receipt
             (poo-flow-gql-candidate-receipt
              "gql-receipt" "candidate" scope Query QuerySpace
              TestQueryProvider
              source-receipt))
            (exchange
             (poo-flow-candidate-exchange
              "exchange" "candidate" scope (list gql-receipt) '())))
       (check (.ref gql-receipt 'provider-identity) => 'gql)
       (check (.ref gql-receipt 'result-digest) => "sha256:result-v1")
       (check (.ref gql-receipt 'result-count) => 3)
       (check (.ref exchange 'status) => 'pending)
       (check (.ref exchange 'missing-providers) => '(ascent))
       (check (.ref exchange 'unchecked-receipts) => '("gql-receipt"))
       (check (.ref exchange 'admitted?) => #f)
       (check-exception
        (poo-flow-gql-candidate-receipt
         "stale" "candidate"
         (poo-flow-candidate-scope
          "scope" "sha256:space-v2" 1 "sha256:coverage" '(gql ascent))
         Query QuerySpace TestQueryProvider source-receipt)
        true)
       (check-exception
        (poo-flow-gql-candidate-receipt
         "forged" "candidate" scope Query QuerySpace
         TestQueryProvider
         (validate PooFlowSourceQueryReceipt
                   (.o (:: @ source-receipt)
                       result-digest: "sha256:other"
                       source-content-identity: "sha256:other-source")))
        true)))

   (yuanxu-test-case "scalar rows replay and check a declared GQL result"
     (let* ((cells
             (list (poo-flow-query-result-cell 'source "source-1")
                   (poo-flow-query-result-cell 'target "profile-1")
                   (poo-flow-query-result-cell 'evidence #t)))
            (row (poo-flow-query-result-row 'row-1 cells))
            (reordered
             (poo-flow-query-result-row 'row-1 (reverse cells)))
            (rows
             (poo-flow-query-result-set
              "result-set" QueryResult (.ref Query 'identity)
              (.ref Query 'version) (.ref Query 'semantic-revision)
              (list row) #t))
            (admission (poo-flow-query-admit Query QuerySpace))
            (provider-candidate
             (poo-flow-query-execution-candidate
              'test (.ref Query 'identity) (.ref Query 'version)
              (.ref Query 'semantic-revision)
              (poo-flow-query-source-content-identity Query)
              'gerbil-parser "sha256:provenance-v1"
              (.ref rows 'result-digest) 1 #t))
            (source-receipt
             (poo-flow-query-bind-execution-receipt
              TestQueryProvider Query admission provider-candidate))
            (scope
             (poo-flow-candidate-scope
              "scope" "sha256:space-v1" 0 "sha256:coverage" '(gql)))
            (candidate-receipt
             (poo-flow-gql-candidate-receipt
              "gql" "candidate" scope Query QuerySpace
              TestQueryProvider source-receipt))
            (row-check
             (poo-flow-gql-candidate-row-check
              "rows" candidate-receipt Query rows))
            (exchange
             (poo-flow-candidate-exchange
              "exchange" "candidate" scope (list candidate-receipt)
              (list row-check))))
       (check (.ref row 'semantic-digest)
              => (.ref reordered 'semantic-digest))
       (check (.ref rows 'result-count) => 1)
       (check (substring (.ref rows 'result-digest) 0 29)
              => "poo-flow.query.scalar-row-v1:")
       (check (.ref row-check 'verdict) => 'valid)
       (check (.ref exchange 'status) => 'reviewable)
       (check (.ref exchange 'admitted?) => #f)
       (check-exception
        (poo-flow-query-result-set-replay
         (.o (:: @ rows) result-count: 2) QueryResult)
        true)
       (check-exception
        (poo-flow-query-result-row 'duplicate
                                   (list (car cells) (car cells)))
        true)
       (check-exception
        (poo-flow-query-result-set
         "missing-field" QueryResult (.ref Query 'identity)
         (.ref Query 'version) (.ref Query 'semantic-revision)
         (list (poo-flow-query-result-row
                'missing (list (car cells)))) #t)
        true)
       (let* ((other-rows
               (poo-flow-query-result-set
                "other" QueryResult (.ref Query 'identity)
                (.ref Query 'version) (.ref Query 'semantic-revision)
                (list (poo-flow-query-result-row
                       'row-1
                       (list (poo-flow-query-result-cell 'source "different")
                             (cadr cells) (caddr cells)))) #t))
              (invalid
               (poo-flow-gql-candidate-row-check
                "invalid" candidate-receipt Query other-rows)))
         (check (.ref invalid 'verdict) => 'invalid))))

   (yuanxu-test-case "rejects undeclared Elements without widening the space"
     (let* ((query
             (validate
              PooFlowQuery
              (.o (:: @ Query)
                  selected-element-identities: '(case-1 missing-profile))))
            (receipt (poo-flow-query-admit query QuerySpace)))
       (check (.ref receipt 'accepted?) => #f)
       (check (.ref receipt 'diagnostics)
              => '((undeclared-selected-elements (missing-profile))))
       (check (.ref receipt 'action-authority?) => #f)))

   (yuanxu-test-case "rejects raw GQL and arbitrary Scheme programs"
     (check
      (poo-flow-query?
       (.o (:: @ Query) program: "MATCH (n) RETURN n"))
      => #f)
     (check
      (poo-flow-query?
       (.o (:: @ Query) program: (lambda (_) #t)))
      => #f))

   (yuanxu-test-case "rejects revision drift and incomplete complete-space claims"
     (let* ((space
             (poo-flow-query-element-space
              'healthcare/case-space "sha256:space-v2"
              '(case-1 profile-1 source-1) #f))
            (receipt (poo-flow-query-admit Query space)))
       (check (.ref receipt 'accepted?) => #f)
       (check (map car (.ref receipt 'diagnostics))
              => '(semantic-revision-mismatch incomplete-element-space))
       (check (.ref receipt 'runtime-executed?) => #f)))))
