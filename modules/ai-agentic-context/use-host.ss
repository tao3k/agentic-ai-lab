;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Explicit runtime authority capability. POO owns contract/grant declarations;
;;; MRR owns typed identities and Context admission. No effect commit occurs here.
(import :agentic-ai-lab/modules/temporal-causality/runtime/change-feed
        (only-in :std/list/list every delete-duplicates/hash)
        (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy
                 agentic-ai-lab-temporal-support-policy-status)
        (only-in :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy-host
                 agentic-ai-lab-temporal-support-policy-host-current))
(export agentic-ai-lab-context-use-contract agentic-ai-lab-context-use-grant
        agentic-ai-lab-context-use-grant-revoke
        agentic-ai-lab-context-use-host agentic-ai-lab-context-use-host-refresh!
        agentic-ai-lab-context-use-host-observe
        agentic-ai-lab-context-use-host-current agentic-ai-lab-context-use-host-watch! agentic-ai-lab-context-use-host-unwatch!
        agentic-ai-lab-context-use-host-drain! agentic-ai-lab-context-use-host-history agentic-ai-lab-context-use-host-snapshots)
(def (text? x) (and (string? x) (< 0 (string-length x) 257)))
(def (names? xs) (and (list? xs) (<= (length xs) 128) (every text? xs)
                     (= (length xs) (length (delete-duplicates/hash xs)))))
(def (digest x) (string-append "sha256:" (hex-encode (sha256 (string->utf8
  (call-with-output-string (lambda (p) (write x p))))))))
(def (agentic-ai-lab-context-use-contract actor-value task-value policy-value required-value temporal-value complete-value)
  (unless (and (text? actor-value) (text? task-value) (text? policy-value)
               (names? required-value) (names? temporal-value) (boolean? complete-value))
    (error "invalid Context use contract"))
  (.o kind: 'agentic-ai-lab.context-use-contract.v1 actor: actor-value task: task-value
      policy-digest: policy-value required: required-value temporal-receipts: temporal-value
      require-complete?: complete-value semantic-digest:
      (digest (list 'agentic-ai-lab.context-use-contract.v1 actor-value task-value policy-value
                    required-value temporal-value complete-value))))
(def (contract-replay x)
  (unless (and (object? x) (.slot? x 'kind) (eq? (.ref x 'kind) 'agentic-ai-lab.context-use-contract.v1))
    (error "invalid Context use contract kind"))
  (let (owned (agentic-ai-lab-context-use-contract (.ref x 'actor) (.ref x 'task) (.ref x 'policy-digest)
                (.ref x 'required) (.ref x 'temporal-receipts) (.ref x 'require-complete?)))
    (unless (equal? (.ref owned 'semantic-digest) (.ref x 'semantic-digest))
      (error "forged Context use contract")) owned))
(def (agentic-ai-lab-context-use-grant id-value generation-value manifest-value admission-value
                               contract-value policy-id-value policy-digest-value purposes-value enabled-value)
  (unless (and (text? id-value) (exact-integer? generation-value) (< 0 generation-value)
               (text? manifest-value) (text? admission-value) (text? policy-id-value)
               (text? policy-digest-value) (list? purposes-value) (<= (length purposes-value) 2)
               (every (lambda (p) (memq p '(display action))) purposes-value)
               (= (length purposes-value) (length (delete-duplicates/hash purposes-value)))
               (boolean? enabled-value)) (error "invalid Context use grant"))
  (let (owned (contract-replay contract-value))
    (.o kind: 'agentic-ai-lab.context-use-grant.v1 identity: id-value generation: generation-value
        manifest-digest: manifest-value admission-digest: admission-value contract: owned
        policy-identity: policy-id-value policy-digest: policy-digest-value
        purposes: purposes-value enabled?: enabled-value semantic-digest:
        (digest (list 'agentic-ai-lab.context-use-grant.v1 id-value generation-value manifest-value
                      admission-value (.ref owned 'semantic-digest) policy-id-value
                      policy-digest-value purposes-value enabled-value)))))
(def (grant-replay x)
  (unless (and (object? x) (.slot? x 'kind) (eq? (.ref x 'kind) 'agentic-ai-lab.context-use-grant.v1))
    (error "invalid Context use grant kind"))
  (let (owned (agentic-ai-lab-context-use-grant (.ref x 'identity) (.ref x 'generation)
               (.ref x 'manifest-digest) (.ref x 'admission-digest) (.ref x 'contract)
               (.ref x 'policy-identity) (.ref x 'policy-digest) (.ref x 'purposes) (.ref x 'enabled?)))
    (unless (equal? (.ref owned 'semantic-digest) (.ref x 'semantic-digest))
      (error "forged Context use grant")) owned))

;;; Revocation is a pure, permission-narrowing proposal. It preserves the exact
;;; admitted contract/provenance and never allocates a replacement identity.
;;; Only the serialized authority Host may publish this proposed next version.
(def (agentic-ai-lab-context-use-grant-revoke grant)
  (let (owned (grant-replay grant))
    (unless (.ref owned 'enabled?)
      (error "Context grant is already retired"))
    (agentic-ai-lab-context-use-grant
     (.ref owned 'identity) (+ 1 (.ref owned 'generation))
     (.ref owned 'manifest-digest) (.ref owned 'admission-digest)
     (.ref owned 'contract) (.ref owned 'policy-identity)
     (.ref owned 'policy-digest) (.ref owned 'purposes) #f)))
(defstruct context-use-state (current owner feed))
(def (agentic-ai-lab-context-use-host)
  (let (runtime-value (make-context-use-state (make-hash-table) (current-thread) (make-change-feed)))
    (.o kind: 'agentic-ai-lab.context-use-host.v1 private-runtime-state: runtime-value)))
(def (state host)
  (unless (and (object? host) (.slot? host 'kind) (eq? (.ref host 'kind) 'agentic-ai-lab.context-use-host.v1)
               (.slot? host 'private-runtime-state) (context-use-state? (.ref host 'private-runtime-state)))
    (error "invalid Context use Host capability"))
  (let (runtime-value (.ref host 'private-runtime-state))
    (unless (eq? (context-use-state-owner runtime-value) (current-thread))
      (error "Context use Host requires its serialized owner thread")) runtime-value))
(def (agentic-ai-lab-context-use-host-refresh! host grant)
  (let* ((owned (grant-replay grant)) (current (context-use-state-current (state host)))
         (id (.ref owned 'identity)) (old (hash-get current id))
         (feed (context-use-state-feed (state host))))
    (change-feed-open! feed)
    (when old
      (unless (or (> (.ref owned 'generation) (.ref old 'generation))
                  (and (= (.ref owned 'generation) (.ref old 'generation))
                       (equal? (.ref owned 'semantic-digest) (.ref old 'semantic-digest))))
        (error "Context grant rollback or same-generation substitution"))
      (when (and (not (.ref old 'enabled?)) (.ref owned 'enabled?))
        (error "retired Context grant cannot resurrect")))
    (unless (or old (< (hash-length current) 128)) (error "Context grant capacity exceeded"))
    (unless (and old (equal? (.ref old 'semantic-digest) (.ref owned 'semantic-digest)))
      (change-feed-stage! feed (authority-change 'grant id (.ref owned 'generation) old owned
        (if old (.ref old 'semantic-digest) "unregistered") (.ref owned 'semantic-digest))))
    (hash-put! current id owned) (change-feed-drain! feed) owned))
(def (agentic-ai-lab-context-use-host-observe host policy-host id generation-value purpose-value)
  (unless (and (text? id) (exact-integer? generation-value) (< 0 generation-value)
               (memq purpose-value '(display action))) (error "invalid Context use request"))
  (let* ((grant-value (agentic-ai-lab-context-use-host-current host id))
         (snapshot (agentic-ai-lab-temporal-support-policy-host-current policy-host (.ref grant-value 'policy-identity)))
         (policy-status-value (agentic-ai-lab-temporal-support-policy-status (.ref snapshot 'policy)
                          (.ref grant-value 'policy-digest) (.ref snapshot 'effective-at)))
         (decision-value (cond ((not (.ref grant-value 'enabled?)) 'revoked)
                         ((not (= generation-value (.ref grant-value 'generation))) 'denied)
                         ((eq? policy-status-value 'expired-policy) 'expired)
                         ((or (not (eq? policy-status-value 'applicable))
                              (not (memq purpose-value (.ref grant-value 'purposes)))) 'denied)
                         (else 'allowed))))
    (.o kind: 'agentic-ai-lab.context-use-observation.v1 grant: grant-value purpose: purpose-value
        decision: decision-value policy-snapshot: snapshot policy-status: policy-status-value
        trust-basis: 'host-registered-contract-policy-and-clock
        action-authorized?: #f durable?: #f)))

(def (agentic-ai-lab-context-use-host-current host id (required? #t))
  (let (s (state host)) (change-feed-open! (context-use-state-feed s))
    (let (grant (hash-get (context-use-state-current s) id))
      (cond
       (grant grant)
       (required? (error "unknown Context use grant"))
       (else #f)))))
(def (agentic-ai-lab-context-use-host-unwatch! host observer)
  (change-feed-unwatch! (context-use-state-feed (state host)) observer))
(def (agentic-ai-lab-context-use-host-watch! host observer)
  (change-feed-watch! (context-use-state-feed (state host)) observer))
(def (agentic-ai-lab-context-use-host-drain! host)
  (change-feed-drain! (context-use-state-feed (state host))))
(def (agentic-ai-lab-context-use-host-history host)
  (reverse (change-feed-history (context-use-state-feed (state host)))))

(def (agentic-ai-lab-context-use-host-snapshots host) (hash-values (context-use-state-current (state host))))
