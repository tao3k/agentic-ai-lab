;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :clan/poo/object .o .cc .ref)
        (only-in :tao3k/yuanxu/graph/types yuanxu-graph yuanxu-graph-node yuanxu-graph-edge)
        (only-in ../modules/query/objects
                 AgenticAILabQuery. AgenticAILabQueryElementSpace. AgenticAILabSchemeGqlQueryLanguage.
                 AgenticAILabGqlQueryProgram. GraphSyntaxNode. GraphSyntaxStep. GraphSyntaxPath.
                 GraphSyntaxEquals. GraphSyntaxLiteral. GraphSyntaxProperty. GraphSyntaxProjection.
                 agentic-ai-lab-query-result-contract)
        (only-in ../modules/query/gql agentic-ai-lab-query->gql)
        (only-in ../modules/query/scheme-graph agentic-ai-lab-query-select-scheme-graph))
(export query-scheme-graph-test)

(def nodes
  (list (yuanxu-graph-node "a" (.o identity: "a" label: 'Commit revision: "rev-a"))
        (yuanxu-graph-node "b" (.o identity: "b" label: 'Commit revision: "rev-b"))
        (yuanxu-graph-node "source-a" (.o identity: "source-a" label: 'File path: "changed.rs"))
        (yuanxu-graph-node "consumer-a" (.o identity: "consumer-a" label: 'File path: "unchanged.rs"))
        (yuanxu-graph-node "source-b" (.o identity: "source-b" label: 'File path: "other.rs"))))
(def ids '("a" "b" "source-a" "consumer-a" "source-b"))
(def edges
  (list (yuanxu-graph-edge "a" "source-a" 'CHANGES)
        (yuanxu-graph-edge "source-a" "consumer-a" 'USED_BY)
        (yuanxu-graph-edge "b" "source-b" 'CHANGES)))
(def space
  (.o (:: @ AgenticAILabQueryElementSpace.) identity: 'review
      semantic-revision: "snapshot-1" element-identities: ids complete?: #t))
(def graph (yuanxu-graph 'review nodes edges))
(def query
  (.o (:: @ AgenticAILabQuery.) identity: 'related-code version: "1"
      semantic-revision: "snapshot-1" element-space-identity: 'review selected-element-identities: ids
      language: AgenticAILabSchemeGqlQueryLanguage. result-bound: 8 completeness-requirement: 'complete
      result-contract: (agentic-ai-lab-query-result-contract 'related-code 'relation-row '(changed related) 8)
      program:
      (.o (:: @ AgenticAILabGqlQueryProgram.) identity: 'related-code
          match: (.o (:: @ GraphSyntaxPath.)
                     start: (.o (:: @ GraphSyntaxNode.) binding: 'c label: 'Commit)
                     next: (.o (:: @ GraphSyntaxStep.) relation: 'CHANGES
                               target: (.o (:: @ GraphSyntaxNode.) binding: 'changed label: 'File)
                               next: (.o (:: @ GraphSyntaxStep.) relation: 'USED_BY
                                         target: (.o (:: @ GraphSyntaxNode.) binding: 'related label: 'File))))
          where: (.o (:: @ GraphSyntaxEquals.)
                     left: (.o (:: @ GraphSyntaxProperty.) binding: 'c property: 'revision)
                     right: (.o (:: @ GraphSyntaxLiteral.) literal-kind: 'string value: "rev-a"))
          project: (.o (:: @ GraphSyntaxProjection.)
                       expression: (.o (:: @ GraphSyntaxProperty.) binding: 'changed property: 'path)
                       next: (.o (:: @ GraphSyntaxProjection.)
                                 expression: (.o (:: @ GraphSyntaxProperty.) binding: 'related property: 'path))))))

(def query-scheme-graph-test
  (test-suite "GQL path selection over the owned Yuanxu graph"
    (test-case "revision root joins changed and unchanged files"
      (let (result (agentic-ai-lab-query-select-scheme-graph query space graph))
        (check (.ref result 'rows) => '(("changed.rs" "unchanged.rs")))
        (check (.ref result 'complete?) => #t)
        (check (.ref result 'action-authority?) => #f)
        (check (.ref result 'external-provenance-verified?) => #f)
        (check (and (string-contains (agentic-ai-lab-query->gql query) "USED_BY") #t) => #t)))
    (test-case "stale semantic revision is not admitted"
      (check-exception
       (agentic-ai-lab-query-select-scheme-graph (.cc query semantic-revision: "snapshot-old") space graph) true))
    (test-case "unknown inventory cannot claim complete coverage"
      (let (unknown (.cc space complete?: #f))
        (check-exception (agentic-ai-lab-query-select-scheme-graph query unknown graph) true)
        (check (.ref (agentic-ai-lab-query-select-scheme-graph
                      (.cc query completeness-requirement: 'partial-allowed) unknown graph) 'complete?) => #f)))
    (test-case "dangling dependencies and duplicate identities reject"
      (check-exception (agentic-ai-lab-query-select-scheme-graph query space
                         (yuanxu-graph 'review nodes (cons (yuanxu-graph-edge "source-a" "missing" 'USED_BY) edges))) true)
      (check-exception (agentic-ai-lab-query-select-scheme-graph query space
                         (yuanxu-graph 'review (cons (car nodes) nodes) edges)) true))
    (test-case "selected scope cannot silently hide a reached consumer"
      (check-exception
       (agentic-ai-lab-query-select-scheme-graph
        (.cc query selected-element-identities: '("a" "b" "source-a" "source-b")) space graph) true))
    (test-case "result bound refuses truncation"
      (check-exception
       (agentic-ai-lab-query-select-scheme-graph (.cc query result-bound: 1) space
        (yuanxu-graph 'review nodes (append edges (list (yuanxu-graph-edge "source-a" "source-b" 'USED_BY))))) true))))
