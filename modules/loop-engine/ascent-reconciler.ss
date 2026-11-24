;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Post-ReAct Loop Engine Core — Module 2:
;;; Declarative ASCENT Obligation-Fixpoint Reconciler
;;; (`modules/loop-engine/ascent-reconciler.ss`).
;;;
;;; ASCENT *IS* the Loop Engine control plane:
;;; Given an immutable `ObligationGraph`, runs a real `gerbil-ascent`
;;; `relational-program` to simultaneously compute the full fixed-point frontier:
;;;   - `refuted_hypothesis(h)`          (counter-evidence or active defeater)
;;;   - `obligation_unsatisfied(o)`      (transitive closure over dependency DAG!)
;;;   - `discharged_obligation(o)`       (all obligations NOT unsatisfied)
;;;   - `ready_deterministic_task(t)`    (all ready FunFlow tasks -> 0 LLM calls!)
;;;   - `candidate_synthesis_hole(h)`    (unattempted `(hole-id, premise-digest)`)
;;;   - `blocked_on_human(o)`            (defeated, governance-blocked, or exhausted)
;;;   - `quiescent_fixed_point`          (zero ready det tasks & zero ready holes)
;;;
;;; Guarantees:
;;;   1. Strict Deterministic-First Precedence: LLM synthesis holes are NEVER
;;;      selected while `ready-deterministic-tasks` is non-empty (`0 LLM calls`).
;;;   2. Relational `(hole-id, premise-digest)` Idempotence: once attempted,
;;;      ASCENT will NEVER re-select the same hole on unchanged premises.
;;;   3. Competing-Hypothesis Preservation: unrefuted competing hypotheses are
;;;      surfaced as `'open-competition` and NEVER collapsed to a greedy path.

(import (only-in :clan/poo/object .o .ref)
        (only-in :std/list/list filter every)
        (only-in :gerbil-ascent/program/api
                 relational-program relational-admit relational-solve
                 relational-query-name)
        "obligation-graph.ss")

(export ascent-reconcile-frontier)

(def (index-map items id-fn)
  (let ((id->idx (make-hash-table))
        (idx->item (make-vector (length items))))
    (let loop ((rest items) (i 1))
      (unless (null? rest)
        (let ((it (car rest)))
          (hash-put! id->idx (id-fn it) i)
          (vector-set! idx->item (- i 1) it)
          (loop (cdr rest) (+ i 1)))))
    (values id->idx idx->item)))

(def (ascent-reconcile-frontier graph)
  (unless (obligation-graph? graph)
    (error "ascent-reconcile-frontier expects an ObligationGraph" graph))
  (let* ((obs (.ref graph 'obligations))
         (hyps (.ref graph 'hypotheses))
         (live-ev (obligation-graph-live-evidence graph))
         (tasks (.ref graph 'det-tasks))
         (holes (.ref graph 'synthesis-holes))
         (completed (.ref graph 'completed-tasks))
         (gov-healthy? (and (.ref graph 'cedar-grant-live?)
                            (.ref graph 'mcp-manifest-healthy?)))
         (live-ev-ids (map (lambda (e) (.ref e 'evidence-id)) live-ev)))
    (let-values (((ob->i i->ob) (index-map obs (lambda (o) (.ref o 'obligation-id))))
                 ((hyp->i i->hyp) (index-map hyps (lambda (h) (.ref h 'hypothesis-id))))
                 ((ev->i _i->ev) (index-map live-ev (lambda (e) (.ref e 'evidence-id))))
                 ((task->i i->task) (index-map tasks (lambda (t) (.ref t 'task-id))))
                 ((hole->i i->hole) (index-map holes (lambda (h) (.ref h 'hole-id)))))
      (let* (;; Build positive relational input facts for `gerbil-ascent`
             (live-ev-rows (map (lambda (e) (list (hash-get ev->i (.ref e 'evidence-id)))) live-ev))
             ;; Missing required evidence per obligation
             (missing-ev-rows
              (let loop ((os obs) (acc '()))
                (if (null? os)
                  acc
                  (let* ((o (car os))
                         (oi (hash-get ob->i (.ref o 'obligation-id)))
                         (missing (filter (lambda (eid) (not (member eid live-ev-ids)))
                                          (.ref o 'required-evidence-ids))))
                    (loop (cdr os)
                          (if (pair? missing) (cons (list oi) acc) acc))))))
             ;; Active defeaters on obligations
             (ob-defeater-rows
              (filter-map (lambda (o)
                            (and (pair? (.ref o 'active-defeaters))
                                 (list (hash-get ob->i (.ref o 'obligation-id)))))
                          obs))
             ;; Transitive obligation dependency edges: (o, dep)
             (ob-dep-rows
              (let loop ((os obs) (acc '()))
                (if (null? os)
                  acc
                  (let* ((o (car os))
                         (oi (hash-get ob->i (.ref o 'obligation-id)))
                         (deps (.ref o 'depends-on)))
                    (loop (cdr os)
                          (foldl (lambda (dep-id a)
                                   (let ((di (hash-get ob->i dep-id)))
                                     (if di (cons (list oi di) a) a)))
                                 acc
                                 deps))))))
             ;; Hypothesis counter-evidence & defeaters
             (hyp-counter-rows
              (let loop ((hs hyps) (acc '()))
                (if (null? hs)
                  acc
                  (let* ((h (car hs))
                         (hi (hash-get hyp->i (.ref h 'hypothesis-id))))
                    (loop (cdr hs)
                          (foldl (lambda (eid a)
                                   (let ((ei (hash-get ev->i eid)))
                                     (if ei (cons (list hi ei) a) a)))
                                 acc
                                 (.ref h 'contradicting-evidence-ids)))))))
             (hyp-defeater-rows
              (filter-map (lambda (h)
                            (and (pair? (.ref h 'active-defeaters))
                                 (list (hash-get hyp->i (.ref h 'hypothesis-id)))))
                          hyps))
             ;; Deterministic FunFlow task facts
             (det-task-rows
              (filter-map (lambda (t)
                            (let ((ti (hash-get task->i (.ref t 'task-id)))
                                  (oi (hash-get ob->i (.ref t 'obligation-id))))
                              (and ti oi (list ti oi))))
                          tasks))
             (task-ready-rows
              (filter-map
               (lambda (t)
                 (let* ((tid (.ref t 'task-id))
                        (ti (hash-get task->i tid))
                        (pdig (obligation-graph-premise-digest graph (.ref t 'obligation-id) (.ref t 'premise-ids)))
                        (inputs-ok? (every (lambda (eid) (member eid live-ev-ids))
                                           (.ref t 'required-evidence-ids)))
                        (not-done? (not (member (cons tid pdig) completed))))
                   (and ti inputs-ok? not-done? (list ti))))
               tasks))
             ;; Synthesis hole facts (with `(hole-id, premise-digest)` idempotence!)
             (synth-hole-rows
              (filter-map (lambda (h)
                            (let ((hi (hash-get hole->i (.ref h 'hole-id)))
                                  (oi (hash-get ob->i (.ref h 'obligation-id))))
                              (and hi oi (list hi oi))))
                          holes))
             (hole-unattempted-rows
              (filter-map (lambda (h)
                            (and (not (obligation-graph-hole-attempted? graph h))
                                 (list (hash-get hole->i (.ref h 'hole-id)))))
                          holes))
             (hole-attempted-rows
              (filter-map (lambda (h)
                            (and (obligation-graph-hole-attempted? graph h)
                                 (list (hash-get hole->i (.ref h 'hole-id)))))
                          holes))
             (gov-rows (if gov-healthy? '((1)) '()))
             ;; Real `gerbil-ascent` Datalog fixed-point program
             (program
              (relational-program
               (relation live_evidence (e) live-ev-rows)
               (relation ob_missing_ev (o) missing-ev-rows)
               (relation ob_has_defeater (o) ob-defeater-rows)
               (relation ob_dep (o dep) ob-dep-rows)
               (relation hyp_counter_ev (h e) hyp-counter-rows)
               (relation hyp_has_defeater (h) hyp-defeater-rows)
               (relation det_task (t o) det-task-rows)
               (relation task_eligible (t) task-ready-rows)
               (relation synth_hole (h o) synth-hole-rows)
               (relation hole_unattempted (h) hole-unattempted-rows)
               (relation hole_attempted (h) hole-attempted-rows)
               (relation gov_healthy (g) gov-rows)
               ;; Derived fixed-point relations
               (relation refuted_hypothesis (h))
               (relation obligation_unsatisfied (o))
               (relation ready_deterministic_task (t))
               (relation candidate_synthesis_hole (h))
               (relation exhausted_hole_obligation (o))
               ;; 1. Epistemic refutation rules
               (rule (refuted_hypothesis ?h) (hyp_counter_ev ?h ?e) (live_evidence ?e))
               (rule (refuted_hypothesis ?h) (hyp_has_defeater ?h))
               ;; 2. Transitive obligation unsatisfaction closure over arbitrary DAG depth!
               (rule (obligation_unsatisfied ?o) (ob_missing_ev ?o))
               (rule (obligation_unsatisfied ?o) (ob_has_defeater ?o))
               (rule (obligation_unsatisfied ?o) (ob_dep ?o ?dep) (obligation_unsatisfied ?dep))
               ;; 3. Ready deterministic FunFlow frontier (0 LLM calls!)
               (rule (ready_deterministic_task ?t)
                     (det_task ?t ?o)
                     (obligation_unsatisfied ?o)
                     (task_eligible ?t)
                     (gov_healthy 1))
               ;; 4. Candidate synthesis holes (strictly gated by unattempted `(hole, premise-digest)`)
               (rule (candidate_synthesis_hole ?h)
                     (synth_hole ?h ?o)
                     (obligation_unsatisfied ?o)
                     (hole_unattempted ?h)
                     (gov_healthy 1))
               ;; 5. Obligations whose synthesis hole was already attempted without resolving
               (rule (exhausted_hole_obligation ?o)
                     (synth_hole ?h ?o)
                     (obligation_unsatisfied ?o)
                     (hole_attempted ?h))
               (limits 1024 4096 4096)))
             (solution (relational-solve (relational-admit program)))
             (refuted-idx (map car (relational-query-name solution 'refuted_hypothesis)))
             (unsat-idx (map car (relational-query-name solution 'obligation_unsatisfied)))
             (ready-det-idx (list-sort < (map car (relational-query-name solution 'ready_deterministic_task))))
             (cand-hole-idx (list-sort < (map car (relational-query-name solution 'candidate_synthesis_hole))))
             (exhausted-idx (list-sort < (map car (relational-query-name solution 'exhausted_hole_obligation))))
             (refuted-hyps (map (lambda (i) (vector-ref i->hyp (- i 1))) refuted-idx))
             (unrefuted-hyps
              (filter (lambda (h) (not (member (hash-get hyp->i (.ref h 'hypothesis-id)) refuted-idx)))
                      hyps))
             (unsat-obs (map (lambda (i) (vector-ref i->ob (- i 1))) (list-sort < unsat-idx)))
             (discharged-obs
              (filter (lambda (o) (not (member (hash-get ob->i (.ref o 'obligation-id)) unsat-idx)))
                      obs))
             (ready-det-tasks (map (lambda (i) (vector-ref i->task (- i 1))) ready-det-idx))
             (cand-holes (map (lambda (i) (vector-ref i->hole (- i 1))) cand-hole-idx))
             (exhausted-obs (map (lambda (i) (vector-ref i->ob (- i 1))) exhausted-idx))
             ;; Strict Deterministic-First Precedence (Slice 57 Lean theorem):
             ;; LLM synthesis holes are NEVER exposed when deterministic FunFlow work is ready!
             (selected-holes (if (null? ready-det-tasks) cand-holes '()))
             (epistemic-status
              (cond
               ((null? unrefuted-hyps) 'none-active)
               ((null? (cdr unrefuted-hyps)) 'single-unrefuted)
               (else 'open-competition)))
             (frontier-mode
              (cond
               ((not gov-healthy?) 'blocked-on-governance)
               ((pair? ready-det-tasks) 'dispatch-deterministic-funflow)
               ((pair? selected-holes) 'invoke-typed-synthesis-oracle)
               (else 'quiescent-fixed-point)))
             (quiescent? (eq? frontier-mode 'quiescent-fixed-point))
             (blocked-on-human-obs
              (filter (lambda (o)
                        (or (not gov-healthy?)
                            (pair? (.ref o 'active-defeaters))
                            (member (.ref o 'obligation-id)
                                    (map (lambda (x) (.ref x 'obligation-id)) exhausted-obs))))
                      unsat-obs)))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.loop-engine.ascent-reconcile-frontier.v1
            cut: (.ref graph 'cut)
            frontier-mode: frontier-mode
            quiescent?: quiescent?
            governance-healthy?: gov-healthy?
            discharged-obligations: discharged-obs
            unsatisfied-obligations: unsat-obs
            blocked-on-human-obligations: blocked-on-human-obs
            refuted-hypotheses: refuted-hyps
            unrefuted-hypotheses: unrefuted-hyps
            epistemic-competition-status: epistemic-status
            ready-deterministic-tasks: ready-det-tasks
            ready-synthesis-holes: selected-holes
            action-authorized?: #f)))))

(def (filter-map fn lst)
  (let loop ((xs lst) (acc '()))
    (if (null? xs)
      (reverse acc)
      (let ((v (fn (car xs))))
        (loop (cdr xs) (if v (cons v acc) acc))))))
