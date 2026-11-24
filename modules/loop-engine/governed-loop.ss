;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; End-to-End ASCENT-Governed Loop Execution Engine (`modules/loop-engine/governed-loop.ss`):
;;; Composes ALL governance layers into one pure functional POO turn loop:
;;;   Stage 1 (Slices 48/50/51): ContextAssemblyPipeline (`assemble-governed-turn`)
;;;   Stage 2 (Slice 55):        MCP Registry Shadow Block + CaMeL Sensitive-Sink
;;;                              Provenance Gate + MindGuard Zero-LLM Audit
;;;   Stage 3 (Slice 56):        ASCENT Relational Termination & Anti-Oscillation Governor
;;;   Stage 4 (Slice 52):        GovernedFunflowRunner (CAS singleflight + nono-sandbox)
;;;   Stage 5 (Capstone 47):     Zero-LLM DeterministicAuditCapsule cold forensic receipt

(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :std/list/list every)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-assembly-pipeline
                 agentic-ai-lab-ai-agentic-context-assemble-governed-turn)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-trust-lattice
                 agentic-ai-lab-ai-agentic-context-admit-mcp-tool-registration
                 agentic-ai-lab-ai-agentic-context-admit-camel-sensitive-sink
                 agentic-ai-lab-ai-agentic-context-audit-tool-metadata-decision-dependence
                 agentic-ai-lab-ai-agentic-context-replay-audit-capsule)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-scope
                 agentic-ai-lab-ai-agentic-context-digest)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/governed-runner
                 governed-funflow-run)
        "ascent-termination.ss")

(export governed-loop-step
        governed-loop-run)

(def digest agentic-ai-lab-ai-agentic-context-digest)

(def (opt-ref obj key default)
  (if (and (object? obj) (.slot? obj key))
    (.ref obj key)
    default))

(def (first-failing results)
  (let loop ((xs results))
    (cond
     ((null? xs) #f)
     ((not (.ref (car xs) 'admitted?)) (car xs))
     (else (loop (cdr xs))))))

;;; Executes one fully governed turn of the redesigned ASCENT Loop Engine.
;;; `proposal` is a POO turn proposal containing:
;;;   - `fingerprint:`    LoopTurnFingerprint (required)
;;;   - `org-text:`       ORG snapshot text for Stage-1 ContextAssemblyPipeline (optional)
;;;   - `bound-cut:` / `live-cut:` / `frozen-entries:` / `memory-candidates:` /
;;;     `detour-return:` / `tool-pin-checks:` / `has-active-defeater?:`
;;;   - `mcp-registrations:` list of `(.o registry: ... server-id: ... tool-id: ... description: ... schema: ...)`
;;;   - `camel-sink-checks:` list of `(.o sink-sensitivity: ... arg-origin: ... manifest-pinned?: ... declass-cert: ... declass-cert-active?: ...)`
;;;   - `mindguard-audit:`   optional `(.o tool-with-metadata: ... tool-without-metadata: ... metadata-endorsed?: ...)`
;;;   - `cedar-grant-live?:` boolean (default `#t`)
;;;   - `durable-unclosed-attempts?:` boolean (default `#f`)
;;;   - `funflow-exec:`      optional `(.o runner: ... flow: ... input: ... capsule-id: ... sandbox-override: ... idempotency-key: ... idempotency-commits: ...)`
(def (governed-loop-step loop-state proposal)
  (unless (ascent-loop-state? loop-state)
    (error "governed-loop-step expects an AscentLoopState" loop-state))
  (let* ((fp (.ref proposal 'fingerprint))
         (epoch (.ref loop-state 'epoch))
         (org-text (opt-ref proposal 'org-text "* TODO Governed Loop Turn\n"))
         (bound-cut (opt-ref proposal 'bound-cut "cut-1"))
         (live-cut (opt-ref proposal 'live-cut bound-cut))
         ;; Stage 1: ContextAssemblyPipeline (Slices 47, 48, 50, 51)
         (assembly
          (agentic-ai-lab-ai-agentic-context-assemble-governed-turn
           org-text
           epoch: epoch
           bound-cut: bound-cut
           live-cut: live-cut
           frozen-entries: (opt-ref proposal 'frozen-entries '())
           memory-candidates: (opt-ref proposal 'memory-candidates '())
           detour-return: (opt-ref proposal 'detour-return #f)
           tool-pin-checks: (opt-ref proposal 'tool-pin-checks '())
           has-active-defeater?: (opt-ref proposal 'has-active-defeater? #f)
           requested-depth: (opt-ref proposal 'requested-depth 2)
           extra-suffix-frames: (opt-ref proposal 'extra-suffix-frames '())))
         ;; Stage 2: Slice 55 MCP Tool Shadowing + CaMeL Sensitive Sink + MindGuard Audit
         (mcp-results
          (map (lambda (r)
                 (agentic-ai-lab-ai-agentic-context-admit-mcp-tool-registration
                  (opt-ref r 'registry '())
                  (.ref r 'server-id)
                  (.ref r 'tool-id)
                  (opt-ref r 'description "")
                  (opt-ref r 'schema '())))
               (opt-ref proposal 'mcp-registrations '())))
         (mcp-fail (first-failing mcp-results))
         (camel-results
          (map (lambda (c)
                 (agentic-ai-lab-ai-agentic-context-admit-camel-sensitive-sink
                  (.ref c 'sink-sensitivity)
                  (.ref c 'arg-origin)
                  (.ref c 'manifest-pinned?)
                  declass-cert: (opt-ref c 'declass-cert #f)
                  declass-cert-active?: (opt-ref c 'declass-cert-active? #f)))
               (opt-ref proposal 'camel-sink-checks '())))
         (camel-fail (first-failing camel-results))
         (mg-spec (opt-ref proposal 'mindguard-audit #f))
         (mindguard-res
          (and mg-spec
               (agentic-ai-lab-ai-agentic-context-audit-tool-metadata-decision-dependence
                (.ref mg-spec 'tool-with-metadata)
                (.ref mg-spec 'tool-without-metadata)
                (opt-ref mg-spec 'metadata-endorsed? #f))))
         (mindguard-hijack? (and mindguard-res (.ref mindguard-res 'decision-hijack-flagged?)))
         (cedar-live? (opt-ref proposal 'cedar-grant-live? #t))
         (unclosed-attempts? (opt-ref proposal 'durable-unclosed-attempts? #f))
         ;; Aggregate pre-execution governance block
         (pre-gov-reason
          (cond
           ((not cedar-live?) 'cedar-grant-revoked)
           (unclosed-attempts? 'durable-unclosed-attempt-requires-recovery)
           ((not (.ref assembly 'admitted?)) (.ref assembly 'reason))
           (mcp-fail (.ref mcp-fail 'reason))
           (camel-fail (.ref camel-fail 'reason))
           (mindguard-hijack? 'mindguard-tool-metadata-decision-hijack)
           (else #f)))
         (pre-gov-blocked? (and pre-gov-reason #t))
         ;; Stage 3: Slice 56 ASCENT Relational Termination & Anti-Oscillation Governor
         (ascent-verdict
          (ascent-evaluate-loop-termination
           loop-state fp
           governance-blocked?: pre-gov-blocked?
           governance-reason: pre-gov-reason))
         ;; Stage 4: Slice 52 GovernedFunflowRunner (ONLY when ASCENT admits the step!)
         (ff-spec (opt-ref proposal 'funflow-exec #f))
         (ff-result
          (if (and (.ref ascent-verdict 'admitted?) ff-spec)
            (governed-funflow-run
             (.ref ff-spec 'runner)
             (.ref ff-spec 'flow)
             (.ref ff-spec 'input)
             capsule-id: (opt-ref ff-spec 'capsule-id #f)
             sandbox-override: (opt-ref ff-spec 'sandbox-override #f)
             env-digest-override: (opt-ref ff-spec 'env-digest-override #f)
             idempotency-key: (opt-ref ff-spec 'idempotency-key #f)
             idempotency-commits: (opt-ref ff-spec 'idempotency-commits '()))
            #f))
         ;; If FunFlow sandbox/Lethal-Trifecta refused, upgrade verdict to halt-governance-blocked!
         (final-verdict
          (if (and ff-result (not (.ref ff-result 'admitted?)))
            (ascent-evaluate-loop-termination
             loop-state fp
             governance-blocked?: #t
             governance-reason: (.ref ff-result 'reason))
            ascent-verdict))
         ;; Stage 5: Zero-LLM DeterministicAuditCapsule sealing
         (kv-digest (.ref (.ref assembly 'two-zone-prompt) 'frozen-prefix-digest))
         (repaired-bytes (.ref (.ref assembly 'repaired-org) 'repaired-text))
         (journal (list (list 'loop-id (.ref loop-state 'loop-id))
                        (list 'epoch epoch)
                        (list 'turn-id (.ref fp 'turn-id))
                        (list 'verdict (.ref final-verdict 'verdict))
                        (list 'reason (.ref final-verdict 'reason))
                        (list 'kv-prefix kv-digest)
                        (list 'cas-key (and ff-result (.ref ff-result 'cas-key)))))
         (commitment (digest (list 'deterministic-audit-capsule.v1
                                   bound-cut repaired-bytes journal)))
         (replay (agentic-ai-lab-ai-agentic-context-replay-audit-capsule
                  repaired-bytes journal bound-cut live-cut commitment))
         (capsule (.o bind-these: #f
                      kind: 'agentic-ai-lab.loop-engine.turn-audit-capsule.v1
                      bound-cut: bound-cut
                      repaired-bytes: repaired-bytes
                      journal-entries: journal
                      commitment: commitment
                      replay: replay
                      llm-calls-used: 0
                      action-authorized?: #f))
         (next-state (ascent-loop-advance-state loop-state fp final-verdict audit-capsule: capsule)))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.loop-engine.governed-turn-result.v1
        state: next-state
        verdict: final-verdict
        context-assembly: assembly
        mcp-results: mcp-results
        camel-results: camel-results
        mindguard-audit: mindguard-res
        funflow-result: ff-result
        audit-capsule: capsule
        action-authorized?: #f)))

;;; Pure functional bounded loop driver matching Lean 4 `runGovernedLoop`:
;;; Executes `proposal-fn(state, turn-index)` until ASCENT halts the loop.
;;; Guaranteed to terminate in <= `max-steps + 1` evaluations against ANY
;;; adversarial `proposal-fn`.
(def (governed-loop-run initial-state proposal-fn)
  (unless (ascent-loop-state? initial-state)
    (error "governed-loop-run expects an AscentLoopState" initial-state))
  (let ((hard-cap (+ 2 (.ref (.ref initial-state 'policy) 'max-steps))))
    (let loop ((st initial-state) (turn-idx 0) (trace-rev '()))
      (if (or (.ref st 'halted?) (>= turn-idx hard-cap))
        (let ((trace (reverse trace-rev)))
          (.o bind-these: #f
              kind: 'agentic-ai-lab.loop-engine.governed-loop-run-report.v1
              final-state: st
              final-verdict: (if (pair? trace-rev) (.ref (car trace-rev) 'verdict) #f)
              turns-executed: (length trace)
              steps-admitted: (.ref st 'steps-taken)
              halted?: (.ref st 'halted?)
              trace: trace))
        (let* ((proposal (proposal-fn st turn-idx))
               (step-res (governed-loop-step st proposal)))
          (loop (.ref step-res 'state)
                (+ turn-idx 1)
                (cons step-res trace-rev)))))))
