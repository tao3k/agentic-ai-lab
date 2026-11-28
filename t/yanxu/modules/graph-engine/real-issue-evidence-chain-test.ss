;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Real-World GitHub Issue Evidence Chain Suite (`real-issue-evidence-chain-test.ss`):
;;; Reproduces and proves structural closure of 6 documented production failure
;;; classes from `anthropics/claude-code` and `openai/codex`:
;;;   1. Claude Code #25000 / #23983: Subagent deny-rule bypass & multi-hop escalation
;;;   2. Claude Code #107019 / #6036: Stale child workspace cut & indirect bash bypass
;;;   3. Codex #34043 / #54855:       Session resume deadlock / unclosed subagent hang
;;;   4. Codex #51116 / #15305:       Async Cedar revocation & grant-epoch TOCTOU race
;;;   5. Claude #6004/#2222/#9766 & Codex #20830/#26745: Compaction / self-fix infinite loop
;;;   6. Claude #47695 & Codex #51799: Approval prompt infinite loop (idempotent event resume)

(import :std/test
        (only-in :clan/poo/object .o .ref)
        (only-in :clan/poo/number Integer)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/api
                 make-pure-task Fun task-flow
                 make-runner make-local-eager-strategy make-request-only-adapter)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/cas-store
                 make-funflow-cas-store)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/governed-runner
                 make-governed-funflow-runner)
        (only-in :tao3k/agentic-ai-lab/modules/graph-engine/obligation-graph
                 make-obligation make-evidence-fact
                 make-deterministic-task-node make-synthesis-hole
                 make-obligation-graph)
        (only-in :tao3k/agentic-ai-lab/modules/graph-engine/ascent-reconciler
                 ascent-reconcile-frontier)
        (only-in :tao3k/agentic-ai-lab/modules/graph-engine/synthesis-oracle
                 make-raw-tool-call-proposal
                 admit-synthesis-proposal
                 reconcile-to-fixed-point
                 reconcile-event-stream)
        (only-in :tao3k/agentic-ai-lab/modules/graph-engine/durable-event-bridge
                 work-snapshot->obligation-graph
                 durable-journal-event->obligation-event)
        (only-in :tao3k/agentic-ai-lab/modules/graph-engine/delegation-fence
                 make-capability-envelope
                 capability-permitted?
                 attenuate-delegation-envelope
                 make-delegated-obligation-token
                 admit-delegated-execution-fence
                 parent-completion-admitted?))

(export real-issue-evidence-chain-test)

(def (make-pure-runner)
  (make-governed-funflow-runner
   (make-runner (make-local-eager-strategy) (make-request-only-adapter))
   cas-store: (make-funflow-cas-store)
   env-digest: "sha256:real-issue-env-v1"))

(def real-issue-evidence-chain-test
  (test-suite "Real-World Codex & Claude Code Issue Evidence Chain (Slices 57 & 58)"

    ;; 1. Claude Code #25000 & #23983: Subagent deny-rule bypass & multi-hop privilege escalation
    (test-case "Issue #25000/#23983: Multi-hop subagent delegation strictly obeys parent denylist & attenuation"
      (let* ((root-env (make-capability-envelope
                        "agent:root"
                        allowed-caps: '(fs-read fs-write git-status bash-exec)
                        denied-caps: '(bash-exec secret-read)
                        egress-allowed?: #f))
             ;; Child requests bash-exec, secret-read, fs-read, fs-write + network egress
             (child-env (attenuate-delegation-envelope
                         root-env "agent:child"
                         '(fs-read fs-write bash-exec secret-read deploy-prod)
                         extra-denied-caps: '(fs-write)
                         requested-egress?: #t))
             ;; Grandchild tries to re-request fs-write and bash-exec
             (grandchild-env (attenuate-delegation-envelope
                              child-env "agent:grandchild"
                              '(fs-read fs-write bash-exec)))
             (tok (make-delegated-obligation-token
                   "agent:child" "agent:grandchild" "O-audit" grandchild-env 1 1))
             (try-bash (admit-delegated-execution-fence tok 'bash-exec live-cut: 1 live-grant-epoch: 1))
             (try-write (admit-delegated-execution-fence tok 'fs-write live-cut: 1 live-grant-epoch: 1))
             (try-read (admit-delegated-execution-fence tok 'fs-read live-cut: 1 live-grant-epoch: 1)))
        (check-equal? (capability-permitted? child-env 'bash-exec) #f)
        (check-equal? (capability-permitted? child-env 'deploy-prod) #f)
        (check-equal? (.ref child-env 'egress-allowed?) #f)
        (check-equal? (capability-permitted? grandchild-env 'fs-write) #f)
        (check-equal? (capability-permitted? grandchild-env 'fs-read) #t)
        (check-equal? (.ref try-bash 'admitted?) #f)
        (check-equal? (.ref try-bash 'reason) 'parent-denylist-or-attenuation-denied)
        (check-equal? (.ref try-write 'admitted?) #f)
        (check-equal? (.ref try-read 'admitted?) #t)))

    ;; 2. Claude Code #107019 & #6036: Stale child workspace cut & indirect bash bypass
    (test-case "Issue #107019/#6036: Stale child cut & raw shell bypass are both rejected fail-closed"
      (let* ((env (make-capability-envelope "agent:child" allowed-caps: '(fs-read)))
             (tok (make-delegated-obligation-token "agent:root" "agent:child" "O-read" env 1 1))
             ;; Workspace transitioned from cut 1 -> cut 2 before child executed
             (stale-try (admit-delegated-execution-fence tok 'fs-read live-cut: 2 live-grant-epoch: 1))
             ;; Indirect bash bypass attempt (`find /etc -exec grep ...`) from oracle
             (raw-bash (admit-synthesis-proposal (make-raw-tool-call-proposal 'bash '("find /etc -exec grep secret {} +")))))
        (check-equal? (.ref stale-try 'admitted?) #f)
        (check-equal? (.ref stale-try 'reason) 'stale-child-context-cut-blocked)
        (check-equal? (.ref raw-bash 'admitted?) #f)
        (check-equal? (.ref raw-bash 'reason) 'raw-single-step-tool-call-forbidden)))

    ;; 3. Codex #34043 & #54855: Session resume deadlock / unclosed subagent hang -> Durable bridge recovery
    (test-case "Issue #34043/#54855: Unclosed subagent attempt surfaces explicit defeater and recovers cleanly via event stream"
      (let* ((snap (.o task-id: "task-codex-34043"
                       root-id: "root-main"
                       root-title: "Resume interrupted subagent"
                       root-status: 'done
                       dag-nodes: '()
                       open-blocker-detours: '()
                       unsatisfied-invariants: '()))
             (journal-crashed (.o unclosed-attempts: '("subagent-7")
                                  completed-node-ids: '()
                                  cedar-grant-live?: #t))
             (g0 (work-snapshot->obligation-graph snap journal-crashed))
             (f0 (ascent-reconcile-frontier g0))
             (parent-check-before (parent-completion-admitted? #t '("subagent-7") '("unclosed-attempt:subagent-7")))
             ;; Explicit recovery event reconciles subagent-7 without hanging!
             (ev-recover (durable-journal-event->obligation-event
                          (.o work-event-kind: 'work-attempt-recovered
                              attempt-id: "subagent-7")))
             (ev-rep (reconcile-event-stream g0 (list ev-recover) funflow-runner: (make-pure-runner)))
             (parent-check-after (parent-completion-admitted? #t '() '())))
        ;; Before recovery: root is unsatisfied & blocked-on-human (never silently hangs or archives!)
        (check-equal? (length (.ref f0 'unsatisfied-obligations)) 1)
        (check-equal? (length (.ref f0 'blocked-on-human-obligations)) 1)
        (check-equal? (.ref parent-check-before 'admitted?) #f)
        (check-equal? (.ref parent-check-before 'reason) 'unclosed-subagent-attempt-requires-recovery)
        ;; After recovery event: root discharges cleanly with 0 LLM calls!
        (check-equal? (length (.ref (.ref ev-rep 'final-frontier) 'discharged-obligations)) 1)
        (check-equal? (length (.ref (.ref ev-rep 'final-frontier) 'unsatisfied-obligations)) 0)
        (check-equal? (.ref ev-rep 'total-llm-calls) 0)
        (check-equal? (.ref parent-check-after 'admitted?) #t)))

    ;; 4. Codex #51116 / #15305 + Async Cedar Revocation TOCTOU
    (test-case "Issue #51116/#15305: Concurrent Cedar grant revocation & epoch drift block child TOCTOU atomically"
      (let* ((env (make-capability-envelope "agent:child" allowed-caps: '(fs-write)))
             (tok (make-delegated-obligation-token "agent:root" "agent:child" "O-edit" env 1 1))
             (revoked-try (admit-delegated-execution-fence
                           tok 'fs-write live-cut: 1 live-grant-epoch: 1 parent-grant-live?: #f))
             (epoch-try (admit-delegated-execution-fence
                         tok 'fs-write live-cut: 1 live-grant-epoch: 2 parent-grant-live?: #t)))
        (check-equal? (.ref revoked-try 'admitted?) #f)
        (check-equal? (.ref revoked-try 'reason) 'cedar-parent-grant-revoked)
        (check-equal? (.ref epoch-try 'admitted?) #f)
        (check-equal? (.ref epoch-try 'reason) 'cedar-grant-epoch-drifted)))

    ;; 5. Claude #6004/#2222/#9766 & Codex #20830/#26745: Compaction / self-fix infinite loop immunity
    (test-case "Issue #6004/#20830: Compaction/self-fix thrashing terminates in 1 evaluation via (hole, premiseDigest) lock"
      (let* ((calls (box 0))
             (ob (make-obligation "O-compact-fix" required-evidence-ids: '("E-fixed") premise-ids: '("P-ctx")))
             (hole (make-synthesis-hole "H-compact-fix" "O-compact-fix" premise-ids: '("P-ctx")))
             (g0 (make-obligation-graph "G-no-thrash"
                                        obligations: (list ob)
                                        synthesis-holes: (list hole)))
             (rep (reconcile-to-fixed-point
                   g0
                   funflow-runner: (make-pure-runner)
                   oracle-fn: (lambda (_h _ctx _hyps)
                                (set-box! calls (+ 1 (unbox calls)))
                                #f))))
        (check-equal? (.ref rep 'quiescent?) #t)
        (check-equal? (unbox calls) 1)))

    ;; 6. Claude #47695 & Codex #51799: Approval prompt infinite loop eliminated by event-driven deterministic resume
    (test-case "Issue #47695/#51799: Human approval restores Cedar grant and discharges FunFlow task directly with 0 re-prompts"
      (let* ((sig (Fun Integer <- Integer))
             (f-op (task-flow 'ws-op (make-pure-task 'ws-op sig (lambda (x) (+ x 1)))))
             (snap (.o task-id: "task-47695"
                       root-id: "root-ws"
                       root-title: "Workspace write after approval"
                       root-status: 'todo
                       dag-nodes: (list (.o id: "ws-op" deps: '()))
                       open-blocker-detours: '()
                       unsatisfied-invariants: '()))
             (journal-blocked (.o unclosed-attempts: '() completed-node-ids: '() cedar-grant-live?: #f))
             (t-ws (make-deterministic-task-node "T-ws" "ws-op" "ev:node:ws-op" f-op 41
                                                 premise-ids: '("premise:ws-op")))
             (g0 (work-snapshot->obligation-graph snap journal-blocked det-tasks: (list t-ws)))
             (ev-approve (durable-journal-event->obligation-event
                          (.o work-event-kind: 'work-human-approved)))
             (ev-rep (reconcile-event-stream g0 (list ev-approve) funflow-runner: (make-pure-runner)))
             (epochs (.ref ev-rep 'reconcile-epochs)))
        ;; Epoch 0 (before approval): blocked-on-governance with 0 det runs, 0 LLM calls
        (check-equal? (.ref (car epochs) 'final-mode) 'blocked-on-governance)
        (check-equal? (.ref (car epochs) 'total-det-tasks) 0)
        ;; Epoch 1 (after single approval): runs deterministic task ONCE and discharges cleanly with 0 LLM calls!
        (check-equal? (.ref (cadr epochs) 'quiescent?) #t)
        (check-equal? (.ref (cadr epochs) 'total-det-tasks) 1)
        (check-equal? (.ref ev-rep 'total-llm-calls) 0)
        (check-equal? (length (.ref (.ref ev-rep 'final-frontier) 'discharged-obligations)) 2)))))
