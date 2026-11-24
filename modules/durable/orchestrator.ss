;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Declarative Durable Task Orchestrator unifying:
;;; - Doom-Emacs-style hygienic declaration macros (zero runtime eval)
;;; - gerbil-poo C4 linearization (Repo A -> Worktree B -> Task C -> SubTask/Extension D)
;;; - Tweag-inspired FunFlow CAS DAG + epoch-bounded dynamic replanning
;;; - Org Elements / ASCENT 4-predicate orchestration & Plan-A index.org sync
;;; - Governance scope isolation & atomic durable-journal Auto-Archive
;;; - Pure functional Task-as-Tab WorkbenchTabProjection (no TUI widget coupling)

(import (only-in :clan/poo/object .def .o .ref .slot? .call object?)
        (only-in :clan/poo/mop .defgeneric)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :std/list/list every filter find filter-map delete-duplicates/hash)
        (only-in :std/string/misc string-trim string-prefix? string-contains string-split)
        (only-in :gerbil-ascent/program/api
                 relational-program relational-admit relational-solve
                 relational-query-name)
        (only-in :orgize/languages/org/modules/org-elements/values
                 org-element-graph-records)
        (only-in :orgize/languages/org/modules/org-elements/query
                 make-org-element-query-context org-element-property)
        (only-in :tao3k/agentic-ai-lab/modules/query/semantic/orgize-source-interface
                 org-source-element-graph org-source-element-field)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/org-contract/elements
                 context-org-source)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-org-elements-gql
                 agentic-ai-lab-ai-agentic-context-org-element-graph
                 agentic-ai-lab-ai-agentic-context-headline-set-todo)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-org-progressive-rules
                 agentic-ai-lab-ai-agentic-context-parse-rule-overrides
                 agentic-ai-lab-ai-agentic-context-ascent-progressive-plan)
        (only-in :tao3k/agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
                 journal-get journal-put! journal-hash journal-pack
                 journal-active? journal-receive! journal-begin! journal-commit! journal-abort!)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/durable-dag
                 OrchestratorStrategy.
                 ParallelFrontierStrategy.
                 TieredModelStrategy.
                 DurableGovernedStrategy.
                 strategy-admit-node
                 strategy-admit-frontier
                 strategy-archive-guard
                 funflow-dag-node
                 funflow-dag-build
                 funflow-resume-plan
                 funflow-replan-epoch))

(export DurableTaskPolicy.
        RepoNode.
        WorktreeNode.
        TaskNode.
        SubTaskNode.
        define-repo!
        define-worktree!
        define-durable-task!
        define-orchestrator-strategy!
        node-effective-rules
        task-artifact-path
        task-funflow-dag
        task-orchestration-plan
        task-archive-transition
        project-workbench-tabs
        durable-orchestrator-record-cas!
        durable-orchestrator-completed-cas
        durable-orchestrator-commit-archive!
        durable-orchestrator-reopen!
        durable-orchestrator-recover
        DurableOrchestratorExports)

;;; ---------------------------------------------------------------------------
;;; 1. Doom-Emacs-Style Compile-Time Hygienic Declaration Macros (Zero eval)
;;; ---------------------------------------------------------------------------

(defrules define-repo! ()
  ((_ name body ...)
   (def name (.o (:: @ RepoNode.) body ...))))

(defrules define-worktree! ()
  ((_ name base-repo body ...)
   (def name (.o (:: @ [base-repo WorktreeNode.]) body ...))))

(defrules define-durable-task! ()
  ((_ name base-worktree body ...)
   (def name (.o (:: @ [base-worktree TaskNode.]) body ...))))

(defrules define-orchestrator-strategy! ()
  ((_ name base-strategy body ...)
   (def name (.o (:: @ base-strategy) body ...))))

;;; ---------------------------------------------------------------------------
;;; 2. MOP .defgeneric Protocol Surface
;;; ---------------------------------------------------------------------------

(.defgeneric (node-effective-rules node org-source-text)
  slot: .effective-rules)

(.defgeneric (task-artifact-path task)
  slot: .artifact-path)

(.defgeneric (task-funflow-dag task org-source-text)
  slot: .funflow-dag)

(.defgeneric (task-orchestration-plan task org-source-text journal-state)
  slot: .orchestration-plan)

(.defgeneric (task-archive-transition task org-source-text index-source-text timestamp)
  slot: .archive-transition)

(.defgeneric (project-workbench-tabs owner task-records journal-state peek-set focused-task-id)
  slot: .project-workbench-tabs)

;;; ---------------------------------------------------------------------------
;;; 3. Pure Helpers
;;; ---------------------------------------------------------------------------

(def (opt-ref obj key default)
  (if (and (object? obj) (.slot? obj key))
    (.ref obj key)
    default))

(def (canonical-sha256 payload)
  (string-append
   "sha256:"
   (hex-encode
    (sha256
     (string->utf8
      (call-with-output-string (lambda (port) (write payload port))))))))

(def (utf8-slice bytes start end)
  (utf8->string (subu8vector bytes start end)))

(def (split-whitespace-tokens text)
  (if (and (string? text) (> (string-length (string-trim text)) 0))
    (filter (lambda (tok) (> (string-length tok) 0))
            (map string-trim (string-split (string-trim text) #\space)))
    '()))

(def (normalize-todo-symbol kw)
  (cond
   ((not kw) 'todo)
   ((string? kw)
    (let ((u (string-upcase (string-trim kw))))
      (cond
       ((member u '("DONE" "COMPLETED" "VERIFIED")) 'done)
       ((member u '("FAILED" "ERROR")) 'failed)
       ((member u '("CANCELLED" "CANCELED" "ABORTED")) 'cancelled)
       ((member u '("BLOCKED" "HOLD" "WAITING")) 'blocked)
       ((member u '("IN_PROGRESS" "NEXT" "STARTED")) 'in-progress)
       ((member u '("REVIEW")) 'review)
       (else 'todo))))
   ((symbol? kw) kw)
   (else 'todo)))

(def (headline-tags-list ctx record)
  (let ((raw (org-element-property ctx record "tags")))
    (cond
     ((list? raw) raw)
     ((vector? raw) (vector->list raw))
     (else '()))))

(def (headline-archived? ctx record)
  (and (find (lambda (tag)
               (and (string? tag)
                    (string=? (string-upcase tag) "ARCHIVE")))
             (headline-tags-list ctx record))
       #t))

(def (string-join-with items sep)
  (if (null? items)
    ""
    (let loop ((rest (cdr items)) (acc (car items)))
      (if (null? rest)
        acc
        (loop (cdr rest) (string-append acc sep (car rest)))))))

(def (string-index-char str ch)
  (let ((len (string-length str)))
    (let loop ((i 0))
      (cond
       ((>= i len) #f)
       ((char=? (string-ref str i) ch) i)
       (else (loop (+ i 1)))))))

(def (headline-property ctx record key)
  (let ((val (org-element-property ctx record (string-append "property:" key))))
    (and (string? val)
         (> (string-length (string-trim val)) 0)
         (string-trim val))))

(def (item-checkbox-checked? ctx it)
  (let ((cb (org-element-property ctx it "checkbox")))
    (or (equal? cb "on") (equal? cb "X") (equal? cb "x") (eq? cb 'on))))

(def (headline-checklists-done? ctx record items)
  (let* ((h-start (.ref record 'start))
         (h-end (.ref record 'end))
         (owned (filter (lambda (it)
                          (let ((s (.ref it 'start))
                                (e (.ref it 'end))
                                (cb (org-element-property ctx it "checkbox")))
                            (and (exact-integer? s) (exact-integer? e)
                                 (>= s h-start) (<= e h-end)
                                 (string? cb) (> (string-length cb) 0))))
                        items)))
    (every (lambda (it) (item-checkbox-checked? ctx it)) owned)))

(def (count-checklists ctx items)
  (let* ((boxes (filter (lambda (it)
                          (let ((cb (org-element-property ctx it "checkbox")))
                            (and (string? cb) (> (string-length cb) 0))))
                        items))
         (done (filter (lambda (it) (item-checkbox-checked? ctx it)) boxes)))
    (cons (length done) (length boxes))))

;;; ---------------------------------------------------------------------------
;;; 4. Core Orchestration Implementations (Backing MOP Generics)
;;; ---------------------------------------------------------------------------

(def (default-effective-rules node org-source-text)
  (let* ((policy (opt-ref node 'policy DurableTaskPolicy.))
         (org-overrides (if (and (string? org-source-text)
                                 (> (string-length org-source-text) 0))
                          (agentic-ai-lab-ai-agentic-context-parse-rule-overrides org-source-text)
                          #f))
         (ov-ref (lambda (k fallback)
                   (if (and (object? org-overrides) (.slot? org-overrides k))
                     (.ref org-overrides k)
                     fallback)))
         (split-wm (ov-ref 'split-line-watermark (opt-ref policy 'split-line-watermark 800)))
         (focus-d (ov-ref 'default-focus-depth (opt-ref policy 'default-focus-depth 2)))
         (req-sod (or (opt-ref policy 'require-sod-reviewer #f)
                      (ov-ref 'require-sod-reviewer #f)))
         (fold-th (ov-ref 'fold-thinking-by-default (opt-ref policy 'fold-thinking-by-default #t)))
         (drill (ov-ref 'allow-agent-drill-down (opt-ref policy 'allow-agent-drill-down #t)))
         (focused-arch (opt-ref policy 'focused-tab-archive 'on-blur))
         (scratch-prom (opt-ref policy 'scratch-promotion 'on-plan))
         (reopen-m (opt-ref policy 'reopen-mode 'peek-until-edit))
         (max-c (opt-ref policy 'max-concurrency 4)))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.durable.effective-rules.v1
        split-line-watermark: split-wm
        default-focus-depth: focus-d
        require-sod-reviewer: req-sod
        fold-thinking-by-default: fold-th
        allow-agent-drill-down: drill
        focused-tab-archive: focused-arch
        scratch-promotion: scratch-prom
        reopen-mode: reopen-m
        max-concurrency: max-c)))

(def (default-task-artifact-path task)
  (let* ((task-id (opt-ref task 'task-id "task-unnamed"))
         (explicit (opt-ref task 'org-path #f))
         (index-p (opt-ref task 'index-path "index.org"))
         (worktree (opt-ref task 'worktree "main"))
         (task-p (or explicit (string-append "work/" task-id ".org"))))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.durable.task-artifact-path.v1
        task-id: task-id
        worktree: worktree
        index-path: index-p
        task-org-path: task-p)))

(def (default-task-funflow-dag task org-source-text)
  (let* ((graph (org-source-element-graph org-source-text))
         (ctx (make-org-element-query-context graph))
         (records (org-element-graph-records graph))
         (bytes (string->utf8 org-source-text))
         (headlines
          (list-sort (lambda (a b) (< (.ref a 'start) (.ref b 'start)))
                     (filter (lambda (r) (member (.ref r 'kind) '("headline" "inlinetask"))) records)))
         (items (filter (lambda (r) (equal? (.ref r 'kind) "item")) records))
         (source-cut (opt-ref task 'source-cut "cut-0"))
         (rules (node-effective-rules task org-source-text))
         (policy-digest (canonical-sha256
                         (list (.ref rules 'require-sod-reviewer)
                               (.ref rules 'focused-tab-archive)
                               (.ref rules 'default-focus-depth))))
         (strategy (opt-ref task 'strategy DurableGovernedStrategy.))
         (root-headline (and (pair? headlines) (car headlines)))
         (sub-headlines (if (and (pair? headlines) (pair? (cdr headlines)))
                          (cdr headlines)
                          headlines))
         (dag-nodes
          (map
           (lambda (h)
             (let* ((prop-id (or (headline-property ctx h "ID")
                                 (headline-property ctx h "CUSTOM_ID")
                                 (string-append "h-" (number->string (.ref h 'start)))))
                    (dep-str (headline-property ctx h "DEPENDS_ON"))
                    (deps (split-whitespace-tokens dep-str))
                    (fin-for (headline-property ctx h "FINALIZER_FOR"))
                    (tier-str (headline-property ctx h "MODEL_TIER"))
                    (tier (if tier-str (string->symbol (string-downcase tier-str)) 'builder))
                    (agent-id (headline-property ctx h "AGENT_ID"))
                    (reviewer-id (headline-property ctx h "REVIEWER_AGENT_ID"))
                    (h-start (.ref h 'start))
                    (h-end (.ref h 'end))
                    (h-text (utf8-slice bytes h-start h-end))
                    (st (normalize-todo-symbol (org-element-property ctx h "todo-keyword")))
                    (chk-ok? (headline-checklists-done? ctx h items))
                    (scope-obj (.o bind-these: #f
                                   task-id: (opt-ref task 'task-id "task")
                                   worktree: (opt-ref task 'worktree "main")
                                   source-cut: source-cut
                                   actor: agent-id
                                   reviewer-id: reviewer-id
                                   restriction-envelope: (opt-ref task 'restriction-envelope #f)
                                   trust-tier: (opt-ref task 'trust-tier 'verified))))
               (funflow-dag-node prop-id
                                 needs: deps
                                 after-start: fin-for
                                 source-cut: source-cut
                                 input-digest: (canonical-sha256 h-text)
                                 contract-digest: (canonical-sha256 (list prop-id deps fin-for))
                                 policy-digest: policy-digest
                                 status: st
                                 checklists-done?: chk-ok?
                                 span: (cons h-start h-end)
                                 scope: scope-obj
                                 model-tier: tier)))
           sub-headlines))
         (dag (funflow-dag-build dag-nodes strategy: strategy))
         (root-status (if root-headline
                        (normalize-todo-symbol (org-element-property ctx root-headline "todo-keyword"))
                        'todo))
         (root-archived? (and root-headline (headline-archived? ctx root-headline)))
         (root-title (if root-headline
                       (or (org-element-property ctx root-headline "title")
                           (opt-ref task 'task-id "Task"))
                       (opt-ref task 'task-id "Task")))
         (root-id (if root-headline
                    (or (headline-property ctx root-headline "ID")
                        (opt-ref task 'scope-root-id (opt-ref task 'task-id "task-root")))
                    (opt-ref task 'scope-root-id (opt-ref task 'task-id "task-root"))))
         (check-counts (count-checklists ctx items)))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.durable.task-dag-projection.v1
        task-id: (opt-ref task 'task-id "task")
        root-id: root-id
        root-title: root-title
        root-status: root-status
        root-archived?: root-archived?
        checklist-done: (car check-counts)
        checklist-total: (cdr check-counts)
        all-checklists-done?: (= (car check-counts) (cdr check-counts))
        dag: dag)))

(def (index-list items)
  (let loop ((rest items) (i 0) (acc '()))
    (if (null? rest)
      (reverse acc)
      (loop (cdr rest) (+ i 1) (cons (list 1 i) acc)))))

(def (run-ascent-orchestration-rules task-id root-done? dag-valid? dag-complete?
                                     all-checklists-done? already-archived?
                                     in-flight-ids pending-effects recovery-ids
                                     ready-ids focused-on-blur? peeked?)
  (let* ((ready-vec (list->vector ready-ids))
         (recov-vec (list->vector recovery-ids))
         (tid-rows '((1)))
         (root-done-rows (if root-done? tid-rows '()))
         (dag-valid-rows (if dag-valid? tid-rows '()))
         (dag-complete-rows (if dag-complete? tid-rows '()))
         (checklists-done-rows (if all-checklists-done? tid-rows '()))
         (quiescent-rows (if (and (null? in-flight-ids) (null? pending-effects)) tid-rows '()))
         (active-rows (if (not already-archived?) tid-rows '()))
         (focused-keep-rows (if focused-on-blur? tid-rows '()))
         (peeked-rows (if peeked? tid-rows '()))
         (ready-node-rows (index-list ready-ids))
         (attempt-rows (index-list recovery-ids))
         (program
          (relational-program
           (relation root_done (t) root-done-rows)
           (relation dag_valid (t) dag-valid-rows)
           (relation dag_complete (t) dag-complete-rows)
           (relation checklists_done (t) checklists-done-rows)
           (relation journal_quiescent (t) quiescent-rows)
           (relation task_active (t) active-rows)
           (relation focused_keep (t) focused-keep-rows)
           (relation peeked (t) peeked-rows)
           (relation ready_node (t n) ready-node-rows)
           (relation unclosed_attempt (t a) attempt-rows)
           (relation ready_to_schedule (t n))
           (relation needs_recovery (t a))
           (relation ready_to_auto_archive (t))
           (relation tab_visible (t))
           (rule (ready_to_schedule ?t ?n) (ready_node ?t ?n) (dag_valid ?t) (task_active ?t))
           (rule (needs_recovery ?t ?a) (unclosed_attempt ?t ?a))
           (rule (ready_to_auto_archive ?t)
                 (root_done ?t)
                 (dag_valid ?t)
                 (dag_complete ?t)
                 (checklists_done ?t)
                 (journal_quiescent ?t)
                 (task_active ?t))
           (rule (tab_visible ?t) (task_active ?t))
           (rule (tab_visible ?t) (focused_keep ?t))
           (rule (tab_visible ?t) (peeked ?t))
           (limits 1024 2048 2048)))
         (solution (relational-solve (relational-admit program)))
         (ready-indices (list-sort < (map cadr (relational-query-name solution 'ready_to_schedule))))
         (recov-indices (list-sort < (map cadr (relational-query-name solution 'needs_recovery)))))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.durable.ascent-orchestration-facts.v1
        ready-to-schedule: (map (lambda (i) (vector-ref ready-vec i)) ready-indices)
        needs-recovery: (map (lambda (i) (vector-ref recov-vec i)) recov-indices)
        ready-to-auto-archive?: (pair? (relational-query-name solution 'ready_to_auto_archive))
        tab-visible?: (pair? (relational-query-name solution 'tab_visible)))))

(def (default-task-orchestration-plan task org-source-text journal-state)
  (let* ((task-id (opt-ref task 'task-id "task"))
         (rules (node-effective-rules task org-source-text))
         (strategy-base (opt-ref task 'strategy DurableGovernedStrategy.))
         (strategy (.o (:: @ strategy-base)
                       require-sod-reviewer: (.ref rules 'require-sod-reviewer)
                       max-concurrency: (.ref rules 'max-concurrency)
                       focused-tab-archive: (.ref rules 'focused-tab-archive)))
         (dag-proj (task-funflow-dag task org-source-text))
         (dag (.ref dag-proj 'dag))
         (completed-cas (opt-ref journal-state 'completed-cas #f))
         (in-flight-ids (opt-ref journal-state 'in-flight-ids '()))
         (pending-effects (opt-ref journal-state 'pending-effects '()))
         (recovery-ids (opt-ref journal-state 'unclosed-attempts '()))
         (gov-context (opt-ref journal-state 'governance-context (.o)))
         (resume (funflow-resume-plan dag
                                      completed-cas-table: completed-cas
                                      in-flight-ids: in-flight-ids
                                      strategy: strategy
                                      context: gov-context))
         (archive-guard-ok? (strategy-archive-guard strategy dag resume journal-state))
         (focused-keep? (and (opt-ref journal-state 'focused? #f)
                             (eq? (.ref rules 'focused-tab-archive) 'on-blur)))
         (peeked? (and (opt-ref journal-state 'peeked? #f) #t))
         (ascent-facts
          (run-ascent-orchestration-rules
           task-id
           (eq? (.ref dag-proj 'root-status) 'done)
           (.ref dag 'valid?)
           (and (.ref resume 'complete?) archive-guard-ok?)
           (.ref dag-proj 'all-checklists-done?)
           (.ref dag-proj 'root-archived?)
           in-flight-ids
           pending-effects
           recovery-ids
           (.ref resume 'ready-frontier)
           focused-keep?
           peeked?))
         (progressive
          (with-catch
            (lambda (_err) #f)
            (lambda ()
              (let* ((src-cut-obj (context-org-source (or (opt-ref task 'org-path task-id) task-id)
                                                      1
                                                      org-source-text
                                                      #t))
                     (elem-graph (agentic-ai-lab-ai-agentic-context-org-element-graph
                                  task-id (list src-cut-obj))))
                (agentic-ai-lab-ai-agentic-context-ascent-progressive-plan
                 elem-graph
                 (.o focus-property-ids: (list (.ref dag-proj 'root-id))
                     drill-downs: (opt-ref journal-state 'drill-downs '()))))))))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.durable.task-orchestration-plan.v1
        task-id: task-id
        effective-rules: rules
        dag-projection: dag-proj
        resume-plan: resume
        ready-to-schedule: (.ref ascent-facts 'ready-to-schedule)
        needs-recovery: (.ref ascent-facts 'needs-recovery)
        ready-to-auto-archive?: (.ref ascent-facts 'ready-to-auto-archive?)
        tab-visible?: (.ref ascent-facts 'tab-visible?)
        progressive-plan: progressive)))

(def (add-archive-tag-to-first-headline org-text timestamp)
  (let* ((lines (string-split org-text #\newline))
         (closed-line (string-append "CLOSED: [" timestamp "]")))
    (let loop ((rest lines) (seen-root? #f) (inserted-closed? #f) (acc '()))
      (cond
       ((null? rest) (string-join-with (reverse acc) "\n"))
       ((and (not seen-root?) (string-prefix? "*" (car rest)))
        (let* ((line (car rest))
               (already? (string-contains line ":ARCHIVE:"))
               (updated
                (cond
                 (already? line)
                 ((and (> (string-length line) 1)
                       (char=? (string-ref line (- (string-length line) 1)) #\:))
                  (string-append line "ARCHIVE:"))
                 (else
                  (string-append line " :ARCHIVE:")))))
          (loop (cdr rest) #t #f (cons updated acc))))
       ((and seen-root? (not inserted-closed?))
        (if (string-prefix? "CLOSED:" (string-trim (car rest)))
          (loop (cdr rest) #t #t (cons closed-line acc))
          (loop (cdr rest) #t #t (cons (car rest) (cons closed-line acc)))))
       (else
        (loop (cdr rest) seen-root? inserted-closed? (cons (car rest) acc)))))))

(def (string-find-substr str sub)
  (let ((slen (string-length str))
        (sublen (string-length sub)))
    (if (= sublen 0)
      0
      (let loop ((i 0))
        (cond
         ((> (+ i sublen) slen) #f)
         ((string=? (substring str i (+ i sublen)) sub) i)
         (else (loop (+ i 1))))))))

(def (remove-archive-tag-and-closed org-text)
  (let ((lines (string-split org-text #\newline)))
    (let loop ((rest lines) (seen-root? #f) (acc '()))
      (cond
       ((null? rest) (string-join-with (reverse acc) "\n"))
       ((and (not seen-root?) (string-prefix? "*" (car rest)))
        (let* ((line (car rest))
               (pos (string-find-substr line ":ARCHIVE:"))
               (stripped
                (if pos
                  (let* ((before (substring line 0 pos))
                         (after (substring line (+ pos 9) (string-length line))))
                    (string-trim
                     (if (and (> (string-length before) 0)
                              (char=? (string-ref before (- (string-length before) 1)) #\:))
                       (string-append before after)
                       (if (> (string-length after) 0)
                         (string-append before ":" after)
                         before))))
                  line)))
          (loop (cdr rest) #t (cons stripped acc))))
       ((and seen-root? (string-prefix? "CLOSED:" (string-trim (car rest))))
        (loop (cdr rest) #t acc))
       (else
        (loop (cdr rest) seen-root? (cons (car rest) acc)))))))

(def (upsert-index-entry index-text task-id root-id title worktree task-path status
                         done-count total-count archived? timestamp)
  (let* ((status-str (cond
                      ((eq? status 'done) "DONE")
                      ((eq? status 'in-progress) "IN_PROGRESS")
                      ((eq? status 'blocked) "BLOCKED")
                      ((eq? status 'review) "REVIEW")
                      (else "TODO")))
         (cookie (if (> total-count 0)
                   (string-append " [" (number->string done-count) "/" (number->string total-count) "]")
                   ""))
         (tag-str (if archived? " :ARCHIVE:" ""))
         (heading (string-append "* " status-str " " title cookie tag-str))
         (closed (if archived? (list (string-append "CLOSED: [" timestamp "]")) '()))
         (block-lines
          (append
           (list heading)
           closed
           (list ":PROPERTIES:"
                 (string-append ":ID: " root-id)
                 (string-append ":TASK_ID: " task-id)
                 (string-append ":WORKTREE: " worktree)
                 (string-append ":TASK_FILE: " task-path)
                 ":END:"
                 (string-append "[[file:" task-path "][" title "]]"))))
         (block-text (string-join-with block-lines "\n"))
         (graph (if (> (string-length (string-trim index-text)) 0)
                  (org-source-element-graph index-text)
                  #f))
         (ctx (and graph (make-org-element-query-context graph)))
         (existing
          (and graph
               (find (lambda (r)
                       (and (member (.ref r 'kind) '("headline" "inlinetask"))
                            (or (equal? (headline-property ctx r "TASK_ID") task-id)
                                (equal? (headline-property ctx r "ID") root-id))))
                     (org-element-graph-records graph)))))
    (if existing
      (let* ((bytes (string->utf8 index-text))
             (s (.ref existing 'start))
             (e (.ref existing 'end))
             (before (utf8-slice bytes 0 s))
             (after (utf8-slice bytes e (u8vector-length bytes))))
        (string-append before block-text "\n" after))
      (if (> (string-length (string-trim index-text)) 0)
        (string-append (string-trim-right index-text) "\n\n" block-text "\n")
        (string-append "#+TITLE: Task Index\n\n" block-text "\n")))))

(def (string-trim-right s)
  (let loop ((i (string-length s)))
    (if (and (> i 0) (char-whitespace? (string-ref s (- i 1))))
      (loop (- i 1))
      (substring s 0 i))))

(def (default-task-archive-transition task org-source-text index-source-text timestamp)
  (let* ((paths (task-artifact-path task))
         (dag-proj (task-funflow-dag task org-source-text))
         (task-id (.ref paths 'task-id))
         (worktree (.ref paths 'worktree))
         (task-path (.ref paths 'task-org-path))
         (ts (if (and (string? timestamp) (> (string-length timestamp) 0))
               timestamp
               "2026-11-24 Tue 00:00"))
         (next-task-org (add-archive-tag-to-first-headline org-source-text ts))
         (next-index-org (upsert-index-entry index-source-text
                                             task-id
                                             (.ref dag-proj 'root-id)
                                             (.ref dag-proj 'root-title)
                                             worktree
                                             task-path
                                             'done
                                             (.ref dag-proj 'checklist-done)
                                             (.ref dag-proj 'checklist-total)
                                             #t
                                             ts))
         (receipt-digest (canonical-sha256
                          (list 'agentic-ai-lab.durable.archive-receipt.v1
                                task-id ts next-task-org next-index-org))))
    ;; Verify both resulting Org documents parse cleanly via orgize.
    (org-source-element-graph next-task-org)
    (org-source-element-graph next-index-org)
    (.o bind-these: #f
        kind: 'agentic-ai-lab.durable.archive-transition.v1
        task-id: task-id
        timestamp: ts
        next-task-org: next-task-org
        next-index-org: next-index-org
        receipt: (.o bind-these: #f
                     kind: 'agentic-ai-lab.durable.archive-receipt.v1
                     task-id: task-id
                     timestamp: ts
                     digest: receipt-digest))))

(def (default-project-workbench-tabs owner task-records journal-state peek-set focused-task-id)
  (let* ((policy (opt-ref owner 'policy DurableTaskPolicy.))
         (focused-policy (opt-ref policy 'focused-tab-archive 'on-blur))
         (peek-list (if (list? peek-set) peek-set '()))
         (pinned (list (.o id: 'index
                           label: "Index"
                           kind: 'index
                           closable?: #f
                           mode: 'pinned)))
         (dynamic-rev '())
         (archived-rev '()))
    (for-each
     (lambda (rec)
       (let* ((tid (.ref rec 'task-id))
              (title (opt-ref rec 'title tid))
              (status (opt-ref rec 'status 'todo))
              (archived? (opt-ref rec 'archived? #f))
              (done-c (opt-ref rec 'checklist-done 0))
              (total-c (opt-ref rec 'checklist-total 0))
              (worktree (opt-ref rec 'worktree (opt-ref owner 'worktree "main")))
              (focused? (and focused-task-id (equal? tid focused-task-id)))
              (peeked? (and (member tid peek-list) #t)))
         (when archived?
           (set! archived-rev
                 (cons (.o bind-these: #f
                           task-id: tid
                           title: title
                           status: status
                           worktree: worktree
                           checklist-done: done-c
                           checklist-total: total-c
                           archived?: #t)
                       archived-rev)))
         (cond
          ((not archived?)
           (set! dynamic-rev
                 (cons (.o bind-these: #f
                           id: tid
                           label: title
                           kind: 'task
                           closable?: #t
                           status: status
                           worktree: worktree
                           checklist-done: done-c
                           checklist-total: total-c
                           archived?: #f
                           mode: 'active)
                       dynamic-rev)))
          ((and archived? peeked?)
           (set! dynamic-rev
                 (cons (.o bind-these: #f
                           id: tid
                           label: title
                           kind: 'task
                           closable?: #t
                           status: status
                           worktree: worktree
                           checklist-done: done-c
                           checklist-total: total-c
                           archived?: #t
                           mode: 'peek-readonly)
                       dynamic-rev)))
          ((and archived? focused? (eq? focused-policy 'on-blur))
           (set! dynamic-rev
                 (cons (.o bind-these: #f
                           id: tid
                           label: title
                           kind: 'task
                           closable?: #t
                           status: status
                           worktree: worktree
                           checklist-done: done-c
                           checklist-total: total-c
                           archived?: #t
                           mode: 'archived-pending-blur)
                       dynamic-rev)))
          (else (void)))))
     task-records)
    (let ((dyn (reverse dynamic-rev))
          (arch (reverse archived-rev)))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.workbench-tab-projection.v1
          pinned-tabs: pinned
          dynamic-tabs: dyn
          archived-index: arch
          visible-tab-ids: (cons 'index (map (lambda (t) (.ref t 'id)) dyn))))))

;;; ---------------------------------------------------------------------------
;;; 5. C4 Linearized POO Prototype Hierarchy (Repo A -> Worktree B -> Task C -> SubTask D)
;;; ---------------------------------------------------------------------------

(.def DurableTaskPolicy.
  kind: 'agentic-ai-lab.durable.task-policy.v1
  split-line-watermark: 800
  default-focus-depth: 2
  require-sod-reviewer: #f
  fold-thinking-by-default: #t
  allow-agent-drill-down: #t
  focused-tab-archive: 'on-blur
  scratch-promotion: 'on-plan
  reopen-mode: 'peek-until-edit
  max-concurrency: 4)

(def RepoNode.
  (.o (:: self)
      kind: 'agentic-ai-lab.durable.repo-node.v1
      repo-id: "repo-default"
      topology-path: "topology.org"
      index-path: "index.org"
      org-graph: #f
      features: '(+plan-a-index +funflow-dag +cas-resume +durable-agenda
                  +auto-archive +progressive-l0-l3 +two-stage-repair +worktrunk)
      policy: DurableTaskPolicy.
      strategy: DurableGovernedStrategy.
      .effective-rules: (lambda (org-source-text)
                          (default-effective-rules self org-source-text))
      .project-workbench-tabs: (lambda (task-records journal-state peek-set focused-task-id)
                                 (default-project-workbench-tabs self task-records journal-state
                                                                 peek-set focused-task-id))))

(def WorktreeNode.
  (.o worktree: "main"
      branch: "main"
      source-cut: "HEAD"
      grant-scope: 'worktree-local))

(def TaskNode.
  (.o (:: self)
      task-id: "task-default"
      org-path: #f
      scope-root-id: #f
      context-scope: #f
      restriction-envelope: #f
      trust-tier: 'verified
      .artifact-path: (default-task-artifact-path self)
      .funflow-dag: (lambda (org-source-text)
                      (default-task-funflow-dag self org-source-text))
      .orchestration-plan: (lambda (org-source-text journal-state)
                             (default-task-orchestration-plan self org-source-text journal-state))
      .archive-transition: (lambda (org-source-text index-source-text timestamp)
                             (default-task-archive-transition self org-source-text index-source-text timestamp))))

(def SubTaskNode.
  (.o (:: @ TaskNode.)
      node-id: #f
      needs: '()
      after-start: #f
      model-tier: 'builder
      disclosure-depth: 2))

;;; ---------------------------------------------------------------------------
;;; 6. Durable Journal-Backed Runtime Operations
;;; ---------------------------------------------------------------------------

(def (cas-journal-key task-id node-id)
  (string-append "orchestrator:cas:" task-id ":"
                 (if (symbol? node-id) (symbol->string node-id) node-id)))

(def (archive-journal-key task-id)
  (string-append "orchestrator:archive:" task-id))

(def (reopen-journal-key task-id)
  (string-append "orchestrator:reopen:" task-id))

(def (journal-put-fenced! journal tx-id key value)
  (if (journal-active? journal)
    (journal-put! journal key value)
    (begin
      (journal-receive! journal tx-id value)
      (journal-begin! journal tx-id)
      (with-catch
        (lambda (err) (journal-abort! journal) (raise err))
        (lambda ()
          (journal-put! journal key value)
          (journal-commit! journal))))))

(def (durable-orchestrator-record-cas! journal task-id node-id fingerprint result-digest)
  (let* ((key (cas-journal-key task-id node-id))
         (tx-id (string-append key ":" fingerprint))
         (entry (.o bind-these: #f
                    kind: 'agentic-ai-lab.durable.cas-entry.v1
                    task-id: task-id
                    node-id: (if (symbol? node-id) node-id (string->symbol node-id))
                    fingerprint: fingerprint
                    result-digest: result-digest)))
    (journal-put-fenced! journal tx-id key entry)
    entry))

(def (durable-orchestrator-completed-cas journal task-id dag)
  (let ((table (make-hash-table-eq)))
    (for-each
     (lambda (node-id)
       (let ((saved (journal-get journal (cas-journal-key task-id node-id))))
         (when (and (object? saved) (.slot? saved 'fingerprint))
           (hash-put! table node-id (.ref saved 'fingerprint)))))
     (.ref dag 'node-ids))
    table))

(def (durable-orchestrator-commit-archive! journal task org-source-text index-source-text
                                           journal-state timestamp)
  (let* ((plan (task-orchestration-plan task org-source-text journal-state))
         (task-id (.ref plan 'task-id)))
    (if (not (.ref plan 'ready-to-auto-archive?))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.archive-commit-result.v1
          committed?: #f
          reason: 'archive-guard-not-satisfied
          task-id: task-id
          plan: plan)
      (let* ((trans (task-archive-transition task org-source-text index-source-text timestamp))
             (receipt (.ref trans 'receipt))
             (key (archive-journal-key task-id))
             (tx-id (string-append key ":" (.ref receipt 'digest))))
        (journal-put-fenced! journal tx-id key receipt)
        (.o bind-these: #f
            kind: 'agentic-ai-lab.durable.archive-commit-result.v1
            committed?: #t
            task-id: task-id
            next-task-org: (.ref trans 'next-task-org)
            next-index-org: (.ref trans 'next-index-org)
            receipt: receipt
            plan: plan)))))

(def (durable-orchestrator-reopen! journal task org-source-text index-source-text timestamp)
  (let* ((paths (task-artifact-path task))
         (task-id (.ref paths 'task-id))
         (worktree (.ref paths 'worktree))
         (task-path (.ref paths 'task-org-path))
         (unarchived (remove-archive-tag-and-closed org-source-text))
         (dag-before (task-funflow-dag task unarchived))
         (root-id (.ref dag-before 'root-id))
         (reopened-res
          (agentic-ai-lab-ai-agentic-context-headline-set-todo unarchived root-id "TODO"))
         (next-task-org (if (string? reopened-res) reopened-res (.ref reopened-res 'source)))
         (next-index-org (upsert-index-entry index-source-text
                                             task-id
                                             root-id
                                             (.ref dag-before 'root-title)
                                             worktree
                                             task-path
                                             'todo
                                             (.ref dag-before 'checklist-done)
                                             (.ref dag-before 'checklist-total)
                                             #f
                                             timestamp))
         (receipt (.o bind-these: #f
                      kind: 'agentic-ai-lab.durable.reopen-receipt.v1
                      task-id: task-id
                      timestamp: timestamp
                      digest: (canonical-sha256 (list task-id timestamp next-task-org))))
         (key (reopen-journal-key task-id))
         (tx-id (string-append key ":" (.ref receipt 'digest))))
    (journal-put-fenced! journal tx-id key receipt)
    (.o bind-these: #f
        kind: 'agentic-ai-lab.durable.reopen-result.v1
        reopened?: #t
        task-id: task-id
        next-task-org: next-task-org
        next-index-org: next-index-org
        receipt: receipt)))

(def (durable-orchestrator-recover journal task org-source-text
                                   in-flight-ids: (in-flight-ids '())
                                   unclosed-attempts: (unclosed-attempts '())
                                   governance-context: (governance-context (.o)))
  (let* ((task-id (opt-ref task 'task-id "task"))
         (dag-proj (task-funflow-dag task org-source-text))
         (dag (.ref dag-proj 'dag))
         (completed-cas (durable-orchestrator-completed-cas journal task-id dag))
         (jstate (.o bind-these: #f
                     completed-cas: completed-cas
                     in-flight-ids: in-flight-ids
                     unclosed-attempts: unclosed-attempts
                     recovery-required?: (pair? unclosed-attempts)
                     governance-context: governance-context))
         (plan (task-orchestration-plan task org-source-text jstate)))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.durable.recovery-snapshot.v1
        task-id: task-id
        completed-cas-count: (hash-length completed-cas)
        plan: plan)))

(def DurableOrchestratorExports
  (.o bind-these: #f
      DurableTaskPolicy: DurableTaskPolicy.
      RepoNode: RepoNode.
      WorktreeNode: WorktreeNode.
      TaskNode: TaskNode.
      SubTaskNode: SubTaskNode.
      node-effective-rules: node-effective-rules
      task-artifact-path: task-artifact-path
      task-funflow-dag: task-funflow-dag
      task-orchestration-plan: task-orchestration-plan
      task-archive-transition: task-archive-transition
      project-workbench-tabs: project-workbench-tabs
      record-cas!: durable-orchestrator-record-cas!
      completed-cas: durable-orchestrator-completed-cas
      commit-archive!: durable-orchestrator-commit-archive!
      reopen!: durable-orchestrator-reopen!
      recover: durable-orchestrator-recover))
