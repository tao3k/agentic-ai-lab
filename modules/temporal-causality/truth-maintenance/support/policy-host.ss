;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Explicit in-process runtime control capability. No semantic wire dispatch.
(import :agentic-ai-lab/modules/temporal-causality/runtime/change-feed
        (only-in :clan/poo/object .o .ref .slot? object? .call)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/objects agentic-ai-lab-temporal-instant)
        "policy.ss")
(export agentic-ai-lab-temporal-support-policy-host
        agentic-ai-lab-temporal-support-policy-host-refresh!
        agentic-ai-lab-temporal-support-policy-host-guard
        agentic-ai-lab-temporal-support-policy-host-guard-current
        agentic-ai-lab-temporal-support-policy-host-current
        agentic-ai-lab-temporal-support-policy-host-watch! agentic-ai-lab-temporal-support-policy-host-unwatch!
        agentic-ai-lab-temporal-support-policy-host-drain!
        agentic-ai-lab-temporal-support-policy-host-deadlines
        agentic-ai-lab-temporal-support-policy-host-fire-deadline!
        agentic-ai-lab-temporal-support-policy-host-history
        agentic-ai-lab-temporal-support-policy-host-release-clock!
        agentic-ai-lab-temporal-support-policy-host-enroll-clock!
        agentic-ai-lab-temporal-support-policy-host-registered agentic-ai-lab-temporal-support-policy-host-snapshots
        policy-host-revisions policy-host-restore-revisions!)
;;; Opaque runtime state, never transported; the host serializes control/use.
(defstruct policy-host-state (current revisions owner feed clock))
(def (agentic-ai-lab-temporal-support-policy-host)
  (let (runtime-value (make-policy-host-state (make-hash-table) (make-hash-table) (current-thread) (make-change-feed) #f))
    (.o kind: 'agentic-ai-lab.temporal-causality.policy-host.v1 private-runtime-state: runtime-value)))
(def (state host)
  (unless (and (object? host) (.slot? host 'kind)
               (eq? (.ref host 'kind) 'agentic-ai-lab.temporal-causality.policy-host.v1)
               (.slot? host 'private-runtime-state)
               (policy-host-state? (.ref host 'private-runtime-state)))
    (error "invalid policy host capability"))
  (let (runtime-value (.ref host 'private-runtime-state))
    (unless (eq? (policy-host-state-owner runtime-value) (current-thread))
      (error "Policy Host requires its serialized owner thread")) runtime-value))
(def (instant-row x)
  (map (lambda (s) (.ref x s)) '(identity domain-identity coordinate provenance-identity modality)))
(def (canonical-policy p)
  (let (canonical (agentic-ai-lab-temporal-support-policy (.ref p 'identity) (.ref p 'revision-identity)
                    (.ref p 'start) (.ref p 'end)))
    (unless (equal? (.ref p 'semantic-digest) (.ref canonical 'semantic-digest))
      (error "forged host policy")) canonical))
(def (agentic-ai-lab-temporal-support-policy-host-refresh! host policy generation-value effective-value)
  (unless (and (exact-integer? generation-value) (<= 0 generation-value))
    (error "invalid host policy generation"))
  (let* ((s (state host)) (owned (canonical-policy policy))
         (clock-value (policy-host-state-clock s))
         (effective-input (begin
                            (when (eq? clock-value 'retired-clock) (error "Policy clock is retired"))
                            (if clock-value (.call clock-value .observe clock-value (.ref owned 'identity)) effective-value)))
         (time-value (agentic-ai-lab-temporal-instant (.ref effective-input 'identity)
           (.ref effective-input 'domain-identity) (.ref effective-input 'coordinate)
           (.ref effective-input 'provenance-identity) (.ref effective-input 'modality)))
         (id (.ref owned 'identity)) (current (policy-host-state-current s))
         (history (policy-host-state-revisions s)) (old (hash-get current id))
         (revision-key (list id (.ref owned 'revision-identity)))
         (original (hash-get history revision-key)))
    (change-feed-open! (policy-host-state-feed s))
    (unless (and (eq? (.ref time-value 'modality) 'observed)
                 (equal? (.ref time-value 'domain-identity) (.ref (.ref owned 'start) 'domain-identity)))
      (error "host policy clock domain or modality mismatch"))
    (when original
      (unless (equal? (.ref original 'semantic-digest) (.ref owned 'semantic-digest))
        (error "host policy revision identity is immutable")))
    (when old
      (unless (and (equal? (.ref time-value 'domain-identity)
                          (.ref (.ref old 'effective-at) 'domain-identity))
                   (>= (.ref time-value 'coordinate) (.ref (.ref old 'effective-at) 'coordinate)))
        (error "host policy clock rollback"))
      (unless (or (> generation-value (.ref old 'generation))
                  (and (= generation-value (.ref old 'generation))
                       (equal? (.ref owned 'semantic-digest) (.ref (.ref old 'policy) 'semantic-digest))
                       (equal? (instant-row time-value) (instant-row (.ref old 'effective-at)))))
        (error "host policy generation rollback or conflict")))
    (unless (and (or old (< (hash-length current) 128))
                 (or original (< (hash-length history) 128)))
      (error "host policy registry capacity exceeded"))
    (let (snapshot (.o kind: 'agentic-ai-lab.temporal-causality.policy-host-snapshot.v1
                       policy: owned generation: generation-value effective-at: time-value
                       trust-basis: 'host-registered-policy-snapshot
                       source-authenticated?: #f action-authorized?: #f durable?: #f))
      (unless (and old (= generation-value (.ref old 'generation)))
        (change-feed-stage! (policy-host-state-feed s)
          (authority-change 'policy id generation-value old snapshot
            (if old (policy-snapshot-digest old) "unregistered") (policy-snapshot-digest snapshot))))
      (hash-put! history revision-key owned)
      (hash-put! current id snapshot)
      (change-feed-drain! (policy-host-state-feed s))
      snapshot)))
(def (agentic-ai-lab-temporal-support-policy-host-guard host expected-generation expected-policy-digest
                                                program journal as-of valid-at budget)
  (let* ((s (state host))
         (snapshot (agentic-ai-lab-temporal-support-policy-host-current host (.ref program 'policy-identity))))
    (unless (and snapshot (exact-integer? expected-generation)
                 (= expected-generation (.ref snapshot 'generation)))
      (error "unregistered or stale host policy generation"))
    ;; The query supplies neither a replacement policy nor an effective clock.
    (agentic-ai-lab-temporal-support-guard program journal as-of valid-at budget
      (.ref snapshot 'policy) expected-policy-digest (.ref snapshot 'effective-at))))

;;; Current proof applicability cannot choose a historical evidence cut or clock.
(def (agentic-ai-lab-temporal-support-policy-host-guard-current host expected-generation expected-policy-digest
                                                        program journal budget)
  (let* ((s (state host))
         (snapshot (agentic-ai-lab-temporal-support-policy-host-current host (.ref program 'policy-identity))))
    (unless (and snapshot (exact-integer? expected-generation)
                 (= expected-generation (.ref snapshot 'generation)))
      (error "unregistered or stale host policy generation"))
    (agentic-ai-lab-temporal-support-guard program journal (.ref snapshot 'effective-at) (.ref snapshot 'effective-at) budget
      (.ref snapshot 'policy) expected-policy-digest (.ref snapshot 'effective-at))))

;;; Read only the registered current snapshot; callers cannot choose its clock.
(def (agentic-ai-lab-temporal-support-policy-host-current host policy-identity)
  (let* ((s (state host)) (feed (policy-host-state-feed s)))
    (change-feed-open! feed)
    (let* ((snapshot (or (hash-get (policy-host-state-current s) policy-identity) (error "unregistered current policy")))
           (clock-value (policy-host-state-clock s)))
      (when (eq? clock-value 'retired-clock) (error "Policy clock is retired"))
      (if (not clock-value) snapshot
        (let* ((observed (.call clock-value .observe clock-value policy-identity))
               (p (.ref snapshot 'policy)) (end-value (.ref p 'end)))
          (unless (and (eq? (.ref observed 'modality) 'observed)
                       (equal? (.ref observed 'domain-identity) (.ref end-value 'domain-identity))
                       (>= (.ref observed 'coordinate) (.ref (.ref snapshot 'effective-at) 'coordinate)))
            (error "Native clock rollback/domain mismatch"))
          ;; Supplement the proactive timer: a delayed mailbox cannot let a
          ;; final-use guard use a clock frozen before the actual deadline.
          (if (and (< (.ref (.ref snapshot 'effective-at) 'coordinate) (.ref end-value 'coordinate))
                   (>= (.ref observed 'coordinate) (.ref end-value 'coordinate)))
            (agentic-ai-lab-temporal-support-policy-host-refresh! host p (+ (.ref snapshot 'generation) 1) observed)
            (let ((policy-value p) (generation-value (.ref snapshot 'generation)))
              (.o kind: 'agentic-ai-lab.temporal-causality.policy-host-snapshot.v1 policy: policy-value
                  generation: generation-value effective-at: observed trust-basis: 'host-enrolled-monotonic-clock
                  source-authenticated?: #f action-authorized?: #f durable?: #f))))))))
(def (agentic-ai-lab-temporal-support-policy-host-enroll-clock! host clock-value)
  (let (s (state host))
    (change-feed-open! (policy-host-state-feed s))
    (when (policy-host-state-clock s) (error "Native clock is already enrolled"))
    (unless (and (object? clock-value) (eq? (.ref clock-value 'kind) 'temporal.native-clock.v1)
                 (.slot? clock-value '.observe)) (error "Expected native clock owner capability"))
    (set! (policy-host-state-clock s) clock-value) #t))

;;; Releasing a runtime lease does not restore authority to a frozen snapshot.
;;; Exact capability matching prevents one owner from detaching another clock.
(def (agentic-ai-lab-temporal-support-policy-host-release-clock! host clock-value)
  (let (s (state host))
    (change-feed-open! (policy-host-state-feed s))
    (unless (eq? (policy-host-state-clock s) clock-value) (error "Foreign clock lease"))
    (set! (policy-host-state-clock s) 'retired-clock)
    #t))

(def (policy-snapshot-digest snapshot)
  (string-append (.ref (.ref snapshot 'policy) 'semantic-digest) ":"
    (number->string (.ref snapshot 'generation)) ":"
    (number->string (.ref (.ref snapshot 'effective-at) 'coordinate))))
(def (agentic-ai-lab-temporal-support-policy-host-unwatch! host observer)
  (change-feed-unwatch! (policy-host-state-feed (state host)) observer))
(def (agentic-ai-lab-temporal-support-policy-host-watch! host observer)
  (change-feed-watch! (policy-host-state-feed (state host)) observer))
(def (agentic-ai-lab-temporal-support-policy-host-drain! host)
  (change-feed-drain! (policy-host-state-feed (state host))))
(def (agentic-ai-lab-temporal-support-policy-host-history host)
  (reverse (change-feed-history (policy-host-state-feed (state host)))))
;;; Registered BEFORE expiry. Only trusted observed-clock refresh fires delivery.
(def (agentic-ai-lab-temporal-support-policy-host-deadlines host)
  (map (lambda (snapshot)
    (let* ((p (.ref snapshot 'policy)) (end-value (.ref p 'end))
           (id-value (.ref p 'identity)) (generation-value (.ref snapshot 'generation)))
      (.o kind: 'temporal.policy-deadline.v1 identity: id-value generation: generation-value
          end: end-value policy-digest: (.ref p 'semantic-digest) half-open?: #t)))
    (filter (lambda (snapshot) (< (.ref (.ref snapshot 'effective-at) 'coordinate)
                                  (.ref (.ref (.ref snapshot 'policy) 'end) 'coordinate)))
      (hash-values (policy-host-state-current (state host))))))

;;; Owner scheduler calls this at an observed deadline; stale tickets cannot fire
;;; against a replacement policy. Refresh performs prepare-before-publication.
(def (agentic-ai-lab-temporal-support-policy-host-fire-deadline! host id expected-generation observed)
  (let* ((snapshot (begin (change-feed-open! (policy-host-state-feed (state host)))
                     (or (hash-get (policy-host-state-current (state host)) id) (error "Unknown deadline policy"))))
         (p (.ref snapshot 'policy)) (end-value (.ref p 'end)))
    (unless (and (< (.ref (.ref snapshot 'effective-at) 'coordinate) (.ref end-value 'coordinate))
                 (= expected-generation (.ref snapshot 'generation))
                 (eq? (.ref observed 'modality) 'observed)
                 (equal? (.ref observed 'domain-identity) (.ref end-value 'domain-identity))
                 (>= (.ref observed 'coordinate) (.ref end-value 'coordinate)))
      (error "Stale, early or foreign-clock policy deadline"))
    (agentic-ai-lab-temporal-support-policy-host-refresh! host p (+ expected-generation 1) observed)))

;;; Raw registration is for the serialized scheduler, never a current-use guard.
(def (agentic-ai-lab-temporal-support-policy-host-registered host id)
  (let (s (state host))
    (change-feed-open! (policy-host-state-feed s))
    (or (hash-get (policy-host-state-current s) id) (error "Unknown registered policy"))))

(def (agentic-ai-lab-temporal-support-policy-host-snapshots host) (hash-values (policy-host-state-current (state host))))

(def (policy-host-revisions host) (hash-values (policy-host-state-revisions (state host))))
(def (policy-host-restore-revisions! host values)
  (let (s (state host))
    (for-each (lambda (value)
      (let* ((p (canonical-policy value)) (key (list (.ref p 'identity) (.ref p 'revision-identity)))
             (old (hash-get (policy-host-state-revisions s) key)))
        (when (and old (not (equal? (.ref old 'semantic-digest) (.ref p 'semantic-digest))))
          (error "Historical policy revision substitution"))
        (hash-put! (policy-host-state-revisions s) key p))) values)))
