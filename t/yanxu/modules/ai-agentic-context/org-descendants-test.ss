;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :std/test
        (only-in :std/error Error? Error-message)
        (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :tao3k/yuanxu/module-system/interface yuanxu-load-modules)
        (only-in :tao3k/yuanxu/module-system/source/objects
                 make-yuanxu-module-generated-source yuanxu-module-source-ref-value)
        (only-in :clan/poo/object .o .ref .cc object?)
        (only-in :clan/poo/type Type.)
        (only-in :std/list/list find filter-map)
        (only-in :orgize/languages/org/modules/org-contract/config OrgDirectoryProfile.)
        (only-in :orgize/languages/org/modules/org-contract/directory-runtime org-directory-validate)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/objects AiAgenticContextScope.)
        (only-in :tao3k/agentic-ai-lab/modules/gitops/features/worktree/objects gitops-worktree-dependency)
        (only-in :tao3k/agentic-ai-lab/modules/gitops/objects GitOpsWorkingCopyPolicy)
        (rename-in (only-in :tao3k/agentic-ai-lab/modules/gitops/features/worktree/interface Feature)
                   (Feature GitOpsWorktreeFeature))
        (rename-in (only-in :tao3k/agentic-ai-lab/modules/gitops/features/worktrunk/interface Feature)
                   (Feature GitOpsWorkTrunkFeature))
        (rename-in (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/features/worktree/interface Feature)
                   (Feature ContextWorktreeFeature))
        (rename-in (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/features/worktrunk/interface Feature)
                   (Feature ContextWorkTrunkFeature))
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/task-publication
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/query-provider
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/use-host
        (only-in :tao3k/agentic-ai-lab/modules/search-engine/interface agentic-ai-lab-search-factor-observation)
        :tao3k/agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy
        :tao3k/agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy-host
        (only-in :tao3k/agentic-ai-lab/modules/temporal-causality/time/objects agentic-ai-lab-temporal-instant))
(export org-descendants-test)

(def (at coordinate)
  (agentic-ai-lab-temporal-instant
   (number->string coordinate) "clock" coordinate "host" 'observed))
(def policy (agentic-ai-lab-temporal-support-policy "org-policy" "1" (at 1) (at 10)))
(def contract (agentic-ai-lab-context-use-contract "actor" "investigate-owner" "task" '() '() #t))
(def anchor "owner-evidence")
(def source-text
  ":PROPERTIES:\n:ID: findings\n:CONTRACT_ID: context.evidence-source.v1\n:CONTRACT_REVISION: 1\n:END:\n* Evidence\n:PROPERTIES:\n:ID: owner-evidence\n:END:\n")

(defstruct scenario (host queries grants policies scope source grant))
(defstruct delivery (ticket query search))

(def (register-source! s identity revision (bytes source-text))
  (context-query-source! (scenario-queries s) (context-org-source identity revision bytes)))

(def (register-grant! s id (generation 1) (source (scenario-source s)) (window #f) (anchor-id anchor))
  (agentic-ai-lab-context-use-host-refresh! (scenario-grants s)
    (agentic-ai-lab-context-use-grant id generation "manifest"
       (context-task-read-scope (scenario-scope s) source anchor-id window)
       contract "org-policy" (.ref policy 'semantic-digest) '(display) #t)))

(def (setup (worktree-id "A") (queries (context-query-host)) (bytes source-text))
  (let* ((scope (.o (:: @ AiAgenticContextScope.) bundle: "lab" organization: "team" epoch: 1
                   project: "gambit" worktree: worktree-id source-cut: "cut-1" actor: "actor"
                   task: "investigate-owner" destination: "search"))
         (grants (agentic-ai-lab-context-use-host))
         (policies (agentic-ai-lab-temporal-support-policy-host))
         (source (string-append worktree-id "/worktree.org"))
         (id (string-append worktree-id "-read"))
         (s (make-scenario (context-task-publication-host scope queries grants policies)
                           queries grants policies scope source id)))
    (agentic-ai-lab-temporal-support-policy-host-refresh! policies policy 1 (at 1))
    (register-source! s source 1 bytes)
    (register-grant! s id)
    s))

(def (search-observation ticket query (cut (.ref ticket 'search-source-cut)))
  (agentic-ai-lab-search-factor-observation
   (string-append (.ref ticket 'search-generation) ":returned")
   (.ref ticket 'search-generation) ContextTaskOrgEvidenceStage
   (.ref query 'query-digest) 1 cut '() 'derived #t))

(def (evaluate s ticket)
  (let (query (context-task-query! (scenario-host s) ticket))
    (make-delivery ticket query (search-observation ticket query))))

(def (issue s)
  (evaluate s (context-task-start! (scenario-host s))))

(def (deliver s item (query (delivery-query item)) (search (delivery-search item)))
  (context-task-publish! (scenario-host s) (delivery-ticket item) query search))

(def (current s)
  (context-task-current (scenario-host s)))

(def descendant-source
  (string-append source-text
    "Evidence — see [[id:unselected-target][link]].\n\n| GC | owner |\n\n"
    "#+begin_src text\n[[id:forged][source-block text]]\n#+end_src\n\n"
    "** Nested\nNested [[https://example.invalid/evidence][evidence]].\n\n"
    "* Evidence\n:PROPERTIES:\n:ID: sibling\n:END:\nSibling [[id:outside][other]].\n"))
(def descendant-window (.o max-depth: 8 result-bound: 16))

(def ScopeType (.cc Type. identity: 'test/context-descendants-scope .element?: object?))

(def (compose-worktree-context flags)
  (let* ((ids '(gitops ai-agentic-context))
         (loaded
           (yuanxu-load-modules
             (.o generation: "worktree-contract-features" module-ids: ids selected: ids denied-modules: '()
                 feature-roots: ids
                 intent: (.o mode: 'explicit
                             decisions: (map (lambda (id)
                                               (.o identity: id selection: (.o selection-flags: flags)))
                                             ids))
                 locate: make-yuanxu-module-generated-source current?: (lambda (_) #t)
                 read-publication:
                 (lambda (reference)
                   (let (id (yuanxu-module-source-ref-value reference))
                     (case id
                       ((gitops)
                        (.o identity: id
                            features: (.o worktree: GitOpsWorktreeFeature worktrunk: GitOpsWorkTrunkFeature)
                            core: (.o scope-contract: ScopeType
                                      exports: (.o working-copy-policy: GitOpsWorkingCopyPolicy))))
                       ((ai-agentic-context)
                        (.o identity: id
                            features: (.o worktree: ContextWorktreeFeature worktrunk: ContextWorkTrunkFeature)
                            core: (.o scope-contract: ScopeType exports: (.o)))))))))))
    (.ref (.ref (.ref loaded 'modules) 'ai-agentic-context) 'worktree-context)))

(def WorktreeContexts
  (.o base: (compose-worktree-context '(+worktree -worktrunk))
      worktrunk: (compose-worktree-context '(+worktree +worktrunk))))

(def (descendant-loader s window (grant-id (scenario-grant s))
                        (design #f) (reference-module #f) (prototype (.o)))
  (let (ids '(worktree org/worktree org/design org/reference org/unrelated))
    (yuanxu-load-modules
      (.o generation: "descendant-fixture" module-ids: ids selected: ids denied-modules: '()
          locate: make-yuanxu-module-generated-source current?: (lambda (_) #t)
          read-publication:
          (lambda (reference)
            (let* ((id (yuanxu-module-source-ref-value reference))
                   (value
                     (case id
                       ((worktree)
                        (.o (:: @ prototype) project: "gambit" worktree: "A" source-cut: "cut-1"
                            org: (.o A/worktree.org: '(org worktree) A/design.org: '(org design)
                                     A/reference.org: '(org reference) A/unrelated.org: '(org unrelated))
                            tasks: (.o investigate-owner:
                                     (.o org: '(A/worktree.org) router-revision: "router-1"
                                         search-contract-revision: "search-1"))))
                       ((org/worktree)
                        (.o worktree: "A" source: (scenario-source s) anchor: "owner-evidence"
                            source-generation: 1 grant: grant-id query-revision: "query-1"
                            descendants: window))
                       ((org/design) design)
                       ((org/reference) reference-module)
                       ((org/unrelated) #f))))
              (.o identity: id features: (.o)
                  core: (.o scope-contract: ScopeType
                            exports: (or value (error "An unrelated Org Module was expanded" id))))))))))

(def (select-worktree! s loader)
  (context-task-select-worktree! (scenario-host s) (scenario-scope s)
    (gitops-worktree-dependency (lambda () loader) '(worktree))))

(def (setup-descendants window (grant-id "descendant-read"))
  (let (s (setup "A" (context-query-host) descendant-source))
    (register-grant! s grant-id 1 (scenario-source s) window)
    (check (select-worktree! s (descendant-loader s window grant-id)) => #t)
    s))

(def (row-field row field)
  (.ref (find (lambda (cell) (eq? (.ref cell 'field) field)) (.ref row 'cells)) 'value))

(def (rows-by-source result-set)
  (list-sort (lambda (left right) (< (row-field left 'byteStart) (row-field right 'byteStart)))
             (.ref result-set 'rows)))

(def (check-descendant-publication s generation raw)
  (let* ((query (.ref (current s) 'query))
         (rows (rows-by-source (.ref query 'result-set)))
         (lineage (context-query-lineage query))
         (window (.ref lineage 'org-window))
         (paths (.ref window 'paths))
         (bytes (string->utf8 raw)))
    (def (row-path row)
      (find (lambda (path) (equal? (.ref path 'identity) (.ref row 'identity))) paths))
    (check (.ref window 'root-anchor) => anchor)
    (check (.ref lineage 'generation) => generation)
    (check (map (lambda (row) (row-field row 'elementKind)) rows)
           => '("paragraph" "link" "table" "paragraph" "link"))
    (check (length paths) => (length rows))
    (for-each
      (lambda (row)
        (let* ((path (row-path row))
               (ancestors (.ref path 'ancestors))
               (start (row-field row 'byteStart)) (end (row-field row 'byteEnd)))
          (check (.ref path 'identity) => (.ref row 'identity))
          (check (.ref (car ancestors) 'identity) => (.ref (.ref window 'root) 'identity))
          (check (.ref (car ancestors) 'element-kind) => "headline")
          (check (<= (.ref (car ancestors) 'byte-start) start end
                     (.ref (car ancestors) 'byte-end) (u8vector-length bytes)) => #t)
          (check (utf8->string (subu8vector bytes start end)) => (row-field row 'text))))
      rows)
    (check (map (lambda (step) (.ref step 'element-kind)) (.ref (row-path (cadr rows)) 'ancestors))
           => '("headline" "paragraph"))))

(def target-source-id "A/design.org")
(def cross-file-path "file:design.org::#design-evidence")
(def link-source
  (string-append source-text "See [[" cross-file-path "][design evidence]].\n"))
(def target-text
  ":PROPERTIES:\n:ID: design\n:CONTRACT_ID: context.evidence-source.v1\n:CONTRACT_REVISION: 1\n:END:\n* Evidence\n:PROPERTIES:\n:ID: owner-evidence\n:CUSTOM_ID: design-evidence\n:END:\nDesign evidence.\n")

(def (org-module file grant-id pin (window #f) (anchor-id anchor))
  (.o worktree: "A" source: file anchor: anchor-id
      source-generation: pin grant: grant-id query-revision: "query-1" descendants: window))

(def (linked-loader s pin (target-id target-source-id))
  (descendant-loader s descendant-window "descendant-read"
    (org-module target-id "target-read" pin)))

(def (setup-link (target-id target-source-id) (target-grant? #t) (bytes link-source))
  (let (s (setup "A" (context-query-host) bytes))
    (register-grant! s "descendant-read" 1 (scenario-source s) descendant-window)
    (register-source! s target-id 1 target-text)
    (when target-grant? (register-grant! s "target-read" 1 target-id))
    s))

(def (check-link s version)
  (let* ((publication (current s))
         (links (.ref publication 'org-links))
         (source (.ref (car links) 'source))
         (target (.ref (car links) 'target))
         (queries (.ref publication 'org-queries))
         (source-lineage (context-query-lineage (car queries)))
         (target-lineage (context-query-lineage (cadr queries)))
         (link (car links)))
    (check (length links) => 1)
    (check (.ref source 'source) => (scenario-source s))
    (check (.ref source 'generation) => 1)
    (check (.ref source 'source-digest) => (.ref source-lineage 'source-digest))
    (check (.ref source 'query-digest) => (.ref source-lineage 'semantic-digest))
    (check (.ref target 'source) => target-source-id)
    (check (.ref target 'anchor) => anchor)
    (check (.ref target 'generation) => version)
    (check (.ref target 'source-digest) => (.ref target-lineage 'source-digest))
    (check (.ref target 'query-digest) => (.ref target-lineage 'semantic-digest))
    (check (.ref link 'link-path) => cross-file-path)
    (let ((row (find (lambda (entry) (equal? (.ref entry 'identity) (.ref link 'link-identity)))
                     (.ref (.ref (car queries) 'result-set) 'rows))))
      (check (.ref link 'byte-start) => (row-field row 'byteStart))
      (check (.ref link 'byte-end) => (row-field row 'byteEnd))
      (check (row-field row 'elementKind) => "link"))))

(def reference-source-id "A/reference.org")
(def reference-path "file:reference.org::#reference-evidence")
(def back-path "file:worktree.org::#worktree-evidence")
(def attachment-path "attachment:reference.org::#reference-evidence")
(def unregistered-path "file:outside.org::#outside-evidence")
(def design-anchor "design-record")
(def reference-anchor "reference-record")
(def worktree-examples "modules/ai-agentic-context/org-contract/templates/worktree")
(def base-worktree-example "modules/ai-agentic-context/org-contract/templates/gitops-worktree")

(def (read-worktree-example file (directory worktree-examples))
  (call-with-input-file (string-append directory "/" file)
    (lambda (port) (read-line port #f))))

(def (link-text path) (string-append "See [[" path "][evidence]].\n"))

(def (chain-loader s pin (cycle? #f) (middle-grant "target-read"))
  (descendant-loader s descendant-window "descendant-read"
    (org-module target-source-id middle-grant pin descendant-window design-anchor)
    (org-module reference-source-id "reference-read" 1 (and cycle? descendant-window) reference-anchor)
    (.ref WorktreeContexts 'worktrunk)))

(def (setup-chain (cycle? #f) (shared? #f) (granted? #t))
  (let* ((root (string-append (read-worktree-example "worktree.org")
                              (if shared? (link-text reference-path) "")))
         (s (setup "A" (context-query-host) root)))
    (register-grant! s "descendant-read" 1 (scenario-source s) descendant-window)
    (register-source! s target-source-id 1 (read-worktree-example "design.org"))
    (register-source! s reference-source-id 1
      (string-append (read-worktree-example "reference.org") (if cycle? (link-text back-path) "")))
    (when granted?
      (register-grant! s "target-read" 1 target-source-id descendant-window design-anchor)
      (register-grant! s "reference-read" 1 reference-source-id (and cycle? descendant-window) reference-anchor))
    s))

(def (end-values end)
  (map (lambda (key) (.ref end key)) '(source anchor generation source-digest query-digest)))

(def (check-chain s version (shared? #f))
  (let* ((receipt (current s))
         (links (.ref receipt 'org-links))
         (roots (.ref receipt 'org-link-roots))
         (queries (.ref receipt 'org-queries))
         (lineages (map context-query-lineage queries)))
    (check (map (lambda (row) (list (.ref row 'source) (.ref row 'anchor))) roots)
           => (list (list (scenario-source s) anchor)))
    (check (map (lambda (hop) (.ref hop 'link-path)) links)
           => (if shared? (list cross-file-path reference-path reference-path)
                   (list cross-file-path reference-path)))
    (check (map (lambda (lineage) (.ref lineage 'source)) lineages)
           => (list (scenario-source s) target-source-id reference-source-id))
    (check (map (lambda (lineage) (.ref lineage 'generation)) lineages) => (list 1 version 1))
    (check (map (lambda (lineage) (.ref lineage 'contract)) lineages)
           => '("context.gitops.worktree.worktrunk.v1" "context.design.v1" "context.reference.v1"))
    (let (root-rows (.ref (.ref (car queries) 'result-set) 'rows))
      (for-each
        (lambda (path)
          (check (ormap (lambda (row) (equal? (row-field row 'text) (string-append "[[" path "][evidence]]")))
                        root-rows) => #t))
        (list attachment-path unregistered-path)))
    (check (end-values (.ref (car links) 'target)) => (end-values (.ref (cadr links) 'source)))
    (when shared?
      (check (end-values (.ref (cadr links) 'target)) => (end-values (.ref (caddr links) 'target))))
    (for-each
      (lambda (hop)
        (let* ((from (.ref hop 'source))
               (to (.ref hop 'target))
               (query (find (lambda (query)
                              (equal? (.ref (context-query-lineage query) 'semantic-digest)
                                      (.ref from 'query-digest))) queries))
               (row (find (lambda (entry) (equal? (.ref entry 'identity) (.ref hop 'link-identity)))
                          (.ref (.ref query 'result-set) 'rows))))
          (check (.ref hop 'byte-start) => (row-field row 'byteStart))
          (check (.ref hop 'byte-end) => (row-field row 'byteEnd))
          (check (row-field row 'elementKind) => "link")
          (for-each
            (lambda (end)
              (let (lineage (find (lambda (value) (equal? (.ref value 'source) (.ref end 'source))) lineages))
                (check (.ref lineage 'org-ids) => (list (.ref end 'anchor)))
                (check (.ref lineage 'generation) => (.ref end 'generation))
                (check (.ref lineage 'source-digest) => (.ref end 'source-digest))
                (check (.ref lineage 'semantic-digest) => (.ref end 'query-digest))))
            (list from to))))
      links)))

(def org-descendants-test
  (test-suite "Org descendant windows and Task admission"
    (yuanxu-test-case "fileOwnedContractTest"
      (let* ((profile (.o (:: @ OrgDirectoryProfile.) directory: worktree-examples))
             (result (org-directory-validate profile))
             (evaluations (.ref result 'evaluations)))
        (check (.ref result 'complete?) => #t)
        (check (.ref result 'passed?) => #t)
        (check (length (.ref result 'files)) => 3)
        (check (filter-map (lambda (row)
                             (let (id (.ref row 'contract-id))
                               (and (not (equal? id "orgize.directory.document-root.v1"))
                                    (list (path-strip-directory (.ref row 'path)) id))))
                           evaluations)
               => '(("design.org" "context.design.v1")
                    ("reference.org" "context.reference.v1")
                    ("worktree.org" "context.gitops.worktree.worktrunk.v1")))
        (let (base (.o (:: @ profile) directory: base-worktree-example))
          (check (.ref (org-directory-validate base) 'passed?) => #t))))
    (yuanxu-test-case "worktreeFeatureContractTest"
      (let* ((base (.ref WorktreeContexts 'base))
             (extended (.ref WorktreeContexts 'worktrunk))
             (source (read-worktree-example "worktree.org" base-worktree-example))
             (s (setup "A" (context-query-host) source)))
        (check (.ref (.ref base 'org-contract) 'identity) => "context.gitops.worktree.v1")
        (check (.ref (.ref extended 'org-contract) 'identity) => "context.gitops.worktree.worktrunk.v1")
        (check (select-worktree! s (descendant-loader s #f (scenario-grant s) #f #f extended)) => #f)
        (check (context-task-start! (scenario-host s)) => #f)
        (check (select-worktree! s (descendant-loader s #f (scenario-grant s) #f #f base)) => #t)
        (check (deliver s (issue s)) => 'published)
        (check (.ref (context-query-lineage (.ref (current s) 'query)) 'contract)
               => "context.gitops.worktree.v1")))
    (yuanxu-test-case "descendantScopeTest"
      (let* ((s (setup-descendants descendant-window)) (item (issue s)))
        (check (deliver s item) => 'published)
        (check-descendant-publication s 1 descendant-source)
        (let* ((catalog (scenario-queries s))
               (receipt (context-query-observation catalog (.ref (delivery-query item) 'query-digest)))
               (saved (context-query-export catalog receipt)))
          (let-values (((restored observed) (context-query-restore saved)))
            (check (.ref observed 'semantic-digest) => (.ref receipt 'semantic-digest))
            (check (context-query-current? restored observed) => #t)))))
    (yuanxu-test-case "descendantBoundsTest"
      (let* ((window (.o max-depth: 8 result-bound: 2))
             (s (setup-descendants window))
             (host (scenario-host s))
             (ticket (context-task-start! host)))
        (check (object? ticket) => #t)
        (check-exception (context-task-query! host ticket) true)
        (check (context-task-current host) => #f)
        (check (cadr (context-query-history (scenario-queries s))) => '())
        (let* ((catalog (scenario-queries s))
               (src (context-query-current-source catalog (scenario-source s)))
               (q (context-org-descendants-query src anchor 1 16))
               (hit (context-query-execute catalog (scenario-source s) q)))
          (check (map (lambda (row) (row-field row 'elementKind))
                      (rows-by-source (.ref hit 'result-set))) => '("paragraph" "table")))))
    (yuanxu-test-case "descendantSourceChangeTest"
      (let* ((s (setup-descendants descendant-window))
             (item (issue s))
             (catalog (scenario-queries s))
             (src (context-query-current-source catalog (scenario-source s)))
             (old-query (context-org-descendants-query src anchor 8 16))
             (updated (string-append "#+title: Revised\n" descendant-source)))
        (check (deliver s item) => 'published)
        (let (pending (issue s))
          (register-source! s (scenario-source s) 2 updated)
          (check (current s) => #f)
          (check-exception (context-query-execute catalog (scenario-source s) old-query) true)
          (let (fresh (issue s))
            (check (deliver s pending) => 'historical)
            (check (deliver s fresh) => 'published)
            (check-descendant-publication s 2 updated)))))
    (yuanxu-test-case "descendantAuthorizationTest"
      (let* ((s (setup "A" (context-query-host) descendant-source))
             (host (scenario-host s)))
        (check (select-worktree! s (descendant-loader s descendant-window)) => #f)
        (check (context-task-start! host) => #f)
        (register-grant! s "descendant-read" 1 (scenario-source s) descendant-window)
        (check (select-worktree! s (descendant-loader s descendant-window "descendant-read")) => #t)
        (check (deliver s (issue s)) => 'published)
        (let* ((late (issue s)) (grants (scenario-grants s))
               (grant (agentic-ai-lab-context-use-host-current grants "descendant-read")))
          (agentic-ai-lab-context-use-host-refresh! grants (agentic-ai-lab-context-use-grant-revoke grant))
          (check (current s) => #f)
          (check (context-task-start! host) => #f)
          (check (deliver s late) => 'historical))))
    (yuanxu-test-case "linkTargetVersionTest"
      (let (s (setup-link))
        (check (select-worktree! s (linked-loader s 1)) => #t)
        (check (deliver s (issue s)) => 'published)
        (check-link s 1)
        (let (late (issue s))
          (register-source! s target-source-id 2 (string-append target-text "Revised evidence.\n"))
          (check (current s) => #f)
          (check (select-worktree! s (linked-loader s 1)) => #f)
          (check (context-task-start! (scenario-host s)) => #f)
          (check (select-worktree! s (linked-loader s 2)) => #t)
          (let (fresh (issue s))
            (check (deliver s late) => 'historical)
            (check (deliver s fresh) => 'published)
            (check-link s 2))
          (check (map (lambda (entry) (.ref (.ref (car (.ref entry 'org-links)) 'target) 'generation))
                      (context-task-history (scenario-host s))) => '(1 1 2)))))
    (yuanxu-test-case "linkTargetAuthorityTest"
      (let (s (setup-link target-source-id #f))
        (check (select-worktree! s (linked-loader s 1)) => #f)
        (check (context-task-start! (scenario-host s)) => #f)
        (check (cadr (context-query-history (scenario-queries s))) => '())
        (register-grant! s "target-read" 1 target-source-id)
        (check (select-worktree! s (linked-loader s 1)) => #t)
        (check (deliver s (issue s)) => 'published)
        (let* ((late (issue s))
               (grants (scenario-grants s))
               (grant (agentic-ai-lab-context-use-host-current grants "target-read")))
          (agentic-ai-lab-context-use-host-refresh! grants (agentic-ai-lab-context-use-grant-revoke grant))
          (check (current s) => #f)
          (check (context-task-start! (scenario-host s)) => #f)
          (check (deliver s late) => 'historical))))
    (yuanxu-test-case "linkTargetSubstitutionTest"
      (let* ((other "A/other-design.org") (s (setup-link other)))
        (check-exception (select-worktree! s (linked-loader s 1 other)) true)
        (check (context-task-start! (scenario-host s)) => #f)
        (check (cadr (context-query-history (scenario-queries s))) => '())))
    (yuanxu-test-case "linkOutsideWindowTest"
      (let* ((bytes (string-append source-text "Local evidence.\n"
                      "* Evidence\n:PROPERTIES:\n:ID: sibling\n:END:\n"
                      "See [[" cross-file-path "][design evidence]].\n"))
             (s (setup-link target-source-id #f bytes)))
        (check (select-worktree! s (linked-loader s 1)) => #t)
        (check (deliver s (issue s)) => 'published)
        (check (.ref (current s) 'org-links) => '())
        (check (length (.ref (current s) 'org-queries)) => 1)))
    (yuanxu-test-case "linkConvergingPathsTest"
      (let (s (setup-chain #f #t))
        (check (select-worktree! s (chain-loader s 1)) => #t)
        (check (deliver s (issue s)) => 'published)
        (check-chain s 1 #t)))
    (yuanxu-test-case "linkCycleTest"
      (let* ((s (setup-chain #t)) (host (scenario-host s)))
        (check-exception (select-worktree! s (chain-loader s 1 #t))
          (lambda (failure) (and (Error? failure) (equal? (Error-message failure) "Cyclic Worktree Org links"))))
        (check (context-task-start! host) => #f)
        (check (current s) => #f)
        (check (cadr (context-query-history (scenario-queries s))) => '())))
    (yuanxu-test-case "linkIntermediateVersionTest"
      (let (s (setup-chain))
        (check (select-worktree! s (chain-loader s 1)) => #t)
        (check (deliver s (issue s)) => 'published)
        (check-chain s 1)
        (let (late (issue s))
          (register-source! s target-source-id 2
            (string-append (read-worktree-example "design.org") "Revised intermediate evidence.\n"))
          (check (current s) => #f)
          (check (context-task-start! (scenario-host s)) => #f)
          (check (select-worktree! s (chain-loader s 2)) => #t)
          (let (fresh (issue s))
            (check (deliver s late) => 'historical)
            (check (deliver s fresh) => 'published)
            (check-chain s 2))
          (check (map (lambda (row)
                         (let (hops (.ref row 'org-links))
                           (list (.ref (.ref (car hops) 'target) 'generation)
                                 (.ref (.ref (cadr hops) 'source) 'generation))))
                       (context-task-history (scenario-host s))) => '((1 1) (1 1) (2 2))))))
    (yuanxu-test-case "linkIntermediateAuthorityTest"
      (let* ((s (setup-chain #f #f #f))
             (host (scenario-host s))
             (grants (scenario-grants s))
             (loader (chain-loader s 1)))
        (check (select-worktree! s loader) => #f)
        (register-grant! s "target-read" 1 target-source-id descendant-window design-anchor)
        (check (select-worktree! s loader) => #f)
        (check (context-task-start! host) => #f)
        (check (cadr (context-query-history (scenario-queries s))) => '())
        (register-grant! s "reference-read" 1 reference-source-id #f reference-anchor)
        (check (select-worktree! s loader) => #t)
        (check (deliver s (issue s)) => 'published)
        (let* ((late (issue s))
               (grant (agentic-ai-lab-context-use-host-current grants "target-read")))
          (agentic-ai-lab-context-use-host-refresh! grants (agentic-ai-lab-context-use-grant-revoke grant))
          (check (current s) => #f)
          (check (context-task-start! host) => #f)
          (check (deliver s late) => 'historical)
          (register-grant! s "replacement-read" 1 target-source-id descendant-window design-anchor)
          (check (select-worktree! s (chain-loader s 1 #f "replacement-read")) => #t)
          (check (deliver s (issue s)) => 'published)
          (check-chain s 1))))))
