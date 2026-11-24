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
        agentic-ai-lab-ai-agentic-context-admit-declassification)

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
