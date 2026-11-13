;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Qualification embedding: actual scoped I/O is behind the live Host handed
;;; to a real Session worker. This driver owns no recovery reducer or database.
(import :clan/poo/object :std/encoding/json (only-in :std/text/pregexp pregexp-replace)
  (only-in :std/list/list find)
  (prefix-in :tao3k/agentic-ai-lab/t/context-query-provider-test query.)
  (only-in :tao3k/agentic-ai-lab/t/context-query-durable-test retain-originals!)
  :tao3k/agentic-ai-lab/modules/ai-agentic-context/durable-owner
  :tao3k/agentic-ai-lab/modules/ai-agentic-context/session-host
  :tao3k/agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
  :tao3k/agentic-ai-lab/modules/temporal-causality/runtime/policy-clock)
(def (ensure x message) (unless x (error message)))
(def (text path) (call-with-input-file path (lambda (p) (read-line p #f))))
(def (write-text path bytes) (call-with-output-file path (lambda (p) (display bytes p) (force-output p))))
(def (json-value v)
  (cond ((object? v) (let (h (make-hash-table))
           (for-each (lambda (e) (hash-put! h (symbol->string (car e)) (json-value (cdr e)))) (.alist/sort v)) h))
        ((symbol? v) (symbol->string v))
        ((list? v) (list->vector (map json-value v)))
        (else v)))
(def args (cddr (command-line)))
(def db (car args)) (def root (cadr args)) (def mode (caddr args))
(def phase (list-ref args 3))
(def journal #f) (def adapter #f) (def restored? #f)
(def target (string-append root "/notes.txt"))
(def calls (string-append db ".calls"))
(def status-file (string-append db ".status.json"))
(def source
  (pregexp-replace "\\* TODO Reassessment"
    (text "modules/ai-agentic-context/org-contract/templates/evidence-source.org")
    (string-append "The declared single-file workspace Host may append Added line. to notes.txt, preserving First line., in " root
      ". Retain writer reconciliation, whole-change and independent acceptance obligations.\n\n* TODO Reassessment")))
(def original #f)
(def clock
  (policy-clock-owner
    (lambda ()
      (set! journal (journal-open db))
      (retain-originals! journal db)
      (set! restored? (if (journal-get journal "context") #t #f))
      (let-values (((f host-value provider workers-value) (query.fixture #t source)))
        (set! adapter (context-durable-adapter journal host-value (.ref f 'grants) (.ref f 'policies)
          (lambda (registration) (.ref f 'proof)) provider))
        (values (.o host: host-value workers: workers-value authority: f) (.ref f 'policies) adapter)))
    "txn" 1 1. 0. 1 #t #f))
(def (owner f) (policy-clock-call! clock f))
(def (command id operation-value body-value action)
  (policy-clock-command! clock
    (.o kind: 'context.durable-command.v1 identity: id operation: operation-value body: body-value) action))
(def (live-cap attempt)
  (.o workspace: root path: "notes.txt" scope-digest: (.ref (.ref attempt 'input) 'scope-digest)
    .read!: (lambda (self)
      ;; This provider is confined to an isolated lab directory after its old
      ;; process group was reaped. Other providers need their own read contract.
      (let* ((first (text target)) (second (text target)))
        (.o bytes: first coherent?: (equal? first second))))
    .apply!: (lambda (self intent)
      ;; The private lab directory is the admitted filesystem Host scope.
      ;; This counter records invocation, including any mistaken replay.
      (call-with-output-file (list path: calls append: #t)
        (lambda (p) (display (.ref intent 'identity) p) (newline p) (force-output p)))
      (let* ((effect (.ref (.ref intent 'body) 'effect)) (before (text target)))
        (ensure (equal? before (.ref effect 'before)) "Actual workspace preimage mismatch")
        (write-text target (.ref effect 'desired))
        (let (after (text target))
          (ensure (equal? after (.ref effect 'desired)) "Actual workspace readback mismatch")
          (journal-pack (.o kind: 'context.workspace-write-observation.v1
            command: (.ref intent 'identity) workspace: root path: "notes.txt"
            before-digest: (journal-hash before) after-digest: (journal-hash after))))))))
(def (snapshot!)
  (let (value (owner (lambda (resource)
    (let* ((h (.ref resource 'host)) (state-value (.call adapter .workspace-state adapter "workspace-edit"))
           (row (query.row h "a")))
      (unless (.ref state-value 'execution-receipt)
        (ensure (eq? (.ref (.ref row 'schedule) 'status) 'recovering) "Old Attempt was silently resumed")
        (ensure (= 1 (length (.ref (.ref row 'schedule) 'obligations))) "Original Attempt obligation was lost or duplicated")
        (ensure (null? (query.outcomes h "a")) "Recovery fabricated a Session terminal")
        (ensure (member '("workspace-edit" historical-effect) (.ref (.ref state-value 'assessment) 'unknown))
                "Matching content erased historical uncertainty")
        (ensure (member '("workspace-edit" task-acceptance) (.ref (.ref state-value 'assessment) 'obligations))
                "Recovery completed the Task without independent acceptance"))
      (journal-unpack (journal-pack (.o state: state-value owner-epoch: (journal-epoch journal) schedule: (.ref row 'schedule)
        terminals: (query.outcomes h "a") handoff-input-status: (.ref (journal-input journal "workspace-edit") 'status))))))))
    (call-with-output-file status-file (lambda (p) (write-json p (json-value value))))
    (displayln "WORKSPACE-STATE " status-file) (force-output)))
(cond
 ((equal? mode "pre")
  (ensure (not restored?) "Pre mode requires a fresh isolated journal")
  (let* ((attempt (owner (lambda (r) (.ref (.ref (query.row (.ref r 'host) "a") 'schedule) 'active))))
         (cap (live-cap attempt))
         (intent (context-durable-workspace-command "workspace-edit" attempt
           (.o workspace: root path: "notes.txt" before: "First line.\n" desired: "First line.\nAdded line.\n"
             requirements: '(writer-reconciliation whole-change task-acceptance)))))
    (let (worker (thread-start! (make-thread
      (lambda () (let (message (thread-receive)) (.call cap .apply! cap message))))))
      (policy-clock-command! clock intent (lambda (r)
        (let* ((h (.ref r 'host))
               (token (agentic-ai-lab-ai-agentic-context-session-host-attach-worker! h (query.sid "a") (query.revision h "a") 1 worker)))
          (hash-put! (.ref r 'workers) "a" (vector worker token #f)))
        (let (decision (.call adapter .workspace-prepare! adapter intent cap))
          (ensure (.ref decision 'accepted?) "First handoff was refused")
          (set! original (.ref decision 'intent)))))
      ;; The normal owner command ACK commits the handoff decision only. Its
      ;; action-authorized? flag remains false; only this newly issued live
      ;; dispatch value can be sent to the separately scoped Host worker.
      (ensure original "No fresh workspace handoff was issued")
      (thread-send worker original)
      (let (observation (owner (lambda (r) (query.joined (.ref r 'host) (.ref r 'workers) "a"))))
        (owner (lambda (r)
          (journal-cut! journal (lambda (cut id)
            (when (and (equal? id "workspace-result") (eq? cut (string->symbol phase)))
              (ensure (= 1 (length (query.outcomes (.ref r 'host) "a"))) "No actual provisional worker terminal")
              (displayln "WORKSPACE-HELD " phase " worker-terminal=1") (force-output) (read-line))))))
        (command "workspace-result" 'workspace-result (.o effect: "workspace-edit")
          (lambda (r) (.call adapter .workspace-complete! adapter
            (.o kind: 'context.durable-command.v1 identity: "workspace-result" operation: 'workspace-result
                body: (.o effect: "workspace-edit")) observation))))))
  (error "Workspace crash hook did not hold"))
 ((equal? mode "recover")
  (ensure restored? "Recovery must restore the original runtime checkpoint")
  (snapshot!)
  (displayln "WORKSPACE-READY") (force-output)
  (let loop ((counter 0))
    ;; This is a qualification REPL over independently callable existing owner
    ;; operations, not a prescribed recovery workflow or a Task DSL.
    (let (request (read))
      (unless (or (eof-object? request) (eq? request 'quit))
        (let ((op (if (pair? request) (car request) request))
              (id (string-append "model:" (number->string (owner (lambda (r) (journal-epoch journal)))) ":" (number->string counter))))
          (case op
            ((inspect) (void))
            ((observe)
              (let* ((saved (owner (lambda (r) (.call adapter .workspace-state adapter "workspace-edit"))))
                     (cap (live-cap (.ref (.ref (.ref saved 'intent) 'body) 'attempt)))
                     (intent (.o kind: 'context.durable-command.v1 identity: id operation: 'workspace-observe body: (.o effect: "workspace-edit"))))
                (policy-clock-command! clock intent (lambda (r) (.call adapter .workspace-observe! adapter intent cap)))))
            ((propose)
              (let* ((data (call-with-input-file (cadr request) read-json))
                     (proposal-value (.o identity: (hash-ref data "identity") question: (hash-ref data "question")))
                     (intent (.o kind: 'context.durable-command.v1 identity: id operation: 'workspace-propose
                       body: (.o effect: "workspace-edit" proposal: proposal-value))))
                (policy-clock-command! clock intent (lambda (r) (.call adapter .workspace-propose! adapter intent)))))
            ((replay)
              (let* ((saved (owner (lambda (r) (.call adapter .workspace-state adapter "workspace-edit"))))
                     (intent (.ref saved 'intent))
                     (ack (policy-clock-command! clock intent
                       (lambda (r) (error "A historical handoff must not re-enter its effect callback")))))
                (ensure (and (.ref ack 'historical?) (not (.ref ack 'action-authorized?)))
                        "Historical handoff ACK became execution authority")
                (displayln "WORKSPACE-REPLAY-REFUSED historical-handoff-ack=#t action-authorized=#f")))
            (else (error "Unknown qualification operation" op)))
          (snapshot!)
          (displayln "WORKSPACE-READY") (force-output)
          (loop (+ counter 1))))))
  (policy-clock-stop! clock)
  (displayln "WORKSPACE-OK"))
 (else (error "Unknown workspace qualification mode" mode)))
