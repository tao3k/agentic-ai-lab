;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Declarative POO Object Contracts (.new/checked) and shared pure utilities
;;; for the modularized Durable Orchestrator subsystem (RFC 40.183 + Slice 49).

(import (only-in :clan/poo/object .def .o .cc .ref .slot? object?)
        (only-in :clan/poo/mop .defgeneric .new/checked)
        (only-in :clan/poo/type Record String Symbol Bool OrFalse Any)
        (only-in :clan/poo/number Integer)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :std/list/list filter)
        (only-in :std/string/misc string-trim string-split)
        (only-in :tao3k/agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
                 journal-active? journal-receive! journal-begin!
                 journal-put! journal-commit! journal-abort!))

(export DurableTaskPolicyContract
        SharedContextClaimContract
        DetourReconcileContract
        DurableTaskPolicy.
        make-checked-task-policy
        make-checked-shared-claim
        node-effective-rules
        task-artifact-path
        task-funflow-dag
        task-orchestration-plan
        task-archive-transition
        project-workbench-tabs
        opt-ref
        canonical-sha256
        utf8-slice
        split-whitespace-tokens
        string-find-substr
        string-join-with
        string-trim-right
        parse-positive-int
        journal-put-fenced!)

;;; ---------------------------------------------------------------------------
;;; 1. MOP .defgeneric Protocol Surface (Single Receiver Axis)
;;; ---------------------------------------------------------------------------

(.defgeneric (node-effective-rules node org-source-text)
  slot: .effective-rules)

(.defgeneric (task-artifact-path task)
  slot: .artifact-path)

(.defgeneric (task-funflow-dag task org-source-text)
  slot: .funflow-dag)

(.defgeneric (task-orchestration-plan task org-source-text journal-state)
  slot: .orchestration-plan)

(.defgeneric (task-archive-transition task org-source-text index-source-text timestamp)
  slot: .archive-transition)

(.defgeneric (project-workbench-tabs owner task-records journal-state peek-set focused-task-id)
  slot: .project-workbench-tabs)

;;; ---------------------------------------------------------------------------
;;; 2. Declarative POO Object Contracts & Checked Constructors (.new/checked)
;;; ---------------------------------------------------------------------------

(def DurableTaskPolicyContract
  (.cc (Record kind: [Symbol]
               split-line-watermark: [Integer]
               default-focus-depth: [Integer]
               require-sod-reviewer: [Bool]
               fold-thinking-by-default: [Bool]
               allow-agent-drill-down: [Bool]
               focused-tab-archive: [Symbol]
               scratch-promotion: [Symbol]
               reopen-mode: [Symbol]
               max-concurrency: [Integer])
       identity: 'durable/task-policy))

(def SharedContextClaimContract
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
       identity: 'durable/shared-context-claim))

(def DetourReconcileContract
  (.cc (Record kind: [Symbol]
               admitted?: [Bool]
               exit-kind: [Symbol]
               reason: [Symbol])
       identity: 'durable/detour-reconcile))

(.def DurableTaskPolicy.
  kind: 'agentic-ai-lab.durable.task-policy.v1
  split-line-watermark: 800
  default-focus-depth: 2
  require-sod-reviewer: #f
  fold-thinking-by-default: #t
  allow-agent-drill-down: #t
  focused-tab-archive: 'on-blur
  scratch-promotion: 'on-plan
  reopen-mode: 'peek-until-edit
  max-concurrency: 4)

(def (make-checked-task-policy
      split-line-watermark: (wm 800)
      default-focus-depth: (fd 2)
      require-sod-reviewer: (sod #f)
      fold-thinking-by-default: (ft #t)
      allow-agent-drill-down: (dd #t)
      focused-tab-archive: (fta 'on-blur)
      scratch-promotion: (sp 'on-plan)
      reopen-mode: (rm 'peek-until-edit)
      max-concurrency: (mc 4))
  (.new/checked DurableTaskPolicyContract
    kind: 'agentic-ai-lab.durable.task-policy.v1
    split-line-watermark: wm
    default-focus-depth: fd
    require-sod-reviewer: sod
    fold-thinking-by-default: ft
    allow-agent-drill-down: dd
    focused-tab-archive: fta
    scratch-promotion: sp
    reopen-mode: rm
    max-concurrency: mc))

(def (make-checked-shared-claim nid owner cstate epoch hb ttl wt ext sp)
  (.new/checked SharedContextClaimContract
    kind: 'agentic-ai-lab.durable.shared-context-claim.v1
    node-id: nid
    owner-actor: owner
    claim-state: cstate
    claim-lease-epoch: epoch
    heartbeat-at: hb
    lease-ttl: ttl
    worktree: wt
    extends-id: ext
    span: sp))

;;; ---------------------------------------------------------------------------
;;; 3. Pure Shared Utilities & Fenced Journal Helper
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

(def (utf8-slice bytes start end)
  (utf8->string (subu8vector bytes start end)))

(def (split-whitespace-tokens text)
  (if (and (string? text) (> (string-length (string-trim text)) 0))
    (filter (lambda (tok) (> (string-length tok) 0))
            (map string-trim (string-split (string-trim text) #\space)))
    '()))

(def (string-join-with items sep)
  (if (null? items)
    ""
    (let loop ((rest (cdr items)) (acc (car items)))
      (if (null? rest)
        acc
        (loop (cdr rest) (string-append acc sep (car rest)))))))

(def (string-find-substr str sub (start-at 0))
  (let ((slen (string-length str))
        (sublen (string-length sub)))
    (if (= sublen 0)
      start-at
      (let loop ((i start-at))
        (cond
         ((> (+ i sublen) slen) #f)
         ((string=? (substring str i (+ i sublen)) sub) i)
         (else (loop (+ i 1))))))))

(def (string-trim-right s)
  (let loop ((i (string-length s)))
    (if (and (> i 0) (char-whitespace? (string-ref s (- i 1))))
      (loop (- i 1))
      (substring s 0 i))))

(def (parse-positive-int s default)
  (let ((n (and (string? s) (string->number (string-trim s)))))
    (if (and (exact-integer? n) (>= n 0)) n default)))

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
