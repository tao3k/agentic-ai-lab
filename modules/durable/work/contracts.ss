;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Pure, domain-agnostic POO ObjectContracts (.new/checked), MOP .defgeneric
;;; protocols, and fenced WAL helpers for the Durable Work Engine Core.
;;; INVARIANT: ZERO orgize imports, ZERO ai-agentic-context imports.

(import (only-in :clan/poo/object .def .o .cc .ref .slot? object?)
        (only-in :clan/poo/mop .defgeneric .new/checked)
        (only-in :clan/poo/type Record String Symbol Bool OrFalse Any List)
        (only-in :clan/poo/number Integer)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :tao3k/agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
                 journal-active? journal-receive! journal-begin!
                 journal-put! journal-commit! journal-abort!))

(export DurableWorkPolicyContract
        WorkClaimContract
        WorkSnapshotContract
        DetourReconcileContract
        DurableWorkPolicy.
        make-checked-work-policy
        make-checked-work-claim
        make-checked-work-snapshot
        work-effective-rules
        work-artifact-path
        work-funflow-dag
        work-orchestration-plan
        project-workbench-tabs
        opt-ref
        canonical-sha256
        journal-put-fenced!)

;;; ---------------------------------------------------------------------------
;;; 1. MOP .defgeneric Protocol Surface (Single Receiver Axis)
;;; ---------------------------------------------------------------------------

(.defgeneric (work-effective-rules node rule-overrides)
  slot: .effective-rules)

(.defgeneric (work-artifact-path task)
  slot: .artifact-path)

(.defgeneric (work-funflow-dag task snapshot)
  slot: .funflow-dag)

(.defgeneric (work-orchestration-plan task snapshot journal-state)
  slot: .orchestration-plan)

(.defgeneric (project-workbench-tabs owner task-records journal-state peek-set focused-task-id)
  slot: .project-workbench-tabs)

;;; ---------------------------------------------------------------------------
;;; 2. Declarative POO Object Contracts & Checked Constructors (.new/checked)
;;; ---------------------------------------------------------------------------

(def DurableWorkPolicyContract
  (.cc (Record kind: [Symbol]
               split-line-watermark: [Integer]
               default-focus-depth: [Integer]
               require-sod-reviewer: [Bool]
               fold-thinking-by-default: [Bool]
               allow-agent-drill-down: [Bool]
               focused-tab-archive: [Symbol]
               scratch-promotion: [Symbol]
               reopen-mode: [Symbol]
               max-concurrency: [Integer]
               retry-budget: [Integer]
               max-detour-depth: [Integer])
       identity: 'durable/work-policy))

(def WorkClaimContract
  (.cc (Record kind: [Symbol]
               node-id: [String]
               owner-actor: [(OrFalse String)]
               claim-state: [String]
               claim-lease-epoch: [Integer]
               heartbeat-at: [Integer]
               lease-ttl: [Integer]
               worktree: [String]
               extends-id: [(OrFalse String)]
               span: [Any])
       identity: 'durable/work-claim))

(def WorkSnapshotContract
  (.cc (Record kind: [Symbol]
               task-id: [String]
               root-id: [String]
               root-title: [String]
               root-status: [Symbol]
               root-archived?: [Bool]
               checklist-done: [Integer]
               checklist-total: [Integer]
               dag-nodes: [(List Any)]
               mainline-done: [Integer]
               mainline-total: [Integer]
               open-blocker-detours: [(List Any)]
               open-side-quests: [(List Any)]
               completed-detours: [(List Any)]
               unsatisfied-invariants: [(List Any)]
               max-detour-depth-observed: [Integer]
               return-anchor-id: [(OrFalse String)]
               claims: [(List Any)]
               rule-overrides: [Any])
       identity: 'durable/work-snapshot))

(def DetourReconcileContract
  (.cc (Record kind: [Symbol]
               admitted?: [Bool]
               exit-kind: [Symbol]
               reason: [Symbol])
       identity: 'durable/detour-reconcile))

(.def DurableWorkPolicy.
  kind: 'agentic-ai-lab.durable.work-policy.v1
  split-line-watermark: 800
  default-focus-depth: 2
  require-sod-reviewer: #f
  fold-thinking-by-default: #t
  allow-agent-drill-down: #t
  focused-tab-archive: 'on-blur
  scratch-promotion: 'on-plan
  reopen-mode: 'peek-until-edit
  max-concurrency: 4
  retry-budget: 2
  max-detour-depth: 2)

(def (make-checked-work-policy
      split-line-watermark: (wm 800)
      default-focus-depth: (fd 2)
      require-sod-reviewer: (sod #f)
      fold-thinking-by-default: (ft #t)
      allow-agent-drill-down: (dd #t)
      focused-tab-archive: (fta 'on-blur)
      scratch-promotion: (sp 'on-plan)
      reopen-mode: (rm 'peek-until-edit)
      max-concurrency: (mc 4)
      retry-budget: (rb 2)
      max-detour-depth: (md 2))
  (.new/checked DurableWorkPolicyContract
    kind: 'agentic-ai-lab.durable.work-policy.v1
    split-line-watermark: wm
    default-focus-depth: fd
    require-sod-reviewer: sod
    fold-thinking-by-default: ft
    allow-agent-drill-down: dd
    focused-tab-archive: fta
    scratch-promotion: sp
    reopen-mode: rm
    max-concurrency: mc
    retry-budget: rb
    max-detour-depth: md))

(def (make-checked-work-claim nid owner cstate epoch hb ttl wt ext sp)
  (.new/checked WorkClaimContract
    kind: 'agentic-ai-lab.durable.work-claim.v1
    node-id: nid
    owner-actor: owner
    claim-state: cstate
    claim-lease-epoch: epoch
    heartbeat-at: hb
    lease-ttl: ttl
    worktree: wt
    extends-id: ext
    span: sp))

(def (make-checked-work-snapshot
      task-id: (tid "task-default")
      root-id: (rid "root")
      root-title: (rtitle "Task")
      root-status: (rstatus 'todo)
      root-archived?: (rarch #f)
      checklist-done: (cdone 0)
      checklist-total: (ctotal 0)
      dag-nodes: (dnodes '())
      mainline-done: (mdone 0)
      mainline-total: (mtotal 0)
      open-blocker-detours: (oblockers '())
      open-side-quests: (osq '())
      completed-detours: (cdetours '())
      unsatisfied-invariants: (uinv '())
      max-detour-depth-observed: (mdepth 0)
      return-anchor-id: (ranchor #f)
      claims: (cl '())
      rule-overrides: (rov #f))
  (.new/checked WorkSnapshotContract
    kind: 'agentic-ai-lab.durable.work-snapshot.v1
    task-id: tid
    root-id: rid
    root-title: rtitle
    root-status: rstatus
    root-archived?: rarch
    checklist-done: cdone
    checklist-total: ctotal
    dag-nodes: dnodes
    mainline-done: mdone
    mainline-total: mtotal
    open-blocker-detours: oblockers
    open-side-quests: osq
    completed-detours: cdetours
    unsatisfied-invariants: uinv
    max-detour-depth-observed: mdepth
    return-anchor-id: ranchor
    claims: cl
    rule-overrides: rov))

;;; ---------------------------------------------------------------------------
;;; 3. Pure Utilities & Fenced Journal Helper
;;; ---------------------------------------------------------------------------

(def (opt-ref obj key default)
  (if (and (object? obj) (.slot? obj key))
    (.ref obj key)
    default))

(def (canonical-sha256 payload)
  (string-append
   "sha256:"
   (hex-encode
    (sha256
     (string->utf8
      (call-with-output-string (lambda (port) (write payload port))))))))

(def (journal-put-fenced! journal tx-id key value)
  (if (journal-active? journal)
    (journal-put! journal key value)
    (begin
      (journal-receive! journal tx-id value)
      (journal-begin! journal tx-id)
      (with-catch
        (lambda (err) (journal-abort! journal) (raise err))
        (lambda ()
          (journal-put! journal key value)
          (journal-commit! journal))))))
