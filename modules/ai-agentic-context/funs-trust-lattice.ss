;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Context Governance Boundary (Slices 40 & 42).
(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :std/list/list every delete-duplicates/hash)
        "types.ss" "objects.ss" "funs-scope.ss")
(export agentic-ai-lab-ai-agentic-context-trust-rank
        agentic-ai-lab-ai-agentic-context-trust<=?
        agentic-ai-lab-ai-agentic-context-trust-min
        agentic-ai-lab-ai-agentic-context-endorsement-receipt
        agentic-ai-lab-ai-agentic-context-admit-trust-promotion
        agentic-ai-lab-ai-agentic-context-restriction-envelope
        agentic-ai-lab-ai-agentic-context-restriction-meet
        agentic-ai-lab-ai-agentic-context-handoff-assess
        agentic-ai-lab-ai-agentic-context-kv-prefix-admit
        agentic-ai-lab-ai-agentic-context-declassification-cert
        agentic-ai-lab-ai-agentic-context-admit-declassification
        agentic-ai-lab-ai-agentic-context-serialize-two-zone-prompt
        agentic-ai-lab-ai-agentic-context-admit-confined-detour-return
        agentic-ai-lab-ai-agentic-context-causal-counterfactual-audit
        agentic-ai-lab-ai-agentic-context-evaluate-stall-advisory
        agentic-ai-lab-ai-agentic-context-verify-tool-schema-pin
        agentic-ai-lab-ai-agentic-context-replay-audit-capsule)

(def digest agentic-ai-lab-ai-agentic-context-digest)

(def (text? x) (and (string? x) (< 0 (string-length x) 257)))

(def (canonical-names xs)
  (unless (and (list? xs) (<= (length xs) 128) (every text? xs))
    (error "Invalid bounded Governance identity list"))
  (list-sort string<? (delete-duplicates/hash (map string-copy xs))))

(def (agentic-ai-lab-ai-agentic-context-trust-rank role)
  (case role
    ((untrusted-data) 0)
    ((observed-fact) 1)
    ((model-proposal) 2)
    ((user-intent) 3)
    ((system-policy) 4)
    (else (error "Unknown Context trust role" role))))

(def (rank->trust-role n)
  (vector-ref '#(untrusted-data observed-fact model-proposal user-intent system-policy) n))

(def (agentic-ai-lab-ai-agentic-context-trust<=? a b)
  (<= (agentic-ai-lab-ai-agentic-context-trust-rank a)
      (agentic-ai-lab-ai-agentic-context-trust-rank b)))

(def (agentic-ai-lab-ai-agentic-context-trust-min a b)
  (rank->trust-role (min (agentic-ai-lab-ai-agentic-context-trust-rank a)
                         (agentic-ai-lab-ai-agentic-context-trust-rank b))))

(def (agentic-ai-lab-ai-agentic-context-endorsement-receipt
      content-digest bound-cut proposer endorser target-role)
  (unless (and (every text? (list content-digest bound-cut proposer endorser))
               (not (equal? proposer endorser))
               (agentic-ai-lab-ai-agentic-context-trust-role? target-role))
    (error "EndorsementReceipt requires distinct proposer/endorser and valid trust role"))
  (let* ((content-digest (string-copy content-digest))
         (bound-cut (string-copy bound-cut))
         (proposer (string-copy proposer))
         (endorser (string-copy endorser))
         (semantic-digest (digest (list 'context-endorsement-receipt.v1
                                        content-digest bound-cut proposer endorser target-role))))
    (.o (:: @ AiAgenticContextEndorsementReceipt.)
        content-digest bound-cut proposer endorser target-role semantic-digest)))

(def (trust-decision accepted? reason effective-role)
  (.o accepted? reason effective-role))

(def (agentic-ai-lab-ai-agentic-context-admit-trust-promotion
      origin-role requested-role content-digest live-cut proposer (endorsement #f))
  (unless (and (agentic-ai-lab-ai-agentic-context-trust-role? origin-role)
               (agentic-ai-lab-ai-agentic-context-trust-role? requested-role)
               (every text? (list content-digest live-cut proposer)))
    (error "Invalid trust promotion check inputs"))
  (cond
   ((agentic-ai-lab-ai-agentic-context-trust<=? requested-role origin-role)
    (trust-decision #t 'non-escalating requested-role))
   ((not endorsement)
    (trust-decision #f 'unendorsed-trust-escalation origin-role))
   ((not (agentic-ai-lab-ai-agentic-context-endorsement-receipt-shape? endorsement))
    (trust-decision #f 'invalid-endorsement-receipt origin-role))
   ((not (equal? (.ref endorsement 'content-digest) content-digest))
    (trust-decision #f 'endorsement-digest-mismatch origin-role))
   ((not (equal? (.ref endorsement 'bound-cut) live-cut))
    (trust-decision #f 'stale-endorsement-cut origin-role))
   ((not (equal? (.ref endorsement 'proposer) proposer))
    (trust-decision #f 'endorsement-proposer-mismatch origin-role))
   ((not (agentic-ai-lab-ai-agentic-context-trust<=? requested-role (.ref endorsement 'target-role)))
    (trust-decision #f 'exceeds-endorsed-ceiling origin-role))
   (else
    (trust-decision #t 'endorsed-promotion requested-role))))

(def (agentic-ai-lab-ai-agentic-context-restriction-envelope
      domain readers destinations capabilities lease-start lease-end trust-ceiling obligations)
  (unless (and (text? domain)
               (exact-integer? lease-start) (exact-integer? lease-end)
               (agentic-ai-lab-ai-agentic-context-trust-role? trust-ceiling))
    (error "Invalid Context RestrictionEnvelope inputs"))
  (let* ((domain (string-copy domain))
         (readers (canonical-names readers))
         (destinations (canonical-names destinations))
         (capabilities (canonical-names capabilities))
         (obligations (canonical-names obligations))
         (semantic-digest (digest (list 'context-restriction-envelope.v1
                                        domain readers destinations capabilities
                                        lease-start lease-end trust-ceiling obligations))))
    (.o (:: @ AiAgenticContextRestrictionEnvelope.)
        domain readers destinations capabilities lease-start lease-end
        trust-ceiling obligations semantic-digest)))

(def (set-intersect a b) (filter (cut member <> b) a))

(def (meet-two a b)
  (unless (equal? (.ref a 'domain) (.ref b 'domain))
    (error "Cannot meet RestrictionEnvelopes from distinct domains" (.ref a 'domain) (.ref b 'domain)))
  (agentic-ai-lab-ai-agentic-context-restriction-envelope
   (.ref a 'domain)
   (set-intersect (.ref a 'readers) (.ref b 'readers))
   (set-intersect (.ref a 'destinations) (.ref b 'destinations))
   (set-intersect (.ref a 'capabilities) (.ref b 'capabilities))
   (max (.ref a 'lease-start) (.ref b 'lease-start))
   (min (.ref a 'lease-end) (.ref b 'lease-end))
   (agentic-ai-lab-ai-agentic-context-trust-min (.ref a 'trust-ceiling) (.ref b 'trust-ceiling))
   (append (.ref a 'obligations) (.ref b 'obligations))))

(def (agentic-ai-lab-ai-agentic-context-restriction-meet envelopes)
  (unless (and (pair? envelopes) (list? envelopes) (<= (length envelopes) 32)
               (every agentic-ai-lab-ai-agentic-context-restriction-envelope-shape? envelopes))
    (error "Restriction meet requires 1..32 valid RestrictionEnvelopes"))
  (foldl meet-two (car envelopes) (cdr envelopes)))

(def (agentic-ai-lab-ai-agentic-context-handoff-assess
      prepared-cut live-cut grant-active? envelope effective-role now-tick
      threat-severity threat-phase (residual-cut #f))
  (let* ((lease-valid? (and (< (.ref envelope 'lease-start) (.ref envelope 'lease-end))
                            (<= (.ref envelope 'lease-start) now-tick)
                            (< now-tick (.ref envelope 'lease-end))))
         (blocking-threat? (and (memq threat-severity '(high critical))
                                (memq threat-phase '(exposed realized))))
         (stale-residual? (and (eq? threat-phase 'accepted)
                               (not (equal? residual-cut live-cut))))
         (reason
          (cond
           ((not grant-active?) 'grant-revoked-or-inactive)
           ((not (equal? prepared-cut live-cut)) 'source-cut-drifted)
           ((not lease-valid?) 'restriction-lease-invalid-or-expired)
           ((not (agentic-ai-lab-ai-agentic-context-trust<=?
                  effective-role (.ref envelope 'trust-ceiling)))
            'exceeds-envelope-trust-ceiling)
           (blocking-threat? 'active-high-or-critical-threat)
           (stale-residual? 'stale-residual-risk-acceptance)
           (else 'handoff-eligible)))
         (kind 'agentic-ai-lab.ai-agentic-context.handoff-assessment.v1)
         (handoff-ready? (eq? reason 'handoff-eligible))
         (bound-cut (string-copy live-cut))
         (restriction-digest (string-copy (.ref envelope 'semantic-digest)))
         (action-authorized? #f))
    (.o kind handoff-ready? reason bound-cut restriction-digest action-authorized?)))

(def (agentic-ai-lab-ai-agentic-context-kv-prefix-admit
      cached-domain cached-principal cached-restriction-digest cached-prefix
      req-domain req-principal req-restriction-digest req-prefix)
  (let* ((reuse-admitted?
          (and (equal? cached-domain req-domain)
               (equal? cached-principal req-principal)
               (equal? cached-restriction-digest req-restriction-digest)
               (equal? cached-prefix req-prefix)))
         (kind 'agentic-ai-lab.ai-agentic-context.kv-prefix-decision.v1)
         (reason (cond
                  ((not (equal? cached-domain req-domain)) 'cross-domain-kv-blocked)
                  ((not (equal? cached-principal req-principal)) 'cross-principal-kv-blocked)
                  ((not (equal? cached-restriction-digest req-restriction-digest)) 'restriction-mismatch-kv-blocked)
                  ((not (equal? cached-prefix req-prefix)) 'prefix-mismatch)
                  (else 'isolated-prefix-reusable))))
    (.o kind reuse-admitted? reason)))

(def (agentic-ai-lab-ai-agentic-context-declassification-cert
      source-repo target-repo bound-source-cut bound-target-cut
      raw-digest redacted-digest preserves-defeaters?
      proposer declassifier recipient origin-role recipient-role)
  (unless (and (every text? (list source-repo target-repo bound-source-cut bound-target-cut
                                  raw-digest redacted-digest proposer declassifier recipient))
               (not (equal? raw-digest redacted-digest))
               (eq? preserves-defeaters? #t)
               (not (equal? proposer declassifier))
               (not (equal? recipient declassifier))
               (not (equal? proposer recipient))
               (agentic-ai-lab-ai-agentic-context-trust-role? origin-role)
               (agentic-ai-lab-ai-agentic-context-trust-role? recipient-role)
               (agentic-ai-lab-ai-agentic-context-trust<=? recipient-role origin-role))
    (error "DeclassificationCert requires redacted output, preserved defeaters, 3-party SoD and non-escalating trust"))
  (let* ((source-repo (string-copy source-repo))
         (target-repo (string-copy target-repo))
         (bound-source-cut (string-copy bound-source-cut))
         (bound-target-cut (string-copy bound-target-cut))
         (raw-digest (string-copy raw-digest))
         (redacted-digest (string-copy redacted-digest))
         (preserves-defeaters? #t)
         (proposer (string-copy proposer))
         (declassifier (string-copy declassifier))
         (recipient (string-copy recipient))
         (semantic-digest (digest (list 'context-declassification-cert.v1
                                        source-repo target-repo bound-source-cut bound-target-cut
                                        raw-digest redacted-digest proposer declassifier recipient
                                        origin-role recipient-role))))
    (.o (:: @ AiAgenticContextDeclassificationCert.)
        source-repo target-repo bound-source-cut bound-target-cut
        raw-digest redacted-digest preserves-defeaters?
        proposer declassifier recipient origin-role recipient-role
        semantic-digest)))

(def (reject-declass reason)
  (let ((admitted? #f))
    (.o admitted? reason)))

(def (agentic-ai-lab-ai-agentic-context-admit-declassification
      topology-verified? cert-active? cert live-source-cut live-target-cut
      requested-recipient delivered-digest)
  (cond
   ((not topology-verified?)
    (reject-declass 'unverified-cross-repo-topology))
   ((not cert-active?)
    (reject-declass 'declassification-cert-revoked))
   ((not (agentic-ai-lab-ai-agentic-context-declassification-cert-shape? cert))
    (reject-declass 'invalid-declassification-cert))
   ((not (and (equal? (.ref cert 'bound-source-cut) live-source-cut)
              (equal? (.ref cert 'bound-target-cut) live-target-cut)))
    (reject-declass 'cross-repo-cut-drifted))
   ((not (equal? (.ref cert 'recipient) requested-recipient))
    (reject-declass 'recipient-mismatch))
   ((equal? delivered-digest (.ref cert 'raw-digest))
    (reject-declass 'raw-payload-leak-blocked))
   ((not (equal? delivered-digest (.ref cert 'redacted-digest)))
    (reject-declass 'redacted-digest-mismatch))
   ((not (agentic-ai-lab-ai-agentic-context-trust<=?
          (.ref cert 'recipient-role) (.ref cert 'origin-role)))
    (reject-declass 'declassification-trust-escalation))
   (else
    (let ((admitted? #t)
          (reason 'admitted-redacted-declassification)
          (delivered-digest (string-copy delivered-digest))
          (effective-role (.ref cert 'recipient-role))
          (certificate-digest (string-copy (.ref cert 'semantic-digest)))
          (action-authorized? #f))
      (.o admitted? reason delivered-digest effective-role
          certificate-digest action-authorized?)))))

;;; ---------------------------------------------------------------------------
;;; Slice 51: Two-Zone KV-Prefix-Stable Prompt Serializer
;;; (`Frozen Canonical Prefix ++ Dynamic Suffix`)
;;; ---------------------------------------------------------------------------

(def (prefix-entry<? a b)
  (let ((ea (.ref a 'epoch))
        (eb (.ref b 'epoch)))
    (or (< ea eb)
        (and (= ea eb)
             (string<? (.ref a 'node-id) (.ref b 'node-id))))))

;; Serializes prompt context into two strictly separated zones:
;; - Zone A (`frozen-prefix-frames`): canonically sorted by `(epoch, node-id)`,
;;   invariant to peer arrival order and immutable within an epoch;
;; - Zone B (`dynamic-suffix-frames`): rolling L2/L3 drill-downs & Scoped Detours.
;; Modifying Zone B NEVER alters `frozen-prefix-bytes` or `frozen-prefix-digest`.
(def (agentic-ai-lab-ai-agentic-context-serialize-two-zone-prompt
      epoch frozen-entries dynamic-suffix-frames)
  (unless (and (exact-integer? epoch) (>= epoch 0)
               (list? frozen-entries)
               (list? dynamic-suffix-frames)
               (every string? dynamic-suffix-frames))
    (error "Invalid Two-Zone KV-Prefix serialization inputs"))
  (let* ((sorted-frozen (list-sort prefix-entry<? frozen-entries))
         (frozen-frames
          (map (lambda (e)
                 (string-append "[E" (number->string (.ref e 'epoch))
                                ":" (.ref e 'node-id) "] "
                                (.ref e 'content)))
               sorted-frozen))
         (frozen-bytes (string-join frozen-frames "\n"))
         (frozen-digest (digest (list 'two-zone-frozen-prefix.v1 epoch frozen-frames)))
         (suffix-frames (map string-copy dynamic-suffix-frames))
         (all-frames (append frozen-frames suffix-frames))
         (full-prompt (string-join all-frames "\n")))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.ai-agentic-context.two-zone-prompt-frame.v1
        epoch: epoch
        frozen-prefix-frames: frozen-frames
        frozen-prefix-count: (length frozen-frames)
        frozen-prefix-bytes: frozen-bytes
        frozen-prefix-digest: frozen-digest
        dynamic-suffix-frames: suffix-frames
        dynamic-suffix-count: (length suffix-frames)
        all-frames: all-frames
        full-prompt: full-prompt
        action-authorized?: #f)))

;;; ---------------------------------------------------------------------------
;;; Slice 50: APPA ConfinedDetour, NeuroTaint Offline Counterfactual Audit,
;;; Zero-Authority Stall Advisory & MindGuard Tool Schema-Digest Pinning
;;; ---------------------------------------------------------------------------

;; APPA-style Scoped Detour Taint Confinement:
;; - Inside a tainted detour, any external egress attempt is strictly blocked.
;; - Returning into a clean mainline requires EITHER bounded `attest-schema`
;;   passing OR a verified active 3-party SoD DeclassificationCert.
;; - Admitted returns preserve `mainline-tainted?: #f` (prevents label creep).
(def (agentic-ai-lab-ai-agentic-context-admit-confined-detour-return
      detour-tainted?: (detour-tainted? #t)
      egress-attempted?: (egress-attempted? #f)
      schema-attested?: (schema-attested? #f)
      declass-cert: (declass-cert #f)
      declass-cert-active?: (declass-cert-active? #f)
      live-source-cut: (live-source-cut #f)
      live-target-cut: (live-target-cut #f))
  (let* ((cert-ok?
          (and declass-cert
               declass-cert-active?
               (agentic-ai-lab-ai-agentic-context-declassification-cert-shape? declass-cert)
               live-source-cut live-target-cut
               (equal? (.ref declass-cert 'bound-source-cut) live-source-cut)
               (equal? (.ref declass-cert 'bound-target-cut) live-target-cut)))
         (reason
          (cond
           ((and detour-tainted? egress-attempted?) 'confined-detour-tainted-egress-blocked)
           ((and detour-tainted? (not schema-attested?) (not cert-ok?))
            'unattested-detour-return-blocked)
           (else 'confined-detour-return-admitted)))
         (admitted? (eq? reason 'confined-detour-return-admitted)))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.ai-agentic-context.confined-detour-decision.v1
        admitted?: admitted?
        reason: reason
        detour-tainted?: (and detour-tainted? #t)
        mainline-tainted?: #f
        egress-blocked?: (and detour-tainted? egress-attempted? #t)
        action-authorized?: #f)))

;; NeuroTaint-style Zero-LLM Offline Counterfactual Causal Dependence Audit:
;; Detects implicit secret leaks where an LLM flips a control/tool decision
;; without copying literal secret substrings.
(def (agentic-ai-lab-ai-agentic-context-causal-counterfactual-audit
      decision-with-secret decision-without-secret declass-certified?)
  (let* ((flipped? (not (equal? decision-with-secret decision-without-secret)))
         (certified? (and declass-certified? #t))
         (leak? (and flipped? (not certified?)))
         (reason (cond
                  (leak? 'uncertified-secret-flipped-decision)
                  (flipped? 'certified-causal-dependence)
                  (else 'counterfactual-invariant-clean))))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.ai-agentic-context.causal-counterfactual-audit.v1
        decision-flipped?: flipped?
        declass-certified?: certified?
        implicit-causal-leak?: leak?
        reason: reason
        llm-calls-used: 0
        action-authorized?: #f)))

;; Memento / SagaLLM-inspired deterministic stall & divergence advisory.
;; Hard invariant (Slice 50 Lean proven): NEVER authorizes automatic mutation.
(def (agentic-ai-lab-ai-agentic-context-evaluate-stall-advisory
      repeated-failures consecutive-invalidations threshold)
  (unless (and (exact-integer? repeated-failures) (>= repeated-failures 0)
               (exact-integer? consecutive-invalidations) (>= consecutive-invalidations 0)
               (exact-integer? threshold) (> threshold 0))
    (error "Invalid stall advisory inputs"))
  (let ((trigger? (or (>= repeated-failures threshold)
                      (>= consecutive-invalidations threshold))))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.ai-agentic-context.stall-advisory.v1
        suggest-park-or-cancel?: trigger?
        repeated-failures: repeated-failures
        consecutive-invalidations: consecutive-invalidations
        threshold: threshold
        authorizes-auto-mutation?: #f
        action-authorized?: #f)))

;; MindGuard-style Tool / MCP schema-digest pinning gate.
(def (agentic-ai-lab-ai-agentic-context-verify-tool-schema-pin
      tool-id pinned-schema-digest live-schema-descriptor)
  (unless (and (text? tool-id) (text? pinned-schema-digest))
    (error "Tool schema pin verification requires tool-id and pinned-schema-digest"))
  (let* ((live-digest (if (string? live-schema-descriptor)
                        live-schema-descriptor
                        (digest (list 'tool-schema-pin.v1 tool-id live-schema-descriptor))))
         (matched? (equal? pinned-schema-digest live-digest))
         (reason (if matched? 'tool-schema-pin-verified 'tool-schema-drift-blocked)))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.ai-agentic-context.tool-schema-pin-decision.v1
        tool-id: (string-copy tool-id)
        admitted?: matched?
        reason: reason
        pinned-digest: (string-copy pinned-schema-digest)
        live-digest: live-digest
        action-authorized?: #f)))

;; Capstone 47: Executable Zero-LLM DeterministicAuditCapsule Cold Replay Verifier.
(def (agentic-ai-lab-ai-agentic-context-replay-audit-capsule
      org-bytes journal-entries bound-cut live-cut expected-commitment)
  (unless (and (string? org-bytes) (list? journal-entries)
               (text? bound-cut) (text? live-cut) (text? expected-commitment))
    (error "Invalid AuditCapsule cold replay inputs"))
  (let* ((recomputed (digest (list 'deterministic-audit-capsule.v1
                                   bound-cut org-bytes journal-entries)))
         (cold-ok? (equal? recomputed expected-commitment))
         (hot-ok? (and cold-ok? (equal? bound-cut live-cut))))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.ai-agentic-context.audit-capsule-replay.v1
        bound-cut: (string-copy bound-cut)
        live-cut: (string-copy live-cut)
        recomputed-commitment: recomputed
        cold-forensic-verified?: cold-ok?
        hot-applicable?: hot-ok?
        llm-calls-used: 0
        action-authorized?: #f)))
