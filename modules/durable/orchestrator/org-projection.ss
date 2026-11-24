;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Pure Org-Elements, Plan-A index.org, FunFlow DAG projection, and
;;; Task-as-Tab workbench projection engine for the Durable Orchestrator.

(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :std/list/list every filter find)
        (only-in :std/string/misc string-trim string-prefix? string-contains string-split)
        (only-in :orgize/languages/org/modules/org-elements/values
                 org-element-graph-records)
        (only-in :orgize/languages/org/modules/org-elements/query
                 make-org-element-query-context org-element-property)
        (only-in :tao3k/agentic-ai-lab/modules/query/semantic/orgize-source-interface
                 org-source-element-graph)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-org-progressive-rules
                 agentic-ai-lab-ai-agentic-context-parse-rule-overrides)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/durable-dag
                 DurableGovernedStrategy.
                 funflow-dag-node
                 funflow-dag-build)
        "contracts.ss")

(export normalize-todo-symbol
        headline-tags-list
        headline-archived?
        headline-property
        item-checkbox-checked?
        headline-checklists-done?
        count-checklists
        default-effective-rules
        default-task-artifact-path
        default-task-funflow-dag
        add-archive-tag-to-first-headline
        remove-archive-tag-and-closed
        upsert-index-entry
        upsert-property-in-drawer
        default-task-archive-transition
        default-project-workbench-tabs)

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

(def (upsert-property-in-drawer org-text node-id prop-pairs)
  (let* ((needle (string-append ":ID: " node-id))
         (idx (string-find-substr org-text needle)))
    (if (not idx)
      org-text
      (let* ((end-idx (string-find-substr org-text ":END:" idx)))
        (if (not end-idx)
          org-text
          (let* ((head (substring org-text 0 idx))
                 (drawer-body (substring org-text idx end-idx))
                 (tail (substring org-text end-idx (string-length org-text)))
                 (lines (string-split drawer-body #\newline))
                 (keys (map car prop-pairs))
                 (kept
                  (filter
                   (lambda (line)
                     (let ((trimmed (string-trim line)))
                       (not (find (lambda (k)
                                    (string-prefix? (string-append ":" k ":") trimmed))
                                  keys))))
                   lines))
                 (filtered-kept (filter (lambda (l) (> (string-length (string-trim l)) 0)) kept))
                 (added (map (lambda (p) (string-append ":" (car p) ": " (cdr p))) prop-pairs))
                 (new-drawer (string-append (string-join-with (append filtered-kept added) "\n") "\n")))
            (string-append head new-drawer tail)))))))

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
