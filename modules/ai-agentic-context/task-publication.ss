;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .o .ref .slot?)
        (only-in :clan/poo/type Type. define-type element? raise-type-error)
        (only-in :clan/poo/type List OrFalse Record)
        (only-in :std/list/list every find)
        (only-in :std/string/uuid random-uuid uuid->string)
        (only-in :tao3k/agentic-ai-lab/modules/gitops/features/worktree/objects gitops-worktree-dependency)
        (only-in :tao3k/agentic-ai-lab/modules/gitops/features/worktree/types GitOpsWorktreeDependency)
        (only-in :tao3k/agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy-host
                 agentic-ai-lab-temporal-support-policy-host-registered)
        :tao3k/agentic-ai-lab/modules/search-engine/interface
        "funs-scope.ss" "query-provider.ss" "use-host.ss" "worktree-selection.ss")
(export context-task-read-scope context-task-publication-host context-task-select! context-task-select-worktree!
        context-task-start! context-task-query! context-task-publish!
        context-task-cancel! context-task-current context-task-history
        ContextTaskOrgEvidenceStage)

(define-type (Name @ Type.)
  .element?: (lambda (value) (and (string? value) (< 0 (string-length value) 257))))
(define-type (SourceGeneration @ Type.)
  .element?: (lambda (value) (and (exact-integer? value) (<= 1 value 65534))))
(def AnchorRef (Record source: [Name] anchor: [Name]))
(def OriginRef (Record [AnchorRef] generation: [SourceGeneration]))
(define-type (WindowBound @ Type.)
  .element?: (lambda (value) (and (exact-integer? value) (<= 1 value 32))))
(def DescendantWindow (Record max-depth: [WindowBound] result-bound: [WindowBound]))
(def OrgSelection
  (Record [AnchorRef] query-revision: [Name] grant: [Name]
          origin: [(OrFalse OriginRef) optional: #t]
          descendants: [(OrFalse DescendantWindow) optional: #t]))
(def RouteSelection (Record router-revision: [Name] search-contract-revision: [Name]))
(def Selection (Record [RouteSelection] org-modules: [(List OrgSelection)]))
(def SingleSelection (Record [RouteSelection OrgSelection]))
(def digest agentic-ai-lab-ai-agentic-context-digest)

;; The existing authority owner issues a display grant whose admission digest
;; identifies this Task scope, source catalog identity and local anchor.
(def (freeze-window window)
  (and window
       (begin
         (unless (element? DescendantWindow window) (raise-type-error DescendantWindow window))
         (list (.ref window 'max-depth) (.ref window 'result-bound)))))

(def (context-task-read-scope scope source anchor (descendants #f))
  (unless (and (element? Name source) (element? Name anchor))
    (error "Task read scope requires a source and Org anchor"))
  (read-scope-digest (agentic-ai-lab-ai-agentic-context-scope-admit scope)
                     source anchor (freeze-window descendants)))

(def (read-scope-digest scope source anchor bounds)
  (digest (append (list 'context-task-read-v1 (.ref scope 'semantic-digest) source anchor)
                  (if bounds (list 'descendants bounds) '()))))

(def ContextTaskOrgEvidenceStage
  (agentic-ai-lab-search-stage 'org-evidence 'query '() 'org-source 'org-result
                              agentic-ai-lab-search-acquisition-role))
(def org-evidence-strategy
  (agentic-ai-lab-search-strategy 'task-org-evidence ContextTaskOrgEvidenceStage '()))

(defstruct owner (thread identity scope queries grants policies busy? selection worktree-dependency module-resolution epoch serial pending superseded publication history))
(defstruct module-resolution (loader path source-digests declaration-reads dependencies link-roots links))
(defstruct evaluation (ticket serial capture engine request receipt))
(defstruct receipt-binding (serial engine request batch ticket versions))
(defstruct query-batch (digest members link-roots links))
(defstruct publication (evaluation search-engine))

(def (context-task-publication-host scope queries grants policies)
  (let (runtime (make-owner (current-thread) (uuid->string (random-uuid))
                  (agentic-ai-lab-ai-agentic-context-scope-admit scope)
                  queries grants policies #f #f #f #f 0 0 #f (make-hash-table-eq) #f '()))
    (.o kind: 'context.task-publication-host.v1 private-runtime-state: runtime)))

(def (task-owner host)
  (let (runtime (.ref host 'private-runtime-state))
    (unless (and (owner? runtime) (eq? (owner-thread runtime) (current-thread)))
      (error "Task publication requires its serialized owner thread"))
    (when (owner-busy? runtime) (error "Task publication observation is in progress"))
    runtime))

(def (observe-task runtime operation)
  (let (previous (owner-busy? runtime))
    (dynamic-wind
      (lambda () (owner-busy?-set! runtime #t))
      operation
      (lambda () (owner-busy?-set! runtime previous)))))

(def (freeze-anchor anchor)
  (map (lambda (key) (string-copy (.ref anchor key))) '(source anchor)))

(def (freeze-org module)
  (let (origin (and (.slot? module 'origin) (.ref module 'origin)))
    (cons (freeze-anchor module)
          (list (string-copy (.ref module 'query-revision)) (string-copy (.ref module 'grant))
                (and origin (append (freeze-anchor origin) (list (.ref origin 'generation))))
                (freeze-window (and (.slot? module 'descendants) (.ref module 'descendants)))))))

(def (freeze-selection selection)
  (let* ((plural? (.slot? selection 'org-modules))
         (type (if plural? Selection SingleSelection))
         (modules (begin
                    (unless (element? type selection) (raise-type-error type selection))
                    (if plural? (.ref selection 'org-modules) (list selection))))
         (entries (map freeze-org modules)))
    (unless (<= 1 (length entries) 32) (error "Task Org selection must contain 1 to 32 anchors"))
    (let loop ((entries entries) (seen '()))
      (unless (null? entries)
        (let (key (caar entries))
          (when (member key seen) (error "Duplicate Task Org anchor" key))
          (loop (cdr entries) (cons key seen)))))
    ;; Every origin is an explicit member of this same Task selection. Follow
    ;; the edges independently of result order.
    (for-each
      (lambda (entry)
        (let walk ((current entry) (visited '()))
          (match current
            ([key _ _ [source anchor _] _]
             (let (parent (assoc (list source anchor) entries))
               (unless (and parent (not (member key visited)))
                 (error "Missing or cyclic Task Org origin" key))
               (walk parent (cons key visited))))
            (else (void)))))
      entries)
    (list (string-copy (.ref selection 'router-revision))
          (string-copy (.ref selection 'search-contract-revision)) entries)))

(def (selection-scope runtime scope)
  (let ((scope (agentic-ai-lab-ai-agentic-context-scope-admit scope))
        (prior (owner-scope runtime)))
    (unless (every (lambda (key) (equal? (.ref scope key) (.ref prior key)))
              '(bundle organization epoch project worktree actor task destination session turn))
      (error "Task publication scope substitution"))
    scope))

(def (same-module-resolution? previous candidate)
  (or (eq? previous candidate)
      (and previous candidate
           (eq? (module-resolution-loader previous) (module-resolution-loader candidate))
           (equal? (module-resolution-path previous) (module-resolution-path candidate))
           (equal? (module-resolution-source-digests previous) (module-resolution-source-digests candidate))
           (equal? (module-resolution-link-roots previous) (module-resolution-link-roots candidate))
           (equal? (module-resolution-links previous) (module-resolution-links candidate))
           (same-task-dependencies? (module-resolution-dependencies previous)
                                    (module-resolution-dependencies candidate)))))

(def (install-selection! runtime scope selection resolution)
  (unless (and (equal? (.ref scope 'semantic-digest) (.ref (owner-scope runtime) 'semantic-digest))
               (equal? selection (owner-selection runtime))
               (same-module-resolution? (owner-module-resolution runtime) resolution))
    (owner-scope-set! runtime scope)
    (owner-selection-set! runtime selection)
    (owner-module-resolution-set! runtime resolution)
    (owner-epoch-set! runtime (+ 1 (owner-epoch runtime)))))

;; Keep the explicit selection boundary for callers that already own resolution.
(def (context-task-select! host scope selection)
  (let* ((runtime (task-owner host))
         (scope (selection-scope runtime scope))
         (frozen (and selection (freeze-selection selection))))
    (owner-worktree-dependency-set! runtime #f)
    (install-selection! runtime scope frozen #f)))

(def (read-authority runtime scope source anchor grant-id bounds)
  (let* ((grants (owner-grants runtime)) (policies (owner-policies runtime))
         (grant (agentic-ai-lab-context-use-host-current grants grant-id #f)))
    (and grant
         (let* ((decision
                  ;; An enrolled clock can call back into Scheme. Fence Task
                  ;; reentry and confirm the grant and policy after that call.
                  (observe-task runtime
                    (lambda ()
                      (agentic-ai-lab-context-use-host-observe
                       grants policies grant-id (.ref grant 'generation) 'display))))
                (contract (.ref grant 'contract)))
           (and (eq? (.ref decision 'decision) 'allowed)
                (equal? (.ref contract 'task) (.ref scope 'task))
                (equal? (.ref contract 'actor) (.ref scope 'actor))
                (equal? (.ref grant 'admission-digest) (read-scope-digest scope source anchor bounds))
                (list (string-copy (.ref grant 'semantic-digest))
                      (.ref (.ref decision 'policy-snapshot) 'generation)))))))

(def (registered-authority runtime grant-id)
  (let* ((grant (agentic-ai-lab-context-use-host-current (owner-grants runtime) grant-id))
         (policy (agentic-ai-lab-temporal-support-policy-host-registered
                   (owner-policies runtime) (.ref grant 'policy-identity))))
    (list (.ref grant 'semantic-digest) (.ref policy 'generation))))

(def (current-worktree-loader runtime)
  (let (dependency (owner-worktree-dependency runtime))
    (and dependency
         (observe-task runtime (.ref dependency 'current-selection)))))

(def (resolve-worktree! runtime scope loaded)
  (let ((path (.ref (owner-worktree-dependency runtime) 'module-path))
        (prior (owner-module-resolution runtime)))
    (with-catch
      (lambda (failure) (install-selection! runtime scope #f #f) (raise failure))
      (lambda ()
        (observe-task runtime
          (lambda ()
            (def (read-source source anchor grant descendants)
              (let (stamp (read-authority runtime scope source anchor grant (freeze-window descendants)))
                (and stamp (equal? stamp (registered-authority runtime grant))
                     (let (cut (context-query-current-source (owner-queries runtime) source #f))
                       (and cut (.ref cut 'active?) cut)))))
            ((.ref loaded 'admit-current))
            (let (resolved (resolve-worktree-org-selection
                             loaded path scope read-source
                             (if prior (module-resolution-declaration-reads prior) '())))
              ((.ref loaded 'admit-current))
              (if (and resolved (eq? loaded (current-worktree-loader runtime))
                       (task-dependencies-current? (.ref resolved 'dependencies)))
                (let (resolution
                       (make-module-resolution loaded (map values path) (.ref resolved 'source-digests)
                                               (.ref resolved 'declaration-reads)
                                               (.ref resolved 'dependencies) (.ref resolved 'link-roots)
                                               (.ref resolved 'links)))
                  (install-selection! runtime scope (freeze-selection (.ref resolved 'selection)) resolution)
                  #t)
                (begin (install-selection! runtime scope #f #f) #f)))))))))

(def (context-task-select-worktree! host scope dependency (module-path #f))
  (let* ((runtime (task-owner host))
         (scope (selection-scope runtime scope))
         (dependency (if module-path
                       (gitops-worktree-dependency (lambda () dependency) module-path)
                       dependency)))
    (unless (element? GitOpsWorktreeDependency dependency)
      (raise-type-error GitOpsWorktreeDependency dependency))
    (owner-worktree-dependency-set! runtime dependency)
    (let (loaded
           (with-catch
             (lambda (failure) (install-selection! runtime scope #f #f) (raise failure))
             (lambda () (current-worktree-loader runtime))))
      (if loaded (resolve-worktree! runtime scope loaded)
          (begin (install-selection! runtime scope #f #f) #f)))))

(def (module-current? runtime)
  (let (resolution (owner-module-resolution runtime))
    (or (not resolution)
        (with-catch (lambda (_) #f)
          (lambda ()
            (observe-task runtime
              (lambda ()
                (let (loaded (module-resolution-loader resolution))
                  (and (eq? loaded (current-worktree-loader runtime))
                       (equal? (module-resolution-path resolution)
                               (.ref (owner-worktree-dependency runtime) 'module-path))
                       (begin ((.ref loaded 'admit-current)) #t)
                       (task-dependencies-current? (module-resolution-dependencies resolution)))))))))))

(def (capture-files runtime modules)
  (let* ((catalog (owner-queries runtime))
         (resolution (owner-module-resolution runtime))
         (files
           (map (match <> ([[source anchor] query _ origin bounds]
                  (list (list source anchor) query origin
                        (context-query-current-source catalog source #f) bounds)))
                modules)))
    (and (every (match <> ([_ _ _ live _] (and live (.ref live 'active?)))) files)
         (or (not resolution)
             (equal? (module-resolution-source-digests resolution)
                     (map (lambda (file) (.ref (cadddr file) 'semantic-digest)) files)))
         (every (match <>
                  ([_ _ #f _ _] #t)
                  ([_ _ [source anchor generation] _ _]
                   (= generation (.ref (cadddr (assoc (list source anchor) files)) 'generation))))
                files)
         files)))

;; Authorize before retrieving protected source bytes from the catalog.
(def (capture runtime)
  (match (owner-selection runtime)
    (#f #f)
    ([router-revision contract-revision modules]
     (and (module-current? runtime)
          (let* ((scope (owner-scope runtime))
                 (stamps (map (match <> ([[source anchor] _ grant _ bounds]
                                (read-authority runtime scope source anchor grant bounds))) modules)))
            ;; Later grant clocks can change earlier registrations.
            (and (every values stamps) (module-current? runtime)
                 (equal? stamps (map (match <> ([_ _ grant _ _] (registered-authority runtime grant))) modules))
                 (let (files (capture-files runtime modules))
                   (and files
                        (let* ((selection-epoch (owner-epoch runtime))
                               (resolution (owner-module-resolution runtime))
                               (dependency-versions
                                 (if resolution (task-dependency-versions (module-resolution-dependencies resolution)) '()))
                               (link-roots (if resolution (module-resolution-link-roots resolution) '()))
                               (link-edges (if resolution (module-resolution-links resolution) '()))
                               (source-cut
                                (digest (append (list (.ref scope 'semantic-digest)
                                              dependency-versions
                                              (map (match <> ([key query origin live bounds]
                                                     (append (list key query origin (.ref live 'semantic-digest))
                                                             (if bounds (list bounds) '()))))
                                                   files))
                                                (if (null? link-edges) '() (list link-roots link-edges))))))
                          (.o epoch: selection-epoch orgs: files route: router-revision
                              search-contract: contract-revision cut: source-cut authority: stamps
                              gitops-versions: dependency-versions org-link-roots: link-roots
                              links: link-edges))))))))))

(def (same-capture? live captured)
  (and live
       (every (lambda (key) (equal? (.ref live key) (.ref captured key)))
              '(epoch cut authority))))

(def (current-capture? runtime captured)
  (same-capture? (capture runtime) captured))

(def (capture-for-task-start runtime)
  (or (capture runtime)
      (with-catch (lambda (_) #f)
        (lambda ()
          (let (loaded (current-worktree-loader runtime))
            (and loaded
                 (resolve-worktree! runtime (owner-scope runtime) loaded)
                 (capture runtime)))))))

(def (context-task-start! host)
  (let* ((runtime (task-owner host))
         (pending (owner-pending runtime))
         (selected (capture-for-task-start runtime)))
    (and selected (not (and pending (same-capture? selected (evaluation-capture pending))))
         (let* ((serial (+ 1 (owner-serial runtime)))
                (generation (digest (list 'context-task-evaluation-v1 (owner-identity runtime) serial)))
                (cut (.ref selected 'cut))
                (configuration (digest (list (.ref selected 'route) (.ref selected 'search-contract))))
                (engine (agentic-ai-lab-search-engine-require-evidence
                         (agentic-ai-lab-search-engine org-evidence-strategy generation configuration cut)))
                (issued (agentic-ai-lab-search-engine-issue engine 'org-evidence))
                (ticket (.o request: serial search-generation: (string-copy generation)
                             search-source-cut: (string-copy cut))))
           ;; Only evaluations with an issued Query ticket can send a valid
           ;; late receipt. Each holds a batch from the bounded Query catalog.
           (when (and pending (evaluation-receipt pending))
             (hash-put! (owner-superseded runtime) (evaluation-ticket pending) (evaluation-receipt pending)))
           (owner-serial-set! runtime serial)
           (owner-pending-set! runtime
             (make-evaluation ticket serial selected (.ref issued 'engine) (.ref issued 'request) #f))
           ticket))))

(def (evaluate-orgs runtime files)
  (let loop ((pending files) (completed '()))
    (match pending
      ([] (reverse completed))
      ([[[source anchor] query-revision origin cut bounds] . rest]
       (let* ((query (match bounds
                       (#f (context-org-query cut anchor 'propertyId 'context/org-elements query-revision 1))
                       ([depth bound] (context-org-descendants-query cut anchor depth bound query-revision))))
              (observation (context-query-execute (owner-queries runtime) source query))
              (lineage (context-query-lineage observation)))
         (and (equal? (.ref lineage 'org-ids) (list anchor))
              (loop rest (cons (list (list source anchor) origin (.ref lineage 'semantic-digest))
                               completed))))))))

(def (bind-link catalog members edge)
  (match edge
    ([source-key link-id _ source-version start end target-key target-version]
     (let* ((source-reference (caddr (assoc source-key members)))
            (target-reference (caddr (assoc target-key members)))
            (source (context-query-observation catalog source-reference))
            (target (context-query-observation catalog target-reference))
            (source-lineage (context-query-lineage source))
            (target-lineage (context-query-lineage target))
            (link (find (lambda (row) (equal? link-id (.ref row 'identity)))
                        (.ref (.ref source 'result-set) 'rows))))
       (def (cell name)
         (.ref (find (lambda (slot) (eq? (.ref slot 'field) name)) (.ref link 'cells)) 'value))
       (unless (and (= source-version (.ref source-lineage 'generation))
                    (= target-version (.ref target-lineage 'generation))
                    (equal? (car source-key) (.ref source-lineage 'source))
                    (equal? (list (cadr source-key)) (.ref source-lineage 'org-ids))
                    (equal? (car target-key) (.ref target-lineage 'source))
                    (equal? (list (cadr target-key)) (.ref target-lineage 'org-ids))
                    link (equal? (cell 'elementKind) "link")
                    (= start (cell 'byteStart)) (= end (cell 'byteEnd)))
         (error "Org link does not match its issued Query receipts" link-id))
       (append edge (list source-reference target-reference
                         (.ref source-lineage 'source-digest) (.ref target-lineage 'source-digest)))))))

(def (bind-orgs catalog members roots edges)
  (let* ((linked
           (map (match <>
                  ([key #f reference] (list key #f reference))
                  ([key [source anchor generation] reference]
                   (let (origin (assoc (list source anchor) members))
                     (list key (list source anchor generation (caddr origin)) reference))))
                members))
         (links (map (lambda (edge) (bind-link catalog linked edge)) edges))
         (reference (cond ((pair? links) (digest (list 'context-task-org-link-batch-v2 linked roots links)))
                          ((null? (cdr linked)) (caddar linked))
                          (else (digest (list 'context-task-org-batch-v1 linked))))))
    (make-query-batch reference linked roots links)))

(def (context-task-query! host ticket)
  (let* ((runtime (task-owner host)) (pending (owner-pending runtime)))
    (and pending (eq? ticket (evaluation-ticket pending))
         (current-capture? runtime (evaluation-capture pending))
         (or (and (evaluation-receipt pending) (receipt-binding-ticket (evaluation-receipt pending)))
             (let (members (evaluate-orgs runtime (.ref (evaluation-capture pending) 'orgs)))
               (if members
                 (let* ((captured (evaluation-capture pending))
                        (batch (bind-orgs (owner-queries runtime) members
                                 (.ref captured 'org-link-roots) (.ref captured 'links)))
                        (serial (evaluation-serial pending))
                        (receipt (.o request: serial
                                     query-digest: (string-copy (query-batch-digest batch)))))
                   (evaluation-receipt-set! pending
                     (make-receipt-binding serial (evaluation-engine pending) (evaluation-request pending)
                       batch receipt (.ref (evaluation-capture pending) 'gitops-versions)))
                   receipt)
                 (begin (owner-pending-set! runtime #f) #f)))))))

(def (settle-search runtime binding event)
  (with-catch (lambda (_) #f)
    (lambda ()
      (observe-task runtime
        (lambda ()
          (let* ((engine (agentic-ai-lab-search-engine-observe (receipt-binding-engine binding)
                           'org-evidence (receipt-binding-request binding) event))
                 (snapshot (agentic-ai-lab-search-engine-evidence engine 'org-evidence)))
            (and (equal? (query-batch-digest (receipt-binding-batch binding)) (.ref snapshot 'payload-identity))
                 engine)))))))

(def (queries-current runtime pending)
  (and (current-capture? runtime (evaluation-capture pending))
       (let* ((catalog (owner-queries runtime))
              (members (query-batch-members (receipt-binding-batch (evaluation-receipt pending))))
              (observations
                (map (lambda (row) (context-query-observation catalog (caddr row))) members)))
         (and (every (lambda (observation) (and observation (context-query-current? catalog observation)))
                     observations)
              observations))))

;; Preserve pending work on unbound input. A bound, superseded return settles as
;; historical. The audit view exposes identities from owned records.
(def (context-task-publish! host ticket query-receipt search-event)
  (let* ((runtime (task-owner host))
         (pending (owner-pending runtime))
         (active? (and pending (eq? ticket (evaluation-ticket pending))))
         (binding (if active? (evaluation-receipt pending) (hash-get (owner-superseded runtime) ticket)))
         (search (and binding (eq? query-receipt (receipt-binding-ticket binding))
                      (settle-search runtime binding search-event)))
         (status (cond ((not search) 'unbound)
                       ((and active? (queries-current runtime pending)) 'published)
                       (else 'historical))))
    (when search
      (when (eq? status 'published)
        (owner-publication-set! runtime (make-publication pending search)))
      (if active? (owner-pending-set! runtime #f)
          (hash-remove! (owner-superseded runtime) ticket)))
    (owner-history-set! runtime
      (cons (list status (and search (receipt-binding-serial binding))
                  (and search (receipt-binding-batch binding))
                  search
                  (if search (receipt-binding-versions binding) '()))
            (owner-history runtime)))
    status))

(def (context-task-cancel! host ticket)
  (let* ((runtime (task-owner host)) (pending (owner-pending runtime)))
    (cond ((and pending (eq? ticket (evaluation-ticket pending)))
           (owner-pending-set! runtime #f) #t)
          ((hash-key? (owner-superseded runtime) ticket)
           (hash-remove! (owner-superseded runtime) ticket) #t)
          (else #f))))

(def (origin-view origin)
  (match origin
    (#f #f)
    ([source-id anchor-id source-generation reference]
     (.o source: (string-copy source-id) anchor: (string-copy anchor-id)
         generation: source-generation query-digest: (string-copy reference)))))

(def (gitops-version-rows versions)
  (map (match <> ([role subject version]
         (.o feature: role identity: (string-copy subject) revision: (string-copy version))))
       versions))

(def (link-rows batch)
  (map (match <>
         ([[source-id source-anchor] link-id path source-version start end
           [target-id target-anchor] target-version source-receipt target-receipt source-hash target-hash]
          (.o source: (.o source: (string-copy source-id) anchor: (string-copy source-anchor)
                          source-digest: (string-copy source-hash)
                          generation: source-version query-digest: (string-copy source-receipt))
              link-identity: (string-copy link-id) link-path: (string-copy path)
              byte-start: start byte-end: end
              target: (.o source: (string-copy target-id) anchor: (string-copy target-anchor)
                          source-digest: (string-copy target-hash)
                          generation: target-version query-digest: (string-copy target-receipt)))))
       (query-batch-links batch)))

(def (link-root-rows batch)
  (map (match <> ([source-id anchor-id]
         (.o source: (string-copy source-id) anchor: (string-copy anchor-id))))
       (query-batch-link-roots batch)))

(def (context-task-current host)
  (let* ((runtime (task-owner host)) (published (owner-publication runtime)))
    (and published
         (let* ((pending (publication-evaluation published))
                (observed (queries-current runtime pending)))
           (and observed
                (let (queries
                       (map (lambda (member observation)
                              (.o lineage: (context-query-lineage observation)
                                  origin: (origin-view (cadr member))
                                  query-receipt: (.ref observation 'query-receipt)
                                  result-set: (.ref observation 'result-set)))
                            (query-batch-members (receipt-binding-batch (evaluation-receipt pending))) observed))
                  (.o request: (evaluation-serial pending)
                      search: (agentic-ai-lab-search-engine-evidence
                               (publication-search-engine published) 'org-evidence)
                      gitops-dependencies: (gitops-version-rows (.ref (evaluation-capture pending) 'gitops-versions))
                      org-link-roots: (link-root-rows (receipt-binding-batch (evaluation-receipt pending)))
                      org-links: (link-rows (receipt-binding-batch (evaluation-receipt pending)))
                      query: (and (null? (cdr queries)) (car queries))
                      org-queries: queries)))))))

(def (context-task-history host)
  (map (lambda (row)
         (match row
           ([outcome serial batch engine versions]
            (.o status: outcome request: serial
                query-digest: (and batch (string-copy (query-batch-digest batch)))
                gitops-dependencies: (gitops-version-rows versions)
                org-link-roots: (if batch (link-root-rows batch) '())
                org-links: (if batch (link-rows batch) '())
                org-receipts: (if batch
                                (map (match <> ([[source-id anchor-id] origin-ref reference]
                                      (.o source: (string-copy source-id) anchor: (string-copy anchor-id)
                                          origin: (origin-view origin-ref)
                                          query-digest: (string-copy reference))))
                                     (query-batch-members batch))
                                '())
                search-identity: (and engine (.ref (agentic-ai-lab-search-engine-evidence
                                                    engine 'org-evidence) 'identity))))))
       (reverse (owner-history (task-owner host)))))
