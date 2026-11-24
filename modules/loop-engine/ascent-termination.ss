;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Slice 56 Runtime Implementation:
;;; Pure functional POO + `gerbil-ascent` Relational Loop Termination &
;;; Anti-Oscillation Governor (`modules/loop-engine/ascent-termination.ss`).
;;;
;;; Replaces imperative while-loop retries with a declarative ASCENT fixed-point
;;; verdict lattice:
;;;   1. `halt-governance-blocked` (absorbing prior halt OR Slice 50-55 / Cedar block)
;;;   2. `halt-converged`          (progress measure == 0 AND journal quiescent)
;;;   3. `halt-cycle-detected`     (ASCENT `exact_state_cycle` OR `oscillation_cycle`)
;;;   4. `halt-stalled-no-progress`(ASCENT `repeated_failure` OR zero-progress streak >= Ks)
;;;   5. `halt-budget-exhausted`   (stepBudgetRemaining == 0 OR tokensRemaining == 0)
;;;   6. `admit-next-step`         (strictly decrements monotonic budget by 1)

(import (only-in :clan/poo/object .def .o .ref .slot? object?)
        (only-in :std/list/list filter)
        (only-in :gerbil-ascent/program/api
                 relational-program relational-admit relational-solve
                 relational-query-name))

(export AscentLoopPolicy.
        make-ascent-loop-policy
        ascent-loop-policy?
        make-loop-turn-fingerprint
        loop-turn-fingerprint?
        loop-progress-measure
        make-ascent-loop-state
        ascent-loop-state?
        ascent-evaluate-loop-termination
        ascent-loop-advance-state
        ascent-loop-reopen-epoch)

(def (opt-ref obj key default)
  (if (and (object? obj) (.slot? obj key))
    (.ref obj key)
    default))

(.def AscentLoopPolicy.
  kind: 'agentic-ai-lab.loop-engine.ascent-loop-policy.v1
  max-steps: 8
  max-tokens: 32000
  max-repeated-failures: 2
  max-stall-turns: 2
  require-human-reopen?: #t)

(def (ascent-loop-policy? v)
  (and (object? v)
       (.slot? v 'kind)
       (eq? (.ref v 'kind) 'agentic-ai-lab.loop-engine.ascent-loop-policy.v1)))

;;; Monotonic policy refinement: when `parent-policy` is supplied, every numeric
;;; budget strictly meets (`min`) with the parent and `require-human-reopen?`
;;; monotonically strengthens (`or`), matching Slice 54 BUG-D1 discipline.
(def (make-ascent-loop-policy
      max-steps: (max-steps 8)
      max-tokens: (max-tokens 32000)
      max-repeated-failures: (max-repeated-failures 2)
      max-stall-turns: (max-stall-turns 2)
      require-human-reopen?: (require-human-reopen? #t)
      parent-policy: (parent-policy #f))
  (let* ((ms (if (ascent-loop-policy? parent-policy)
               (min (max 0 max-steps) (.ref parent-policy 'max-steps))
               (max 0 max-steps)))
         (mt (if (ascent-loop-policy? parent-policy)
               (min (max 0 max-tokens) (.ref parent-policy 'max-tokens))
               (max 0 max-tokens)))
         (mf (if (ascent-loop-policy? parent-policy)
               (min (max 1 max-repeated-failures) (.ref parent-policy 'max-repeated-failures))
               (max 1 max-repeated-failures)))
         (mst (if (ascent-loop-policy? parent-policy)
                (min (max 1 max-stall-turns) (.ref parent-policy 'max-stall-turns))
                (max 1 max-stall-turns)))
         (rhr (if (ascent-loop-policy? parent-policy)
                (or (and require-human-reopen? #t) (.ref parent-policy 'require-human-reopen?))
                (and require-human-reopen? #t))))
    (.o (:: @ AscentLoopPolicy.)
        kind: 'agentic-ai-lab.loop-engine.ascent-loop-policy.v1
        max-steps: ms
        max-tokens: mt
        max-repeated-failures: mf
        max-stall-turns: mst
        require-human-reopen?: rhr)))

(def (make-loop-turn-fingerprint
      turn-id
      state-digest
      action-digest: (action-digest "")
      failure-signature: (failure-signature #f)
      remaining-frontier: (remaining-frontier 0)
      open-invariants: (open-invariants 0)
      open-defeaters: (open-defeaters 0)
      open-blockers: (open-blockers 0)
      tokens-used: (tokens-used 0)
      journal-quiescent?: (journal-quiescent? #t)
      evidence-endorsed?: (evidence-endorsed? #f))
  (.o bind-these: #f
      kind: 'agentic-ai-lab.loop-engine.turn-fingerprint.v1
      turn-id: turn-id
      state-digest: state-digest
      action-digest: action-digest
      failure-signature: failure-signature
      remaining-frontier: (max 0 remaining-frontier)
      open-invariants: (max 0 open-invariants)
      open-defeaters: (max 0 open-defeaters)
      open-blockers: (max 0 open-blockers)
      tokens-used: (max 0 tokens-used)
      journal-quiescent?: (and journal-quiescent? #t)
      evidence-endorsed?: (and evidence-endorsed? #t)))

(def (loop-turn-fingerprint? v)
  (and (object? v)
       (.slot? v 'kind)
       (eq? (.ref v 'kind) 'agentic-ai-lab.loop-engine.turn-fingerprint.v1)))

(def (loop-progress-measure fp)
  (+ (opt-ref fp 'remaining-frontier 0)
     (opt-ref fp 'open-invariants 0)
     (opt-ref fp 'open-defeaters 0)
     (opt-ref fp 'open-blockers 0)))

(def (make-ascent-loop-state
      loop-id
      agent-id: (agent-id "agent:primary")
      epoch: (epoch 1)
      policy: (policy AscentLoopPolicy.)
      history: (history '())
      steps-taken: (steps-taken 0)
      tokens-spent: (tokens-spent 0)
      zero-progress-streak: (zero-progress-streak 0)
      halted?: (halted? #f)
      halt-verdict: (halt-verdict #f)
      halt-reason: (halt-reason #f)
      human-reopen-endorser: (human-reopen-endorser #f)
      audit-capsules: (audit-capsules '()))
  (.o bind-these: #f
      kind: 'agentic-ai-lab.loop-engine.ascent-loop-state.v1
      loop-id: loop-id
      agent-id: agent-id
      epoch: epoch
      policy: policy
      history: history
      steps-taken: steps-taken
      tokens-spent: tokens-spent
      zero-progress-streak: zero-progress-streak
      halted?: (and halted? #t)
      halt-verdict: halt-verdict
      halt-reason: halt-reason
      human-reopen-endorser: human-reopen-endorser
      audit-capsules: audit-capsules))

(def (ascent-loop-state? v)
  (and (object? v)
       (.slot? v 'kind)
       (eq? (.ref v 'kind) 'agentic-ai-lab.loop-engine.ascent-loop-state.v1)))

;;; Intern arbitrary Scheme values (strings/lists/symbols) into compact 1-based
;;; integer IDs for `gerbil-ascent` relational tuples.
(def (intern-id! table counter-box val)
  (let ((existing (hash-get table val)))
    (or existing
        (let ((id (+ 1 (unbox counter-box))))
          (set-box! counter-box id)
          (hash-put! table val id)
          id))))

(def (build-earlier-rows n)
  (let loop-i ((i 0) (acc '()))
    (if (>= i n)
      acc
      (let loop-j ((j (+ i 1)) (acc2 acc))
        (if (>= j n)
          (loop-i (+ i 1) acc2)
          (loop-j (+ j 1) (cons (list i j) acc2)))))))

(def (max-failure-signature-count fps)
  (let ((counts (make-hash-table)))
    (for-each
     (lambda (fp)
       (let ((fsig (opt-ref fp 'failure-signature #f)))
         (when fsig
           (let ((key (list (opt-ref fp 'action-digest "") fsig)))
             (hash-put! counts key (+ 1 (hash-ref counts key 0)))))))
     fps)
    (let loop ((rows (hash->list counts)) (best 0))
      (if (null? rows)
        best
        (loop (cdr rows) (max best (cdar rows)))))))

(def (compute-zero-progress-streak prior-history next-fp)
  (if (null? prior-history)
    0
    (let* ((prev-fp (car (reverse prior-history)))
           (prev-m (loop-progress-measure prev-fp))
           (next-m (loop-progress-measure next-fp)))
      (if (or (< next-m prev-m)
              (opt-ref next-fp 'evidence-endorsed? #f))
        0
        (+ 1 (let loop ((rev (reverse prior-history)) (streak 0))
               (if (or (null? rev) (null? (cdr rev)))
                 streak
                 (let ((cur (car rev))
                       (bef (cadr rev)))
                   (if (or (< (loop-progress-measure cur) (loop-progress-measure bef))
                           (opt-ref cur 'evidence-endorsed? #f))
                     streak
                     (loop (cdr rev) (+ 1 streak)))))))))))

;;; Runs the real `gerbil-ascent` relational fixed-point program over the loop's
;;; full turn trace + current candidate fingerprint + upstream governance flags.
(def (ascent-evaluate-loop-termination
      loop-state
      candidate-fp
      governance-blocked?: (governance-blocked? #f)
      governance-reason: (governance-reason #f))
  (unless (ascent-loop-state? loop-state)
    (error "ascent-evaluate-loop-termination expects an AscentLoopState" loop-state))
  (unless (loop-turn-fingerprint? candidate-fp)
    (error "ascent-evaluate-loop-termination expects a LoopTurnFingerprint" candidate-fp))
  (let* ((policy (.ref loop-state 'policy))
         (prior-history (.ref loop-state 'history))
         (all-fps (append prior-history (list candidate-fp)))
         (n (length all-fps))
         (state-table (make-hash-table))
         (state-counter (box 0))
         (fail-table (make-hash-table))
         (fail-counter (box 0))
         (state-ids (map (lambda (fp)
                           (intern-id! state-table state-counter (.ref fp 'state-digest)))
                         all-fps))
         (visited-rows
          (let loop ((ids state-ids) (idx 0) (acc '()))
            (if (null? ids)
              (reverse acc)
              (loop (cdr ids) (+ idx 1) (cons (list idx (car ids)) acc)))))
         (edge-rows
          (let loop ((ids state-ids) (idx 1) (acc '()))
            (if (or (null? ids) (null? (cdr ids)))
              (reverse acc)
              (loop (cdr ids) (+ idx 1)
                    (cons (list idx (car ids) (cadr ids)) acc)))))
         (fail-rows
          (let loop ((fps all-fps) (idx 0) (acc '()))
            (if (null? fps)
              (reverse acc)
              (let ((fsig (opt-ref (car fps) 'failure-signature #f)))
                (if fsig
                  (let ((fid (intern-id! fail-table fail-counter
                                         (list (opt-ref (car fps) 'action-digest "") fsig))))
                    (loop (cdr fps) (+ idx 1) (cons (list idx fid) acc)))
                  (loop (cdr fps) (+ idx 1) acc))))))
         (earlier-rows (build-earlier-rows n))
         (steps-taken (.ref loop-state 'steps-taken))
         (tokens-spent (+ (.ref loop-state 'tokens-spent) (opt-ref candidate-fp 'tokens-used 0)))
         (step-budget-remaining (max 0 (- (.ref policy 'max-steps) steps-taken)))
         (tokens-remaining (max 0 (- (.ref policy 'max-tokens) tokens-spent)))
         (measure (loop-progress-measure candidate-fp))
         (quiescent? (opt-ref candidate-fp 'journal-quiescent? #t))
         (prior-halted? (.ref loop-state 'halted?))
         (max-rep-fail (max-failure-signature-count all-fps))
         (rep-fail-hit? (>= max-rep-fail (.ref policy 'max-repeated-failures)))
         (stall-streak (compute-zero-progress-streak prior-history candidate-fp))
         (stall-hit? (>= stall-streak (.ref policy 'max-stall-turns)))
         (budget-hit? (or (= step-budget-remaining 0) (= tokens-remaining 0)))
         (converged? (and (= measure 0) quiescent?))
         ;; Real `gerbil-ascent` Datalog / fixed-point program
         (program
          (relational-program
           (relation visited_state (t s) visited-rows)
           (relation edge (t a b) edge-rows)
           (relation earlier (t1 t2) earlier-rows)
           (relation fail_event (t f) fail-rows)
           (relation prior_halted_unreopened (x) (if prior-halted? '((1)) '()))
           (relation gov_blocked (x) (if governance-blocked? '((1)) '()))
           (relation converged_ready (x) (if converged? '((1)) '()))
           (relation repeat_fail_threshold_hit (x) (if rep-fail-hit? '((1)) '()))
           (relation stall_threshold_hit (x) (if stall-hit? '((1)) '()))
           (relation budget_exhausted (x) (if budget-hit? '((1)) '()))
           (relation exact_state_cycle (s))
           (relation oscillation_cycle (a b))
           (relation repeated_failure_pair (f))
           (relation halt_governance_blocked (x))
           (relation halt_converged (x))
           (relation halt_cycle (x))
           (relation halt_stalled (x))
           (relation halt_budget (x))
           ;; Core anti-infinite-loop relational derivations:
           (rule (exact_state_cycle ?s)
                 (visited_state ?t1 ?s)
                 (visited_state ?t2 ?s)
                 (earlier ?t1 ?t2))
           (rule (oscillation_cycle ?a ?b)
                 (edge ?t1 ?a ?b)
                 (edge ?t2 ?b ?a)
                 (earlier ?t1 ?t2))
           (rule (repeated_failure_pair ?f)
                 (fail_event ?t1 ?f)
                 (fail_event ?t2 ?f)
                 (earlier ?t1 ?t2))
           (rule (halt_governance_blocked ?x) (prior_halted_unreopened ?x))
           (rule (halt_governance_blocked ?x) (gov_blocked ?x))
           (rule (halt_converged ?x) (converged_ready ?x))
           (rule (halt_cycle 1) (exact_state_cycle ?s))
           (rule (halt_cycle 1) (oscillation_cycle ?a ?b))
           (rule (halt_stalled ?x) (repeat_fail_threshold_hit ?x))
           (rule (halt_stalled ?x) (stall_threshold_hit ?x))
           (rule (halt_budget ?x) (budget_exhausted ?x))
           (limits 1024 4096 4096)))
         (solution (relational-solve (relational-admit program)))
         (exact-cycle? (pair? (relational-query-name solution 'exact_state_cycle)))
         (osc-cycle? (pair? (relational-query-name solution 'oscillation_cycle)))
         (rep-fail-pair? (pair? (relational-query-name solution 'repeated_failure_pair)))
         (gov-halt? (pair? (relational-query-name solution 'halt_governance_blocked)))
         (conv-halt? (pair? (relational-query-name solution 'halt_converged)))
         (cycle-halt? (pair? (relational-query-name solution 'halt_cycle)))
         (stall-halt? (pair? (relational-query-name solution 'halt_stalled)))
         (budget-halt? (pair? (relational-query-name solution 'halt_budget)))
         ;; Strict priority verdict lattice matching Lean 4 `evaluateLoopVerdict` 1-to-1
         (verdict
          (cond
           (gov-halt? 'halt-governance-blocked)
           (conv-halt? 'halt-converged)
           (cycle-halt? 'halt-cycle-detected)
           (stall-halt? 'halt-stalled-no-progress)
           (budget-halt? 'halt-budget-exhausted)
           (else 'admit-next-step)))
         (admitted? (eq? verdict 'admit-next-step))
         (halted? (not admitted?))
         (reason
          (cond
           (prior-halted? 'halted-loop-requires-human-reopen)
           (governance-blocked? (or governance-reason 'upstream-governance-gate-blocked))
           (conv-halt? 'fixed-point-converged)
           (osc-cycle? 'ascent-oscillation-cycle-detected)
           (exact-cycle? 'ascent-exact-state-cycle-detected)
           (rep-fail-hit? 'ascent-repeated-failure-signature-halted)
           (stall-hit? 'ascent-zero-progress-stall-halted)
           (budget-halt? 'monotonic-budget-exhausted)
           (else 'ascent-step-admitted)))
         (escalate? (and halted? (not (eq? verdict 'halt-converged))))
         (inbox-item
          (and escalate?
               (.o bind-these: #f
                   kind: 'agentic-ai-lab.loop-engine.human-inbox-escalation.v1
                   loop-id: (.ref loop-state 'loop-id)
                   epoch: (.ref loop-state 'epoch)
                   verdict: verdict
                   reason: reason
                   steps-taken: steps-taken
                   progress-measure: measure
                   zero-progress-streak: stall-streak
                   requires-human-reopen?: #t
                   action-authorized?: #f))))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.loop-engine.ascent-termination-verdict.v1
        verdict: verdict
        admitted?: admitted?
        halted?: halted?
        reason: reason
        escalate-human-inbox?: escalate?
        human-inbox-item: inbox-item
        exact-cycle?: exact-cycle?
        oscillation-cycle?: osc-cycle?
        repeated-failure-detected?: (and rep-fail-hit? (or rep-fail-pair? (= (.ref policy 'max-repeated-failures) 1)))
        zero-progress-stalled?: stall-hit?
        zero-progress-streak: stall-streak
        budget-exhausted?: budget-halt?
        governance-blocked?: (or prior-halted? governance-blocked?)
        step-budget-remaining: step-budget-remaining
        tokens-remaining: tokens-remaining
        progress-measure: measure
        action-authorized?: #f)))

(def (ascent-loop-advance-state loop-state candidate-fp verdict-obj
                                audit-capsule: (audit-capsule #f))
  (let* ((admitted? (.ref verdict-obj 'admitted?))
         (new-history (append (.ref loop-state 'history) (list candidate-fp)))
         (new-steps (if admitted? (+ 1 (.ref loop-state 'steps-taken)) (.ref loop-state 'steps-taken)))
         (new-tokens (+ (.ref loop-state 'tokens-spent) (opt-ref candidate-fp 'tokens-used 0)))
         (new-capsules (if audit-capsule
                         (append (.ref loop-state 'audit-capsules) (list audit-capsule))
                         (.ref loop-state 'audit-capsules))))
    (make-ascent-loop-state
     (.ref loop-state 'loop-id)
     agent-id: (.ref loop-state 'agent-id)
     epoch: (.ref loop-state 'epoch)
     policy: (.ref loop-state 'policy)
     history: new-history
     steps-taken: new-steps
     tokens-spent: new-tokens
     zero-progress-streak: (.ref verdict-obj 'zero-progress-streak)
     halted?: (.ref verdict-obj 'halted?)
     halt-verdict: (if (.ref verdict-obj 'halted?) (.ref verdict-obj 'verdict) #f)
     halt-reason: (if (.ref verdict-obj 'halted?) (.ref verdict-obj 'reason) #f)
     human-reopen-endorser: (.ref loop-state 'human-reopen-endorser)
     audit-capsules: new-capsules)))

;;; Absorbing-halt reopen boundary (Slice 56 Lean theorem
;;; `haltedLoop_absorbing_without_human_reopen`):
;;; A halted loop CANNOT self-reset its budget or cycle history. Reopening
;;; requires a non-empty human endorser distinct from the loop's `agent-id`
;;; and starts a fresh bounded epoch (`epoch + 1`).
(def (ascent-loop-reopen-epoch
      loop-state
      human-endorser
      new-max-steps: (new-max-steps #f)
      new-max-tokens: (new-max-tokens #f))
  (unless (ascent-loop-state? loop-state)
    (error "ascent-loop-reopen-epoch expects an AscentLoopState" loop-state))
  (let* ((agent-id (.ref loop-state 'agent-id))
         (endorser-ok? (and (string? human-endorser)
                            (> (string-length human-endorser) 0)
                            (not (equal? human-endorser agent-id)))))
    (cond
     ((not (.ref loop-state 'halted?))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.loop-engine.reopen-result.v1
          reopened?: #f
          reason: 'loop-not-halted
          state: loop-state))
     ((not endorser-ok?)
      (.o bind-these: #f
          kind: 'agentic-ai-lab.loop-engine.reopen-result.v1
          reopened?: #f
          reason: 'self-reset-or-missing-human-endorser-rejected
          state: loop-state))
     (else
      (let* ((old-pol (.ref loop-state 'policy))
             (next-pol (make-ascent-loop-policy
                        max-steps: (or new-max-steps (.ref old-pol 'max-steps))
                        max-tokens: (or new-max-tokens (.ref old-pol 'max-tokens))
                        max-repeated-failures: (.ref old-pol 'max-repeated-failures)
                        max-stall-turns: (.ref old-pol 'max-stall-turns)
                        require-human-reopen?: #t
                        parent-policy: old-pol))
             (fresh-state (make-ascent-loop-state
                           (.ref loop-state 'loop-id)
                           agent-id: agent-id
                           epoch: (+ 1 (.ref loop-state 'epoch))
                           policy: next-pol
                           history: '()
                           steps-taken: 0
                           tokens-spent: 0
                           zero-progress-streak: 0
                           halted?: #f
                           halt-verdict: #f
                           halt-reason: #f
                           human-reopen-endorser: human-endorser
                           audit-capsules: (.ref loop-state 'audit-capsules))))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.loop-engine.reopen-result.v1
            reopened?: #t
            reason: 'human-endorsed-fresh-epoch-opened
            state: fresh-state))))))
