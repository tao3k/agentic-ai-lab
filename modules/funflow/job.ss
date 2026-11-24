;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Job projection reuses the functional Flow interpreter; Ops owns processes.
(import :clan/poo/object
        (only-in :std/list/list delete-duplicates/hash)
        (only-in :tao3k/yuanxu/graph/types-core yuanxu-graph yuanxu-graph-node yuanxu-graph-edge)
        (only-in :clan/poo/graph/computation Computation.)
        (prefix-in :clan/poo/graph/schedule schedule.)
        (only-in :tao3k/yuanxu/ops/types ProcessScriptContract ProcessResultContract)
        (only-in "control-plane/signatures.ss" Fun Function Record String Symbol List validate)
        (only-in "control-plane/runtime-protocol.ss" AdapterResult)
        (only-in "control-plane/flow.ss" flow-compose)
        (only-in "control-plane/task.ss" execution-request-name execution-request-request execution-request-input
                 make-external-task make-pure-task)
        (only-in "control-plane/runtime-protocol.ss" make-adapter-result adapter-result-value)
        (only-in "control-plane/strategy.ss" make-local-eager-strategy)
        (for-template "control-plane/runtime-adapter.ss" "control-plane/runner.ss")
        (only-in :tao3k/yuanxu/module-system/source/module-binding module-binding-action)
        (only-in :tao3k/yuanxu/module-system/source/compiled-role
                 bind-deferred-interfaces deferred-interface-values))
(export job-graph job-flow run-job)

(bind-deferred-interfaces "control-plane/runtime-adapter.ss" "control-plane/runner.ss")

;; Importing a Job prototype or projecting its graph leaves execution cold.
(def job-runtime
  (.o adapter: (deferred-interface-values
                 "control-plane/runtime-adapter.ss"
                 tao3k/agentic-ai-lab/modules/funflow/control-plane/runtime-adapter
                 (make-runtime-adapter) module-binding-action)
      runner: (deferred-interface-values
                "control-plane/runner.ss"
                tao3k/agentic-ai-lab/modules/funflow/control-plane/runner
                (make-runner runner-run run-result-value run-result-receipt) module-binding-action)))

(def (symbol-set? values)
  (and (list? values) (every symbol? values)
       (= (length values) (length (delete-duplicates/hash values)))))
(def TaskRun (Function (list ProcessResultContract) '() rest: String))
(def (task-run task) (validate TaskRun (.get task .run)))
(def (admit-task tasks name)
  (unless (.slot? tasks name) (error "Funflow dependency has no task" name))
  (def task (validate ProcessScriptContract (.ref tasks name)))
  (unless (and (.get task check-status) (symbol-set? (.get task needs)))
    (error "Funflow task requires a checked Ops action and distinct dependencies" name))
  ;; Preflight the callback without freezing a receiver-dependent .run slot.
  ;; Workspace refinement below must still bind the actual derived script.
  (task-run task)
  task)
(def (job-graph job)
  (let* ((tasks (.get job tasks)) (roots (.get job selected))
         (cleanup-names (.get job finalizers))
         (visited (make-hash-table-eq)) (edges '())
         (incoming (make-hash-table-eq)) (outgoing (make-hash-table-eq))
         (codes '()))
    (unless (and (symbol-set? roots) (symbol-set? cleanup-names))
      (error "Funflow targets and finalizers must be distinct symbol lists"))
    (def (visit name names)
      (if (hash-key? visited name)
        names
        (begin
          (hash-put! visited name #t)
          (let (needs (.get (admit-task tasks name) needs))
            (hash-put! incoming name needs)
            (when (pair? needs)
              (set! codes (cons (cons name (.cc Computation. reads: needs)) codes)))
            (cons name
              (foldl (lambda (dependency prior)
                       (let (next (visit dependency prior))
                         (set! edges (cons (yuanxu-graph-edge dependency name) edges))
                         (hash-put! outgoing dependency
                           (cons name (hash-ref outgoing dependency '())))
                         next))
                     names needs))))))
    (def keys (reverse (foldl visit '() roots)))
    ;; Finalizers are exceptional-exit edges, not successful dependency edges.
    ;; Their trigger must be in the selected closure and they cannot spawn a
    ;; second unselected dependency closure while handling failure.
    (for-each
      (lambda (name)
        (let* ((task (admit-task tasks name)) (trigger (.get task after-start)))
          (unless (and (not (hash-key? visited name)) (null? (.get task needs))
                       (symbol? trigger) (hash-key? visited trigger))
            (error "invalid Funflow finalizer trigger" name trigger)))) cleanup-names)
    (def scheduled
      (with-catch
        (lambda (cause)
          (if (and (schedule.failure? cause) (eq? (schedule.failure-kind cause) 'cycle))
            (error "Funflow task dependency cycle" roots)
            (raise cause)))
        (lambda () (schedule.schedule-owned keys codes))))
    (def ranks (make-hash-table-eq))
    (for-each
      (lambda (key)
        (hash-put! ranks key
          (foldl (lambda (dep rank) (max rank (+ 1 (hash-ref ranks dep))))
                 0 (hash-ref incoming key))))
      (schedule.schedule-order scheduled))
    ;; The POO schedule validates the dependencies. Within each executable
    ;; wave, preserve the public FIFO order in which jobs become ready.
    (def roots-in-order (filter (lambda (key) (zero? (hash-ref ranks key))) keys))
    (def seen (make-hash-table-eq))
    (def order-value
      (let loop ((wave roots-in-order) (rank 0) (ordered '()))
        (if (null? wave)
          (reverse ordered)
          (let (next
                (foldl
                  (lambda (key pending)
                    (foldl
                      (lambda (target rest)
                        (if (and (= (hash-ref ranks target) (+ rank 1))
                                 (not (hash-key? seen target)))
                          (begin (hash-put! seen target #t) (cons target rest))
                          rest))
                      pending (hash-ref outgoing key '())))
                  '() (reverse wave)))
            (loop next (+ rank 1) (foldl cons ordered wave))))))
    (.o graph: (yuanxu-graph (.get job name) (map yuanxu-graph-node keys) (reverse edges))
        order: order-value finalizers: cleanup-names)))

(def (job-results-type job)
  (apply Record
    (foldr (lambda (name fields)
             (cons (string->keyword (symbol->string name))
               (cons (list ProcessResultContract optional: #t) fields)))
           '() (.all-slots (.get job tasks)))))
(def (job-flow job projection workspace)
  (def Results (job-results-type job))
  (def submit-signature (Fun AdapterResult <- Results))
  (def result-signature (Fun Results <- AdapterResult))
  ;; The ordered route is already known. Construct its native Tasks directly
  ;; and validate the whole route once, with the same typed effect/result edges.
  (def steps
    (apply append
      (map (lambda (name)
             (def script (.cc (admit-task (.get job tasks) name) 'directory workspace))
             (def result-name
               (string->symbol (string-append (symbol->string name) "/result-map")))
             (list (make-external-task name 'ops script submit-signature)
                   (make-pure-task result-name result-signature adapter-result-value)))
           (.get projection order))))
  (flow-compose (.get job name) steps (Fun Results <- Results)))
(def (unsupported-ops-operation _value)
  (error "Job Ops interpreter does not provide fetch or Store operations"))
(def (run-job job workspace)
  (unless (string? workspace) (error "Funflow execution requires a workspace" workspace))
  (let* ((projection (job-graph job)) (started (make-hash-table-eq))
         (results (.o)) (flow-receipt-value #f) (cleanup-failures '()) (primary-failure #f))
    (def (execute name script)
      (hash-put! started name #t)
      (let (receipt ((task-run script)))
        (set! results (.cc results name receipt))
        receipt))
    (def (submit request)
      (let* ((declaration (execution-request-request request))
             (name (execution-request-name request)))
        (unless (and (eq? (cadr declaration) 'ops) (object? (caddr declaration)))
          (error "Job Ops interpreter received a foreign request" name))
        (execute name (caddr declaration))
        ;; The next Flow receives the accumulated immutable result object.
        (make-adapter-result (list 'ops name) 'completed results #f #f)))
    (def (finalize)
      (for-each
        (lambda (name)
          (let (task (admit-task (.get job tasks) name))
            (when (hash-key? started (.get task after-start))
              (with-catch
                (lambda (failure) (set! cleanup-failures (cons (cons name failure) cleanup-failures)))
                (lambda () (execute name (.cc task 'directory workspace)))))))
        (.get projection finalizers)))
    (with-catch
      (lambda (failure) (set! primary-failure failure))
      (lambda ()
        (dynamic-wind void
          (lambda ()
            (let* ((adapter ((.get job-runtime adapter make-runtime-adapter) 'ops '(external) submit
                              unsupported-ops-operation unsupported-ops-operation unsupported-ops-operation))
                   (runtime (.get job-runtime runner))
                   (runner ((.get runtime make-runner) (make-local-eager-strategy) adapter))
                   (outcome ((.get runtime runner-run) runner (job-flow job projection workspace) (.o))))
              (set! results ((.get runtime run-result-value) outcome))
              (set! flow-receipt-value ((.get runtime run-result-receipt) outcome))))
          finalize)))
    (when (pair? cleanup-failures)
      (error "Funflow finalizer failed" primary-failure (reverse cleanup-failures)))
    (when primary-failure (raise primary-failure))
    (.o steps: results flow-receipt: flow-receipt-value)))
