;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .o .ref .slot?)
        (only-in :clan/poo/type element? raise-type-error)
        (only-in :std/list/list every filter delete-duplicates/hash)
        (only-in :tao3k/agentic-ai-lab/modules/gitops/dependency GitOpsModuleDependency)
        (only-in :tao3k/agentic-ai-lab/modules/gitops/features/work/types GitOpsWorkBinding)
        (only-in :tao3k/agentic-ai-lab/modules/gitops/features/worktrunk/types GitOpsWorkTrunkBinding)
        (only-in :orgize/languages/org/modules/org-elements/source-interface org-source-element-graph)
        (only-in :orgize/languages/org/modules/org-elements/source-graph org-source-element-field)
        (only-in :orgize/languages/org/modules/org-elements/syntax org-elements descendant-of)
        (only-in :orgize/languages/org/modules/org-elements/link-properties
                 org-link-protocol org-link-file-path org-link-file-path-kind
                 org-link-search org-link-search-kind org-link-search-value)
        (only-in :orgize/languages/org/modules/org-elements/values org-element-graph-records)
        "org-contract/descendants.ss")
(export resolve-worktree-org-selection task-dependencies-current? same-task-dependencies?
        task-dependency-versions)

(def (module-at modules path)
  (unless (and (pair? path) (list? path) (every symbol? path))
    (error "Worktree Module path must contain slot names" path))
  (let loop ((branch modules) (names path))
    (let (value (.ref branch (car names)))
      (if (null? (cdr names)) value (loop value (cdr names))))))

(defstruct task-dependency (binding loader path version roots))

(def (resolve-task-dependency task scope role type)
  (let (binding (and (.slot? task role) (.ref task role)))
    (and binding
         (begin
           (unless (element? GitOpsModuleDependency binding)
             (raise-type-error GitOpsModuleDependency binding))
           (let* ((loaded (or ((.ref binding 'current-selection))
                            (error "No current GitOps dependency" role)))
                  (path (map values (.ref binding 'module-path)))
                  (_ ((.ref loaded 'admit-current)))
                  (view (module-at (.ref loaded 'modules) path))
                  (_type (unless (element? type view) (raise-type-error type view)))
                  (identity (.ref view role))
                  (revision (.ref view 'revision))
                  (roots (.ref view 'org)))
             (unless (and (equal? (.ref view 'project) (.ref scope 'project))
                          (list? roots) (every symbol? roots))
               (error "Invalid GitOps dependency in Task scope" role))
             (make-task-dependency binding loaded path
               (list role (string-copy identity) (string-copy revision)) (map values roots)))))))

(def (task-dependencies-current? dependencies)
  (every (lambda (entry)
           (let ((binding (task-dependency-binding entry)) (loaded (task-dependency-loader entry)))
             (and (eq? loaded ((.ref binding 'current-selection)))
                  (equal? (task-dependency-path entry) (.ref binding 'module-path))
                  (begin ((.ref loaded 'admit-current)) #t))))
         dependencies))

(def (same-task-dependencies? left right)
  (and (= (length left) (length right))
       (every (lambda (a b)
                (and (eq? (task-dependency-binding a) (task-dependency-binding b))
                     (eq? (task-dependency-loader a) (task-dependency-loader b))
                     (equal? (task-dependency-path a) (task-dependency-path b))
                     (equal? (task-dependency-version a) (task-dependency-version b))))
              left right)))

(def (task-dependency-versions dependencies) (map task-dependency-version dependencies))

(def (origin-at record anchor)
    (let* ((fields
             (map (lambda (key) (org-source-element-field record key))
                  '("property:CONTEXT_ORIGIN_MODULE" "property:CONTEXT_ORIGIN_SOURCE"
                    "property:CONTEXT_ORIGIN_ID" "property:CONTEXT_ORIGIN_GENERATION"))))
      (match fields
        ([#f #f #f #f] #f)
        ([module-name source-id anchor-id version]
         (let (generation (and (string? version) (string->number version)))
           (unless (and (every (lambda (value)
                                (and (string? value) (< 0 (string-length value) 257)))
                              (list module-name source-id anchor-id))
                        (exact-integer? generation) (<= 1 generation 65534)
                        (equal? (number->string generation) version))
             (error "Incomplete or invalid Org origin at selected anchor" anchor))
           (list (string->symbol module-name) source-id anchor-id generation))))))

(def (anchor-declaration source anchor key cut)
  (let* ((records (org-element-graph-records (org-source-element-graph (.ref source 'source))))
         (record (context-org-anchor-element records anchor)))
    (unless record (error "Worktree Org anchor is missing" (.ref source 'identity) anchor))
    (let (custom-id (org-source-element-field record "property:CUSTOM_ID"))
      (list key cut (origin-at record anchor)
            (and custom-id
                 (= 1 (length (filter (lambda (row)
                                         (equal? custom-id (org-source-element-field row "property:CUSTOM_ID")))
                                       records)))
                 custom-id)))))

;; The loaded Yuanxu namespace owns path resolution. A Worktree declaration
;; names the Org modules visible to its Tasks. read-source admits authority
;; before handing this resolver the selected source bytes.
(def (resolve-worktree-org-selection loaded path task-scope read-source (prior-declarations '()))
  (let* ((modules (.ref loaded 'modules))
         (worktree (module-at modules path))
         (identity (.ref task-scope 'worktree))
         (_ (unless (and (equal? (.ref task-scope 'project) (.ref worktree 'project))
                         (equal? identity (.ref worktree 'worktree))
                         (equal? (.ref task-scope 'source-cut) (.ref worktree 'source-cut)))
              (error "Worktree Module does not match the Task scope")))
         (task (.ref (.ref worktree 'tasks) (string->symbol (.ref task-scope 'task))))
         (task-roots (.ref task 'org))
         (feature-dependencies
           (filter values (list (resolve-task-dependency task task-scope 'work GitOpsWorkBinding)
                                (resolve-task-dependency task task-scope 'worktrunk GitOpsWorkTrunkBinding))))
         (roots (and (list? task-roots) (every symbol? task-roots)
                     (= (length task-roots) (length (delete-duplicates/hash task-roots)))
                     (delete-duplicates/hash
                       (append task-roots (apply append (map task-dependency-roots feature-dependencies))))))
         (paths (.ref worktree 'org))
         (declared (make-hash-table-eq))
         (demanded '()))
    (unless (and roots (<= 1 (length roots) 32))
      (error "Task declares invalid Org roots"))
    (let/cc unresolved
      (def (observe-origin source anchor)
        (let* ((key (list (.ref source 'identity) anchor))
               (cut (.ref source 'semantic-digest))
               (prior (assoc key prior-declarations)))
          (if (and prior (equal? cut (cadr prior))) prior
              (anchor-declaration source anchor key cut))))
      (def (visit name trail (expected #f) (version #f) (selector #f))
        (when (memq name trail) (error "Cyclic Worktree Org origin" name))
        (let* ((cached (hash-get declared name))
               (org-module (if cached (.ref cached 'definition) (module-at modules (.ref paths name))))
               (source-id (.ref org-module 'source))
               (anchor-id (.ref org-module 'anchor)))
          (when expected
            (unless (and (equal? source-id (car expected))
                         (or (not (cadr expected)) (equal? anchor-id (cadr expected))))
              (error "Org Module does not match the selected source and anchor" name)))
          (let* ((grant-id (.ref org-module 'grant))
                 (window (and (.slot? org-module 'descendants) (.ref org-module 'descendants)))
                 (pinned
                   (if selector
                     (let (pin (.ref org-module 'source-generation))
                       (unless (and (exact-integer? pin) (<= 1 pin 65534))
                         (error "Invalid linked Org source generation" name))
                       pin)
                     version))
                 (source
                   (if cached (.ref cached 'source-cut)
                       (begin
                         (unless (equal? identity (.ref org-module 'worktree))
                           (error "Org Module belongs to a different Worktree" name))
                         (when (>= (length demanded) 32) (error "Worktree Org demand exceeds 32 anchors"))
                         (set! demanded (cons name demanded))
                         (or (read-source source-id anchor-id grant-id window) (unresolved #f))))))
            (when (and pinned (not (= pinned (.ref source 'generation)))) (unresolved #f))
            (when (and (.slot? worktree 'org-contract)
                       (equal? (path-strip-directory source-id) "worktree.org"))
              (let (contract (.ref worktree 'org-contract))
                (unless (and (equal? (.ref contract 'identity) (.ref source 'contract-identity))
                             (equal? (.ref contract 'revision) (.ref source 'contract-revision)))
                  (unresolved #f))))
            (let (declaration (if cached (.ref cached 'declaration-read) (observe-origin source anchor-id)))
              (when (and selector (not (equal? selector (cadddr declaration))))
                (error "Org link custom ID does not uniquely identify the pinned anchor" name selector))
              (or cached
                  (let* ((origin-ref
                         (match (caddr declaration)
                           (#f #f)
                           ([original-name original-source original-anchor generation-value]
                            (visit original-name (cons name trail) (list original-source original-anchor)
                                   generation-value)
                            (.o source: original-source anchor: original-anchor generation: generation-value))))
                       (result (.o module: (.o source: source-id anchor: anchor-id grant: grant-id
                                               query-revision: (.ref org-module 'query-revision)
                                               origin: origin-ref descendants: window)
                                   source-cut: source
                                   definition: org-module
                                   declaration-read: declaration)))
                    (hash-put! declared name result)
                    result))))))
      (def expanded (make-hash-table-eq))
      (def linked '())
      (def link-count 0)
      (def (follow-hop key version node trail)
        (let (path (.ref node 'link-path))
          (when (and (string? path) (equal? (org-link-protocol path) "file"))
            (let ((file (org-link-file-path path)) (search (org-link-search path)))
              (when (and (equal? (org-link-file-path-kind file) "relative")
                         (equal? (org-link-search-kind search) "custom-id"))
                ;; The Orgize file field is a Worktree namespace key suffix.
                (let* ((target-source (string-append (path-directory (car key)) file))
                       (target-name (string->symbol target-source)))
                  (when (and (not (equal? target-source (car key))) (.slot? paths target-name))
                    (when (>= link-count 32) (error "Task Org links exceed 32 Elements"))
                    (let* ((target (visit target-name '() (list target-source #f) #f
                                         (org-link-search-value search)))
                           (target-key (car (.ref target 'declaration-read)))
                           (generation (.ref (.ref target 'source-cut) 'generation)))
                      (set! link-count (+ link-count 1))
                      (set! linked (cons (list key (.ref node 'identity) path version
                                               (.ref node 'byteStart) (.ref node 'byteEnd)
                                               target-key generation) linked))
                      (follow-links target-name target trail)))))))))
      ;; Expand each reachable anchor once. A revisit along the active path
      ;; is a cycle; converging paths can reuse an already expanded anchor.
      (def (follow-links name entry trail)
        (let* ((module (.ref entry 'module))
               (cut (.ref entry 'source-cut))
               (anchor (.ref module 'anchor))
               (key (list (.ref cut 'identity) anchor)))
          (when (member key trail) (error "Cyclic Worktree Org links" key))
          (unless (hash-key? expanded name)
            (let ((window (.ref module 'descendants)) (before link-count))
              (when window
                (let* ((result (context-org-descendants cut anchor
                                 (.ref window 'max-depth) (.ref window 'result-bound)
                                 (org-elements link (descendant-of scope))))
                       (version (.ref cut 'generation))
                       (trail (cons key trail)))
                  (for-each (lambda (node) (follow-hop key version node trail)) (.ref result 'descendants))))
              (hash-put! expanded name (and (> link-count before) key))))
          (hash-ref expanded name)))
      (for-each (lambda (root) (visit root '())) roots)
      (let* ((root-keys
               (filter values (map (lambda (root) (follow-links root (hash-ref declared root) '())) roots)))
             (dependencies (filter (lambda (name) (not (memq name roots))) (reverse demanded)))
             (selected (map (lambda (name) (hash-ref declared name)) (append roots dependencies)))
             (reads (map (lambda (entry) (.ref entry 'declaration-read)) selected)))
        (.o selection: (.o router-revision: (.ref task 'router-revision)
                           search-contract-revision: (.ref task 'search-contract-revision)
                           org-modules: (map (lambda (entry) (.ref entry 'module)) selected))
            source-digests: (map cadr reads)
            dependencies: feature-dependencies
            link-roots: root-keys
            links: (reverse linked)
            declaration-reads: reads)))))
