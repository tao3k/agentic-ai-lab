;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Coproduct / ArrowChoice dual of FunFlow's Product (`flow-fanout`):
;;; Declarative POO `ChoiceFlowPlan.`, native `flow?` Arrow entry normalization,
;;; static pre-execution branch completeness & Tarjan SCC DAG validation,
;;; cross-world shared `FunflowCasStore` execution, and active epistemic probing
;;; auto-refutation convergence (`choice-flow-converge`).
;;;
;;; Core invariants:
;;;   - `shared-prefix` and every branch slot forbid `fenced-effect` entries.
;;;   - Missing branch or DAG cycle fails closed with ZERO executions.
;;;   - `fenced-tail` executes ONLY when `world-count == 1`, `approval-live?`,
;;;     and `fenced-admitted?` holds; receipts always carry `action-authorized?: #f`.
;;;   - `defyuanxu-choice` expands hygienically to ordinary POO + `flow-choice`.

(import (only-in :clan/poo/object .def .o .ref .slot? object?)
        (only-in :clan/poo/type Enum Record Symbol String validate)
        (only-in :std/list/list every filter delete-duplicates/hash)
        (only-in "control-plane/flow.ss" flow? flow-name flow-input-contract)
        (only-in "durable-dag.ss"
                 PureCAS. VerifiedEpistemic. FencedEffect.
                 ParallelFrontierStrategy. funflow-dag-node funflow-dag-build)
        (only-in "governed-runner.ss"
                 governed-funflow-runner? governed-funflow-run))

(export ChoiceFlowPlan.
        ChoiceTaskEntry.
        EpistemicVerdictKind
        EpistemicProbeEvidence
        choice-flow-plan?
        choice-task-entry?
        make-choice-task-entry
        flow-choice
        make-choice-flow-plan
        choice-flow-execute
        choice-flow-converge
        defyuanxu-choice
        ChoiceFlowExports)

(def (opt-ref obj key default)
  (if (and (object? obj) (.slot? obj key))
    (.ref obj key)
    default))

(def (as-symbol value)
  (cond
   ((symbol? value) value)
   ((string? value) (string->symbol value))
   (else (error "expected symbol or string for choice option" value))))

(def (normalize-symbol-list values)
  (delete-duplicates/hash (map as-symbol values)))

(def EpistemicVerdictKind
  (Enum supports refutes inconclusive))

(def EpistemicProbeEvidence
  (Record kind: [(Enum epistemic-verdict)]
          verdict: [EpistemicVerdictKind]
          option: [Symbol]
          detail: [String]))

(.def ChoiceFlowPlan.
  kind: 'agentic-ai-lab.funflow.choice-flow-plan.v1
  choice-key: 'choice
  shared-prefix: '()
  branches: (.o)
  fenced-tail: '()
  action-authorized?: #f)

(.def ChoiceTaskEntry.
  kind: 'agentic-ai-lab.funflow.choice-task-entry.v1
  effect-class: 'pure-cas
  needs: '()
  required-evidence-ids: '()
  idempotency-key: #f
  idempotency-commits: '()
  sandbox-profile: #f
  env-digest: #f)

(def (choice-flow-plan? value)
  (and (object? value)
       (.slot? value 'kind)
       (eq? (.ref value 'kind) 'agentic-ai-lab.funflow.choice-flow-plan.v1)
       (.slot? value 'choice-key)
       (.slot? value 'shared-prefix)
       (.slot? value 'branches)
       (object? (.ref value 'branches))
       (.slot? value 'fenced-tail)))

(def (choice-task-entry? value)
  (and (object? value)
       (or (and (.slot? value 'flow) (flow? (.ref value 'flow)) (.slot? value 'input))
           (and (.slot? value 'arrow) (flow? (.ref value 'arrow)) (.slot? value 'input)))))

(def (make-choice-task-entry
      flow input
      task-id: (task-id #f)
      produces-evidence-id: (produces-evidence-id #f)
      needs: (needs '())
      required-evidence-ids: (required-evidence-ids '())
      effect-class: (effect-class 'pure-cas)
      idempotency-key: (idempotency-key #f)
      idempotency-commits: (idempotency-commits '())
      sandbox-profile: (sandbox-profile #f)
      env-digest: (env-digest #f))
  (unless (flow? flow)
    (error "make-choice-task-entry expects a FunFlow flow? Arrow" flow))
  (unless (memq effect-class '(pure-cas verified-epistemic fenced-effect))
    (error "make-choice-task-entry expects effect-class in (pure-cas verified-epistemic fenced-effect)"
           effect-class))
  (validate (flow-input-contract flow) input)
  (let* ((fname (symbol->string (flow-name flow)))
         (tid (or task-id (string-append "task:choice:" fname)))
         (ev-id (or produces-evidence-id (string-append "ev:choice:" fname))))
    (.o (:: @ ChoiceTaskEntry.)
        (kind := 'agentic-ai-lab.funflow.choice-task-entry.v1)
        (task-id := tid)
        (produces-evidence-id := ev-id)
        (flow := flow)
        (input := input)
        (needs := needs)
        (required-evidence-ids := required-evidence-ids)
        (effect-class := effect-class)
        (idempotency-key := idempotency-key)
        (idempotency-commits := idempotency-commits)
        (sandbox-profile := sandbox-profile)
        (env-digest := env-digest))))

(def (entry-flow entry)
  (or (opt-ref entry 'flow #f) (opt-ref entry 'arrow #f)))

(def (entry-task-id entry)
  (or (opt-ref entry 'task-id #f)
      (string-append "task:choice:" (symbol->string (flow-name (entry-flow entry))))))

(def (entry-effect-class entry)
  (opt-ref entry 'effect-class 'pure-cas))

(def (normalize-entry label allow-fenced? entry)
  (unless (choice-task-entry? entry)
    (error (string-append label " expects typed ChoiceTaskEntry or FunFlow task objects") entry))
  (let* ((flow (entry-flow entry))
         (input (.ref entry 'input))
         (eff (entry-effect-class entry))
         (tid (entry-task-id entry)))
    (unless (or allow-fenced? (not (eq? eff 'fenced-effect)))
      (error (string-append label " forbids fenced-effect entries; place them in fenced-tail") tid))
    (validate (flow-input-contract flow) input)
    entry))

(def (normalize-entries label allow-fenced? value)
  (let ((entries (cond
                  ((list? value) value)
                  ((choice-task-entry? value) (list value))
                  (else (error (string-append label " expects a list or single ChoiceTaskEntry") value)))))
    (map (lambda (entry) (normalize-entry label allow-fenced? entry)) entries)))

(def (flow-choice
      branches
      choice-key: (choice-key 'choice)
      shared-prefix: (shared-prefix '())
      fenced-tail: (fenced-tail '()))
  (unless (object? branches)
    (error "flow-choice expects a POO branches object" branches))
  (unless (symbol? choice-key)
    (error "flow-choice expects a symbol choice-key" choice-key))
  (let ((norm-prefix (normalize-entries "choice-flow-plan shared-prefix" #f shared-prefix))
        (norm-fenced (normalize-entries "choice-flow-plan fenced-tail" #t fenced-tail)))
    (.o (:: @ ChoiceFlowPlan.)
        (choice-key := choice-key)
        (shared-prefix := norm-prefix)
        (branches := branches)
        (fenced-tail := norm-fenced)
        (action-authorized? := #f))))

(def make-choice-flow-plan flow-choice)

;; Hygienic authoring macro parallel to `defyuanxu-fanout`:
;; expands directly to `flow-choice` + POO objects (never a custom workflow DSL).
(defrules defyuanxu-choice ()
  ((_ binding branches option ...)
   (def binding (flow-choice branches option ...))))

(def (effect-symbol->prototype eff)
  (case eff
    ((fenced-effect) FencedEffect.)
    ((verified-epistemic) VerifiedEpistemic.)
    (else PureCAS.)))

(def (validate-world-dag entries strategy)
  ;; Map `produces-evidence-id` -> task symbol so `required-evidence-ids` + explicit
  ;; `needs` form the exact FunFlow DAG checked by Tarjan SCC in `funflow-dag-build`.
  (let ((ev->task (make-hash-table)))
    (for-each
     (lambda (entry)
       (let ((ev (opt-ref entry 'produces-evidence-id #f)))
         (when ev (hash-put! ev->task ev (as-symbol (entry-task-id entry))))))
     entries)
    (let ((nodes
           (map (lambda (entry)
                  (let* ((tid-sym (as-symbol (entry-task-id entry)))
                         (explicit-needs (map as-symbol (opt-ref entry 'needs '())))
                         (ev-needs
                          (filter values
                                  (map (lambda (req-ev) (hash-get ev->task req-ev))
                                       (opt-ref entry 'required-evidence-ids '()))))
                         (all-needs (delete-duplicates/hash (append explicit-needs ev-needs))))
                    (funflow-dag-node
                     tid-sym
                     needs: all-needs
                     effect-class: (effect-symbol->prototype (entry-effect-class entry)))))
                entries)))
      (funflow-dag-build nodes strategy: strategy))))

(def (extract-worlds worlds-or-solution)
  (cond
   ((list? worlds-or-solution) worlds-or-solution)
   ((and (object? worlds-or-solution) (.slot? worlds-or-solution 'worlds))
    (.ref worlds-or-solution 'worlds))
   (else (error "choice-flow-execute expects a list of world objects or a choice solution"
                worlds-or-solution))))

(def (default-fenced-admitted? world)
  (let ((ddec (opt-ref world 'dispatch-decision 'fenced-apply)))
    (eq? ddec 'fenced-apply)))

(def (choice-flow-execute
      worlds-or-solution runner plan
      approval-live?: (approval-live? #f)
      strategy: (strategy ParallelFrontierStrategy.)
      fenced-admitted?: (fenced-admitted? #f))
  (unless (governed-funflow-runner? runner)
    (error "choice-flow-execute expects a GovernedFunflowRunner" runner))
  (unless (choice-flow-plan? plan)
    (error "choice-flow-execute expects a ChoiceFlowPlan" plan))
  (let* ((worlds (extract-worlds worlds-or-solution))
         (wcount (length worlds))
         (status (if (and (object? worlds-or-solution) (.slot? worlds-or-solution 'choice-status))
                   (.ref worlds-or-solution 'choice-status)
                   (cond ((= wcount 0) 'unsatisfiable)
                         ((= wcount 1) 'unique-deduction)
                         (else 'competing-worlds))))
         (ckey (.ref plan 'choice-key))
         (shared-prefix (normalize-entries "choice-flow-plan shared-prefix" #f (.ref plan 'shared-prefix)))
         (branches (.ref plan 'branches))
         (fenced-tail (normalize-entries "choice-flow-plan fenced-tail" #t (.ref plan 'fenced-tail)))
         (fenced-pred (or fenced-admitted? default-fenced-admitted?))
         (missing-branches
          (delete-duplicates/hash
           (filter values
                   (map (lambda (w)
                          (let ((key-val (opt-ref w ckey #f)))
                            (if (and (symbol? key-val) (.slot? branches key-val))
                              #f
                              (or key-val 'missing-choice-value))))
                        worlds))))
         (world-plans
          (if (pair? missing-branches)
            '()
            (let loop ((ws worlds) (idx 0) (acc '()))
              (if (null? ws)
                (reverse acc)
                (let* ((w (car ws))
                       (key-val (.ref w ckey))
                       (branch-entries
                        (normalize-entries
                         (string-append "choice-flow-plan branch:" (symbol->string key-val))
                         #f (.ref branches key-val)))
                       (entries (append shared-prefix branch-entries fenced-tail))
                       (dag (validate-world-dag entries strategy)))
                  (loop (cdr ws) (+ idx 1) (cons (list idx w key-val dag entries) acc)))))))
         (invalid-dags
          (filter (lambda (wp) (not (.ref (list-ref wp 3) 'valid?))) world-plans)))
    (cond
     ((pair? missing-branches)
      (.o (kind := 'agentic-ai-lab.funflow.choice-execution.v1)
          (admitted? := #f)
          (reason := 'incomplete-choice-flow-branches)
          (missing-branches := missing-branches)
          (choice-status := status)
          (world-count := wcount)
          (worlds := '())
          (total-executions := 0)
          (total-cas-hits := 0)
          (fenced-blocked-count := 0)
          (action-authorized? := #f)))
     ((pair? invalid-dags)
      (let* ((bad-dag (list-ref (car invalid-dags) 3))
             (reason (if (pair? (.ref bad-dag 'cycle-nodes))
                       'funflow-dag-cycle-detected
                       'invalid-choice-flow-dag)))
        (.o (kind := 'agentic-ai-lab.funflow.choice-execution.v1)
            (admitted? := #f)
            (reason := reason)
            (missing-branches := '())
            (choice-status := status)
            (world-count := wcount)
            (worlds := '())
            (total-executions := 0)
            (total-cas-hits := 0)
            (fenced-blocked-count := 0)
            (action-authorized? := #f))))
     (else
      (let loop ((wps world-plans)
                 (exec-total 0)
                 (hit-total 0)
                 (blocked-total 0)
                 (acc '()))
        (if (null? wps)
          (.o (kind := 'agentic-ai-lab.funflow.choice-execution.v1)
              (admitted? := #t)
              (reason := 'choice-flow-plan-executed)
              (missing-branches := '())
              (choice-status := status)
              (world-count := wcount)
              (worlds := (reverse acc))
              (total-executions := exec-total)
              (total-cas-hits := hit-total)
              (fenced-blocked-count := blocked-total)
              (action-authorized? := #f))
          (let* ((wp (car wps))
                 (idx (list-ref wp 0))
                 (w (list-ref wp 1))
                 (key-val (list-ref wp 2))
                 (dag (list-ref wp 3))
                 (entries (list-ref wp 4))
                 (widx (opt-ref w 'world-index idx))
                 (fenced-ok? (and (= wcount 1) approval-live? (and (fenced-pred w) #t))))
            (let tloop ((es entries)
                        (w-exec 0)
                        (w-hit 0)
                        (w-blocked 0)
                        (t-results '())
                        (t-blocked '()))
              (if (null? es)
                (loop (cdr wps)
                      (+ exec-total w-exec)
                      (+ hit-total w-hit)
                      (+ blocked-total w-blocked)
                      (cons (.o (kind := 'agentic-ai-lab.funflow.choice-world-receipt.v1)
                                (world-index := widx)
                                (choice-value := key-val)
                                (dag-digest := (.ref dag 'dag-digest))
                                (task-results := (reverse t-results))
                                (fenced-blocked-tasks := (reverse t-blocked))
                                (executions := w-exec)
                                (cas-hits := w-hit)
                                (action-authorized? := #f))
                            acc))
                (let* ((entry (car es))
                       (tid (entry-task-id entry))
                       (eff (entry-effect-class entry))
                       (fenced? (eq? eff 'fenced-effect)))
                  (if (and fenced? (not fenced-ok?))
                    (let ((reason
                           (cond
                            ((not (= wcount 1)) 'fenced-effect-blocked-in-competing-worlds)
                            ((not approval-live?) 'fenced-effect-requires-human-approval)
                            (else 'fenced-effect-not-admitted-by-choice-dispatch))))
                      (tloop (cdr es)
                             w-exec w-hit (+ w-blocked 1)
                             t-results
                             (cons (.o (task-id := tid)
                                       (effect-class := eff)
                                       (executed? := #f)
                                       (fenced-blocked? := #t)
                                       (reason := reason)
                                       (action-authorized? := #f))
                                   t-blocked)))
                    (let* ((res (governed-funflow-run
                                 runner
                                 (entry-flow entry)
                                 (.ref entry 'input)
                                 idempotency-key: (opt-ref entry 'idempotency-key #f)
                                 idempotency-commits: (opt-ref entry 'idempotency-commits '())
                                 sandbox-override: (opt-ref entry 'sandbox-profile #f)
                                 env-digest-override: (opt-ref entry 'env-digest #f)))
                           (hit? (and (.ref res 'cas-hit?) #t))
                           (ex? (and (.ref res 'executed?) #t)))
                      (tloop (cdr es)
                             (+ w-exec (if ex? 1 0))
                             (+ w-hit (if hit? 1 0))
                             w-blocked
                             (cons (.o (task-id := tid)
                                       (effect-class := eff)
                                       (admitted? := (.ref res 'admitted?))
                                       (executed? := ex?)
                                       (cas-hit? := hit?)
                                       (cas-key := (.ref res 'cas-key))
                                       (value := (opt-ref res 'value #f))
                                       (reason := (.ref res 'reason))
                                       (action-authorized? := #f))
                                   t-results)
                             t-blocked)))))))))))))

(def (extract-epistemic-verdicts exec-receipt)
  (let loop ((ws (.ref exec-receipt 'worlds)) (verdicts '()))
    (if (null? ws)
      (reverse verdicts)
      (let* ((w (car ws))
             (widx (.ref w 'world-index))
             (trs (.ref w 'task-results)))
        (let tloop ((ts trs) (acc verdicts))
          (if (null? ts)
            (loop (cdr ws) acc)
            (let* ((tr (car ts))
                   (val (opt-ref tr 'value #f)))
              (if (and (object? val)
                       (eq? (opt-ref val 'kind #f) 'epistemic-verdict)
                       (memq (opt-ref val 'verdict #f) '(supports refutes inconclusive))
                       (opt-ref val 'option #f))
                (tloop (cdr ts)
                       (cons (.o (kind := 'epistemic-verdict)
                                 (world-index := widx)
                                 (task-id := (.ref tr 'task-id))
                                 (verdict := (.ref val 'verdict))
                                 (option := (as-symbol (.ref val 'option)))
                                 (detail := (opt-ref val 'detail ""))
                                 (cas-hit? := (.ref tr 'cas-hit?))
                                 (action-authorized? := #f))
                             acc))
                (tloop (cdr ts) acc)))))))))

;;; Active Epistemic Probing & Auto-Refutation Convergence Loop:
;;; Iterates `solve-fn` -> `choice-flow-execute` over ONE shared `FunflowCasStore`,
;;; feeding any `EpistemicProbeEvidence` with `verdict: 'refutes` into the next
;;; round's refuted option set until convergence or fail-closed stop.
(def (choice-flow-converge
      solve-fn runner plan
      max-rounds: (max-rounds 4)
      approval-live?: (approval-live? #f)
      initial-refuted: (initial-refuted '())
      strategy: (strategy ParallelFrontierStrategy.)
      fenced-admitted?: (fenced-admitted? #f))
  (unless (procedure? solve-fn)
    (error "choice-flow-converge expects a solve-fn procedure" solve-fn))
  (unless (governed-funflow-runner? runner)
    (error "choice-flow-converge expects a GovernedFunflowRunner" runner))
  (unless (choice-flow-plan? plan)
    (error "choice-flow-converge expects a ChoiceFlowPlan" plan))
  (let loop ((round 0)
             (refuted (normalize-symbol-list initial-refuted))
             (rounds-acc '())
             (exec-total 0)
             (hit-total 0))
    (let* ((sol (solve-fn refuted))
           (worlds (extract-worlds sol))
           (wcount (length worlds)))
      (if (= wcount 0)
        (.o (kind := 'agentic-ai-lab.funflow.choice-convergence.v1)
            (convergence-status := 'unsatisfiable)
            (reason := 'choice-space-unsatisfiable)
            (round-count := round)
            (rounds := (reverse rounds-acc))
            (refuted-options := refuted)
            (final-solution := sol)
            (final-execution := #f)
            (total-executions := exec-total)
            (total-cas-hits := hit-total)
            (action-authorized? := #f))
        (let ((exec (choice-flow-execute
                     sol runner plan
                     approval-live?: approval-live?
                     strategy: strategy
                     fenced-admitted?: fenced-admitted?)))
          (if (not (.ref exec 'admitted?))
            (.o (kind := 'agentic-ai-lab.funflow.choice-convergence.v1)
                (convergence-status := 'plan-rejected)
                (reason := (.ref exec 'reason))
                (round-count := round)
                (rounds := (reverse rounds-acc))
                (refuted-options := refuted)
                (final-solution := sol)
                (final-execution := exec)
                (total-executions := exec-total)
                (total-cas-hits := hit-total)
                (action-authorized? := #f))
            (let* ((next-exec-total (+ exec-total (.ref exec 'total-executions)))
                   (next-hit-total (+ hit-total (.ref exec 'total-cas-hits)))
                   (verdicts (extract-epistemic-verdicts exec))
                   (newly-refuted
                    (delete-duplicates/hash
                     (filter (lambda (opt) (not (memq opt refuted)))
                             (map (lambda (v) (.ref v 'option))
                                  (filter (lambda (v) (eq? (.ref v 'verdict) 'refutes))
                                          verdicts)))))
                   (round-entry
                    (.o (kind := 'agentic-ai-lab.funflow.choice-convergence-round.v1)
                        (round := round)
                        (world-count := wcount)
                        (refuted-before := refuted)
                        (newly-refuted := newly-refuted)
                        (verdicts := verdicts)
                        (executions := (.ref exec 'total-executions))
                        (cas-hits := (.ref exec 'total-cas-hits))
                        (fenced-blocked-count := (.ref exec 'fenced-blocked-count))
                        (action-authorized? := #f)))
                   (next-rounds (cons round-entry rounds-acc)))
              (cond
               ((null? newly-refuted)
                (let ((final-status (if (= wcount 1)
                                      'converged-unique
                                      'irreducible-competition)))
                  (.o (kind := 'agentic-ai-lab.funflow.choice-convergence.v1)
                      (convergence-status := final-status)
                      (reason := final-status)
                      (round-count := (+ round 1))
                      (rounds := (reverse next-rounds))
                      (refuted-options := refuted)
                      (final-solution := sol)
                      (final-execution := exec)
                      (total-executions := next-exec-total)
                      (total-cas-hits := next-hit-total)
                      (action-authorized? := #f))))
               ((>= (+ round 1) max-rounds)
                (.o (kind := 'agentic-ai-lab.funflow.choice-convergence.v1)
                    (convergence-status := 'budget-exhausted)
                    (reason := 'convergence-round-budget-exhausted)
                    (round-count := (+ round 1))
                    (rounds := (reverse next-rounds))
                    (refuted-options := (normalize-symbol-list (append refuted newly-refuted)))
                    (final-solution := sol)
                    (final-execution := exec)
                    (total-executions := next-exec-total)
                    (total-cas-hits := next-hit-total)
                    (action-authorized? := #f)))
               (else
                (loop (+ round 1)
                      (normalize-symbol-list (append refuted newly-refuted))
                      next-rounds
                      next-exec-total
                      next-hit-total))))))))))

(def ChoiceFlowExports
  (.o (ChoiceFlowPlan := ChoiceFlowPlan.)
      (ChoiceTaskEntry := ChoiceTaskEntry.)
      (EpistemicVerdictKind := EpistemicVerdictKind)
      (EpistemicProbeEvidence := EpistemicProbeEvidence)
      (choice-flow-plan? := choice-flow-plan?)
      (choice-task-entry? := choice-task-entry?)
      (make-choice-task-entry := make-choice-task-entry)
      (flow-choice := flow-choice)
      (make-choice-flow-plan := make-choice-flow-plan)
      (choice-flow-execute := choice-flow-execute)
      (choice-flow-converge := choice-flow-converge)))
