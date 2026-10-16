;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; One document-local, read-only Query over source-derived Orgize Elements.
;;; A host must supply and recheck current source bytes; this value does not
;;; grant file, WorkTree, Session, temporal, or effect authority.
(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :clan/poo/mop validate)
        (only-in :poo-flow/modules/query/semantic/orgize-source-interface
                 org-source-headline-elements
                 org-source-headline-elements?
                 org-source-headline-parser-identity)
        (only-in "objects.ss"
                 PooFlowQuery. PooFlowSchemeGqlQueryLanguage.
                 PooFlowGqlQueryProgram.
                 GraphSyntaxPath. GraphSyntaxNode. GraphSyntaxEquals.
                 GraphSyntaxProperty. GraphSyntaxLiteral. GraphSyntaxProjection.
                 poo-flow-query-element-space
                 poo-flow-query-result-contract)
        (only-in "types.ss" PooFlowQuery)
        (only-in "funs.ss" poo-flow-query-admit)
        (only-in "gql.ss" poo-flow-query->gql)
        (only-in "scheme-select.ss" poo-flow-query-select-scheme-nodes)
        (only-in "results/funs.ss"
                 poo-flow-query-result-cell poo-flow-query-result-row
                 poo-flow-query-result-set poo-flow-query-result-set-replay)
        :core/poo-clos/interface)

(export poo-flow-query-orgize-open-headlines-incremental
        poo-flow-query-orgize-open-headlines
        poo-flow-query-orgize-open-headlines-replay
        poo-flow-query-orgize-source-observation?)

(def OrgOpenHeadlineResult
  (poo-flow-query-result-contract
   'orgize/open-headline-row-v1 'relation-row
   '(source-sha256 byte-start byte-end title todo-type) 256))

(def OrgOpenHeadlineProgram
  (.o (:: @ PooFlowGqlQueryProgram.)
      identity: 'orgize/open-headlines-v1
      match:
      (.o (:: @ GraphSyntaxPath.)
          start: (.o (:: @ GraphSyntaxNode.)
                     binding: 'h label: 'OrgHeadline))
      where:
      (.o (:: @ GraphSyntaxEquals.)
          left: (.o (:: @ GraphSyntaxProperty.)
                    binding: 'h property: 'todoType)
          right: (.o (:: @ GraphSyntaxLiteral.)
                     literal-kind: 'string value: "todo"))
      project:
      (.o (:: @ GraphSyntaxProjection.)
          expression: (.o (:: @ GraphSyntaxProperty.)
                          binding: 'h property: 'identity)
          next:
          (.o (:: @ GraphSyntaxProjection.)
              expression: (.o (:: @ GraphSyntaxProperty.)
                              binding: 'h property: 'byteStart)
              next:
              (.o (:: @ GraphSyntaxProjection.)
                  expression: (.o (:: @ GraphSyntaxProperty.)
                                  binding: 'h property: 'byteEnd)
                  next:
                  (.o (:: @ GraphSyntaxProjection.)
                      expression: (.o (:: @ GraphSyntaxProperty.)
                                      binding: 'h property: 'title)
                      next:
                      (.o (:: @ GraphSyntaxProjection.)
                          expression: (.o (:: @ GraphSyntaxProperty.)
                                          binding: 'h property: 'todoType))))))))

(def (source-elements->query-nodes elements digest)
  (map (lambda (element)
         (.o label: 'OrgHeadline
             identity: (.ref element 'identity)
             byteStart: (.ref element 'byte-start)
             byteEnd: (.ref element 'byte-end)
             title: (.ref element 'title)
             todoType: (.ref element 'todo-type)
             sourceSha256: digest))
       elements))

(def (query-row->result-row values digest)
  (unless (= (length values) 5)
    (error "Org Query projection returned an invalid row" values))
  (poo-flow-query-result-row
   (car values)
   (list (poo-flow-query-result-cell 'source-sha256 digest)
         (poo-flow-query-result-cell 'byte-start (cadr values))
         (poo-flow-query-result-cell 'byte-end (caddr values))
         (poo-flow-query-result-cell 'title (cadddr values))
         (poo-flow-query-result-cell 'todo-type (car (cddddr values))))))

(def (open-headlines source previous)
  (let* ((projection (org-source-headline-elements source)))
    (unless (and (org-source-headline-elements? projection)
                 (equal? (.ref projection 'parser-identity)
                         org-source-headline-parser-identity)
                 (.ref projection 'complete?))
      (error "Orgize source Element projection is incomplete"))
    (let* ((digest (.ref projection 'source-sha256))
           (elements (.ref projection 'elements))
           (space-id (string-append digest ":org-headlines"))
           (space
            (poo-flow-query-element-space
             space-id digest
             (map (lambda (element) (.ref element 'identity)) elements)
             #t))
           (query-value
            (validate
             PooFlowQuery
             (.o (:: @ PooFlowQuery.)
                 identity: 'orgize/open-headlines-v1
                 version: "1"
                 semantic-revision: digest
                 element-space-identity: space-id
                 selected-element-identities:
                 (.ref space 'element-identities)
                 language: PooFlowSchemeGqlQueryLanguage.
                 program: OrgOpenHeadlineProgram
                 result-bound: 256
                 completeness-requirement: 'complete
                 evidence-requirements: '()
                 visibility-request: 'restricted
                 result-contract: OrgOpenHeadlineResult)))
           (admission-value (poo-flow-query-admit query-value space)))
      (unless (.ref admission-value 'accepted?)
        (error "source-derived Org Query failed ElementSpace admission"))
      (let* ((nodes (source-elements->query-nodes elements digest))
             ;; Complete local inputs exclude the globally rebound source identity.
             ;; Byte positions are conservative local keys; shifted nodes are recomputed.
             (snapshot (lambda (node)
               (list (.ref node 'byteStart) (.ref node 'byteEnd)
                     (.ref node 'title) (.ref node 'todoType))))
             (old-inputs (make-hash-table test: equal?))
             (old-rows (make-hash-table test: equal?))
             (_ (when previous
                  (for-each (lambda (v) (hash-put! old-inputs (car v) v)) (.ref previous 'node-snapshots))
                  (for-each (lambda (v) (hash-put! old-rows (cadr v) v)) (.ref previous 'selection-rows))))
             (reusable? (lambda (node)
               (equal? (hash-get old-inputs (.ref node 'byteStart)) (snapshot node))))
             (changed (filter (lambda (node) (not (reusable? node))) nodes))
             (selection (poo-flow-query-select-scheme-nodes query-value changed))
             (changed-rows (make-hash-table test: equal?))
             (_rows (for-each (lambda (v) (hash-put! changed-rows (cadr v) v)) (.ref selection 'rows)))
             (selected-values
               (filter values (map (lambda (node)
                 (let (row (hash-get (if (reusable? node) old-rows changed-rows) (.ref node 'byteStart)))
                   (and row (cons (.ref node 'identity) (cdr row))))) nodes)))
             (rows
              (map (lambda (values) (query-row->result-row values digest))
                   selected-values))
             (result
              (poo-flow-query-result-set
               (string-append digest ":open-headlines-result")
               OrgOpenHeadlineResult
               (.ref query-value 'identity) (.ref query-value 'version) digest rows #t)))
        (.o kind: 'poo-flow.query.orgize-source-observation
            node-snapshots: (map snapshot nodes) selection-rows: selected-values
            evaluated-node-count: (length changed) reused-node-count: (- (length nodes) (length changed))
            dependency-profile: 'orgize/local-open-headline-v1
            parser-identity: org-source-headline-parser-identity
            source-sha256: digest
            source-size: (.ref projection 'source-size)
            element-space: space
            query: query-value
            admission: admission-value
            result-set: result
            query-executed-in-scheme?: #t
            worktree-bound?: #f
            session-admitted?: #f
            action-authority?: #f)))))

(def (poo-flow-query-orgize-open-headlines source)
  (open-headlines source #f))
(def (poo-flow-query-orgize-open-headlines-incremental base-source observed source)
  ;; Rebuild the cache from source replay; caller-supplied cache slots are never trusted.
  (let (verified (poo-flow-query-orgize-open-headlines-replay base-source observed))
    (open-headlines source verified)))

(def (poo-flow-query-orgize-source-observation? value)
  (and (object? value) (.slot? value 'kind)
       (eq? (.ref value 'kind)
            'poo-flow.query.orgize-source-observation)))

(def (same-slots? left right names)
  (and (object? left) (object? right)
       (let loop ((rest names))
         (or (null? rest)
             (and (.slot? left (car rest)) (.slot? right (car rest))
                  (equal? (.ref left (car rest))
                          (.ref right (car rest)))
                  (loop (cdr rest)))))))

;;; Replay always re-parses the supplied current bytes through Orgize and
;;; re-executes the fixed canonical Query. A digest-valid forged row or altered
;;; Query program still has to match the fresh source-derived result exactly.
(def (poo-flow-query-orgize-open-headlines-replay source observed)
  (unless (poo-flow-query-orgize-source-observation? observed)
    (error "invalid Org source Query observation"))
  (let* ((current (poo-flow-query-orgize-open-headlines source))
         (expected-query (.ref current 'query))
         (observed-query (.ref observed 'query))
         (observed-set
          (poo-flow-query-result-set-replay
           (.ref observed 'result-set) OrgOpenHeadlineResult)))
    (unless
      (and (same-slots?
            observed current
            '(parser-identity source-sha256 source-size
              query-executed-in-scheme? worktree-bound?
              session-admitted? action-authority?))
           (same-slots?
            observed-query expected-query
            '(identity version semantic-revision element-space-identity
              selected-element-identities result-bound
              completeness-requirement evidence-requirements
              visibility-request mutation-authority? action-authority?
              runtime-executed?))
           (same-slots?
            (.ref observed-query 'language)
            (.ref expected-query 'language)
            '(identity representation execution-boundary runtime-owner
              parser-owner syntax-contract))
           (same-slots?
            (.ref observed-query 'result-contract)
            (.ref expected-query 'result-contract)
            '(identity result-kind required-fields max-results))
           (equal? (poo-flow-query->gql observed-query)
                   (poo-flow-query->gql expected-query))
           (same-slots?
            (.ref observed 'element-space) (.ref current 'element-space)
            '(identity semantic-revision element-identities complete?))
           (same-slots?
            (.ref observed 'admission) (.ref current 'admission)
            '(query-identity query-version semantic-revision
              element-space-identity accepted? diagnostics))
           (equal? (.ref observed-set 'identity)
                   (.ref (.ref current 'result-set) 'identity))
           (equal? (.ref observed-set 'semantic-digest)
                   (.ref (.ref current 'result-set) 'semantic-digest)))
      (error "Org source Query observation differs from current source"))
    current))
