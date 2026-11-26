;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Unified Pure Scheme High-Order Execution Driver
;;; (`modules/graph-engine/unified-effect-driver.ss`).
;;;
;;; Uses idiomatic `gerbil-poo` prototypes, constant slot capture `(slot)` /
;;; `(slot := expr)`, and standard functional combinators (Style 02/03).

(import (only-in :clan/poo/object .def .o .ref .slot? object?)
        (only-in :std/list/list filter find)
        "obligation-graph.ss"
        "ascent-reconciler.ss"
        "dag-frontier-scheduler.ss"
        "task-actor.ss"
        "atomic-effect-orchestrator.ss")

(export UnifiedDriverState.
        UnifiedDriverStepResult.
        UnifiedDriverRunTrace.
        make-unified-driver-state
        drive-graph-actor-step
        run-unified-driver-to-quiescence
        project-driver-state->workbench-projection)

(def (opt-ref obj key default)
  (if (and (object? obj) (.slot? obj key)) (.ref obj key) default))

(def (strip-prefix prefix s)
  (let ((plen (string-length prefix)) (slen (string-length s)))
    (and (>= slen plen) (string-prefix? prefix s) (substring s plen slen))))

(.def UnifiedDriverState.
  kind: 'agentic-ai-lab.graph-engine.unified-driver-state.v1
  authorizes-effect?: #f)

(.def UnifiedDriverStepResult.
  kind: 'agentic-ai-lab.graph-engine.unified-driver-step-result.v1
  authorizes-effect?: #f)

(.def UnifiedDriverRunTrace.
  kind: 'agentic-ai-lab.graph-engine.unified-driver-run-trace.v1
  authorizes-effect?: #f)

(def (make-unified-driver-state
      actor obligation-graph governed-context
      competing-hypotheses: (competing-hypotheses '())
      branch-proposals: (branch-proposals '())
      hypothesis-matrix: (hypothesis-matrix #f)
      completed-step-outputs: (completed-step-outputs '())
      step-count: (step-count 0)
      repair-budget: (repair-budget 3)
      repair-history: (repair-history '()))
  (.o (:: @ UnifiedDriverState.)
      (actor) (obligation-graph) (governed-context)
      (competing-hypotheses) (branch-proposals) (hypothesis-matrix)
      (completed-step-outputs) (step-count)
      (repair-budget := (max 1 repair-budget))
      (repair-history)))

(def (det-task->funflow-step task)
  (let* ((tid (.ref task 'task-id))
         (purity (if (eq? (opt-ref task 'effect-class 'pure-cas) 'fenced-effect)
                   'sandboxed-effect 'pure-cas)))
    (make-funflow-step-spec
     tid purity: purity
     input-digest: (string-append "det-input:" tid)
     program: (and (eq? purity 'sandboxed-effect) (opt-ref task 'program "verify-step"))
     args: (opt-ref task 'args '())
     mutates-trunk?: (pair? (opt-ref task 'write-footprint '())))))

(def (collect-plan-effects plans)
  (foldl (lambda (p acc) (append acc (.ref p 'effects))) '() plans))

(def (repair-history-lookup history tid)
  (let ((entry (assoc tid history)))
    (if entry (cdr entry) (cons 0 '()))))

(def (repair-history-put history tid attempts visited)
  (cons (cons tid (cons attempts visited))
        (filter (lambda (e) (not (equal? (car e) tid))) history)))

(def (total-repair-attempts history)
  (foldl (lambda (h acc) (+ acc (cadr h))) 0 history))

(def (count-active-defeaters graph)
  (foldl (lambda (o acc) (+ acc (length (.ref o 'active-defeaters))))
         0 (.ref graph 'obligations)))

(def (ingest-deterministic-receipts graph actor ctx receipts prev-outputs repair-budget prev-repair-history)
  (let ((det-tasks (.ref graph 'det-tasks))
        (cut (.ref graph 'cut))
        (kv-digest (opt-ref ctx 'kv-prefix-digest "sha256:unbound"))
        (has-defeater? (opt-ref ctx 'has-active-defeater? #f))
        (disc-depth (opt-ref ctx 'disclosure-depth 'L1)))
    (let loop ((rs receipts) (g graph) (outs prev-outputs)
               (cas-hits 0) (cas-puts 0) (followups '())
               (rhist prev-repair-history) (halt-reason #f) (halt-task #f))
      (if (null? rs)
        (values g outs cas-hits cas-puts (reverse followups) rhist halt-reason halt-task)
        (let* ((r (car rs))
               (rk (and (object? r) (opt-ref r 'kind #f)))
               (eid (and (object? r) (opt-ref r 'effect-id ""))))
          (cond
           ((and (eq? rk 'cas-miss) (strip-prefix "cas-get:" eid))
            => (lambda (tid)
                 (let ((task (find (lambda (t) (equal? (.ref t 'task-id) tid)) det-tasks)))
                   (if task
                     (let* ((step (det-task->funflow-step task))
                            (prompt (make-two-zone-prompt-spec
                                     (string-append "ZONE1::" kv-digest) kv-digest
                                     (string-append "Execute deterministic step: " tid)
                                     disclosure-depth: (if has-defeater? 'L3 disc-depth)))
                            (rec (reconcile-funflow-step-receipts
                                  step actor ctx (list r) two-zone-prompt: prompt))
                            (next-effs (opt-ref rec 'next-effects '())))
                       (loop (cdr rs) g outs cas-hits cas-puts
                             (append (reverse next-effs) followups) rhist halt-reason halt-task))
                     (loop (cdr rs) g outs cas-hits cas-puts followups rhist halt-reason halt-task)))))

           ((and (eq? rk 'llm-completed) (strip-prefix "llm:" eid))
            => (lambda (tid)
                 (let ((task (find (lambda (t) (equal? (.ref t 'task-id) tid)) det-tasks)))
                   (if task
                     (let* ((step (det-task->funflow-step task))
                            (put-effs (opt-ref (reconcile-funflow-step-receipts step actor ctx (list r))
                                               'next-effects '()))
                            (payload (opt-ref r 'content ""))
                            (pdig (obligation-graph-premise-digest
                                   g (.ref task 'obligation-id) (.ref task 'premise-ids)))
                            (ev (make-evidence-fact (.ref task 'produces-evidence-id) payload
                                                    cut: cut premise-ids: (.ref task 'premise-ids)))
                            (g2 (obligation-graph-mark-task-completed
                                 (obligation-graph-with-evidence g ev) tid pdig)))
                       (loop (cdr rs) g2 (append outs (list (cons tid payload)))
                             cas-hits (+ cas-puts (length put-effs))
                             (append (reverse put-effs) followups) rhist halt-reason halt-task))
                     (loop (cdr rs) g outs cas-hits cas-puts followups rhist halt-reason halt-task)))))

           ((and (eq? rk 'sandbox-exited) (not (= (opt-ref r 'exit-code 1) 0)) (strip-prefix "sandbox:" eid))
            => (lambda (tid)
                 (let* ((task (find (lambda (t) (equal? (.ref t 'task-id) tid)) det-tasks))
                        (fail-sig (string-append tid ":exit=" (number->string (opt-ref r 'exit-code 1))
                                                 ":" (opt-ref r 'stderr "")))
                        (prev (repair-history-lookup rhist tid))
                        (next-attempts (+ (car prev) 1))
                        (visited (cdr prev))
                        (oscillating? (and (member fail-sig visited) #t))
                        (exhausted? (>= next-attempts repair-budget))
                        (next-rhist (repair-history-put rhist tid next-attempts (cons fail-sig visited))))
                   (cond
                    ((not task)
                     (loop (cdr rs) g outs cas-hits cas-puts followups next-rhist halt-reason halt-task))
                    ((or oscillating? exhausted?)
                     (let* ((why (if oscillating? 'cycle-oscillation-detected 'cycle-budget-exhausted))
                            (g1 (obligation-graph-add-human-inbox
                                 g (.o (kind := why) (task-id := tid)
                                       (detail := fail-sig) (attempts := next-attempts)))))
                       (loop (cdr rs) g1 outs cas-hits cas-puts followups next-rhist why tid)))
                    (else
                     (let* ((plan (plan-funflow-step-effects (det-task->funflow-step task) actor ctx))
                            (retry-effs (if (.ref plan 'admitted?) (.ref plan 'effects) '())))
                       (loop (cdr rs) g outs cas-hits cas-puts
                             (append (reverse retry-effs) followups) next-rhist halt-reason halt-task)))))))

           ((or (and (eq? rk 'cas-hit) (strip-prefix "cas-get:" eid))
                (and (eq? rk 'sandbox-exited) (= (opt-ref r 'exit-code 1) 0) (strip-prefix "sandbox:" eid)))
            => (lambda (tid)
                 (let ((task (find (lambda (t) (equal? (.ref t 'task-id) tid)) det-tasks)))
                   (if task
                     (let* ((pdig (obligation-graph-premise-digest
                                   g (.ref task 'obligation-id) (.ref task 'premise-ids)))
                            (payload (if (eq? rk 'cas-hit) (opt-ref r 'payload "") (opt-ref r 'stdout "")))
                            (ev (make-evidence-fact (.ref task 'produces-evidence-id) payload
                                                    cut: cut premise-ids: (.ref task 'premise-ids)))
                            (g2 (obligation-graph-mark-task-completed
                                 (obligation-graph-with-evidence g ev) tid pdig)))
                       (loop (cdr rs) g2 (append outs (list (cons tid payload)))
                             (if (eq? rk 'cas-hit) (+ cas-hits 1) cas-hits)
                             cas-puts followups rhist halt-reason halt-task))
                     (loop (cdr rs) g outs cas-hits cas-puts followups rhist halt-reason halt-task)))))

           (else
            (loop (cdr rs) g outs cas-hits cas-puts followups rhist halt-reason halt-task))))))))

(def (drive-graph-actor-step state (receipts '()))
  (let*-values
      (((raw-actor) (.ref state 'actor))
       ((raw-graph) (.ref state 'obligation-graph))
       ((ctx) (.ref state 'governed-context))
       ((hyps) (.ref state 'competing-hypotheses))
       ((branches) (.ref state 'branch-proposals))
       ((prev-matrix) (opt-ref state 'hypothesis-matrix #f))
       ((prev-outputs) (opt-ref state 'completed-step-outputs '()))
       ((next-count) (+ (opt-ref state 'step-count 0) 1))
       ((repair-budget) (opt-ref state 'repair-budget 3))
       ((prev-rhist) (opt-ref state 'repair-history '()))
       ((graph1 next-outputs cas-hits cas-puts followup-effs next-rhist cycle-halt halt-tid)
        (ingest-deterministic-receipts
         raw-graph raw-actor ctx receipts prev-outputs repair-budget prev-rhist))
       ((actor)
        (if (and cycle-halt (eq? (opt-ref raw-actor 'detour-mode 'mainline) 'mainline))
          (.ref (enter-task-actor-detour
                 raw-actor 'blocker-active
                 (string-append "blk-" (symbol->string cycle-halt) ":" (or halt-tid "step")))
                'actor)
          raw-actor))
       ((detour-mode) (opt-ref actor 'detour-mode 'mainline))
       ((hyp-receipts)
        (filter (lambda (r) (and (object? r) (string-prefix? "hyp:" (opt-ref r 'effect-id ""))))
                receipts))
       ((matrix)
        (if (and (pair? hyp-receipts) (pair? hyps) (pair? branches))
          (reconcile-competing-hypothesis-matrix hyps branches hyp-receipts)
          prev-matrix))
       ((graph)
        (if (and (pair? hyp-receipts) matrix)
          (obligation-graph-record-branch-matrix graph1 matrix)
          graph1))
       ((ascent) (ascent-reconcile-frontier graph))
       ((frontier-mode) (.ref ascent 'frontier-mode))
       ((ready-det) (.ref ascent 'ready-deterministic-tasks))
       ((epistemic-status) (.ref ascent 'epistemic-competition-status))
       ((followup-llm-count)
        (length (filter (lambda (e) (eq? (.ref e 'kind) 'llm-complete)) followup-effs)))
       ((next-state)
        (make-unified-driver-state
         actor graph ctx
         competing-hypotheses: hyps branch-proposals: branches hypothesis-matrix: matrix
         completed-step-outputs: next-outputs step-count: next-count
         repair-budget: repair-budget repair-history: next-rhist)))
    (def (step-result phase effs llm-count
                      blocked-reasons: (blocked-reasons '())
                      c4-plan: (c4-plan #f)
                      mat: (mat matrix))
      (.o (:: @ UnifiedDriverStepResult.)
          (phase) (blocked-reasons)
          (llm-calls-emitted := llm-count)
          (cas-hits-observed := cas-hits)
          (cas-puts-emitted := cas-puts)
          (c4-frontier-plan := c4-plan)
          (effects := effs)
          (ascent-frontier := ascent)
          (hypothesis-matrix := mat)
          (state := next-state)))
    (cond
     (cycle-halt
      (step-result 'cycle-repair-halted-blocker '() 0 blocked-reasons: (list cycle-halt)))
     ((pair? followup-effs)
      (step-result (cond ((> followup-llm-count 0) 'funflow-cas-miss-llm-fill)
                         ((> cas-puts 0) 'funflow-cas-store-commit)
                         (else 'bounded-repair-cycle-retry))
                   followup-effs followup-llm-count))
     ((eq? frontier-mode 'blocked-on-governance)
      (step-result 'blocked-on-governance '() 0))
     ((pair? ready-det)
      (let* ((c4-plan (plan-funflow-c4-frontier graph ready-det))
             (wave-tasks (if (.ref c4-plan 'valid?) (.ref c4-plan 'parallel-batch) '()))
             (plans (map (lambda (t) (plan-funflow-step-effects (det-task->funflow-step t) actor ctx))
                         wave-tasks))
             (blocked-plans (filter (lambda (p) (not (.ref p 'admitted?))) plans))
             (admitted-effects (collect-plan-effects (filter (lambda (p) (.ref p 'admitted?)) plans))))
        (step-result (if (and (null? admitted-effects) (pair? blocked-plans))
                       'blocked-by-detour-or-policy 'deterministic-funflow-wave)
                     admitted-effects 0
                     c4-plan: c4-plan
                     blocked-reasons: (map (lambda (p) (.ref p 'reason)) blocked-plans))))
     ((and (not matrix) (pair? hyps) (pair? branches)
           (or (eq? epistemic-status 'open-competition) (> (length hyps) 1)))
      (let ((effs (.ref (plan-competing-hypothesis-frontier actor hyps branches ctx) 'effects)))
        (step-result 'evaluating-competing-hypotheses effs (length effs) mat: #f)))
     ((eq? detour-mode 'blocker-active)
      (step-result 'blocker-detour-halting-settlement '() 0))
     (else
      (step-result 'quiescent-fixed-point '() 0)))))

(def (run-unified-driver-to-quiescence initial-state effect-interpreter max-rounds: (max-rounds 8))
  (let loop ((st initial-state) (incoming '()) (round 1)
             (total-llm 0) (total-hits 0) (total-puts 0) (trace '()))
    (let* ((step (drive-graph-actor-step st incoming))
           (phase (.ref step 'phase))
           (effs (.ref step 'effects))
           (llm-n (+ total-llm (.ref step 'llm-calls-emitted)))
           (cas-n (+ total-hits (opt-ref step 'cas-hits-observed 0)))
           (put-n (+ total-puts (opt-ref step 'cas-puts-emitted 0)))
           (entry (.o (round) (phase)
                      (effects-count := (length effs))
                      (llm-calls-emitted := (.ref step 'llm-calls-emitted))
                      (cas-hits-observed := (opt-ref step 'cas-hits-observed 0))
                      (cas-puts-emitted := (opt-ref step 'cas-puts-emitted 0))))
           (next-trace (append trace (list entry))))
      (if (or (null? effs) (>= round max-rounds))
        (.o (:: @ UnifiedDriverRunTrace.)
            (final-phase := phase)
            (final-state := (.ref step 'state))
            (final-step := step)
            (rounds-executed := round)
            (total-llm-calls := llm-n)
            (cas-hits-count := cas-n)
            (cas-puts-count := put-n)
            (trace := next-trace))
        (loop (.ref step 'state) (effect-interpreter effs) (+ round 1) llm-n cas-n put-n next-trace)))))

(def (enrich-hypothesis-for-workbench hyp matrix)
  (let* ((hid (.ref hyp 'hypothesis-id))
         (cells (if (object? matrix)
                  (filter (lambda (c) (equal? (.ref c 'hypothesis-id) hid)) (.ref matrix 'cells))
                  '())))
    (.o (hypothesis-id := hid)
        (claim := (.ref hyp 'claim))
        (contradictions := (.ref hyp 'contradictions))
        (open-questions := (.ref hyp 'open-questions))
        (observed-branches := (length (filter (lambda (c) (opt-ref c 'observed? #f)) cells)))
        (total-branches := (length cells))
        (authorizes-effect? := #f))))

(def (project-driver-state->workbench-projection driver-obj archived-actors: (archived-actors '()))
  (let* ((step (case (and (object? driver-obj) (opt-ref driver-obj 'kind #f))
                 ((agentic-ai-lab.graph-engine.unified-driver-run-trace.v1) (.ref driver-obj 'final-step))
                 ((agentic-ai-lab.graph-engine.unified-driver-step-result.v1) driver-obj)
                 (else (drive-graph-actor-step driver-obj))))
         (st (.ref step 'state))
         (actor (.ref st 'actor))
         (graph (.ref st 'obligation-graph))
         (ascent (.ref step 'ascent-frontier))
         (matrix (.ref step 'hypothesis-matrix))
         (tid (.ref actor 'task-id))
         (tab (.o (id := tid)
                  (label := (opt-ref actor 'title tid))
                  (status := (opt-ref actor 'status 'in-progress))
                  (mode := 'active)
                  (detour-mode := (opt-ref actor 'detour-mode 'mainline))
                  (detour-node-id := (opt-ref actor 'detour-node-id #f))
                  (driver-phase := (.ref step 'phase))
                  (pending-effects-count := (length (.ref step 'effects)))
                  (worktree := (opt-ref actor 'worktree "main"))
                  (checklist-done := (length (.ref ascent 'discharged-obligations)))
                  (checklist-total := (length (.ref graph 'obligations)))
                  (competing-hypotheses :=
                   (map (lambda (h) (enrich-hypothesis-for-workbench h matrix))
                        (.ref st 'competing-hypotheses)))
                  (human-inbox := (opt-ref graph 'human-inbox '()))
                  (active-defeaters-count := (count-active-defeaters graph))
                  (repair-attempts := (total-repair-attempts (opt-ref st 'repair-history '())))
                  (repair-budget := (opt-ref st 'repair-budget 3))))
         (archived (map (lambda (a)
                          (.o (task-id := (.ref a 'task-id))
                              (title := (opt-ref a 'title (.ref a 'task-id)))
                              (worktree := (opt-ref a 'worktree "main"))))
                        archived-actors)))
    (.o (pinned-tab := 'index)
        (dynamic-tabs := (list tab))
        (archived-index := archived)
        (visible-tab-ids := (list 'index tid)))))
