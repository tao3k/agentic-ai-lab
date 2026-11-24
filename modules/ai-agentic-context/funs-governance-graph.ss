;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Layered Org-as-Context governance graph projection and POO GQL queries.
(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :std/list/list every find delete-duplicates/hash)
        (only-in :std/string/misc string-trim)
        (only-in :tao3k/yuanxu/graph/types
                 yuanxu-graph yuanxu-graph-node yuanxu-graph-edge
                 yuanxu-graph-edges yuanxu-graph-edge-from yuanxu-graph-edge-to
                 yuanxu-graph-edge-kind yuanxu-graph-nodes yuanxu-graph-node-id
                 yuanxu-graph-node-payload)
        (only-in :tao3k/agentic-ai-lab/modules/query/objects
                 AgenticAILabQuery. AgenticAILabQueryElementSpace.
                 AgenticAILabSchemeGqlQueryLanguage. AgenticAILabGqlQueryProgram.
                 GraphSyntaxNode. GraphSyntaxStep. GraphSyntaxPath.
                 GraphSyntaxEquals. GraphSyntaxLiteral. GraphSyntaxProperty.
                 GraphSyntaxProjection. agentic-ai-lab-query-result-contract)
        (only-in :tao3k/agentic-ai-lab/modules/query/gql agentic-ai-lab-query->gql)
        (only-in :tao3k/agentic-ai-lab/modules/query/scheme-graph
                 agentic-ai-lab-query-select-scheme-graph)
        "types.ss" "objects.ss" "funs-scope.ss" "funs-org-properties.ss")
(export agentic-ai-lab-ai-agentic-context-governance-graph
        agentic-ai-lab-ai-agentic-context-topology-entry-query
        agentic-ai-lab-ai-agentic-context-topology-entries
        agentic-ai-lab-ai-agentic-context-agent-task-query
        agentic-ai-lab-ai-agentic-context-agent-affinities
        agentic-ai-lab-ai-agentic-context-governance-conflicts)

(def digest agentic-ai-lab-ai-agentic-context-digest)

(def (org-source-cut? v)
  (and (object? v) (.slot? v 'kind)
       (eq? (.ref v 'kind) 'context.org-source.v1)
       (eq? (.ref v 'active?) #t)))

(def (split-csv text)
  (if (not (string? text)) '()
    (let loop ((chars (string->list text)) (cur '()) (acc '()))
      (cond
       ((null? chars)
        (let (s (string-trim (list->string (reverse cur))))
          (reverse (if (string-empty? s) acc (cons s acc)))))
       ((char=? (car chars) #\,)
        (let (s (string-trim (list->string (reverse cur))))
          (loop (cdr chars) '() (if (string-empty? s) acc (cons s acc)))))
       (else (loop (cdr chars) (cons (car chars) cur) acc))))))

(def (container-groups props)
  (let loop ((rest props) (groups '()))
    (if (null? rest)
      (map (lambda (g) (cons (car g) (reverse (cdr g)))) (reverse groups))
      (let* ((p (car rest))
             (k (list (.ref p 'container-kind) (.ref p 'container-start) (.ref p 'container-end))))
        (if (assoc k groups)
          (loop (cdr rest)
                (map (lambda (g) (if (equal? (car g) k) (cons k (cons p (cdr g))) g)) groups))
          (loop (cdr rest) (cons (list k p) groups)))))))

(def (drawer-value props key)
  (let (p (find (cut agentic-ai-lab-ai-agentic-context-org-property-key? <> key) props))
    (and p (.ref p 'value))))

(def (qualified-anchor-id sid local-id) (digest (list 'org-element.v1 sid local-id)))

(def (gql-node binding label)
  (.o (:: @ GraphSyntaxNode.) binding label))

(def (gql-path start-binding start-label steps)
  (let ((start (gql-node start-binding start-label))
        (next (foldr (lambda (step next)
                       (with ([relation binding label] step)
                         (let (target (gql-node binding label))
                           (.o (:: @ GraphSyntaxStep.) relation target next))))
                     #f steps)))
    (.o (:: @ GraphSyntaxPath.) start next)))

(def (gql-equals binding property val)
  (let* ((left (.o (:: @ GraphSyntaxProperty.) binding property))
         (literal-kind 'string)
         (value (string-copy val))
         (right (.o (:: @ GraphSyntaxLiteral.) literal-kind value)))
    (.o (:: @ GraphSyntaxEquals.) left right)))

(def (gql-projections pairs)
  (foldr (lambda (pair next)
           (let* ((binding (car pair))
                  (property (cdr pair))
                  (expression (.o (:: @ GraphSyntaxProperty.) binding property)))
             (.o (:: @ GraphSyntaxProjection.) expression next)))
         #f pairs))

(def (make-gov-gql-query gov-graph identity fields bound match where project)
  (let ((version "1")
        (semantic-revision (.ref gov-graph 'semantic-revision))
        (element-space-identity (.ref gov-graph 'identity))
        (selected-element-identities (.ref gov-graph 'element-identities))
        (language AgenticAILabSchemeGqlQueryLanguage.)
        (result-bound bound)
        (completeness-requirement (if (.ref gov-graph 'complete?) 'complete 'partial-allowed))
        (result-contract (agentic-ai-lab-query-result-contract identity 'relation-row fields bound))
        (program (.o (:: @ AgenticAILabGqlQueryProgram.) identity match where project)))
    (.o (:: @ AgenticAILabQuery.)
        identity version semantic-revision element-space-identity
        selected-element-identities language result-bound
        completeness-requirement result-contract program)))

(def (agentic-ai-lab-ai-agentic-context-governance-graph identity sources (complete? #t))
  (unless (and (symbol? identity)
               (pair? sources) (list? sources) (<= (length sources) 64)
               (every org-source-cut? sources) (boolean? complete?))
    (error "Governance graph requires bounded active Org source cuts"))
  (let ((node-table (make-hash-table))
        (edge-table (make-hash-table))
        (anchor-index (make-hash-table))
        (node-order '())
        (edge-order '())
        (deferred '()))
    (def (add-node! id payload)
      (unless (hash-get node-table id)
        (hash-put! node-table id (yuanxu-graph-node id payload))
        (set! node-order (cons id node-order))))
    (def (add-edge! from to kind)
      (let (k (list from to kind))
        (unless (hash-get edge-table k)
          (hash-put! edge-table k (yuanxu-graph-edge from to kind))
          (set! edge-order (cons k edge-order)))))
    (def (ensure-project! proj)
      (let* ((pid (string-append "project:" proj))
             (identity pid)
             (label 'Project)
             (projectId (string-copy proj)))
        (add-node! pid (.o identity label projectId))
        pid))
    (def (ensure-worktree! pid proj wt cut)
      (let* ((wid (string-append "worktree:" proj "/" wt))
             (identity wid)
             (label 'Worktree)
             (projectId (string-copy proj))
             (worktreeId (string-copy wt))
             (sourceCut (string-copy cut)))
        (add-node! wid (.o identity label projectId worktreeId sourceCut))
        (add-edge! pid wid 'HAS_WORKTREE)
        wid))
    (for-each
     (lambda (src)
       (let* ((sid (string-copy (.ref src 'identity)))
              (srev (.ref src 'generation))
              (sdigest (string-copy (.ref src 'source-digest)))
              (cid (string-copy (.ref src 'contract-identity)))
              (groups (container-groups (agentic-ai-lab-ai-agentic-context-org-properties (.ref src 'source))))
              (root-props (cond ((find (lambda (g) (eq? (caar g) 'OrgFile)) groups) => cdr) (else '())))
              (default-proj (or (drawer-value root-props "PROJECT_ID")
                                (drawer-value root-props "GITOPS_PROJECT")))
              (default-wt (or (drawer-value root-props "WORKTREE_ID")
                              (drawer-value root-props "GITOPS_WORKTREE")))
              (default-cut (or (drawer-value root-props "GITOPS_SOURCE_CUT") sdigest))
              (src-id (string-append "source:" sid)))
         (let ((identity src-id)
               (label 'OrgSource)
               (sourceId sid)
               (sourceRevision srev)
               (sourceDigest sdigest)
               (rootAnchorId (string-copy (or (drawer-value root-props "ID") "")))
               (contractIdentity cid))
           (add-node! src-id
             (.o identity label sourceId sourceRevision sourceDigest rootAnchorId contractIdentity)))
         (when default-proj
           (let (pid (ensure-project! default-proj))
             (add-edge! pid src-id 'OWNS_SOURCE)
             (when default-wt
               (add-edge! (ensure-worktree! pid default-proj default-wt default-cut)
                          src-id 'OBSERVES_SOURCE))))
         (for-each
          (lambda (group)
            (match group
              ([[container-kind byteStart byteEnd] . props]
               (let (local-id (drawer-value props "ID"))
                 (when local-id
                   (let* ((qid (qualified-anchor-id sid local-id))
                          (proj (or (drawer-value props "PROJECT_ID") default-proj))
                          (wt (or (drawer-value props "WORKTREE_ID") default-wt))
                          (comp (drawer-value props "ARCH_COMPONENT"))
                          (entry-src (drawer-value props "ENTRY_SOURCE"))
                          (rel-proj (drawer-value props "RELATED_PROJECT"))
                          (owner (drawer-value props "AGENT_ID"))
                          (role-val (or (drawer-value props "AGENT_ROLE") "owner"))
                          (reviewer (drawer-value props "REVIEWER_AGENT_ID"))
                          (task (drawer-value props "TASK_ID")))
                     (unless (hash-get anchor-index local-id) (hash-put! anchor-index local-id qid))
                     (hash-put! anchor-index (string-append sid "#" local-id) qid)
                     (let ((identity qid)
                           (label 'OrgElement)
                           (propertyId (string-copy local-id))
                           (sourceId sid)
                           (sourceRevision srev)
                           (contractIdentity cid)
                           (elementKind (symbol->string container-kind))
                           (projectId (string-copy (or proj "")))
                           (worktreeId (string-copy (or wt "")))
                           (componentId (string-copy (or comp "")))
                           (ownerAgentId (string-copy (or owner "")))
                           (reviewerAgentId (string-copy (or reviewer ""))))
                       (add-node! qid
                         (.o identity label propertyId sourceId sourceRevision contractIdentity
                             elementKind projectId worktreeId componentId
                             ownerAgentId reviewerAgentId byteStart byteEnd)))
                     (add-edge! src-id qid 'CONTAINS_ANCHOR)
                     (when proj
                       (let (pid (ensure-project! proj))
                         (when rel-proj (add-edge! pid (ensure-project! rel-proj) 'RELATES_PROJECT))
                         (when wt (ensure-worktree! pid proj wt default-cut))
                         (when comp
                           (let* ((comp-id (string-append "component:" proj "/" comp))
                                  (identity comp-id)
                                  (label 'ArchComponent)
                                  (projectId (string-copy proj))
                                  (componentId (string-copy comp)))
                             (add-node! comp-id (.o identity label projectId componentId))
                             (add-edge! pid comp-id 'HAS_COMPONENT)
                             (add-edge! qid comp-id 'BELONGS_TO_COMPONENT)
                             (when entry-src
                               (set! deferred (cons (list 'entry comp-id (string-append "source:" entry-src))
                                                    deferred)))))
                         (when owner
                           (let* ((aid (string-append "agent:" owner))
                                  (identity aid)
                                  (label 'Agent)
                                  (agentId (string-copy owner))
                                  (role (string-copy role-val)))
                             (add-node! aid (.o identity label agentId role))
                             (add-edge! aid pid 'MEMBER_OF)
                             (add-edge! aid qid 'OWNS_ANCHOR)
                             (when task
                               (let* ((tid (string-append "task:" proj "/" task))
                                      (identity tid)
                                      (label 'Task)
                                      (taskId (string-copy task))
                                      (projectId (string-copy proj))
                                      (worktreeId (string-copy (or wt ""))))
                                 (add-node! tid (.o identity label taskId projectId worktreeId))
                                 (add-edge! aid tid 'ASSIGNED_TO)
                                 (add-edge! tid pid 'SCOPED_TO)
                                 (add-edge! tid qid 'TARGETS_ANCHOR)))))
                         (when reviewer
                           (let* ((rid (string-append "agent:" reviewer))
                                  (identity rid)
                                  (label 'Agent)
                                  (agentId (string-copy reviewer))
                                  (role "reviewer"))
                             (add-node! rid (.o identity label agentId role))
                             (add-edge! rid pid 'MEMBER_OF)
                             (add-edge! rid qid 'REVIEWS_ANCHOR)))))
                     (for-each (lambda (dep) (set! deferred (cons (list 'dep sid qid dep) deferred)))
                               (split-csv (drawer-value props "DEPENDS_ON")))))))))
          groups)))
     sources)
    (for-each
     (lambda (item)
       (match item
         (['entry comp-id target-src]
          (when (hash-get node-table target-src) (add-edge! comp-id target-src 'ENTRY_SOURCE)))
         (['dep sid from-qid ref]
          (let (to-qid (or (hash-get anchor-index (string-append sid "#" ref))
                           (hash-get anchor-index ref)))
            (when (and to-qid (hash-get node-table to-qid))
              (add-edge! from-qid to-qid 'DEPENDS_ON))))))
     (reverse deferred))
    (let* ((element-identities (reverse node-order))
           (ordered-edges (reverse edge-order))
           (source-digests (map (lambda (s) (string-copy (.ref s 'semantic-digest))) sources))
           (semantic-revision
            (digest (list 'context-governance-graph.v1 identity source-digests
                          element-identities ordered-edges)))
           (element-space
            (.o (:: @ AgenticAILabQueryElementSpace.)
                identity semantic-revision element-identities complete?))
           (graph (yuanxu-graph identity
                                (map (cut hash-get node-table <>) element-identities)
                                (map (cut hash-get edge-table <>) ordered-edges))))
      (.o (:: @ AiAgenticContextGovernanceGraph.)
          identity semantic-revision element-space graph
          source-digests element-identities complete?))))

(def (agentic-ai-lab-ai-agentic-context-topology-entry-query gov-graph component-id (bound 16))
  (unless (and (agentic-ai-lab-ai-agentic-context-governance-graph-shape? gov-graph)
               (string? component-id) (< 0 (string-length component-id) 257)
               (exact-integer? bound) (<= 1 bound 64))
    (error "Invalid topology entry GQL query inputs"))
  (make-gov-gql-query
   gov-graph 'context-topology-entry
   '(projectId componentId sourceId rootAnchorId contractIdentity) bound
   (gql-path 'c 'ArchComponent '((ENTRY_SOURCE s OrgSource)))
   (gql-equals 'c 'componentId component-id)
   (gql-projections '((c . projectId) (c . componentId) (s . sourceId)
                      (s . rootAnchorId) (s . contractIdentity)))))

(def (agentic-ai-lab-ai-agentic-context-topology-entries gov-graph component-id (bound 16))
  (let* ((query (agentic-ai-lab-ai-agentic-context-topology-entry-query gov-graph component-id bound))
         (selection (agentic-ai-lab-query-select-scheme-graph
                     query (.ref gov-graph 'element-space) (.ref gov-graph 'graph)))
         (kind 'agentic-ai-lab.ai-agentic-context.topology-entry-result.v1)
         (gql (agentic-ai-lab-query->gql query))
         (rows (.ref selection 'rows))
         (action-authorized? #f))
    (.o kind gql selection rows action-authorized?)))

(def (agentic-ai-lab-ai-agentic-context-agent-task-query gov-graph agent-id (bound 32))
  (unless (and (agentic-ai-lab-ai-agentic-context-governance-graph-shape? gov-graph)
               (string? agent-id) (< 0 (string-length agent-id) 257)
               (exact-integer? bound) (<= 1 bound 64))
    (error "Invalid Agent task GQL query inputs"))
  (make-gov-gql-query
   gov-graph 'context-agent-task-anchors
   '(projectId worktreeId taskId anchorIdentity propertyId sourceId) bound
   (gql-path 'a 'Agent '((ASSIGNED_TO t Task) (TARGETS_ANCHOR e OrgElement)))
   (gql-equals 'a 'agentId agent-id)
   (gql-projections '((t . projectId) (t . worktreeId) (t . taskId)
                      (e . identity) (e . propertyId) (e . sourceId)))))

(def (agentic-ai-lab-ai-agentic-context-agent-affinities
      gov-graph agent-id expected-project expected-worktree (bound 32))
  (let* ((query (agentic-ai-lab-ai-agentic-context-agent-task-query gov-graph agent-id bound))
         (selection (agentic-ai-lab-query-select-scheme-graph
                     query (.ref gov-graph 'element-space) (.ref gov-graph 'graph)))
         (graph (.ref gov-graph 'graph))
         (payloads (make-hash-table))
         (deps-out (make-hash-table))
         (scored (make-hash-table)))
    (for-each (lambda (n) (hash-put! payloads (yuanxu-graph-node-id n) (yuanxu-graph-node-payload n)))
              (yuanxu-graph-nodes graph))
    (for-each (lambda (e)
                (when (eq? (yuanxu-graph-edge-kind e) 'DEPENDS_ON)
                  (let ((from (yuanxu-graph-edge-from e)) (to (yuanxu-graph-edge-to e)))
                    (hash-put! deps-out from (cons to (or (hash-get deps-out from) '()))))))
              (yuanxu-graph-edges graph))
    (def (score-anchor anchor-identity task-id base-bps base-reason write-ok?)
      (let* ((elem (hash-get payloads anchor-identity))
             (same-proj? (and (string? expected-project) (equal? (.ref elem 'projectId) expected-project)))
             (same-wt? (and (string? expected-worktree) (equal? (.ref elem 'worktreeId) expected-worktree)))
             (comp? (not (string-empty? (.ref elem 'componentId))))
             (score-bps (min 10000 (+ base-bps (if same-proj? 2000 0) (if same-wt? 1500 0)
                                      (if comp? 1000 0) 500)))
             (reasons (append (list base-reason)
                              (if same-proj? '(same-project) '())
                              (if same-wt? '(same-worktree) '())
                              (if comp? '(arch-component-bound) '())
                              '(contract-admitted)))
             (agent-id (string-copy agent-id))
             (project-id (let (p (.ref elem 'projectId))
                           (string-copy (if (string-empty? p) (or expected-project "unbound") p))))
             (task-id (string-copy task-id))
             (anchor-identity (string-copy anchor-identity))
             (property-id (string-copy (.ref elem 'propertyId)))
             (source-id (string-copy (.ref elem 'sourceId)))
             (container-start (.ref elem 'byteStart))
             (container-end (.ref elem 'byteEnd))
             (write-eligible? (and write-ok?
                                   (equal? (.ref elem 'ownerAgentId) agent-id)
                                   (not (equal? (.ref elem 'reviewerAgentId) agent-id)))))
        (.o (:: @ AiAgenticContextAgentAffinity.)
            agent-id project-id task-id anchor-identity property-id source-id
            container-start container-end score-bps reasons write-eligible?)))
    (for-each
     (lambda (row)
       (match row
         ([_ _ task-id qid . _]
          (hash-put! scored qid (score-anchor qid task-id 5000 'assigned-task-target #t))
          (for-each (lambda (dep-qid)
                      (unless (hash-get scored dep-qid)
                        (hash-put! scored dep-qid (score-anchor dep-qid task-id 2500 'depends-on-neighbor #f))))
                    (or (hash-get deps-out qid) '())))))
     (.ref selection 'rows))
    (let ((kind 'agentic-ai-lab.ai-agentic-context.agent-affinity-result.v1)
          (gql (agentic-ai-lab-query->gql query))
          (affinities (list-sort (lambda (a b)
                                   (if (= (.ref a 'score-bps) (.ref b 'score-bps))
                                     (string<? (.ref a 'anchor-identity) (.ref b 'anchor-identity))
                                     (> (.ref a 'score-bps) (.ref b 'score-bps))))
                                 (map cdr (hash->list scored))))
          (action-authorized? #f))
      (.o kind gql selection affinities action-authorized?))))

(def (agentic-ai-lab-ai-agentic-context-governance-conflicts gov-graph)
  (unless (agentic-ai-lab-ai-agentic-context-governance-graph-shape? gov-graph)
    (error "Invalid Governance graph"))
  (let* ((graph (.ref gov-graph 'graph))
         (owners-by-anchor (make-hash-table))
         (conflicts '()))
    (for-each (lambda (e)
                (when (eq? (yuanxu-graph-edge-kind e) 'OWNS_ANCHOR)
                  (let ((aid (yuanxu-graph-edge-from e)) (qid (yuanxu-graph-edge-to e)))
                    (hash-put! owners-by-anchor qid (cons aid (or (hash-get owners-by-anchor qid) '()))))))
              (yuanxu-graph-edges graph))
    (for-each
     (lambda (n)
       (let (p (yuanxu-graph-node-payload n))
         (when (eq? (.ref p 'label) 'OrgElement)
           (let ((anchor-identity (.ref p 'identity))
                 (property-id (.ref p 'propertyId))
                 (owner (.ref p 'ownerAgentId))
                 (reviewer (.ref p 'reviewerAgentId)))
             (when (and (not (string-empty? owner)) (equal? owner reviewer))
               (let ((kind 'separation-of-duties) (agent-id owner))
                 (set! conflicts
                   (cons (.o kind anchor-identity property-id agent-id) conflicts))))
             (let (owners (delete-duplicates/hash (or (hash-get owners-by-anchor anchor-identity) '())))
               (when (> (length owners) 1)
                 (let ((kind 'shared-exclusive-owner)
                       (agents (list-sort string<? owners)))
                   (set! conflicts
                     (cons (.o kind anchor-identity property-id agents) conflicts)))))))))
     (yuanxu-graph-nodes graph))
    (reverse conflicts)))
