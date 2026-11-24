;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Epistemic Projection, ASCENT Security Branch Gating & Temporal Quotient
;;; Consolidation (Slices 41, 43, 44 & 45).
(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :std/list/list every find delete-duplicates/hash append-map)
        "types.ss" "objects.ss" "funs-scope.ss")
(export agentic-ai-lab-ai-agentic-context-project-epistemic
        agentic-ai-lab-ai-agentic-context-admit-security-branch
        agentic-ai-lab-ai-agentic-context-admit-consolidation
        agentic-ai-lab-ai-agentic-context-quotient-survives?
        agentic-ai-lab-ai-agentic-context-join-provider-receipts
        agentic-ai-lab-ai-agentic-context-memory-candidate
        agentic-ai-lab-ai-agentic-context-admit-memory-promotion
        agentic-ai-lab-ai-agentic-context-recall-memories)

(def digest agentic-ai-lab-ai-agentic-context-digest)

(def (text? x) (and (string? x) (< 0 (string-length x) 257)))

(def (agentic-ai-lab-ai-agentic-context-project-epistemic
      inquiry-id restriction-digest restriction-cost live-hypotheses selected-ids budget)
  (unless (and (text? inquiry-id) (text? restriction-digest)
               (exact-integer? restriction-cost) (>= restriction-cost 0)
               (exact-integer? budget) (>= budget 0)
               (pair? live-hypotheses) (list? live-hypotheses)
               (list? selected-ids) (every text? selected-ids))
    (error "Invalid epistemic projection inputs"))
  (let* ((live-ids (map (cut .ref <> 'id) live-hypotheses))
         (_ (unless (every (cut member <> live-ids) selected-ids)
              (error "Selected hypothesis is not in live inquiry set")))
         (chosen (filter (lambda (h) (member (.ref h 'id) selected-ids)) live-hypotheses))
         (retained-defeaters
          (list-sort string<?
            (delete-duplicates/hash
             (append-map (lambda (h) (map string-copy (.ref h 'defeaters))) chosen))))
         (hyp-cost (foldl (lambda (h acc) (+ acc (.ref h 'cost))) 0 chosen))
         (total-cost (+ restriction-cost hyp-cost (length retained-defeaters)))
         (omitted (list-sort string<?
                    (filter (lambda (id) (not (member id selected-ids))) live-ids))))
    (if (> total-cost budget)
      (let ((admitted? #f)
            (status 'refused-over-budget)
            (inquiry-id (string-copy inquiry-id))
            (selected-hypotheses '())
            (retained-defeaters '())
            (restriction-digest (string-copy restriction-digest))
            (omission-receipt #f)
            (claims-exhaustive? #f))
        (.o (:: @ AiAgenticContextEpistemicProjection.)
            admitted? status inquiry-id budget total-cost
            selected-hypotheses retained-defeaters restriction-digest
            omission-receipt claims-exhaustive?))
      (let* ((exhaustive? (null? omitted))
             (omission-receipt
              (and (not exhaustive?)
                   (let ((inquiry-id (string-copy inquiry-id))
                         (omitted-hypotheses (map string-copy omitted))
                         (claims-exhaustive? #f)
                         (semantic-digest (digest (list 'omitted-alternatives.v1 inquiry-id omitted))))
                     (.o (:: @ AiAgenticContextOmittedAlternativesReceipt.)
                         inquiry-id omitted-hypotheses claims-exhaustive? semantic-digest))))
             (admitted? #t)
             (status 'admitted)
             (inquiry-id (string-copy inquiry-id))
             (selected-hypotheses (map (lambda (h) (string-copy (.ref h 'id))) chosen))
             (restriction-digest (string-copy restriction-digest))
             (claims-exhaustive? exhaustive?))
        (.o (:: @ AiAgenticContextEpistemicProjection.)
            admitted? status inquiry-id budget total-cost
            selected-hypotheses retained-defeaters restriction-digest
            omission-receipt claims-exhaustive?)))))

(def (agentic-ai-lab-ai-agentic-context-admit-security-branch projection branch)
  (unless (agentic-ai-lab-ai-agentic-context-epistemic-projection-shape? projection)
    (error "Security branch gate requires an EpistemicProjection"))
  (let* ((proj-hyps (.ref projection 'selected-hypotheses))
         (eval-hyps (.ref branch 'evaluated-hypotheses))
         (branch-kind (.ref branch 'branch-kind))
         (matrix-complete? (every (cut member <> eval-hyps) proj-hyps))
         (reason
          (cond
           ((not (.ref projection 'admitted?)) 'projection-not-admitted)
           ((not (memq branch-kind '(read-discriminator destructive-remediation))) 'unknown-branch-kind)
           ((.ref branch 'used-missing-claim-shortcut?) 'missing-claim-likelihood-shortcut-forbidden)
           ((.ref branch 'used-hypothetical-fit-shortcut?) 'hypothetical-fit-authority-forbidden)
           ((not matrix-complete?) 'incomplete-projected-hypothesis-matrix)
           ((not (.ref branch 'scope-grant-active?)) 'missing-branch-scope-grant)
           ((and (eq? branch-kind 'destructive-remediation)
                 (not (.ref projection 'claims-exhaustive?)))
            'destructive-branch-blocked-by-omitted-alternatives)
           (else 'branch-admitted)))
         (kind 'agentic-ai-lab.ai-agentic-context.security-branch-decision.v1)
         (admitted? (eq? reason 'branch-admitted))
         (branch-id (string-copy (.ref branch 'id)))
         (claims-exhaustive? (.ref projection 'claims-exhaustive?))
         (action-authorized? #f))
    (.o kind admitted? reason branch-id branch-kind claims-exhaustive? action-authorized?)))

(def (three-way-distinct? p e a)
  (and (every text? (list p e a))
       (not (equal? p e)) (not (equal? p a)) (not (equal? e a))))

(def (agentic-ai-lab-ai-agentic-context-admit-consolidation req)
  (let* ((raw-insight-id (.ref req 'insight-id))
         (raw-proposer (.ref req 'proposer))
         (raw-evidence-owner (.ref req 'evidence-owner))
         (raw-approver (.ref req 'approver))
         (outcome-digest (.ref req 'outcome-receipt-digest))
         (outcome-supported? (.ref req 'outcome-supported?))
         (raw-cited (.ref req 'cited-premises))
         (raw-defeats (.ref req 'defeat-conditions))
         (raw-cost (.ref req 'raw-cost))
         (quotient-cost (.ref req 'quotient-cost))
         (raw-hook (.ref req 'audit-hook-id))
         (uses-why-not? (.ref req 'uses-why-not?))
         (raw-wm (.ref req 'watermark-covered?))
         (promote-to-org? (.ref req 'promote-to-org?))
         (org-write-grant? (.ref req 'org-write-grant?))
         (reason
          (cond
           ((not (and (text? outcome-digest) outcome-supported?)) 'unanchored-or-unsupported-outcome)
           ((not (three-way-distinct? raw-proposer raw-evidence-owner raw-approver)) 'consolidation-sod-violation)
           ((not (and (pair? raw-defeats) (every text? raw-defeats))) 'missing-defeat-conditions)
           ((not (and (pair? raw-cited) (every text? raw-cited))) 'missing-cited-premises)
           ((not (and (exact-integer? raw-cost) (exact-integer? quotient-cost)
                      (< 0 quotient-cost raw-cost)))
            'no-strict-entropy-reduction)
           ((not (text? raw-hook)) 'missing-reverse-dependency-audit-hook)
           ((and uses-why-not? (not raw-wm)) 'why-not-blocked-by-uncovered-watermark)
           ((and promote-to-org? (not org-write-grant?)) 'org-promotion-lacks-write-grant)
           (else 'consolidation-admitted)))
         (admitted? (eq? reason 'consolidation-admitted))
         (insight-id (string-copy raw-insight-id))
         (proposer (string-copy raw-proposer))
         (evidence-owner (string-copy raw-evidence-owner))
         (approver (string-copy raw-approver))
         (outcome-receipt-digest (and (string? outcome-digest) (string-copy outcome-digest)))
         (cited-premises (if (list? raw-cited) (map string-copy raw-cited) '()))
         (defeat-conditions (if (list? raw-defeats) (map string-copy raw-defeats) '()))
         (audit-hook-id (and (string? raw-hook) (string-copy raw-hook)))
         (watermark-covered? (and raw-wm #t))
         (org-promoted? (and admitted? promote-to-org? #t))
         (semantic-digest (and admitted?
                               (digest (list 'consolidation-receipt.v1 insight-id proposer
                                             evidence-owner approver outcome-digest
                                             cited-premises defeat-conditions quotient-cost
                                             audit-hook-id)))))
    (.o (:: @ AiAgenticContextConsolidationReceipt.)
        admitted? reason insight-id proposer evidence-owner approver
        outcome-receipt-digest cited-premises defeat-conditions
        raw-cost quotient-cost audit-hook-id watermark-covered?
        org-promoted? semantic-digest)))

(def (agentic-ai-lab-ai-agentic-context-quotient-survives?
      receipt consumer-read-grant? outcome-still-live? active-premises current-citations)
  (unless (agentic-ai-lab-ai-agentic-context-consolidation-receipt-shape? receipt)
    (error "Survival check requires a ConsolidationReceipt"))
  (let* ((cited (.ref receipt 'cited-premises))
         (post-hoc-added? (not (equal? cited current-citations)))
         (all-cited-active? (every (cut member <> active-premises) cited))
         (reason
          (cond
           ((not (.ref receipt 'admitted?)) 'never-admitted)
           ((not consumer-read-grant?) 'consumer-lacks-independent-read-grant)
           ((not outcome-still-live?) 'bound-outcome-retracted)
           (post-hoc-added? 'unreviewed-post-admission-citation)
           ((not all-cited-active?) 'cited-premise-retracted-or-uncertain)
           (else 'causally-survives)))
         (survives? (eq? reason 'causally-survives))
         (historical-audit-retained? #t)
         (action-authorized? #f))
    (.o survives? reason historical-audit-retained? action-authorized?)))

(def (agentic-ai-lab-ai-agentic-context-join-provider-receipts
      active-generation required-providers receipts)
  (unless (and (exact-integer? active-generation) (>= active-generation 1)
               (pair? required-providers) (list? required-providers)
               (every symbol? required-providers) (list? receipts))
    (error "Invalid multi-provider exchange join inputs"))
  (let* ((at-gen (filter (lambda (r) (= (.ref r 'generation) active-generation)) receipts))
         (duplicate-conflict?
          (let loop ((rest at-gen) (seen (make-hash-table)))
            (if (null? rest) #f
              (let* ((r (car rest))
                     (p (.ref r 'provider))
                     (sig (list (.ref r 'result-digest) (.ref r 'complete?)))
                     (prior (hash-get seen p)))
                (cond
                 ((and prior (not (equal? prior sig))) #t)
                 (else (hash-put! seen p sig) (loop (cdr rest) seen)))))))
         (all-complete?
          (every (lambda (req-p)
                   (find (lambda (r)
                           (and (eq? (.ref r 'provider) req-p)
                                (eq? (.ref r 'complete?) #t)))
                         at-gen))
                 required-providers))
         (reason
          (cond
           (duplicate-conflict? 'conflicting-same-generation-provider-retry)
           ((not all-complete?) 'missing-or-incomplete-provider-at-active-generation)
           (else 'exchange-published)))
         (kind 'agentic-ai-lab.ai-agentic-context.provider-exchange-join.v1)
         (published? (eq? reason 'exchange-published))
         (retained-history-count (length receipts))
         (action-authorized? #f))
    (.o kind published? reason active-generation retained-history-count action-authorized?)))

;;; ---------------------------------------------------------------------------
;;; Slice 51: Quarantine-Before-Recall & Typed MemoryContract (MINJA / MemoryGraft)
;;; ---------------------------------------------------------------------------

;; Constructs a typed MemoryContract candidate.
;; Any `untrusted-ingest` (or non-`trusted-internal`) candidate is ALWAYS forced
;; into `memory-tier: 'quarantined`, even if `self-claimed-success?: #t`.
(def (agentic-ai-lab-ai-agentic-context-memory-candidate
      candidate-id origin-trust payload-digest
      self-claimed-success?: (self-claimed-success? #f)
      open-defeaters: (open-defeaters '())
      proposer: (proposer "agent-proposer"))
  (unless (and (text? candidate-id)
               (memq origin-trust '(trusted-internal untrusted-ingest))
               (text? payload-digest)
               (text? proposer)
               (list? open-defeaters)
               (every text? open-defeaters))
    (error "Invalid MemoryContractCandidate inputs"))
  (let* ((cid (string-copy candidate-id))
         (pdig (string-copy payload-digest))
         (prop (string-copy proposer))
         (defs (list-sort string<? (delete-duplicates/hash (map string-copy open-defeaters))))
         (self-ok? (and self-claimed-success? #t))
         (tier (if (and (eq? origin-trust 'trusted-internal) (null? defs))
                 'recallable
                 'quarantined))
         (semantic-digest (digest (list 'memory-contract-candidate.v1 cid origin-trust pdig prop defs))))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.ai-agentic-context.memory-contract-candidate.v1
        candidate-id: cid
        origin-trust: origin-trust
        payload-digest: pdig
        proposer: prop
        self-claimed-success?: self-ok?
        open-defeaters: defs
        memory-tier: tier
        semantic-digest: semantic-digest
        action-authorized?: #f)))

;; Promotes a quarantined MemoryContract candidate into `recallable` ONLY when
;; backed by an independent EndorsementReceipt (`proposer != endorser`) on
;; `live-cut` AND zero open defeaters. Self-claimed success NEVER auto-promotes.
(def (agentic-ai-lab-ai-agentic-context-admit-memory-promotion
      candidate live-cut (endorsement #f) (reject? #f))
  (unless (and (object? candidate)
               (.slot? candidate 'kind)
               (eq? (.ref candidate 'kind)
                    'agentic-ai-lab.ai-agentic-context.memory-contract-candidate.v1)
               (text? live-cut))
    (error "Memory promotion requires a valid MemoryContractCandidate and live-cut"))
  (let* ((orig-tier (.ref candidate 'memory-tier))
         (defs (.ref candidate 'open-defeaters))
         (pdig (.ref candidate 'payload-digest))
         (prop (.ref candidate 'proposer))
         (reason
          (cond
           (reject? 'quarantined-candidate-rejected)
           ((eq? orig-tier 'rejected) 'already-rejected)
           ((pair? defs) 'open-defeaters-block-promotion)
           ((not endorsement)
            (if (and (eq? (.ref candidate 'origin-trust) 'untrusted-ingest)
                     (.ref candidate 'self-claimed-success?))
              'untrusted-self-claimed-success-blocked
              'missing-independent-endorsement))
           ((not (agentic-ai-lab-ai-agentic-context-endorsement-receipt-shape? endorsement))
            'invalid-endorsement-receipt)
           ((equal? (.ref endorsement 'proposer) (.ref endorsement 'endorser))
            'self-endorsement-forbidden)
           ((not (equal? (.ref endorsement 'proposer) prop))
            'endorsement-proposer-mismatch)
           ((not (equal? (.ref endorsement 'content-digest) pdig))
            'endorsement-digest-mismatch)
           ((not (equal? (.ref endorsement 'bound-cut) live-cut))
            'stale-endorsement-cut)
           (else 'promoted-to-recallable)))
         (promoted? (eq? reason 'promoted-to-recallable))
         (next-tier (cond
                     (reject? 'rejected)
                     (promoted? 'recallable)
                     (else orig-tier)))
         (updated (.o (:: @ candidate)
                      bind-these: #f
                      memory-tier: next-tier)))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.ai-agentic-context.memory-promotion-decision.v1
        promoted?: promoted?
        reason: reason
        memory-tier: next-tier
        candidate: updated
        action-authorized?: #f)))

;; Production recall strictly queries `memory-tier == 'recallable`, guaranteeing
;; zero quarantined or rejected (MINJA / MemoryGraft) leakage into agent context.
(def (agentic-ai-lab-ai-agentic-context-recall-memories candidates)
  (unless (list? candidates)
    (error "Memory recall expects a list of MemoryContractCandidate objects"))
  (let* ((recalled (filter (lambda (c)
                             (and (object? c)
                                  (.slot? c 'memory-tier)
                                  (eq? (.ref c 'memory-tier) 'recallable)))
                           candidates))
         (excluded-count (- (length candidates) (length recalled))))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.ai-agentic-context.memory-recall-view.v1
        recalled: recalled
        recalled-count: (length recalled)
        quarantined-or-rejected-excluded: excluded-count
        action-authorized?: #f)))
