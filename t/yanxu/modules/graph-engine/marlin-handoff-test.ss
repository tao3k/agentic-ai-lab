;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Scheme -> Marlin (`marlin-agent-core`) Dispatch Envelope, Flat Wire ABI,
;;; Fencing-Epoch Anti-Split-Brain Guard & Optional `+sqlite-turso` Round-Trip
;;; Tests (`t/yanxu/modules/graph-engine/marlin-handoff-test.ss`).

(import :std/test
        (only-in :clan/poo/object .o .ref object?)
        (only-in :tao3k/agentic-ai-lab/modules/nono-sandbox/profile-interface
                 nono-sandbox-profile)
        :tao3k/agentic-ai-lab/modules/graph-engine/interface
        :tao3k/agentic-ai-lab/modules/graph-engine/features/sqlite-turso/adapter)

(export marlin-handoff-test)

(def (make-sample-trunk trunk-id apex-id)
  (let* ((env (make-capability-envelope
               "actor-owner"
               allowed-caps: '(context-read repo-scan verify-build)
               denied-caps: '(host-egress shell-exec)
               egress-allowed?: #f))
         (ob-a (make-obligation "ob-a"
                                title: "Collect Context"
                                required-evidence-ids: '("ev-a")))
         (ob-apex (make-obligation apex-id
                                   title: "Converge Mission"
                                   required-evidence-ids: '("ev-a")
                                   depends-on: '("ob-a")))
         (g (make-obligation-graph
             (string-append "g-" trunk-id)
             cut: 1
             obligations: (list ob-a ob-apex)
             evidence: '()
             det-tasks: '())))
    (make-context-trunk trunk-id apex-id g env
                        shared-context-cut: 1
                        kv-prefix-digest: "sha256:shared-structural-prefix")))

(def (no-poo-objects-in-alist? alist)
  (cond
   ((null? alist) #t)
   ((pair? alist)
    (and (not (object? (car alist)))
         (not (object? (cdr (car alist))))
         (no-poo-objects-in-alist? (cdr alist))))
   (else #f)))

(def marlin-handoff-test
  (test-suite "GraphEngine -> Marlin Dispatch Envelope, ABI Projection & Fencing Reconciliation"

    (test-case "Fail-closed pre-handoff gate blocks Lethal Trifecta, detached journal writes, blocked joins & settled actors"
      (let* ((trunk (make-sample-trunk "trunk-fc" "ob-apex"))
             (actor (make-task-actor "task-fc" trunk '(scope/core)))
             (env (make-capability-envelope "owner" allowed-caps: '(context-read) denied-caps: '()))
             (detached (make-open-focus-actor "adhoc-q" '(scope/detached) env scope-mode: 'detached))
             ;; 1. Lethal Trifecta denied sandbox admission MUST fail-closed!
             (egress-profile (.o (:: @ nono-sandbox-profile)
                                 egress-enabled?: #t))
             (bad-sbx (admit-graph-nono-sandbox
                       profile: egress-profile
                       has-untrusted-input?: #t
                       has-private-data?: #t
                       egress-endorsed?: #f))
             (d-sbx (make-graph-marlin-dispatch actor sandbox-admission: bad-sbx))
             ;; 2. Detached actor targeting project Turso journal MUST fail-closed!
             (d-det (make-graph-marlin-dispatch detached substrate-target: 'sqlite-turso))
             ;; 3. Settled actor cannot be dispatched for execute-frontier!
             (settled (.ref (settle-task-actor actor (make-task-actor-index) outcome: 'cancelled) 'actor))
             (d-settled (make-graph-marlin-dispatch settled operation: 'execute-frontier)))
        (check (.ref d-sbx 'admitted?) => #f)
        (check (and (member 'sandbox-admission-denied (.ref d-sbx 'errors)) #t) => #t)
        (check (.ref d-det 'admitted?) => #f)
        (check (and (member 'detached-actor-cannot-write-project-journal (.ref d-det 'errors)) #t) => #t)
        (check (.ref d-settled 'admitted?) => #f)
        (check (and (member 'task-actor-not-dispatchable (.ref d-settled 'errors)) #t) => #t)))

    (test-case "Valid Marlin dispatch projects to flat POO-free ABI alist and enforces C4 Steering anti-split-brain"
      (let* ((trunk (make-sample-trunk "trunk-dfg" "ob-apex"))
             (a0 (make-task-actor "task-dfg" trunk '(scope/core) title: "Main Trunk A->D->F->G"))
             ;; Derive D1 and D2 off D targeting join point F
             (m1 (make-steering-message "s1" 'branch "D1" c4-priority: 1
                                        anchor-node-id: "D" join-node-id: "F"
                                        branch-id: "D1" target-obligation-id: "ob-a"))
             (m2 (make-steering-message "s2" 'branch "D2" c4-priority: 2
                                        anchor-node-id: "D" join-node-id: "F"
                                        branch-id: "D2" target-obligation-id: "ob-a"))
             (a1 (.ref (steer-task-actor a0 m1) 'actor))
             (a2 (.ref (steer-task-actor a1 m2) 'actor))
             ;; Attempting continue-trunk at F while D1/D2 are in-flight MUST be blocked!
             (d-blocked (make-graph-marlin-dispatch a2 operation: 'continue-trunk join-node-id: "F"))
             ;; Dispatching the branch wave with valid Cedar + Nono sandbox SUCCEEDS
             (cedar (make-graph-cedar-handoff "pol/graph-dfg" "permit(principal, action, resource);" "trunk-dfg"))
             (sbx (admit-graph-nono-sandbox has-untrusted-input?: #f has-private-data?: #f))
             (d-ok (make-graph-marlin-dispatch
                    a2
                    operation: 'execute-branch
                    cedar-handoff: cedar
                    sandbox-admission: sbx
                    substrate-target: 'marlin-store))
             (env (.ref d-ok 'envelope))
             (abi-alist (graph-marlin-dispatch->alist env)))
        (check (.ref d-blocked 'admitted?) => #f)
        (check (and (member 'required-branches-still-in-flight (.ref d-blocked 'errors)) #t) => #t)
        (check (.ref d-ok 'admitted?) => #t)
        (check (marlin-dispatch-envelope? env) => #t)
        (check (no-poo-objects-in-alist? abi-alist) => #t)
        (check (cdr (assq 'runtime-owner abi-alist)) => "marlin-agent-core")
        (check (cdr (assq 'handoff-required? abi-alist)) => #t)
        (check (cdr (assq 'runtime-executed? abi-alist)) => #f)
        (check (cdr (assq 'runtime-parses-scheme-source? abi-alist)) => #f)
        (check (cdr (assq 'scheme-manufactures-runtime-handlers? abi-alist)) => #f)
        (check (cdr (assq 'session-free? abi-alist)) => #t)
        (check (cdr (assq 'cedar-policy-valid? abi-alist)) => #t)
        (check (cdr (assq 'sandbox-admitted? abi-alist)) => #t)
        ;; 7-slot C-ABI dispatch vector matches marlin_graph_engine_dispatch_vector with zero POO objects!
        (let ((c-vec (graph-marlin-dispatch->c-abi-vector env)))
          (check (vector? c-vec) => #t)
          (check (vector-length c-vec) => 7)
          (check (vector-ref c-vec 1) => "task-dfg")
          (check (vector-ref c-vec 2) => 'apply-steering)
          (check (vector-ref c-vec 3) => (.ref a2 'fencing-epoch))
          (check (vector-ref c-vec 4) => 'project)
          (check (vector-ref c-vec 6) => 'sqlite-turso))
        ;; Design 165 / MAR-GRAPH-R06: blocker-active Scoped Detour blocks commit-settlement!
        (let ((d-blocker (make-graph-marlin-dispatch
                          a2
                          operation: 'commit-settlement
                          detour-mode: 'blocker-active)))
          (check (.ref d-blocker 'admitted?) => #f)
          (check (and (member 'blocker-detour-blocks-settlement (.ref d-blocker 'errors)) #t) => #t))
        ;; Reconcile fresh Marlin receipt completing D1 & D2 -> opens join F for continue-trunk!
        (let* ((rcpt (make-marlin-execution-receipt
                      (.ref env 'request-id)
                      "task-dfg"
                      (.ref a2 'fencing-epoch)
                      status: 'ok
                      journal-epoch: 2
                      chain-head-hash: "sha256:marlin-head-2"
                      branch-outcomes: '(("D1" . completed) ("D2" . completed))))
               (rec (reconcile-marlin-execution-receipt a2 rcpt join-node-id: "F"))
               (a3 (.ref rec 'actor))
               (d-cont (make-graph-marlin-dispatch a3 operation: 'continue-trunk join-node-id: "F")))
          (check (.ref rec 'accepted?) => #t)
          (check (.ref rec 'next-action) => 'continue-trunk)
          (check (.ref (.ref rec 'join-gate) 'can-continue?) => #t)
          (check (.ref d-cont 'admitted?) => #t))
        ;; Mid-flight C4 Trunk Steering pivot bumps fencing-epoch -> stale Marlin receipt REJECTED!
        (let* ((pivot (make-steering-message "s-pivot" 'trunk "Pivot trunk" c4-priority: 0))
               (a-pivoted (.ref (steer-task-actor a2 pivot) 'actor))
               (stale-rcpt (make-marlin-execution-receipt
                            (.ref env 'request-id)
                            "task-dfg"
                            1  ;; stale fencing epoch!
                            status: 'ok
                            branch-outcomes: '(("D1" . completed))))
               (rec-stale (reconcile-marlin-execution-receipt a-pivoted stale-rcpt join-node-id: "F")))
          (check (.ref a-pivoted 'fencing-epoch) => 2)
          (check (.ref rec-stale 'accepted?) => #f)
          (check (.ref rec-stale 'reason) => 'stale-fencing-epoch))))

    (test-case "Live optional +sqlite-turso adapter executes MarlinDispatchEnvelope and emits verifiable receipt"
      (let* ((db-path (string-append "/tmp/graph-engine-marlin-handoff-"
                                     (number->string (inexact->exact (floor (time->seconds (current-time)))))
                                     ".db"))
             (trunk (make-sample-trunk "trunk-turso" "ob-apex"))
             (a0 (make-task-actor "task-turso" trunk '(scope/core)))
             (m1 (make-steering-message "s1" 'branch "D1" c4-priority: 1
                                        anchor-node-id: "D" join-node-id: "F"
                                        branch-id: "D1" target-obligation-id: "ob-a"))
             (a1 (.ref (steer-task-actor a0 m1) 'actor))
             (jh (plan-trunk-journal-handoff "ev:marlin-step-1" "branch-D1-exec" (.ref a1 'trunk)))
             (d-res (make-graph-marlin-dispatch
                     a1
                     operation: 'execute-branch
                     journal-handoff: jh
                     substrate-target: 'sqlite-turso))
             (env (.ref d-res 'envelope))
             (j (durable-trunk-open db-path)))
        (try
          (let* ((rcpt (durable-trunk-execute-marlin-dispatch!
                        j env
                        branch-outcomes: '(("D1" . completed))
                        executed-wave-ids: '("wave-0")))
                 (rec (reconcile-marlin-execution-receipt a1 rcpt join-node-id: "F")))
            (check (.ref d-res 'admitted?) => #t)
            (check (marlin-execution-receipt? rcpt) => #t)
            (check (.ref rcpt 'substrate) => 'sqlite-turso)
            (check (> (.ref rcpt 'journal-epoch) 0) => #t)
            (check (string? (.ref rcpt 'chain-head-hash)) => #t)
            (check (.ref rec 'accepted?) => #t)
            (check (.ref rec 'next-action) => 'continue-trunk)
            (displayln "GRAPH-ENGINE-MARLIN-HANDOFF-ROUNDTRIP-OK"))
          (finally
            (durable-trunk-close! j)
            (when (file-exists? db-path) (delete-file db-path))
            (when (file-exists? (string-append db-path "-wal"))
              (delete-file (string-append db-path "-wal")))
            (when (file-exists? (string-append db-path "-shm"))
              (delete-file (string-append db-path "-shm")))))))))
