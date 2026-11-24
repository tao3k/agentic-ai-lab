;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Step 5 Runtime Convergence Pipeline:
;;; Pure functional End-to-End Governed Context Assembly Pipeline composing:
;;; - Stage 1 (Slice 48): Zero-token Stage-1 ORG AST auto-repair + L0..L3
;;;   progressive disclosure (active defeaters force full L3 unmasked floor).
;;; - Stage 2 (Slice 51): Quarantine-Before-Recall memory filtering (blocking
;;;   MINJA / MemoryGraft quarantined or rejected candidates from recall).
;;; - Stage 3 (Slice 50): APPA confined-detour return gating + MindGuard tool
;;;   schema-digest pinning + zero-authority stall/divergence advisory.
;;; - Stage 4 (Slice 51): Two-Zone KV-Prefix-Stable prompt serialization
;;;   (Frozen Canonical Prefix ++ Dynamic Suffix).
;;; - Stage 5 (Capstone 47): Zero-LLM DeterministicAuditCapsule sealing &
;;;   cold forensic replay verification (`action-authorized?: #f`).

(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :std/list/list every filter)
        (only-in :std/string/misc string-trim string-prefix?)
        "funs-scope.ss"
        "funs-epistemic-consolidation.ss"
        "funs-trust-lattice.ss")

(export agentic-ai-lab-ai-agentic-context-assemble-governed-turn)

(def digest agentic-ai-lab-ai-agentic-context-digest)

(def (opt-ref obj key default)
  (if (and (object? obj) (.slot? obj key))
    (.ref obj key)
    default))

(def (default-stage-one-ast-repair raw-org-text)
  ;; Pure zero-token Stage-1 structural ORG repair (closes unclosed `:PROPERTIES:` /
  ;; `:RESULTS:` drawers and `#+BEGIN_SRC` / `#+BEGIN_THINKING` blocks cleanly without
  ;; touching prose inside `src-block` fences; callers with full Orgize may inject
  ;; `agentic-ai-lab-ai-agentic-context-ast-auto-repair` via `stage-one-repair-fn:`).
  (let* ((lines (string-split raw-org-text #\newline))
         (fixes-box (box '())))
    (let loop ((rest lines) (in-src? #f) (open-drawer #f) (out '()))
      (if (null? rest)
        (let* ((o1 (if in-src?
                     (begin (set-box! fixes-box (cons 'closed-unterminated-src-block (unbox fixes-box)))
                            (cons "#+END_SRC" out))
                     out))
               (o2 (if open-drawer
                     (begin (set-box! fixes-box (cons 'closed-unterminated-drawer (unbox fixes-box)))
                            (cons ":END:" o1))
                     o1))
               (repaired (string-join (reverse o2) "\n")))
          (.o bind-these: #f
              kind: 'agentic-ai-lab.ai-agentic-context.stage-one-repair.v1
              repaired-text: repaired
              fixes: (reverse (unbox fixes-box))
              llm-tokens-used: 0))
        (let* ((line (car rest))
               (trimmed (string-trim line))
               (upper (string-upcase trimmed)))
          (cond
           (in-src?
            (loop (cdr rest)
                  (not (string-prefix? "#+END_SRC" upper))
                  open-drawer
                  (cons line out)))
           ((string-prefix? "#+BEGIN_SRC" upper)
            (let ((out1 (if open-drawer
                          (begin (set-box! fixes-box (cons 'closed-unterminated-drawer (unbox fixes-box)))
                                 (cons ":END:" out))
                          out)))
              (loop (cdr rest) #t #f (cons line out1))))
           ((or (equal? upper ":PROPERTIES:") (equal? upper ":RESULTS:"))
            (let ((out1 (if open-drawer
                          (begin (set-box! fixes-box (cons 'closed-unterminated-drawer (unbox fixes-box)))
                                 (cons ":END:" out))
                          out)))
              (loop (cdr rest) #f upper (cons line out1))))
           ((equal? upper ":END:")
            (loop (cdr rest) #f #f (cons line out)))
           ((and open-drawer (> (string-length trimmed) 0) (char=? (string-ref trimmed 0) #\*))
            (set-box! fixes-box (cons 'closed-unterminated-drawer (unbox fixes-box)))
            (loop (cdr rest) #f #f (cons line (cons ":END:" out))))
           (else
            (loop (cdr rest) #f open-drawer (cons line out)))))))))

(def (agentic-ai-lab-ai-agentic-context-assemble-governed-turn
      org-text
      epoch: (epoch 1)
      bound-cut: (bound-cut "cut-1")
      live-cut: (live-cut "cut-1")
      frozen-entries: (frozen-entries '())
      memory-candidates: (memory-candidates '())
      detour-return: (detour-return #f)
      tool-pin-checks: (tool-pin-checks '())
      journal-entries: (journal-entries '())
      repeated-failures: (repeated-failures 0)
      consecutive-invalidations: (consecutive-invalidations 0)
      stall-threshold: (stall-threshold 3)
      has-active-defeater?: (has-active-defeater? #f)
      requested-depth: (requested-depth 2)
      explicit-drill-down?: (explicit-drill-down? #f)
      extra-suffix-frames: (extra-suffix-frames '())
      stage-one-repair-fn: (stage-one-repair-fn #f))
  (unless (string? org-text)
    (error "assemble-governed-turn expects an ORG text string" org-text))
  ;; Stage 1 (Slice 48): Zero-token Stage-1 AST auto-repair + L0..L3 floor
  (let* ((repaired (if (procedure? stage-one-repair-fn)
                     (stage-one-repair-fn org-text)
                     (default-stage-one-ast-repair org-text)))
         (repaired-text (.ref repaired 'repaired-text))
         (effective-depth (if (or has-active-defeater? explicit-drill-down?)
                            3
                            (max 0 (min 3 requested-depth))))
         ;; Stage 2 (Slice 51): Quarantine-Before-Recall memory filtering
         (recall-view (agentic-ai-lab-ai-agentic-context-recall-memories memory-candidates))
         (recalled-frames
          (map (lambda (m)
                 (string-append "[MEMORY:" (.ref m 'candidate-id) "] "
                                (opt-ref m 'payload (opt-ref m 'payload-digest ""))))
               (.ref recall-view 'recalled)))
         ;; Stage 3 (Slice 50): APPA confined-detour return gate + MindGuard tool pins + stall advisory
         (detour-decision
          (and detour-return
               (agentic-ai-lab-ai-agentic-context-admit-confined-detour-return
                detour-tainted?: (opt-ref detour-return 'detour-tainted? #t)
                egress-attempted?: (opt-ref detour-return 'egress-attempted? #f)
                schema-attested?: (opt-ref detour-return 'schema-attested? #f)
                declass-cert: (opt-ref detour-return 'declass-cert #f)
                declass-cert-active?: (opt-ref detour-return 'declass-cert-active? #f)
                live-source-cut: (opt-ref detour-return 'live-source-cut bound-cut)
                live-target-cut: (opt-ref detour-return 'live-target-cut live-cut))))
         (detour-ok? (or (not detour-decision) (.ref detour-decision 'admitted?)))
         (detour-frames
          (if (and detour-decision detour-ok? (string? (opt-ref detour-return 'payload #f)))
            (list (string-append "[DETOUR-RETURN] " (.ref detour-return 'payload)))
            '()))
         (tool-decisions
          (map (lambda (spec)
                 (agentic-ai-lab-ai-agentic-context-verify-tool-schema-pin
                  (.ref spec 'tool-id)
                  (.ref spec 'pinned-digest)
                  (.ref spec 'live-schema)))
               tool-pin-checks))
         (tools-ok? (every (lambda (d) (.ref d 'admitted?)) tool-decisions))
         (stall-advisory
          (agentic-ai-lab-ai-agentic-context-evaluate-stall-advisory
           repeated-failures consecutive-invalidations stall-threshold))
         ;; Stage 4 (Slice 51): Two-Zone KV-Prefix-Stable prompt serialization
         (org-suffix (list (string-append "[ORG-L" (number->string effective-depth) "] "
                                          repaired-text)))
         (dynamic-suffix (append org-suffix recalled-frames detour-frames extra-suffix-frames))
         (two-zone (agentic-ai-lab-ai-agentic-context-serialize-two-zone-prompt
                    epoch frozen-entries dynamic-suffix))
         ;; Stage 5 (Capstone 47): Zero-LLM DeterministicAuditCapsule sealing & verification
         (capsule-journal (append journal-entries
                                  (list (list 'kv-prefix (.ref two-zone 'frozen-prefix-digest))
                                        (list 'disclosure-depth effective-depth)
                                        (list 'recalled-count (.ref recall-view 'recalled-count))
                                        (list 'quarantined-excluded (.ref recall-view 'quarantined-or-rejected-excluded)))))
         (commitment (digest (list 'deterministic-audit-capsule.v1
                                   bound-cut repaired-text capsule-journal)))
         (replay (agentic-ai-lab-ai-agentic-context-replay-audit-capsule
                  repaired-text capsule-journal bound-cut live-cut commitment))
         (admitted? (and detour-ok? tools-ok? (.ref replay 'hot-applicable?)))
         (reason (cond
                  ((not detour-ok?) (.ref detour-decision 'reason))
                  ((not tools-ok?) 'tool-schema-drift-blocked)
                  ((not (.ref replay 'hot-applicable?)) 'audit-capsule-stale-cut)
                  (else 'governed-turn-assembled))))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.ai-agentic-context.governed-turn-assembly.v1
        admitted?: admitted?
        reason: reason
        repaired-org: repaired
        effective-disclosure-depth: effective-depth
        recall-view: recall-view
        detour-decision: detour-decision
        tool-decisions: tool-decisions
        stall-advisory: stall-advisory
        two-zone-prompt: two-zone
        audit-capsule: (.o bind-these: #f
                           bound-cut: bound-cut
                           live-cut: live-cut
                           repaired-bytes: repaired-text
                           journal-entries: capsule-journal
                           commitment: commitment
                           replay: replay
                           llm-calls-used: 0)
        action-authorized?: #f)))
