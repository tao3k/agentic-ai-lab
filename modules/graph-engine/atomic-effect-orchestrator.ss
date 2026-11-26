;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; 100% Pure Scheme POO + Functional High-Order Orchestrator over Marlin's Thin
;;; Atomic Effect Runtime (`modules/graph-engine/atomic-effect-orchestrator.ss`).
;;; Follows Style 02/03 (`(.o (:: @ Prototype.) (slot) (slot := expr))`, zero
;;; `bind-these: #f`, and `append-map` / `foldl` functional combinators).

(import (only-in :clan/poo/object .def .o .ref .slot? object?)
        (only-in :std/list/list append-map find))

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
  (if (and (object? obj) (.slot? obj key)) (.ref obj key) default))

(def (sym->str v)
  (cond ((string? v) v) ((symbol? v) (symbol->string v))
        ((number? v) (number->string v)) (else "unknown")))

;;; ---------------------------------------------------------------------------
;;; 1. Four Canonical Atomic Effects & Receipts (1:1 with Marlin `effect_pump`)
;;; ---------------------------------------------------------------------------

(.def LlmCompleteEffect. kind: 'llm-complete runtime-executed?: #f)
(.def CasGetEffect. kind: 'cas-get runtime-executed?: #f)
(.def CasPutEffect. kind: 'cas-put runtime-executed?: #f)
(.def SandboxRunEffect. kind: 'sandbox-run runtime-executed?: #f)
(.def AtomicEffectReceipt. kind: 'agentic-ai-lab.graph-engine.atomic-effect-receipt.v1)

(def (make-llm-complete-effect effect-id endpoint messages metadata: (metadata '()))
  (.o (:: @ LlmCompleteEffect.) (effect-id) (endpoint) (messages) (metadata)))

(def (make-cas-get-effect effect-id key)
  (.o (:: @ CasGetEffect.) (effect-id) (key)))

(def (make-cas-put-effect effect-id key payload)
  (.o (:: @ CasPutEffect.) (effect-id) (key) (payload)))

(def (make-sandbox-run-effect effect-id program args cwd: (cwd #f))
  (.o (:: @ SandboxRunEffect.) (effect-id) (program) (args) (cwd)))

(def (make-cas-hit-receipt effect-id payload)
  (.o (:: @ AtomicEffectReceipt.) (kind := 'cas-hit) (effect-id) (payload)))

(def (make-cas-miss-receipt effect-id)
  (.o (:: @ AtomicEffectReceipt.) (kind := 'cas-miss) (effect-id)))

(def (make-cas-stored-receipt effect-id)
  (.o (:: @ AtomicEffectReceipt.) (kind := 'cas-stored) (effect-id)))

(def (make-llm-completed-receipt effect-id content)
  (.o (:: @ AtomicEffectReceipt.) (kind := 'llm-completed) (effect-id) (content)))

(def (make-sandbox-exited-receipt effect-id exit-code stdout stderr: (stderr ""))
  (.o (:: @ AtomicEffectReceipt.) (kind := 'sandbox-exited) (effect-id) (exit-code) (stdout) (stderr)))

(def (make-effect-error-receipt effect-id message)
  (.o (:: @ AtomicEffectReceipt.) (kind := 'effect-error) (effect-id) (message)))

;;; ---------------------------------------------------------------------------
;;; 2. FunFlow CAS Purity & Two-Zone KV-Prefix Orchestrator
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
  (.o (:: @ FunflowStepSpec.)
      (step-id) (purity) (input-digest) (endpoint)
      (program) (args) (cwd) (mutates-trunk?)))

(def (make-two-zone-prompt-spec
      frozen-prefix kv-prefix-digest dynamic-tail
      disclosure-depth: (disclosure-depth 'L1))
  (.o (:: @ TwoZonePromptSpec.)
      (frozen-prefix) (kv-prefix-digest) (dynamic-tail) (disclosure-depth)))

(def (disclosure-rank depth)
  (case depth ((L0) 0) ((L1) 1) ((L2) 2) ((L3) 3) (else -1)))

(def (compute-funflow-cas-key step-id purity context-cut kv-prefix-digest input-digest)
  (string-append "funflow-cas:v1:" (sym->str step-id) "|" (sym->str purity)
                 "|cut=" (sym->str context-cut)
                 "|prefix=" (sym->str kv-prefix-digest)
                 "|input=" (sym->str input-digest)))

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
         (cas-key (compute-funflow-cas-key step-id purity cut kv-digest (.ref step 'input-digest))))
    (def (plan-outcome admitted? reason (effects '()))
      (.o (admitted?) (reason) (cas-key) (effects)))
    (cond
     ((and mutates-trunk? (eq? scope-mode 'detached))
      (plan-outcome #f 'detached-actor-cannot-mutate-trunk))
     ((and mutates-trunk? (eq? detour-mode 'blocker-active))
      (plan-outcome #f 'blocker-detour-blocks-trunk-mutation))
     ((eq? purity 'pure-cas)
      (plan-outcome #t 'pure-cas-lookup-planned
                    (list (make-cas-get-effect (string-append "cas-get:" (sym->str step-id)) cas-key))))
     ((memq purity '(sandboxed-effect fenced-effect))
      (cond
       ((not sandbox-ok?) (plan-outcome #f 'sandbox-admission-required))
       ((not cedar-ok?) (plan-outcome #f 'cedar-handoff-required))
       ((not (string? (.ref step 'program))) (plan-outcome #f 'sandbox-program-required))
       (else (plan-outcome #t 'sandbox-effect-planned
                           (list (make-sandbox-run-effect
                                  (string-append "sandbox:" (sym->str step-id))
                                  (.ref step 'program) (opt-ref step 'args '())
                                  cwd: (opt-ref step 'cwd #f)))))))
     (else (plan-outcome #f 'unsupported-step-purity)))))

(def (validate-two-zone-prompt two-zone-prompt governed-context)
  (let* ((admitted-digest (opt-ref governed-context 'kv-prefix-digest ""))
         (prompt-digest (opt-ref two-zone-prompt 'kv-prefix-digest ""))
         (has-defeater? (opt-ref governed-context 'has-active-defeater? #f))
         (required-rank (if has-defeater? 3 (disclosure-rank (opt-ref governed-context 'disclosure-depth 'L1))))
         (tail (opt-ref two-zone-prompt 'dynamic-tail "")))
    (cond
     ((not (equal? admitted-digest prompt-digest)) (values #f 'kv-prefix-digest-mismatch))
     ((< (disclosure-rank (opt-ref two-zone-prompt 'disclosure-depth 'L1)) required-rank)
      (values #f 'disclosure-floor-violation))
     ((or (not (string? tail)) (= (string-length tail) 0)) (values #f 'empty-dynamic-tail))
     (else (values #t 'two-zone-prompt-admitted)))))

(def (reconcile-funflow-step-receipts step actor governed-context receipts two-zone-prompt: (two-zone-prompt #f))
  (let* ((step-id (.ref step 'step-id))
         (purity (.ref step 'purity))
         (cut (opt-ref governed-context 'context-cut 1))
         (kv-digest (opt-ref governed-context 'kv-prefix-digest "sha256:unbound"))
         (cas-key (compute-funflow-cas-key step-id purity cut kv-digest (.ref step 'input-digest)))
         (receipt (and (pair? receipts) (car receipts))))
    (def (rec status reason (cache-hit? #f) (output #f) (next-effects '()))
      (.o (status) (reason) (cache-hit?) (output) (next-effects)))
    (cond
     ((not (object? receipt)) (rec 'rejected 'missing-atomic-receipt))
     ((eq? (.ref receipt 'kind) 'cas-hit)
      (if (eq? purity 'pure-cas)
        (rec 'completed 'funflow-cas-hit #t (.ref receipt 'payload))
        (rec 'rejected 'sandboxed-effect-cannot-skip-via-cas)))
     ((eq? (.ref receipt 'kind) 'cas-miss)
      (if (not (object? two-zone-prompt))
        (rec 'rejected 'missing-two-zone-prompt)
        (let-values (((ok? why) (validate-two-zone-prompt two-zone-prompt governed-context)))
          (if (not ok?)
            (rec 'rejected why)
            (rec 'awaiting-effect 'funflow-cas-miss-dispatching-llm #f #f
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
        (rec 'completed 'llm-completed-and-cas-put-emitted #f content
             (if (eq? purity 'pure-cas)
               (list (make-cas-put-effect (string-append "cas-put:" (sym->str step-id)) cas-key content))
               '()))))
     ((eq? (.ref receipt 'kind) 'sandbox-exited)
      (let ((ok? (= (.ref receipt 'exit-code) 0)))
        (rec (if ok? 'completed 'failed)
             (if ok? 'sandbox-exited-ok 'sandbox-exited-nonzero)
             #f (.ref receipt 'stdout))))
     (else (rec 'failed 'atomic-effect-error #f (opt-ref receipt 'message "unknown error"))))))

;;; ---------------------------------------------------------------------------
;;; 3. Parallel Competing Hypothesis Branch Matrix (Non-Authorizing)
;;; ---------------------------------------------------------------------------

(.def CompetingHypothesis.
  kind: 'agentic-ai-lab.graph-engine.competing-hypothesis.v1)

(.def HypothesisBranchProposal.
  kind: 'agentic-ai-lab.graph-engine.hypothesis-branch-proposal.v1
  authorizes-effect?: #f)

(.def CompetingHypothesisCell.
  authenticates-evidence?: #f
  establishes-attribution?: #f
  authorizes-effect?: #f)

(.def CompetingHypothesisMatrix.
  kind: 'agentic-ai-lab.graph-engine.competing-hypothesis-matrix.v1
  favored-path-collapsed?: #f
  missing-claim-likelihood-inferred?: #f
  authenticates-evidence?: #f
  establishes-attribution?: #f
  authorizes-effect?: #f)

(def (make-competing-hypothesis
      hypothesis-id claim
      evidence-lineage: (evidence-lineage '())
      contradictions: (contradictions '())
      open-questions: (open-questions '()))
  (.o (:: @ CompetingHypothesis.)
      (hypothesis-id) (claim) (evidence-lineage) (contradictions) (open-questions)))

(def (make-hypothesis-branch-proposal
      branch-id question
      proposer: (proposer 'investigator)
      endpoint: (endpoint "openai/gpt-marlin")
      evidence-refs: (evidence-refs '()))
  (.o (:: @ HypothesisBranchProposal.)
      (branch-id) (question) (proposer) (endpoint) (evidence-refs)))

(def (plan-competing-hypothesis-frontier actor hypotheses branches governed-context)
  (let* ((kv-digest (opt-ref governed-context 'kv-prefix-digest "sha256:unbound"))
         (cut (opt-ref governed-context 'context-cut 1))
         (detour-mode (opt-ref actor 'detour-mode 'mainline))
         (effects
          (append-map
           (lambda (h)
             (map (lambda (b)
                    (let* ((hid (.ref h 'hypothesis-id))
                           (bid (.ref b 'branch-id))
                           (eid (string-append "hyp:" (sym->str hid) "::br:" (sym->str bid))))
                      (make-llm-complete-effect
                       eid (.ref b 'endpoint)
                       (list (list 'system (string-append
                                            "Evaluative branch only (non-authorizing). "
                                            "Preserve contradictions and open questions. "
                                            "KV-Prefix=" (sym->str kv-digest)))
                             (list 'user (string-append
                                          "Hypothesis [" (sym->str hid) "]: " (.ref h 'claim)
                                          " | Branch [" (sym->str bid) "]: " (.ref b 'question))))
                       metadata: (list (cons 'hypothesis-id hid) (cons 'branch-id bid)
                                       (cons 'context-cut cut) (cons 'detour-mode detour-mode)
                                       (cons 'authorizes-effect? #f)))))
                  branches))
           hypotheses)))
    (.o (kind := 'agentic-ai-lab.graph-engine.competing-hypothesis-frontier-plan.v1)
        (hypothesis-count := (length hypotheses))
        (branch-count := (length branches))
        (cell-count := (length effects))
        (effects)
        (authorizes-effect? := #f))))

(def (reconcile-competing-hypothesis-matrix hypotheses branches receipts)
  (let ((cells
         (append-map
          (lambda (h)
            (map (lambda (b)
                   (let* ((hid (.ref h 'hypothesis-id))
                          (bid (.ref b 'branch-id))
                          (eid (string-append "hyp:" (sym->str hid) "::br:" (sym->str bid)))
                          (rcpt (find (lambda (r) (equal? (.ref r 'effect-id) eid)) receipts))
                          (observed (and (object? rcpt) (eq? (.ref rcpt 'kind) 'llm-completed)
                                         (.ref rcpt 'content)))
                          (extra-open (if observed '() (list (string-append "unobserved-branch:" (sym->str bid))))))
                     (.o (:: @ CompetingHypothesisCell.)
                         (hypothesis-id := hid)
                         (branch-id := bid)
                         (evidence-lineage := (append (.ref h 'evidence-lineage) (.ref b 'evidence-refs)))
                         (contradictions := (.ref h 'contradictions))
                         (open-questions := (append (.ref h 'open-questions) extra-open))
                         (branch-observation := observed)
                         (observed? := (and observed #t)))))
                 branches))
          hypotheses)))
    (.o (:: @ CompetingHypothesisMatrix.)
        (hypotheses) (branches) (cells)
        (preserved-hypothesis-count := (length hypotheses)))))
