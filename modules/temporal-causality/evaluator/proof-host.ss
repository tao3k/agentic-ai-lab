;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Library proof retention and Host current-state selection. No effect grant.
(import (only-in :clan/poo/object .o .ref .slot? object? .call)
        (only-in :std/list/list delete-duplicates/hash)
        (only-in :agentic-ai-lab/modules/temporal-causality/truth-maintenance/objects agentic-ai-lab-temporal-derivation)
        (only-in :agentic-ai-lab/modules/temporal-causality/truth-maintenance/funs agentic-ai-lab-temporal-dependency-index agentic-ai-lab-temporal-reverse-dependency-plan)
        (only-in :std/crypto/digest sha256) (only-in :std/encoding/hex hex-encode)
        (only-in :agentic-ai-lab/modules/temporal-causality/revisions/interface agentic-ai-lab-temporal-evidence-journal)
        (only-in :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/interface agentic-ai-lab-temporal-support-program)
        (only-in :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy-host
                 agentic-ai-lab-temporal-support-policy-host-guard-current)
        "derivation.ss" "rule.ss")
(export agentic-ai-lab-temporal-derivation-context agentic-ai-lab-temporal-proof-host
        agentic-ai-lab-temporal-proof-host-refresh! agentic-ai-lab-temporal-proof-host-register!
        agentic-ai-lab-temporal-proof-host-current
        agentic-ai-lab-temporal-proof-host-watch! agentic-ai-lab-temporal-proof-host-unwatch! agentic-ai-lab-temporal-proof-host-drain!
        agentic-ai-lab-temporal-proof-host-pending? agentic-ai-lab-temporal-proof-host-policy agentic-ai-lab-temporal-proof-host-retained-digest agentic-ai-lab-temporal-proof-host-source-snapshot)
(defstruct proof-context (admission arguments program journal))
(defstruct proof-host-state (policy-host current proofs owner observers pending busy?))
(def (text? x) (and (string? x) (< 0 (string-length x) 257)))
(def (tag? x k) (and (object? x) (.slot? x 'kind) (eq? (.ref x 'kind) k)))
(def (digest x) (string-append "sha256:" (hex-encode (sha256 (string->utf8
  (call-with-output-string (lambda (p) (write x p))))))))
(def (canonical-program p)
  (let (v (agentic-ai-lab-temporal-rule-program (.ref p 'identity) (.ref p 'catalog-digest)
             (.ref p 'generation) (.ref p 'ascent-generation) (.ref p 'relations) (.ref p 'rules)))
    (unless (equal? (.ref v 'semantic-digest) (.ref p 'semantic-digest)) (error "forged proof host catalog")) v))
(def (canonical-journal j)
  (unless (<= (length (.ref j 'revisions)) 128) (error "proof host journal capacity exceeded"))
  (let (v (agentic-ai-lab-temporal-evidence-journal (.ref j 'identity) (.ref j 'admission-domain-identity) (.ref j 'revisions)))
    (unless (equal? (.ref v 'semantic-digest) (.ref j 'semantic-digest)) (error "forged proof host journal")) v))
;;; Pure native owner adapter. The context retains original replay inputs; it is
;;; not accepted from a wire and caller flags never become authority.
(def (agentic-ai-lab-temporal-derivation-context held program correspondence bound admission snapshot candidate receipt
                                         steps max-nodes node-bindings output source-bindings journal)
  (let* ((arguments-value (list program correspondence bound admission snapshot candidate receipt
                                steps max-nodes node-bindings output source-bindings journal))
         (verified-value (apply agentic-ai-lab-temporal-mrr-derivation-admission-replay (cons held arguments-value)))
         (private-value (make-proof-context verified-value arguments-value (canonical-program program) (canonical-journal journal))))
    (.o kind: 'temporal.derivation-context.v1 semantic-digest: (.ref verified-value 'semantic-digest)
        private-context: private-value)))
(def (context value)
  (unless (and (tag? value 'temporal.derivation-context.v1) (.slot? value 'private-context)
               (proof-context? (.ref value 'private-context))) (error "invalid retained proof context"))
  (let* ((c (.ref value 'private-context))
         (verified (apply agentic-ai-lab-temporal-mrr-derivation-admission-replay
                     (cons (proof-context-admission c) (proof-context-arguments c)))))
    (unless (equal? (.ref value 'semantic-digest) (.ref verified 'semantic-digest))
      (error "retained proof context digest mismatch")) c))
(def (agentic-ai-lab-temporal-proof-host policy-host-value)
  (let (runtime-value (make-proof-host-state policy-host-value (make-hash-table) (make-hash-table) (current-thread) '() #f #f))
    (.o kind: 'temporal.proof-host.v1 private-runtime-state: runtime-value)))
(def (state host)
  (unless (and (tag? host 'temporal.proof-host.v1) (.slot? host 'private-runtime-state)
               (proof-host-state? (.ref host 'private-runtime-state))) (error "invalid proof host capability"))
  (let (runtime-value (.ref host 'private-runtime-state))
    (unless (eq? (proof-host-state-owner runtime-value) (current-thread))
      (error "Temporal proof Host requires its serialized owner thread")) runtime-value))
;;; A Host explicitly registers the catalog and complete append-only journal.
;;; Validate the entire refresh before changing any current state.
(def (agentic-ai-lab-temporal-proof-host-refresh! host identity-value generation-value program journal)
  (unless (and (text? identity-value) (exact-integer? generation-value) (<= 0 generation-value))
    (error "invalid proof host state identity or generation"))
  (when (or (proof-host-state-pending (state host)) (proof-host-state-busy? (state host))) (error "Drain pending proof propagation before refresh"))
  (let* ((s (state host)) (p (canonical-program program)) (j (canonical-journal journal))
         (current (proof-host-state-current s)) (old (hash-get current identity-value))
         (fingerprint-value (digest (list 'temporal.proof-host-snapshot.v1 identity-value generation-value
                                         (.ref p 'semantic-digest) (.ref j 'semantic-digest)))))
    (when old
      (unless (or (> generation-value (.ref old 'generation))
                  (and (= generation-value (.ref old 'generation))
                       (equal? fingerprint-value (.ref old 'semantic-digest))))
        (error "proof host generation rollback or conflict"))
      (let* ((old-j (.ref old 'journal)) (ids (map (lambda (r) (.ref r 'identity)) (.ref old-j 'revisions)))
             (retained (filter (lambda (r) (member (.ref r 'identity) ids)) (.ref j 'revisions)))
             (prefix (agentic-ai-lab-temporal-evidence-journal (.ref j 'identity) (.ref j 'admission-domain-identity) retained)))
        (unless (equal? (.ref prefix 'semantic-digest) (.ref old-j 'semantic-digest))
          (error "proof host cannot rewrite or remove evidence history"))))
    (unless (or old (< (hash-length current) 128)) (error "proof host state capacity exceeded"))
    (let (value (.o kind: 'temporal.proof-host-snapshot.v1 identity: (string-copy identity-value)
                   generation: generation-value program: p journal: j semantic-digest: fingerprint-value
                   source-authenticated?: #f action-authorized?: #f durable?: #f))
      (let* ((changed? (and old (not (equal? fingerprint-value (.ref old 'semantic-digest)))))
             (event (and changed? (pair? (proof-host-state-observers s)) (source-change s identity-value old value)))
             ;; All observers prepare/validate before source mutation. Batches are
             ;; owner-local capabilities, never caller verdicts or wire handlers.
             (batches (if event
                        (dynamic-wind
                          (lambda () (set! (proof-host-state-busy? s) #t))
                          (lambda () (map (lambda (observer)
                            (let (batch (.call observer .prepare observer event))
                              (unless (and (tag? batch 'temporal.source-propagation-batch.v1) (.slot? batch '.publish!))
                                (error "Invalid prepared native propagation batch")) batch))
                            (proof-host-state-observers s)))
                          (lambda () (set! (proof-host-state-busy? s) #f))) '())))
        (when event (set! (proof-host-state-pending s) batches))
        (hash-put! current (string-copy identity-value) value)
        (when event (agentic-ai-lab-temporal-proof-host-drain! host))
        value))))
(def (agentic-ai-lab-temporal-proof-host-register! host identity-value expected-state-digest context-value policy-identity-value)
  (unless (and (text? identity-value) (text? expected-state-digest) (text? policy-identity-value))
    (error "invalid proof host registration"))
  (let* ((s (state host)) (current (hash-get (proof-host-state-current s) identity-value))
         (_ (when (or (proof-host-state-pending s) (proof-host-state-busy? s))
              (error "Cannot register proof during propagation")))
         (c (context context-value)) (a (proof-context-admission c))
         (proof-digest-value (.ref a 'semantic-digest))
         (key-value (digest (list 'temporal.proof-host-registration.v1 identity-value expected-state-digest
                                  proof-digest-value policy-identity-value)))
         (proofs (proof-host-state-proofs s)))
    (unless (and current (equal? expected-state-digest (.ref current 'semantic-digest))
                 (equal? (.ref (canonical-program (.ref current 'program)) 'semantic-digest)
                         (.ref (proof-context-program c) 'semantic-digest))
                 (equal? (.ref (canonical-journal (.ref current 'journal)) 'semantic-digest)
                         (.ref (proof-context-journal c) 'semantic-digest)))
      (error "unregistered or stale proof host state"))
    (unless (or (hash-key? proofs key-value) (< (hash-length proofs) 128))
      (error "proof host admission capacity exceeded"))
    (unless (hash-key? proofs key-value)
      (hash-put! proofs key-value (list (string-copy identity-value) context-value
                                       (string-copy policy-identity-value) (string-copy expected-state-digest)
                                       ;; Owner-sealed historical credential, independent of
                                       ;; caller-owned registration/context string aliases.
                                       (string-copy proof-digest-value))))
    (.o kind: 'temporal.proof-host-registration.v1 identity: (string-copy key-value)
        proof-digest: (string-copy proof-digest-value)
        original-state-digest: (string-copy expected-state-digest) proof-admitted?: #t
        source-authenticated?: #f selection-admitted?: #f action-authorized?: #f durable?: #f)))
;;; Read-only owner-thread use. Neither a replacement journal/catalog nor a
;;; historical cut/effective clock is accepted here. Replays historical truth
;;; and checks current support independently; the result grants no effects.
(def (agentic-ai-lab-temporal-proof-host-current host registration-value expected-state-generation
                                         expected-policy-generation expected-policy-digest budget)
  (let* ((s (state host)) (held (hash-get (proof-host-state-proofs s) registration-value)))
    (when (or (proof-host-state-pending s) (proof-host-state-busy? s)) (error "Proof propagation pending; current use blocked"))
    (unless held (error "unknown registered proof"))
    (let* ((c (context (cadr held))) (a (proof-context-admission c))
           (current (hash-get (proof-host-state-current s) (car held))))
      (unless (and current (exact-integer? expected-state-generation)
                   (= expected-state-generation (.ref current 'generation)))
        (error "unregistered or stale proof host generation"))
      (let* ((p (canonical-program (.ref current 'program))) (j (canonical-journal (.ref current 'journal)))
             (same-catalog-value (equal? (.ref p 'semantic-digest) (.ref (proof-context-program c) 'semantic-digest)))
             (support-program-value (agentic-ai-lab-temporal-support-program registration-value (caddr held) #t (list (.ref a 'support))))
             (guard-value (agentic-ai-lab-temporal-support-policy-host-guard-current (proof-host-state-policy-host s)
               expected-policy-generation expected-policy-digest support-program-value j budget))
             (support-status-value (.ref (car (.ref (.ref guard-value 'evaluation) 'conclusions)) 'status))
             (status-value (cond ((not same-catalog-value) 'stale-catalog)
                                 ((not (.ref guard-value 'policy-applicable?)) (.ref guard-value 'policy-status))
                                 ((not (eq? support-status-value 'supported)) support-status-value)
                                 (else 'current))))
        (.o kind: 'temporal.proof-host-applicability.v1 registration: registration-value
            proof-digest: (.ref a 'semantic-digest) original-state-digest: (cadddr held)
            current-state-digest: (.ref current 'semantic-digest) state-generation: expected-state-generation
            guard: guard-value status: status-value current?: (eq? status-value 'current)
            semantic-digest: (digest (list 'temporal.proof-host-applicability.v1 registration-value
              (.ref a 'semantic-digest) (cadddr held) (.ref current 'semantic-digest)
              expected-state-generation expected-policy-generation (.ref guard-value 'semantic-digest) status-value))
            proof-admitted?: #t trust-basis: 'host-registered-source-relative-native-proof
            source-authenticated?: #f selection-admitted?: #f action-authorized?: #f durable?: #f)))))

;;; Trusted synchronous source observers; all use the creating owner thread.
(def (agentic-ai-lab-temporal-proof-host-watch! host observer)
  (let (s (state host))
    (when (or (proof-host-state-pending s) (proof-host-state-busy? s)) (error "Cannot enroll observer during propagation"))
    (unless (and (tag? observer 'temporal.source-observer.v1) (.slot? observer '.prepare))
      (error "Expected native POO source observer"))
    (unless (memq observer (proof-host-state-observers s))
      (when (>= (length (proof-host-state-observers s)) 128) (error "Source observer capacity"))
      (set! (proof-host-state-observers s) (cons observer (proof-host-state-observers s)))) observer))
(def (agentic-ai-lab-temporal-proof-host-unwatch! host observer)
  (let (s (state host))
    (when (or (proof-host-state-pending s) (proof-host-state-busy? s))
      (error "Cannot detach observer during propagation"))
    (let (present? (if (memq observer (proof-host-state-observers s)) #t #f))
      (set! (proof-host-state-observers s)
        (filter (lambda (held) (not (eq? held observer))) (proof-host-state-observers s)))
      present?)))
(def (agentic-ai-lab-temporal-proof-host-pending? host)
  (if (or (proof-host-state-pending (state host)) (proof-host-state-busy? (state host))) #t #f))
(def (agentic-ai-lab-temporal-proof-host-drain! host)
  (let (s (state host))
    (let loop ()
      (let (pending (proof-host-state-pending s))
        (cond ((not pending) #t)
              ((null? pending) (set! (proof-host-state-pending s) #f) #t)
              (else
                ;; Keep the batch on failure. Recovery retries against actual
                ;; current Context state, never restores a pre-event schedule.
                (.call (car pending) .publish! (car pending))
                (set! (proof-host-state-pending s) (cdr pending)) (loop)))))))
(def (source-change s source-id old revised)
  (let* ((old-j (.ref old 'journal)) (new-j (.ref revised 'journal))
         (old-ids (map (lambda (r) (.ref r 'identity)) (.ref old-j 'revisions)))
         (changed (delete-duplicates/hash
                    (map (lambda (r) (.ref r 'subject-identity))
                      (filter (lambda (r) (not (member (.ref r 'identity) old-ids))) (.ref new-j 'revisions)))))
         (old-cut (.ref old-j 'semantic-digest)) (new-cut (.ref new-j 'semantic-digest))
         (old-program (.ref (.ref old 'program) 'semantic-digest))
         (new-program (.ref (.ref revised 'program) 'semantic-digest))
         (registrations (filter (lambda (entry) (equal? (car (cdr entry)) source-id))
                          (hash->list (proof-host-state-proofs s))))
         (nodes (map (lambda (entry)
                  (let* ((c (context (cadr (cdr entry)))) (a (proof-context-admission c))
                         (support (.ref a 'support)))
                    (unless (null? (.ref support 'conclusion-premises))
                      (error "Propagation requires complete selected source-premise support"))
                    (agentic-ai-lab-temporal-derivation (car entry) old-cut old-program (caddr (cdr entry))
                      (map (lambda (premise) (.ref premise 'subject-identity)) (.ref support 'premises)) '()))) registrations))
         (index (agentic-ai-lab-temporal-dependency-index source-id old-cut old-program #t nodes))
         (plan (agentic-ai-lab-temporal-reverse-dependency-plan index new-cut new-program changed))
         (all-ids (list-sort string<? (map car registrations)))
         (affected (if (equal? old-program new-program) (.ref plan 'affected-conclusion-identities) all-ids))
         (fingerprint (digest (list 'source-propagation.v1 source-id (.ref old 'semantic-digest)
                              (.ref revised 'semantic-digest) (.ref index 'semantic-digest) changed affected))))
    (.o kind: 'temporal.source-change.v1 source: (string-copy source-id)
      previous-generation: (.ref old 'generation) generation: (.ref revised 'generation)
      previous-cut: old-cut revised-cut: new-cut previous-program: old-program revised-program: new-program
      changed-subjects: changed proof-identities: all-ids affected-proofs: affected
      inventory-complete?: (.ref plan 'inventory-complete?) index-digest: (.ref index 'semantic-digest)
      semantic-digest: fingerprint)))

(def (agentic-ai-lab-temporal-proof-host-policy host registration)
  (let* ((s (state host)) (held (hash-get (proof-host-state-proofs s) registration)))
    (unless held (error "unknown registered proof"))
    (values (proof-host-state-policy-host s) (caddr held))))

(def (agentic-ai-lab-temporal-proof-host-retained-digest host registration)
  (let* ((s (state host)) (held (hash-get (proof-host-state-proofs s) registration)))
    (unless held (error "Unknown recovered original proof"))
    ;; Reading original evidence is not a current-use admission. Replaying the
    ;; whole ASCENT proof here made every parent/checkpoint copy reallocate its
    ;; derivation graph. Return the credential sealed by register!, detached
    ;; from the caller. current and source-change still perform native replay.
    (string-copy (list-ref held 4))))

(def (agentic-ai-lab-temporal-proof-host-source-snapshot host registration)
  (let* ((s (state host)) (held (hash-get (proof-host-state-proofs s) registration)))
    (unless held (error "Unknown proof source"))
    (hash-get (proof-host-state-current s) (car held))))
