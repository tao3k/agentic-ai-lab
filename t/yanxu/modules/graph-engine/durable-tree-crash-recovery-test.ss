;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Process-Level Crash -> Restart -> SQLite WAL Journal Recovery Test for
;;; GraphEngine Convergent Trees (`durable-tree-journal.ss`).
;;;
;;; Verifies:
;;;   1. Real SQLite WAL journal commits inert Trunk snapshots + immutable evidence
;;;   2. Hard close (crash) + fresh reopen increments monotonic owner epoch (1 -> 2)
;;;   3. Epoch fencing rejects writes from any superseded stale journal handle
;;;   4. Recovered Trunk preserves unclosed required branches & blocks premature Apex
;;;   5. Completing & absorbing branches post-crash converges to Apex, seals durable
;;;      terminal, and verifies cleanly on a 3rd reopen (`epoch == 3`)!

(import :std/test
        (only-in :std/list/list filter)
        (only-in :std/os/pid getpid)
        (only-in :clan/poo/object .o .ref)
        (only-in :clan/poo/number Integer)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/api
                 make-pure-task Fun task-flow
                 make-runner make-local-eager-strategy
                 make-request-only-adapter)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/cas-store
                 make-funflow-cas-store)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/governed-runner
                 make-governed-funflow-runner)
        (only-in :tao3k/agentic-ai-lab/modules/graph-engine/obligation-graph
                 make-obligation
                 make-evidence-fact
                 make-deterministic-task-node
                 make-obligation-graph)
        (only-in :tao3k/agentic-ai-lab/modules/graph-engine/delegation-fence
                 make-capability-envelope)
        (only-in :tao3k/agentic-ai-lab/modules/graph-engine/convergent-tree
                 make-context-trunk
                 spawn-trunk-branch
                 execute-branch-funflow-dag
                 make-branch-contribution
                 absorb-branch-contribution
                 converge-trunk-to-apex)
        (only-in :tao3k/agentic-ai-lab/modules/graph-engine/features/sqlite-turso/adapter
                 plan-turso-substrate-envelope
                 durable-trunk-open
                 durable-trunk-close!
                 durable-trunk-commit-step!
                 durable-trunk-recover))

(export graph-engine-durable-tree-crash-recovery-test)

(def (make-pure-runner)
  (make-governed-funflow-runner
   (make-runner (make-local-eager-strategy) (make-request-only-adapter))
   cas-store: (make-funflow-cas-store)
   env-digest: "sha256:durable-crash-env-v1"))

(def (mk-pure-flow tag)
  (task-flow tag (make-pure-task tag (Fun Integer <- Integer) (lambda (x) (+ x 10)))))

(def (cleanup-sqlite path)
  (for-each (lambda (p) (when (file-exists? p) (delete-file p)))
            (list path (string-append path "-wal") (string-append path "-shm"))))

(def graph-engine-durable-tree-crash-recovery-test
  (test-suite "GraphEngine Durable SQLite WAL Crash/Restart Recovery"

    (test-case "survives hard crash mid-branch, enforces owner epoch fencing, and converges to Apex cleanly after restart"
      (let* ((db-path (string-append "/tmp/graph-engine-durable-tree-"
                                     (number->string (getpid))
                                     ".sqlite"))
             (f-diag (mk-pure-flow 'diag-trunk))
             (f-sub (mk-pure-flow 'subtask-patch))
             (flow-registry (list (cons "diag-trunk" f-diag))))
        (cleanup-sqlite db-path)
        (try
          ;; --- EPOCH 1: Start Trunk, spawn 2 required branches, commit mid-flight, then CRASH! ---
          (let* ((j1 (durable-trunk-open db-path))
                 (env (make-capability-envelope
                       "trunk-durable-1"
                       allowed-caps: '(read-file run-subdag)
                       denied-caps: '(raw-bash-exec)))
                 (ob-apex (make-obligation
                           "ob-durable-apex"
                           required-evidence-ids: '("ev-diag-trunk" "ev-spec" "ev-subtask")))
                 (t-diag (make-deterministic-task-node
                          "diag-trunk" "ob-durable-apex" "ev-diag-trunk" f-diag 7
                          read-footprint: '(repo-ro) write-footprint: '()))
                 (g0 (make-obligation-graph "g-durable"
                                            cut: 1
                                            obligations: (list ob-apex)
                                            det-tasks: (list t-diag)))
                 (trunk0 (make-context-trunk "trunk-dur-1" "ob-durable-apex" g0 env))
                 (sp1 (spawn-trunk-branch trunk0 "b-subtask" 'subordinate-task
                                          '(run-subdag) "ob-durable-apex" c4-priority: 2))
                 (sp2 (spawn-trunk-branch (.ref sp1 'trunk) "b-enrichment" 'context-enrichment-detour
                                          '(read-file) "ob-durable-apex" c4-priority: 1))
                 (trunk-mid (.ref sp2 'trunk))
                 (c1 (durable-trunk-commit-step! j1 "ev-step-1-spawn"
                                                 (.o bind-these: #f action: 'spawn-branches)
                                                 trunk-mid)))
            (check (.ref c1 'committed?) => #t)
            (check (.ref c1 'journal-epoch) => 1)

            ;; --- EPOCH 2: Simulate process crash/takeover by opening j2 BEFORE closing j1! ---
            (let* ((j2 (durable-trunk-open db-path))
                   ;; Stale epoch-1 handle MUST be fenced out on attempted write!
                   (stale-rejected?
                    (with-catch
                      (lambda (_e) #t)
                      (lambda ()
                        (durable-trunk-commit-step! j1 "ev-stale-zombie"
                                                    (.o bind-these: #f action: 'zombie-write)
                                                    trunk-mid)
                        #f)))
                   (_ (durable-trunk-close! j1))
                   ;; Recover Trunk purely from SQLite inert snapshot + hash-chain verify!
                   (rec (durable-trunk-recover j2 task-flow-registry: flow-registry))
                   (trunk-rec (.ref rec 'trunk))
                   ;; Premature Apex MUST still be blocked post-crash because both branches are unclosed!
                   (runner (make-pure-runner))
                   (premature (converge-trunk-to-apex trunk-rec funflow-runner: runner)))
              (check stale-rejected? => #t)
              (check (.ref rec 'recovered?) => #t)
              (check (.ref rec 'journal-epoch) => 2)
              (check (.ref rec 'needs-branch-reconciliation?) => #t)
              (check (length (.ref rec 'open-required-branch-ids)) => 2)
              (check (.ref premature 'converged?) => #f)
              (check (.ref premature 'reason) => 'unclosed-serving-branches-remaining)

              ;; Now complete both recovered branches and converge Trunk to Apex!
              (let* ((b-sub (car (filter (lambda (b) (equal? (.ref b 'branch-id) "b-subtask"))
                                         (.ref trunk-rec 'branches))))
                     (b-enr (car (filter (lambda (b) (equal? (.ref b 'branch-id) "b-enrichment"))
                                         (.ref trunk-rec 'branches))))
                     (sub-node (make-deterministic-task-node
                                "subtask-build" "ob-durable-apex" "ev-subtask" f-sub 5
                                read-footprint: '(a) write-footprint: '(overlay-a)))
                     (sub-res (execute-branch-funflow-dag trunk-rec b-sub (list sub-node) 'run-subdag runner))
                     (abs1 (absorb-branch-contribution trunk-rec (.ref sub-res 'contribution)))
                     (enr-contrib (make-branch-contribution
                                   b-enr
                                   exit-kind: 'completed
                                   evidence-facts: (list (make-evidence-fact "ev-spec" 'spec-ok cut: 1))
                                   counterexample-core: '("ce-crash-recovery-verified")))
                     (abs2 (absorb-branch-contribution (.ref abs1 'trunk) enr-contrib))
                     (apex (converge-trunk-to-apex (.ref abs2 'trunk) funflow-runner: runner))
                     (trunk-done (.ref apex 'trunk))
                     (c2 (durable-trunk-commit-step! j2 "ev-step-2-apex"
                                                     (.o bind-these: #f action: 'apex-converged)
                                                     trunk-done)))
                (check (.ref sub-res 'admitted?) => #t)
                (check (.ref apex 'converged?) => #t)
                (check (.ref c2 'committed?) => #t)
                (check (.ref c2 'apex-status) => 'converged)
                (durable-trunk-close! j2)

                ;; --- EPOCH 3: Reopen cold and verify converged Apex + C4 order + counterexamples ---
                (let* ((j3 (durable-trunk-open db-path))
                       (rec3 (durable-trunk-recover j3 task-flow-registry: flow-registry))
                       (t3 (.ref rec3 'trunk))
                       (r3 (.ref t3 'apex-receipt)))
                  (check (.ref rec3 'recovered?) => #t)
                  (check (.ref rec3 'journal-epoch) => 3)
                  (check (.ref rec3 'needs-branch-reconciliation?) => #f)
                  (check (.ref t3 'apex-status) => 'converged)
                  (check (.ref r3 'absorbed-branch-ids-c4-order) => '("b-enrichment" "b-subtask"))
                  (check (and (member "ce-crash-recovery-verified" (.ref r3 'counterexample-core)) #t) => #t)
                  (durable-trunk-close! j3)))))
          (finally
            (cleanup-sqlite db-path)))))))
