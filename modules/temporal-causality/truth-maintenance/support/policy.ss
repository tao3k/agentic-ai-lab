;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Caller-declared policy window and replay binding; never a proof or grant.
(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :clan/poo/mop validate)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/objects agentic-ai-lab-temporal-instant)
        "types.ss" "funs.ss")
(export agentic-ai-lab-temporal-support-policy agentic-ai-lab-temporal-support-policy-status agentic-ai-lab-temporal-support-guard
        agentic-ai-lab-temporal-support-guard-replay agentic-ai-lab-temporal-support-claim)
(def (text? x) (and (string? x) (< 0 (string-length x) 257)))
(def (digest x) (string-append "sha256:" (hex-encode (sha256 (string->utf8
  (call-with-output-string (lambda (p) (write x p))))))))
(def (instant x)
  (unless (and (object? x) (.slot? x 'kind)
               (eq? (.ref x 'kind) 'agentic-ai-lab.temporal-causality.instant))
    (error "invalid policy instant"))
  (let (value (agentic-ai-lab-temporal-instant (.ref x 'identity) (.ref x 'domain-identity)
               (.ref x 'coordinate) (.ref x 'provenance-identity) (.ref x 'modality)))
    (unless (and (integer? (.ref value 'coordinate)) (exact? (.ref value 'coordinate))
                 (eq? (.ref value 'modality) 'observed))
      (error "policy requires explicit observed integer coordinate")) value))
(def (instant-row x)
  (map (lambda (s) (.ref x s)) '(identity domain-identity coordinate provenance-identity modality)))
(def (agentic-ai-lab-temporal-support-policy id revision start end)
  (unless (and (text? id) (text? revision)) (error "invalid support policy identity"))
  (let* ((a (instant start)) (b (instant end))
         (domain (.ref a 'domain-identity)))
    (unless (and (equal? domain (.ref b 'domain-identity))
                 (< (.ref a 'coordinate) (.ref b 'coordinate)))
      (error "policy window must be nonempty in one time domain"))
    (validate AgenticAILabTemporalSupportPolicy
      (.o kind: 'agentic-ai-lab.temporal-causality.support-policy identity: id revision-identity: revision
          start: a end: b semantic-digest: (digest
            (list 'agentic-ai-lab.temporal-support-policy.v1 id revision (instant-row a) (instant-row b)))))))
(def (canonical-policy policy)
  (unless (and (object? policy) (.slot? policy 'kind)
               (eq? (.ref policy 'kind) 'agentic-ai-lab.temporal-causality.support-policy))
    (error "invalid support policy"))
  (let (value (agentic-ai-lab-temporal-support-policy (.ref policy 'identity)
               (.ref policy 'revision-identity) (.ref policy 'start) (.ref policy 'end)))
    (unless (equal? (.ref value 'semantic-digest) (.ref policy 'semantic-digest))
      (error "support policy digest mismatch")) value))
;;; Shared temporal applicability; Context use consumes the existing clock owner.
(def (agentic-ai-lab-temporal-support-policy-status policy expected-digest effective-at)
  (unless (text? expected-digest) (error "expected policy digest required"))
  (let* ((owned (canonical-policy policy)) (now (instant effective-at))
         (start (.ref owned 'start)) (end (.ref owned 'end)))
    (unless (equal? (.ref now 'domain-identity) (.ref start 'domain-identity))
      (error "policy evaluation time domain mismatch"))
    (cond ((not (equal? expected-digest (.ref owned 'semantic-digest))) 'stale-policy)
          ((< (.ref now 'coordinate) (.ref start 'coordinate)) 'not-yet-effective)
          ((>= (.ref now 'coordinate) (.ref end 'coordinate)) 'expired-policy)
          (else 'applicable))))
(def (agentic-ai-lab-temporal-support-guard program journal as-of-value valid-at-value budget-value policy expected-digest effective-at)
  (unless (text? expected-digest) (error "expected policy digest required"))
  (let* ((owned (canonical-policy policy)) (now (instant effective-at))
         (evaluation-value (agentic-ai-lab-temporal-support-evaluate program journal as-of-value valid-at-value budget-value))
         (start (.ref owned 'start)) (end (.ref owned 'end)))
    (unless (equal? (.ref now 'domain-identity) (.ref start 'domain-identity))
      (error "policy evaluation time domain mismatch"))
    (unless (equal? (.ref program 'policy-identity) (.ref owned 'identity))
      (error "support program policy owner mismatch"))
    (let* ((status (agentic-ai-lab-temporal-support-policy-status owned expected-digest now))
           (fingerprint (digest (list 'agentic-ai-lab.temporal-support-guard.v1
              (.ref evaluation-value 'semantic-digest) (.ref owned 'semantic-digest)
              expected-digest (instant-row now) status))))
      (validate AgenticAILabTemporalSupportGuard
        (.o kind: 'agentic-ai-lab.temporal-causality.support-guard semantic-digest: fingerprint
            policy: owned policy-digest: (.ref owned 'semantic-digest)
            expected-policy-digest: expected-digest effective-at: now policy-status: status
            policy-applicable?: (eq? status 'applicable) evaluation: evaluation-value
            as-of: as-of-value valid-at: valid-at-value budget: budget-value
            proof-admitted?: #f source-authenticated?: #f selection-admitted?: #f
            action-authorized?: #f durable?: #f)))))
(def (agentic-ai-lab-temporal-support-guard-replay receipt program journal policy)
  (unless (and (object? receipt) (.slot? receipt 'kind)
               (eq? (.ref receipt 'kind) 'agentic-ai-lab.temporal-causality.support-guard)
               (not (.ref receipt 'proof-admitted?)) (not (.ref receipt 'source-authenticated?))
               (not (.ref receipt 'selection-admitted?)) (not (.ref receipt 'action-authorized?))
               (not (.ref receipt 'durable?)))
    (error "invalid support guard receipt"))
  (let (value (agentic-ai-lab-temporal-support-guard program journal (.ref receipt 'as-of)
               (.ref receipt 'valid-at) (.ref receipt 'budget) policy
               (.ref receipt 'expected-policy-digest) (.ref receipt 'effective-at)))
    (unless (and (equal? (.ref value 'semantic-digest) (.ref receipt 'semantic-digest))
                 (equal? (.ref value 'policy-digest) (.ref receipt 'policy-digest))
                 (equal? (.ref (.ref value 'policy) 'semantic-digest)
                         (.ref (canonical-policy (.ref receipt 'policy)) 'semantic-digest))
                 (equal? (.ref value 'policy-status) (.ref receipt 'policy-status))
                 (equal? (.ref value 'policy-applicable?) (.ref receipt 'policy-applicable?))
                 (equal? (.ref (.ref value 'evaluation) 'semantic-digest)
                         (.ref (.ref receipt 'evaluation) 'semantic-digest)))
      (error "support guard replay binding mismatch")) value))

;;; A read-only projection of a native policy guard, never an effect permit.
(def (agentic-ai-lab-temporal-support-claim guard-value identity expected-binding)
  (validate AgenticAILabTemporalSupportGuard guard-value)
  (unless (and (text? identity) (or (not expected-binding) (text? expected-binding)))
    (error "invalid native claim selection"))
  (let* ((matches (filter (lambda (row) (equal? (.ref row 'identity) identity))
                    (.ref (.ref guard-value 'evaluation) 'conclusions)))
         (binding (.ref guard-value 'semantic-digest))
         (fresh? (or (not expected-binding) (equal? expected-binding binding))))
    (unless (= (length matches) 1) (error "claim outside named inventory"))
    (validate AgenticAILabTemporalSupportClaim
      (.o kind: 'agentic-ai-lab.temporal-causality.support-claim claim: (car matches)
          status: (if (and fresh? (.ref guard-value 'policy-applicable?)) (.ref (car matches) 'status) 'unknown)
          context-status: (if fresh? 'matches-cut 'stale-context)
          binding-digest: binding guard: guard-value proof-admitted?: #f source-authenticated?: #f
          selection-admitted?: #f action-authorized?: #f durable?: #f))))
