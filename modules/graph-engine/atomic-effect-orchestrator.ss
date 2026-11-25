;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; 100% Pure Scheme POO + Functional High-Order Orchestrator over Marlin's Thin
;;; Atomic Effect Runtime (`modules/graph-engine/atomic-effect-orchestrator.ss`).
;;;
;;; ARCHITECTURAL INVARIANT:
;;;   - ALL high-level and high-order orchestration (FunFlow CAS purity & cache
;;;     decisions, Two-Zone KV-Prefix prompt assembly checks, Scoped Detour
;;;     gating, DAG frontier batch fan-out, and competing hypothesis branch
;;;     evaluation) lives 100% in Scheme POO / functional code.
;;;   - Rust (`marlin-agent-runtime::effect_pump`) is a thin, domain-agnostic
;;;     pump that executes ONLY four primitive I/O effects in parallel:
;;;       1. `llm-complete`
;;;       2. `cas-get`
;;;       3. `cas-put`
;;;       4. `sandbox-run`
;;;   - Security inference strictly preserves ALL competing hypotheses, their
;;;     evidence lineage, contradictions, and open questions. It NEVER collapses
;;;     to a single favored path, NEVER infers likelihood from missing-claim
;;;     counts, and NEVER allows hypothetical model fit to authenticate evidence,
;;;     establish historical attribution, or authorize an effect.

(import (only-in :clan/poo/object .def .o .ref .slot? object?)
        (only-in :std/list/list filter find every))

(export LlmCompleteEffect.
        CasGetEffect.
        CasPutEffect.
        SandboxRunEffect.
        AtomicEffectReceipt.
        FunflowStepSpec.
        TwoZonePromptSpec.
        CompetingHypothesis.
        HypothesisBranchProposal.
        CompetingHypothesisMatrix.
        make-llm-complete-effect
        make-cas-get-effect
        make-cas-put-effect
        make-sandbox-run-effect
        make-cas-hit-receipt
        make-cas-miss-receipt
        make-cas-stored-receipt
        make-llm-completed-receipt
        make-sandbox-exited-receipt
        make-effect-error-receipt
        make-funflow-step-spec
        make-two-zone-prompt-spec
        compute-funflow-cas-key
        plan-funflow-step-effects
        reconcile-funflow-step-receipts
        make-competing-hypothesis
        make-hypothesis-branch-proposal
        plan-competing-hypothesis-frontier
        reconcile-competing-hypothesis-matrix)

(def (opt-ref obj key default)
  (if (and (object? obj) (.slot? obj key))
    (.ref obj key)
    default))

(def (sym->str v)
  (cond
   ((string? v) v)
   ((symbol? v) (symbol->string v))
   ((number? v) (number->string v))
   (else "unknown")))

;;; ---------------------------------------------------------------------------
;;; 1. Four Canonical Atomic Effects (1:1 with Marlin `effect_pump.rs`)
;;; ---------------------------------------------------------------------------

(.def LlmCompleteEffect.
  kind: 'llm-complete
  runtime-executed?: #f)

(.def CasGetEffect.
  kind: 'cas-get
  runtime-executed?: #f)

(.def CasPutEffect.
  kind: 'cas-put
  runtime-executed?: #f)

(.def SandboxRunEffect.
  kind: 'sandbox-run
  runtime-executed?: #f)

(.def AtomicEffectReceipt.
  kind: 'agentic-ai-lab.graph-engine.atomic-effect-receipt.v1)

(def (make-llm-complete-effect effect-id endpoint messages metadata: (metadata '()))
  (.o bind-these: #f
      kind: 'llm-complete
      effect-id: effect-id
      endpoint: endpoint
      messages: messages
      metadata: metadata
      runtime-executed?: #f))

(def (make-cas-get-effect effect-id key)
  (.o bind-these: #f
      kind: 'cas-get
      effect-id: effect-id
      key: key
      runtime-executed?: #f))

(def (make-cas-put-effect effect-id key payload)
  (.o bind-these: #f
      kind: 'cas-put
      effect-id: effect-id
      key: key
      payload: payload
      runtime-executed?: #f))

(def (make-sandbox-run-effect effect-id program args cwd: (cwd #f))
  (.o bind-these: #f
      kind: 'sandbox-run
      effect-id: effect-id
      program: program
      args: args
      cwd: cwd
      runtime-executed?: #f))

(def (make-cas-hit-receipt effect-id payload)
  (.o bind-these: #f
      kind: 'cas-hit
      effect-id: effect-id
      payload: payload))

(def (make-cas-miss-receipt effect-id)
  (.o bind-these: #f
      kind: 'cas-miss
      effect-id: effect-id))

(def (make-cas-stored-receipt effect-id)
  (.o bind-these: #f
      kind: 'cas-stored
      effect-id: effect-id))

(def (make-llm-completed-receipt effect-id content)
  (.o bind-these: #f
      kind: 'llm-completed
      effect-id: effect-id
      content: content))

(def (make-sandbox-exited-receipt effect-id exit-code stdout stderr: (stderr ""))
  (.o bind-these: #f
      kind: 'sandbox-exited
      effect-id: effect-id
      exit-code: exit-code
      stdout: stdout
      stderr: stderr))

(def (make-effect-error-receipt effect-id message)
  (.o bind-these: #f
      kind: 'effect-error
      effect-id: effect-id
      message: message))

;;; ---------------------------------------------------------------------------
;;; 2. 100% Scheme FunFlow CAS Purity & Two-Zone KV-Prefix Orchestrator
;;; ---------------------------------------------------------------------------

(.def FunflowStepSpec.
  kind: 'agentic-ai-lab.graph-engine.funflow-step-spec.v1
  purity: 'pure-cas
  mutates-trunk?: #f)

(.def TwoZonePromptSpec.
  kind: 'agentic-ai-lab.graph-engine.two-zone-prompt-spec.v1
  disclosure-depth: 'L1)

(def (make-funflow-step-spec
      step-id
      purity: (purity 'pure-cas)
      input-digest: (input-digest "sha256:input-empty")
      endpoint: (endpoint "openai/gpt-marlin")
      program: (program #f)
      args: (args '())
      cwd: (cwd #f)
      mutates-trunk?: (mutates-trunk? #f))
  (.o bind-these: #f
      kind: 'agentic-ai-lab.graph-engine.funflow-step-spec.v1
      step-id: step-id
      purity: purity
      input-digest: input-digest
      endpoint: endpoint
      program: program
      args: args
      cwd: cwd
      mutates-trunk?: mutates-trunk?))

(def (make-two-zone-prompt-spec
      frozen-prefix
      kv-prefix-digest
      dynamic-tail
      disclosure-depth: (disclosure-depth 'L1))
  (.o bind-these: #f
      kind: 'agentic-ai-lab.graph-engine.two-zone-prompt-spec.v1
      frozen-prefix: frozen-prefix
      kv-prefix-digest: kv-prefix-digest
      dynamic-tail: dynamic-tail
      disclosure-depth: disclosure-depth))

(def (disclosure-rank depth)
  (cond
   ((eq? depth 'L0) 0)
   ((eq? depth 'L1) 1)
   ((eq? depth 'L2) 2)
   ((eq? depth 'L3) 3)
   (else -1)))

;;; Deterministic FunFlow CAS key owned strictly by Scheme.
(def (compute-funflow-cas-key step-id purity context-cut kv-prefix-digest input-digest)
  (string-append
   "funflow-cas:v1:"
   (sym->str step-id) "|"
   (sym->str purity) "|"
   "cut=" (sym->str context-cut) "|"
   "prefix=" (sym->str kv-prefix-digest) "|"
   "input=" (sym->str input-digest)))

;;; Phase 1 of a FunFlow step: Scheme decides which atomic effect to emit first.
;;; - `blocker-active` detour blocks trunk-mutating steps fail-closed (0 effects).
;;; - `pure-cas` emits `cas-get` so Rust checks CAS before any LLM call.
;;; - `sandboxed-effect` / `fenced-effect` NEVER short-circuits via cache and
;;;   requires valid sandbox + Cedar handoff before emitting `sandbox-run`.
(def (plan-funflow-step-effects step actor governed-context)
  (let* ((step-id (.ref step 'step-id))
         (purity (.ref step 'purity))
         (mutates-trunk? (opt-ref step 'mutates-trunk? #f))
         (detour-mode (opt-ref actor 'detour-mode 'mainline))
         (scope-mode (opt-ref actor 'scope-mode 'project))
         (cut (opt-ref governed-context 'context-cut 1))
         (kv-digest (opt-ref governed-context 'kv-prefix-digest "sha256:unbound"))
         (sandbox-ok? (opt-ref governed-context 'sandbox-admitted? #f))
         (cedar-ok? (opt-ref governed-context 'cedar-handoff-valid? #f))
         (cas-key (compute-funflow-cas-key
                   step-id purity cut kv-digest (.ref step 'input-digest))))
    (cond
     ((and mutates-trunk? (eq? scope-mode 'detached))
      (.o bind-these: #f
          admitted?: #f
          reason: 'detached-actor-cannot-mutate-trunk
          cas-key: cas-key
          effects: '()))
     ((and mutates-trunk? (eq? detour-mode 'blocker-active))
      (.o bind-these: #f
          admitted?: #f
          reason: 'blocker-detour-blocks-trunk-mutation
          cas-key: cas-key
          effects: '()))
     ((eq? purity 'pure-cas)
      (.o bind-these: #f
          admitted?: #t
          reason: 'pure-cas-lookup-planned
          cas-key: cas-key
          effects: (list (make-cas-get-effect
                          (string-append "cas-get:" (sym->str step-id))
                          cas-key))))
     ((or (eq? purity 'sandboxed-effect) (eq? purity 'fenced-effect))
      (cond
       ((not sandbox-ok?)
        (.o bind-these: #f
            admitted?: #f
            reason: 'sandbox-admission-required
            cas-key: cas-key
            effects: '()))
       ((not cedar-ok?)
        (.o bind-these: #f
            admitted?: #f
            reason: 'cedar-handoff-required
            cas-key: cas-key
            effects: '()))
       ((not (string? (.ref step 'program)))
        (.o bind-these: #f
            admitted?: #f
            reason: 'sandbox-program-required
            cas-key: cas-key
            effects: '()))
       (else
        (.o bind-these: #f
            admitted?: #t
            reason: 'sandbox-effect-planned
            cas-key: cas-key
            effects: (list (make-sandbox-run-effect
                            (string-append "sandbox:" (sym->str step-id))
                            (.ref step 'program)
                            (opt-ref step 'args '())
                            cwd: (opt-ref step 'cwd #f)))))))
     (else
      (.o bind-these: #f
          admitted?: #f
          reason: 'unsupported-step-purity
          cas-key: cas-key
          effects: '())))))

(def (validate-two-zone-prompt two-zone-prompt governed-context)
  (let* ((admitted-digest (opt-ref governed-context 'kv-prefix-digest ""))
         (prompt-digest (opt-ref two-zone-prompt 'kv-prefix-digest ""))
         (has-defeater? (opt-ref governed-context 'has-active-defeater? #f))
         (admitted-depth (opt-ref governed-context 'disclosure-depth 'L1))
         (prompt-depth (opt-ref two-zone-prompt 'disclosure-depth 'L1))
         (required-rank (if has-defeater? 3 (disclosure-rank admitted-depth)))
         (tail (opt-ref two-zone-prompt 'dynamic-tail "")))
    (cond
     ((not (equal? admitted-digest prompt-digest))
      (values #f 'kv-prefix-digest-mismatch))
     ((< (disclosure-rank prompt-depth) required-rank)
      (values #f 'disclosure-floor-violation))
     ((or (not (string? tail)) (= (string-length tail) 0))
      (values #f 'empty-dynamic-tail))
     (else (values #t 'two-zone-prompt-admitted)))))

;;; Phase 2 of a FunFlow step: Scheme reconciles raw atomic receipts from Rust
;;; and emits either zero effects (completed / rejected) or the next atomic effect.
(def (reconcile-funflow-step-receipts step actor governed-context receipts two-zone-prompt: (two-zone-prompt #f))
  (let* ((step-id (.ref step 'step-id))
         (purity (.ref step 'purity))
         (cut (opt-ref governed-context 'context-cut 1))
         (kv-digest (opt-ref governed-context 'kv-prefix-digest "sha256:unbound"))
         (cas-key (compute-funflow-cas-key
                   step-id purity cut kv-digest (.ref step 'input-digest)))
         (receipt (and (pair? receipts) (car receipts))))
    (cond
     ((not (object? receipt))
      (.o bind-these: #f
          status: 'rejected
          reason: 'missing-atomic-receipt
          cache-hit?: #f
          output: #f
          next-effects: '()))
     ((eq? (.ref receipt 'kind) 'cas-hit)
      (if (eq? purity 'pure-cas)
        (.o bind-these: #f
            status: 'completed
            reason: 'funflow-cas-hit
            cache-hit?: #t
            output: (.ref receipt 'payload)
            next-effects: '())
        (.o bind-these: #f
            status: 'rejected
            reason: 'sandboxed-effect-cannot-skip-via-cas
            cache-hit?: #f
            output: #f
            next-effects: '())))
     ((eq? (.ref receipt 'kind) 'cas-miss)
      (if (not (object? two-zone-prompt))
        (.o bind-these: #f
            status: 'rejected
            reason: 'missing-two-zone-prompt
            cache-hit?: #f
            output: #f
            next-effects: '())
        (let-values (((ok? why) (validate-two-zone-prompt two-zone-prompt governed-context)))
          (if (not ok?)
            (.o bind-these: #f
                status: 'rejected
                reason: why
                cache-hit?: #f
                output: #f
                next-effects: '())
            (.o bind-these: #f
                status: 'awaiting-effect
                reason: 'funflow-cas-miss-dispatching-llm
                cache-hit?: #f
                output: #f
                next-effects:
                (list (make-llm-complete-effect
                       (string-append "llm:" (sym->str step-id))
                       (.ref step 'endpoint)
                       (list (list 'system (.ref two-zone-prompt 'frozen-prefix))
                             (list 'user (.ref two-zone-prompt 'dynamic-tail)))
                       metadata: (list (cons 'kv-prefix-digest kv-digest)
                                       (cons 'context-cut cut)
                                       (cons 'detour-mode (opt-ref actor 'detour-mode 'mainline))))))))))
     ((eq? (.ref receipt 'kind) 'llm-completed)
      (let ((content (.ref receipt 'content)))
        (.o bind-these: #f
            status: 'completed
            reason: 'llm-completed-and-cas-put-emitted
            cache-hit?: #f
            output: content
            next-effects:
            (if (eq? purity 'pure-cas)
              (list (make-cas-put-effect
                     (string-append "cas-put:" (sym->str step-id))
                     cas-key
                     content))
              '()))))
     ((eq? (.ref receipt 'kind) 'sandbox-exited)
      (.o bind-these: #f
          status: (if (= (.ref receipt 'exit-code) 0) 'completed 'failed)
          reason: (if (= (.ref receipt 'exit-code) 0) 'sandbox-exited-ok 'sandbox-exited-nonzero)
          cache-hit?: #f
          output: (.ref receipt 'stdout)
          next-effects: '()))
     (else
      (.o bind-these: #f
          status: 'failed
          reason: 'atomic-effect-error
          cache-hit?: #f
          output: (opt-ref receipt 'message "unknown error")
          next-effects: '())))))

;;; ---------------------------------------------------------------------------
;;; 3. 100% Scheme Parallel DAG Frontier & Competing Hypothesis Branch Matrix
;;; ---------------------------------------------------------------------------
;;; Strictly preserves competing hypotheses, evidence lineage, contradictions,
;;; and open questions. Evaluates EVERY proposed POO branch against EVERY
;;; hypothesis as a single parallel batch of read-only AtomicEffects.
;;; Hypothetical model fit NEVER authenticates evidence, establishes historical
;;; attribution, grants tool execution, or authorizes an effect.

(.def CompetingHypothesis.
  kind: 'agentic-ai-lab.graph-engine.competing-hypothesis.v1)

(.def HypothesisBranchProposal.
  kind: 'agentic-ai-lab.graph-engine.hypothesis-branch-proposal.v1
  authorizes-effect?: #f)

(.def CompetingHypothesisMatrix.
  kind: 'agentic-ai-lab.graph-engine.competing-hypothesis-matrix.v1
  missing-claim-likelihood-inferred?: #f
  authenticates-evidence?: #f
  establishes-attribution?: #f
  authorizes-effect?: #f)

(def (make-competing-hypothesis
      hypothesis-id
      claim
      evidence-lineage: (evidence-lineage '())
      contradictions: (contradictions '())
      open-questions: (open-questions '()))
  (.o bind-these: #f
      kind: 'agentic-ai-lab.graph-engine.competing-hypothesis.v1
      hypothesis-id: hypothesis-id
      claim: claim
      evidence-lineage: evidence-lineage
      contradictions: contradictions
      open-questions: open-questions))

(def (make-hypothesis-branch-proposal
      branch-id
      question
      proposer: (proposer 'investigator)
      endpoint: (endpoint "openai/gpt-marlin")
      evidence-refs: (evidence-refs '()))
  (.o bind-these: #f
      kind: 'agentic-ai-lab.graph-engine.hypothesis-branch-proposal.v1
      branch-id: branch-id
      question: question
      proposer: proposer
      endpoint: endpoint
      evidence-refs: evidence-refs
      ;; Structurally guaranteed: a hypothetical investigation branch NEVER
      ;; authorizes an effect or grants tool execution.
      authorizes-effect?: #f))

;;; Emit one parallel batch of read-only `LlmCompleteEffect.`s covering the full
;;; Cartesian product `(hypotheses x branches)` for Marlin's thin `effect_pump`.
(def (plan-competing-hypothesis-frontier actor hypotheses branches governed-context)
  (let* ((kv-digest (opt-ref governed-context 'kv-prefix-digest "sha256:unbound"))
         (cut (opt-ref governed-context 'context-cut 1))
         (detour-mode (opt-ref actor 'detour-mode 'mainline))
         (effects
          (let loop-h ((hs hypotheses) (acc '()))
            (if (null? hs)
              (reverse acc)
              (let ((h (car hs)))
                (loop-h
                 (cdr hs)
                 (let loop-b ((bs branches) (b-acc acc))
                   (if (null? bs)
                     b-acc
                     (let* ((b (car bs))
                            (hid (.ref h 'hypothesis-id))
                            (bid (.ref b 'branch-id))
                            (eid (string-append "hyp:" (sym->str hid) "::br:" (sym->str bid)))
                            (eff (make-llm-complete-effect
                                  eid
                                  (.ref b 'endpoint)
                                  (list
                                   (list 'system
                                         (string-append
                                          "Evaluative branch only (non-authorizing). "
                                          "Preserve contradictions and open questions. "
                                          "KV-Prefix=" (sym->str kv-digest)))
                                   (list 'user
                                         (string-append
                                          "Hypothesis [" (sym->str hid) "]: " (.ref h 'claim)
                                          " | Branch [" (sym->str bid) "]: " (.ref b 'question))))
                                  metadata: (list (cons 'hypothesis-id hid)
                                                  (cons 'branch-id bid)
                                                  (cons 'context-cut cut)
                                                  (cons 'detour-mode detour-mode)
                                                  (cons 'authorizes-effect? #f)))))
                       (loop-b (cdr bs) (cons eff b-acc)))))))))))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.graph-engine.competing-hypothesis-frontier-plan.v1
        hypothesis-count: (length hypotheses)
        branch-count: (length branches)
        cell-count: (length effects)
        effects: effects
        authorizes-effect?: #f)))

;;; Reconcile raw parallel receipts from Marlin back into a complete
;;; `CompetingHypothesisMatrix.` preserving every hypothesis, evidence lineage,
;;; contradiction, and open question without collapsing or inferring likelihood
;;; from missing claims.
(def (reconcile-competing-hypothesis-matrix hypotheses branches receipts)
  (let ((cells
         (let loop-h ((hs hypotheses) (acc '()))
           (if (null? hs)
             (reverse acc)
             (let ((h (car hs)))
               (loop-h
                (cdr hs)
                (let loop-b ((bs branches) (b-acc acc))
                  (if (null? bs)
                    b-acc
                    (let* ((b (car bs))
                           (hid (.ref h 'hypothesis-id))
                           (bid (.ref b 'branch-id))
                           (eid (string-append "hyp:" (sym->str hid) "::br:" (sym->str bid)))
                           (rcpt (find (lambda (r) (equal? (.ref r 'effect-id) eid)) receipts))
                           (observed (if (and (object? rcpt) (eq? (.ref rcpt 'kind) 'llm-completed))
                                       (.ref rcpt 'content)
                                       #f))
                           (extra-open (if observed
                                         '()
                                         (list (string-append "unobserved-branch:" (sym->str bid)))))
                           (cell (.o bind-these: #f
                                     hypothesis-id: hid
                                     branch-id: bid
                                     evidence-lineage: (append (.ref h 'evidence-lineage)
                                                               (.ref b 'evidence-refs))
                                     contradictions: (.ref h 'contradictions)
                                     open-questions: (append (.ref h 'open-questions) extra-open)
                                     branch-observation: observed
                                     observed?: (and observed #t)
                                     ;; Non-negotiable security inference invariants:
                                     authenticates-evidence?: #f
                                     establishes-attribution?: #f
                                     authorizes-effect?: #f)))
                      (loop-b (cdr bs) (cons cell b-acc)))))))))))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.graph-engine.competing-hypothesis-matrix.v1
        hypotheses: hypotheses
        branches: branches
        cells: cells
        preserved-hypothesis-count: (length hypotheses)
        favored-path-collapsed?: #f
        missing-claim-likelihood-inferred?: #f
        authenticates-evidence?: #f
        establishes-attribution?: #f
        authorizes-effect?: #f)))
