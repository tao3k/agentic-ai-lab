;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Trusted native recovery adapter. Source producers are replayed before restore.
(import (only-in :std/list/list find)
        (only-in :clan/poo/object .o .ref .slot? object?)
        :agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
        :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy-host
        (only-in :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy agentic-ai-lab-temporal-support-policy)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/objects agentic-ai-lab-temporal-instant)
        :agentic-ai-lab/modules/temporal-causality/runtime/monotonic-clock
        "session-host.ss" "use-host.ss" "query-provider.ss")
(export context-durable-adapter context-durable-source-command context-durable-revoke-command
        context-durable-policy-command)

(def (command-identity? value)
  (and (string? value) (< 0 (string-length value) 257)))

;;; Ordinary callers construct inert POO commands. The existing inbox identity
;;; is the retry key; neither the command nor its source allocates a Session.
(def (context-durable-source-command id-value expected-value source-value)
  (unless (and (command-identity? id-value)
               (or (not expected-value) (string? expected-value)))
    (error "Invalid durable source command identity or expected cut"))
  (let (canonical-value
        (context-org-source (.ref source-value 'identity) (.ref source-value 'generation)
                            (.ref source-value 'source) (.ref source-value 'active?)))
    (unless (equal? (.ref canonical-value 'semantic-digest) (.ref source-value 'semantic-digest))
      (error "Forged durable source command"))
    (.o kind: 'context.durable-command.v1 identity: (string-copy id-value)
        operation: 'query-source
        body: (.o expected: (and expected-value (string-copy expected-value))
                  source: canonical-value))))

;;; Freeze a revocation of this exact grant cut, not an arbitrary grant update.
;;; The data-only copy prevents later mutation of caller-owned strings from
;;; changing the intent already being handed to the durable owner protocol.
(def (context-durable-revoke-command id-value grant-value)
  (unless (command-identity? id-value)
    (error "Invalid durable grant command identity"))
  (let (revoked-value (agentic-ai-lab-context-use-grant-revoke grant-value))
    (journal-unpack
     (journal-pack
      (.o kind: 'context.durable-command.v1 identity: (string-copy id-value)
          operation: 'grant-revocation
          body: (.o expected: (.ref grant-value 'semantic-digest) grant: revoked-value))))))

;;; A policy proposal captures the registered revision/generation, not a
;;; caller-selected effective time. The existing native clock owns publication.
(def (context-durable-policy-command id-value expected-snapshot proposed-policy)
  (unless (command-identity? id-value)
    (error "Invalid durable policy command identity"))
  (let* ((old-policy (.ref expected-snapshot 'policy))
         (generation-value (.ref expected-snapshot 'generation))
         (canonical-value
          (agentic-ai-lab-temporal-support-policy
           (.ref proposed-policy 'identity) (.ref proposed-policy 'revision-identity)
           (.ref proposed-policy 'start) (.ref proposed-policy 'end))))
    (unless (and (exact-integer? generation-value) (<= 0 generation-value)
                 (equal? (.ref old-policy 'identity) (.ref canonical-value 'identity))
                 (not (equal? (.ref old-policy 'revision-identity) (.ref canonical-value 'revision-identity)))
                 (equal? (.ref proposed-policy 'semantic-digest) (.ref canonical-value 'semantic-digest)))
      (error "Policy replacement requires a canonical new revision of the same policy"))
    (journal-unpack
     (journal-pack
      (.o kind: 'context.durable-command.v1 identity: (string-copy id-value)
          operation: 'policy-transition
          body: (.o expected-generation: generation-value
                    expected-digest: (.ref old-policy 'semantic-digest)
                    policy: canonical-value))))))

(def (context-durable-adapter journal host grants policies resolver (initial-provider #f))
  (def catalog-value (or initial-provider (context-host-query-provider host)))
  (def active-input #f)
  (def closed? #f)

  (def (verify-input! id payload)
    (let (old (journal-input journal id))
      (when (and old (not (equal? (journal-pack (.ref old 'payload)) (journal-pack payload))))
        (error "Durable command identity substitution"))))

  (def (require-command! intent operation-value)
    ;; All controls use the existing inbox/transaction identity. A closure
    ;; cannot substitute a different operation or body after input admission.
    (unless (and active-input (journal-active? journal)
                 (eq? (.ref intent 'kind) 'context.durable-command.v1)
                 (eq? (.ref intent 'operation) operation-value)
                 (equal? (journal-pack active-input) (journal-pack intent)))
      (error "Control change requires its exact active durable command"))
    ;; The caller may still hold mutable strings in its command object. Once
    ;; validated, consume only the detached inbox copy owned by this adapter.
    active-input)

  (def (apply-source! intent)
    (unless catalog-value (error "Source change requires a catalog owner"))
    (let* ((owned-input (require-command! intent 'query-source))
           (body (.ref owned-input 'body))
           (source-value (.ref body 'source))
           (id-value (.ref owned-input 'identity))
           ;; Look up this source head, not a copy/scan of every historical
           ;; Query and proof. Dependency propagation stays with its native owner.
           (current-value
            (context-query-current-source catalog-value (.ref source-value 'identity) #f))
           (expected-value (.ref body 'expected))
           (accepted-value
            (and (equal? expected-value (and current-value (.ref current-value 'semantic-digest)))
                 (or current-value (.ref source-value 'active?))
                 (or (not current-value)
                     (> (.ref source-value 'generation) (.ref current-value 'generation))))))
      (when accepted-value
        (context-query-source! catalog-value source-value))
      ;; Refusal is a durable decision too. An obsolete pending input must not
      ;; retry forever or be rebased onto a newer source generation.
      (let (decision-value
            (.o kind: 'context.query-source-decision.v1
                accepted?: accepted-value expected: expected-value
                previous: (and current-value (.ref current-value 'semantic-digest))
                proposed: (.ref source-value 'semantic-digest)))
        (journal-put! journal (string-append "query-source-decision:" id-value) decision-value)
        decision-value)))

  (def (apply-revoke! intent)
    (let* ((owned-input (require-command! intent 'grant-revocation))
           (body (.ref owned-input 'body))
           (proposed-value (.ref body 'grant))
           (id-value (.ref owned-input 'identity))
           (current-value
            (agentic-ai-lab-context-use-host-current grants (.ref proposed-value 'identity) #f))
           (expected-value (.ref body 'expected))
           (accepted-value
            (and current-value (.ref current-value 'enabled?)
                 (equal? expected-value (.ref current-value 'semantic-digest))
                 (equal? (journal-pack proposed-value)
                         (journal-pack (agentic-ai-lab-context-use-grant-revoke current-value))))))
      (when accepted-value
        ;; Reuse native authority observers and the captured-version dependency
        ;; graph. No second propagation mechanism or grant registry is created.
        (agentic-ai-lab-context-use-host-refresh! grants proposed-value))
      (let (decision-value
            (.o kind: 'context.grant-revocation-decision.v1
                accepted?: (if accepted-value #t #f) expected: expected-value
                previous: (and current-value (.ref current-value 'semantic-digest))
                proposed: (.ref proposed-value 'semantic-digest)))
        (journal-put! journal (string-append "grant-revocation-decision:" id-value) decision-value)
        decision-value)))

  (def (observed-now)
    ;; Recovery runs before the reactor enrolls its clock. Derive time from the
    ;; same durable anchor; never accept an effective instant in command bytes.
    (let* ((anchor (journal-get journal "anchor")) (now (native-monotonic-seconds)))
      (unless (and anchor (equal? (.ref anchor 'boot) (native-boot-identity))
                   (>= now (.ref anchor 'epoch)))
        (error "Policy transition requires the current durable clock anchor"))
      (let (coordinate (+ (.ref anchor 'origin)
                         (inexact->exact (floor (/ (- now (.ref anchor 'epoch)) (.ref anchor 'tick))))))
        (agentic-ai-lab-temporal-instant
         (string-append "policy-owner:" (number->string coordinate))
         (.ref anchor 'domain) coordinate (.ref anchor 'boot) 'observed))))

  (def (apply-policy! intent)
    (unless (memq (.ref intent 'operation) '(policy-transition policy-replacement))
      (error "Expected a durable policy command"))
    (let* ((owned-input (require-command! intent (.ref intent 'operation)))
           (body (.ref owned-input 'body))
           (proposed-value (.ref body 'policy))
           (current-value (agentic-ai-lab-temporal-support-policy-host-registered
                           policies (.ref proposed-value 'identity)))
           (generation-value (.ref current-value 'generation))
           (digest-value (.ref (.ref current-value 'policy) 'semantic-digest))
           ;; Old inputs did not carry an expected cut. Preserve their exact
           ;; bytes and refuse under the original inbox identity. Never infer
           ;; the missing expectation from a newer policy during recovery.
           (has-cut? (and (.slot? body 'expected-generation) (.slot? body 'expected-digest)))
           (expected-generation-value (and has-cut? (.ref body 'expected-generation)))
           (expected-digest-value (and has-cut? (.ref body 'expected-digest)))
           (same-cut? (and has-cut? (equal? generation-value expected-generation-value)
                          (equal? digest-value expected-digest-value)))
           (canonical? (and same-cut?
             (equal? (journal-pack (.o (:: @ owned-input) operation: 'policy-transition))
                     (journal-pack (context-durable-policy-command
                                    (.ref owned-input 'identity) current-value proposed-value)))))
           (accepted-value (and same-cut? canonical?)))
      (when accepted-value
        ;; The native Host owns deadline replacement and dependency-directed
        ;; invalidation. Context and terminal state are saved in this transaction.
        (agentic-ai-lab-temporal-support-policy-host-refresh!
         policies proposed-value (+ generation-value 1) (observed-now)))
      (let (decision-value
            (.o kind: 'context.policy-transition-decision.v1
                accepted?: (if accepted-value #t #f)
                reason: (cond ((not has-cut?) 'missing-expected-cut)
                              ((not same-cut?) 'stale-policy-cut)
                              ((not canonical?) 'noncanonical-proposal)
                              (else 'accepted))
                expected-generation: expected-generation-value
                expected-digest: expected-digest-value
                previous-generation: generation-value previous-digest: digest-value
                proposed: (.ref proposed-value 'semantic-digest)))
        (journal-put! journal
          (string-append "policy-transition-decision:" (.ref owned-input 'identity)) decision-value)
        decision-value)))

  (def (save!)
    (let ((bound-provider (context-host-query-provider host))
          (checkpoint (context-host-checkpoint host)))
      (when (and catalog-value bound-provider (not (eq? catalog-value bound-provider)))
        (error "Durable Context and catalog must share one Provider"))
      (unless catalog-value (set! catalog-value bound-provider))
      (when catalog-value
        (journal-put! journal "query-catalog" (context-query-export catalog-value)))
      (journal-put! journal "context" checkpoint)
      (journal-put! journal "policy-revisions" (policy-host-revisions policies))
      (journal-put! journal "policies" (agentic-ai-lab-temporal-support-policy-host-snapshots policies))
      (journal-put! journal "grants" (agentic-ai-lab-context-use-host-snapshots grants))
      (for-each (lambda (row) (for-each (lambda (t) (journal-terminal! journal t)) (.ref row 'terminals)))
        (.ref checkpoint 'entries))))
  (when (journal-get journal "context")
    (journal-verify! journal)
    (policy-host-restore-revisions! policies (journal-get journal "policy-revisions"))
    (for-each (lambda (snapshot)
      (agentic-ai-lab-temporal-support-policy-host-refresh! policies (.ref snapshot 'policy)
        (.ref snapshot 'generation) (.ref snapshot 'effective-at))) (journal-get journal "policies"))
    (for-each (lambda (g) (agentic-ai-lab-context-use-host-refresh! grants g)) (journal-get journal "grants"))
    ;; Select the committed catalog before restoring consumer bindings. Those
    ;; bindings must resolve against this exact owner; subscriptions are rebuilt
    ;; by Context restoration before pending source changes are replayed.
    (when (journal-get journal "query-catalog")
      (let-values (((provider observed)
                    (context-query-restore (journal-get journal "query-catalog"))))
        (when observed (error "Durable catalog root cannot select an observation"))
        (set! catalog-value provider)))
    (context-host-restore! host (journal-get journal "context") resolver catalog-value)
    ;; Known authority inputs are re-admitted before any new effects. Endpoint
    ;; observations/cancellation remain obligations, never fabricated terminals.
    (let* ((anchor (journal-get journal "anchor")) (now (native-monotonic-seconds)))
      (unless (and anchor (equal? (.ref anchor 'boot) (native-boot-identity)) (>= now (.ref anchor 'epoch)))
        (error "Durable clock boot mismatch"))
      (for-each (lambda (row)
        (let (intent (.ref row 'payload))
          (when (and (equal? (.ref row 'status) "pending") (eq? (.ref intent 'kind) 'context.opaque-owner-call.v1))
            (error "Unresolved opaque owner call requires explicit recovery"))
          (when (and (equal? (.ref row 'status) "pending") (eq? (.ref intent 'kind) 'context.durable-command.v1))
            (case (.ref intent 'operation)
              ((query-source grant-revocation policy-transition policy-replacement)
                ;; Reuse the original received input, including its retry key.
                ;; Source state, pushed invalidation and Context obligations are
                ;; saved under one fenced SQLite decision before reopening.
                (journal-begin! journal (.ref row 'id))
                (set! active-input intent)
                (with-catch
                 (lambda (e) (journal-abort! journal) (set! active-input #f) (raise e))
                 (lambda ()
                   (case (.ref intent 'operation)
                     ((query-source) (apply-source! intent))
                     ((grant-revocation) (apply-revoke! intent))
                     ((policy-transition policy-replacement) (apply-policy! intent)))
                   (save!)
                   (journal-commit! journal)
                   (set! active-input #f))))
              ((result cancel recover) #t)
              (else (error "Unknown durable command requires explicit recovery")))))) (journal-rows journal))
      (let (id (string-append "owner-recovery:" (number->string (journal-epoch journal))))
        (journal-receive! journal id (.o kind: 'context.owner-recovered.v1))
        (journal-begin! journal id) (save!) (journal-commit! journal))))
  (.o kind: 'context.durability-adapter.v1
    ;; Called on the creating owner after its timer has joined. Every previous
    ;; accepted command/paused delivery already committed before its ACK. Closing
    ;; retains the database and outstanding recovery obligations, not live caps.
    .close!: (lambda (self)
      (unless closed?
        (when (journal-active? journal) (error "Cannot dispose Context during a decision"))
        (context-host-dispose! host)
        (journal-close! journal)
        (set! active-input #f)
        (set! catalog-value #f)
        (set! initial-provider #f)
        (set! resolver #f)
        (set! host #f)
        (set! grants #f)
        (set! policies #f)
        (set! closed? #t))
      (let (journal-closed-value (journal-closed? journal))
        (.o kind: 'context.durable-close.v1 journal-closed?: journal-closed-value
            subscriptions: 0 context-disposed?: closed?)))
    ;; Service receipts are original decisions, not current-use capabilities.
    ;; The exact active inbox key fences writes; history reads never re-execute
    ;; a Session terminal CAS or reconstruct an observation seal.
    .service-input: (lambda (self id command)
      (let (old (journal-input journal id))
        (and old
          (let (input (.ref old 'payload))
            (if (eq? (.ref input 'kind) 'context.durable-command.v1)
              (let* ((body (.ref input 'body))
                     (original (if (and (object? body) (.slot? body 'service-command))
                                 (.ref body 'service-command) body)))
                (if (equal? (journal-pack original) (journal-pack command)) input
                  (.o kind: 'context.service-input-conflict.v1)))
              (.o kind: 'context.service-input-conflict.v1))))))
    .service-decision!: (lambda (self id receipt)
      (unless (and active-input (journal-active? journal)
                   (equal? id (.ref active-input 'identity)))
        (error "Service decision requires its exact active inbox key"))
      (journal-put! journal (string-append "service-decision:" id) receipt))
    .service-decision: (lambda (self id)
      (journal-get journal (string-append "service-decision:" id)))
    .query-provider: (lambda (self) catalog-value)
    .query-source!: (lambda (self intent) (apply-source! intent))
    .replace-policy!: (lambda (self intent) (apply-policy! intent))
    .revoke-grant!: (lambda (self intent) (apply-revoke! intent))
    .verify-input!: (lambda (self id payload) (verify-input! id payload))
    .anchor!: (lambda (self domain-value origin-value tick-value now-value boot-value)
      (let (old (journal-get journal "anchor"))
        (if old
          (begin
            (unless (and (equal? (.ref old 'boot) boot-value) (equal? (.ref old 'domain) domain-value)
                         (= (.ref old 'origin) origin-value) (= (.ref old 'tick) tick-value) (>= now-value (.ref old 'epoch)))
              (error "Clock boot/profile changed; explicit re-admission required"))
            (.ref old 'epoch))
          (begin
            (journal-receive! journal "bootstrap" (.o kind: 'context.bootstrap.v1 domain: domain-value))
            (journal-begin! journal "bootstrap")
            (journal-put! journal "anchor" (.o boot: boot-value domain: domain-value origin: origin-value tick: tick-value epoch: now-value))
            (save!) (journal-commit! journal) now-value))))
    .ticket!: (lambda (self ticket)
      (let* ((key (string-append "ticket:" (.ref ticket 'identity))) (old (journal-get journal key)))
        (when (and old (not (equal? (journal-pack old) (journal-pack ticket)))) (error "Durable ticket substitution"))
        (unless old
          (let (retain! (lambda ()
            (journal-put! journal key ticket)
            (journal-put! journal "calendar" (cons ticket (or (journal-get journal "calendar") '())))))
          (if (journal-active? journal) (retain!)
            (begin (journal-receive! journal key ticket) (journal-begin! journal key)
              (retain!) (save!) (journal-commit! journal)))))))
    .tickets: (lambda (self)
      ;; Includes tickets enrolled inside a policy replacement transaction,
      ;; which have no separately received transport input yet.
      (or (journal-get journal "calendar") '()))
    .pending: (lambda (self)
      (filter (lambda (row) (and (equal? (.ref row 'status) "pending")
        (eq? (.ref (.ref row 'payload) 'kind) 'context.durable-delivery.v1))) (journal-rows journal)))
    .seen?: (lambda (self id) (if (journal-get journal (string-append "seen:" id)) #t #f))
    .seen!: (lambda (self id) (journal-put! journal (string-append "seen:" id) #t))
    .epoch: (lambda (self) (journal-epoch journal))
    .applied?: (lambda (self id)
      (let (row (journal-input journal id))
        (and row (equal? (.ref row 'status) "applied"))))
    .begin!: (lambda (self id payload)
      (verify-input! id payload)
      (journal-receive! journal id payload)
      (journal-begin! journal id)
      (set! active-input (journal-unpack (journal-pack payload))))
    .finish!: (lambda (self id applied?)
      (save!) (journal-commit! journal applied?) (set! active-input #f))
    .abort!: (lambda (self) (journal-abort! journal) (set! active-input #f))))
