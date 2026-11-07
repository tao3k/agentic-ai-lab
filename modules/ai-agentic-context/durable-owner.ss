;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Trusted runtime recovery adapter. Source producers are replayed before restore.
(import (only-in :std/list/list find)
        (only-in :clan/poo/object .o .ref .slot? object?)
        :agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
        :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy-host
        (only-in :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy agentic-ai-lab-temporal-support-policy)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/objects agentic-ai-lab-temporal-instant)
        :agentic-ai-lab/modules/temporal-causality/runtime/monotonic-clock
        (only-in "../durable/recovery-decision.ss" durable-recovery-decision)
        :agentic-ai-lab/modules/governance/policy/authorized-effect-token
        :agentic-ai-lab/modules/governance/policy/strict-mediation
        "session-host.ss" "use-host.ss" "query-provider.ss" "recovery-observation.ss")
(export context-durable-adapter context-durable-source-command context-durable-revoke-command
        context-durable-policy-command context-durable-workspace-command)

;;; The trusted application supplies a separately scoped live effect Host.
;;; This data-only descriptor cannot carry that Host, a worker or a retry closure.
(def (context-durable-workspace-command id-value attempt-value effect-value)
  (unless (and (command-identity? id-value)
               (eq? (.ref attempt-value 'kind) 'agentic-ai-lab.session.attempt.v1)
               (command-identity? (.ref effect-value 'workspace))
               (command-identity? (.ref effect-value 'path))
               (not (member (.ref effect-value 'path) '("." "..")))
               (not (ormap (lambda (c) (memv c '(#\/ #\\))) (string->list (.ref effect-value 'path))))
               (string? (.ref effect-value 'before)) (string? (.ref effect-value 'desired))
               (<= (string-length (.ref effect-value 'before)) 65536)
               (<= (string-length (.ref effect-value 'desired)) 65536)
               (list? (.ref effect-value 'requirements))
               (<= (length (.ref effect-value 'requirements)) 32)
               (andmap symbol? (.ref effect-value 'requirements)))
    (error "Invalid bounded workspace effect descriptor"))
  (journal-unpack (journal-pack
    (.o kind: 'context.durable-command.v1 identity: id-value operation: 'workspace-effect
      body: (.o attempt: attempt-value effect: effect-value)))))

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
;;; caller-selected effective time. The existing runtime clock owns publication.
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

(def (context-durable-adapter journal host grants policies resolver (initial-provider #f) (recovery-config #f))
  ;; The embedding supplies the admitted composition and its live policy.
  ;; Only portable identity bytes are retained, never the policy procedures.
  (def recovery-binding-value
    (and recovery-config
         (journal-unpack (journal-pack
           (list (.ref recovery-config 'composition)
                 (.ref (.ref recovery-config 'policy) 'revision))))))
  (def recovery-policy
    (and recovery-binding-value
         (let ((source (.ref recovery-config 'policy))
               (revision-value (cadr recovery-binding-value)))
           (let ((interpreter (.ref source 'outcome-interpreter))
                 (retry (.ref source 'retry-policy)))
             (unless (and (car recovery-binding-value) revision-value
                          (procedure? interpreter) (procedure? retry))
               (error "Recovery requires an admitted composition and revisioned policy"))
             (.o revision: revision-value outcome-interpreter: interpreter retry-policy: retry)))))
  ;; An optional trusted effect host owns current permission, repeat safety
  ;; and issuer verification. An unconfigured reader can only assess evidence.
  (def recovery-effect-host
    (and recovery-config (.slot? recovery-config 'effect-host)
         (.ref recovery-config 'effect-host)))
  (def catalog-value (or initial-provider (context-host-query-provider host)))
  (def active-input #f)
  (def closed? #f)
  (def live-retry-handoffs (make-hash-table))

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

  (def (workspace-key id) (string-append "workspace-effect:" id))
  (def (workspace-state id)
    (or (journal-get journal (workspace-key id)) (error "Unknown retained workspace effect" id)))
  (def (workspace-assess! value)
    (let* ((intent (.ref value 'intent)) (id (.ref intent 'identity))
           (body (.ref intent 'body)) (attempt-value (.ref body 'attempt)) (effect (.ref body 'effect))
           (workspace-value (.ref effect 'workspace)) (owner-epoch-value (journal-epoch journal))
           (observed (.ref value 'observation)) (receipt (.ref value 'execution-receipt))
           (journal-cut-value (journal-hash (journal-pack
             (list owner-epoch-value (.ref value 'origin-epoch) id
               (.ref (journal-input journal id) 'status) receipt))))
           (facts-value (.o (:: @ RecoveryObservation.) identity: id revision: owner-epoch-value
             intents: (list (.o command: id task: (.ref attempt-value 'task) revision: (.ref attempt-value 'task-revision)
               attempt: (.ref attempt-value 'identity) scope: workspace-value epoch: (.ref value 'origin-epoch)))
             journal-heads: (list (.o scope: workspace-value cut: journal-cut-value epoch: owner-epoch-value))
             scans: (list (.o identity: journal-cut-value command: id scope: workspace-value cut: journal-cut-value epoch: owner-epoch-value
               coverage: 'complete outcome: (if receipt 'committed 'missing)))
             ;; Restored reads remain evidence at their old cuts. A new owner
             ;; cannot call them current merely because their bytes survived.
             workspace-cuts: (if (and observed (= (.ref observed 'owner-epoch) owner-epoch-value))
                               (list (.o scope: workspace-value cut: (.ref observed 'cut))) '())
             reads: (if observed (list (.o identity: (.ref observed 'identity) command: id scope: workspace-value
               cut: (.ref observed 'cut) coherent: (.ref observed 'coherent?) content: (.ref observed 'content))) '())
             history: (if receipt (list (.o identity: (.ref receipt 'identity) command: id
               attempt: (.ref attempt-value 'identity) scope: workspace-value epoch: (.ref value 'origin-epoch) outcome: 'applied)) '())
             requirements: (map (lambda (aspect-value) (.o command: id aspect: aspect-value)) (.ref effect 'requirements))
             hypotheses: (map (lambda (h) (.o command: id identity: (.ref h 'identity)
               question: (.ref h 'question))) (.ref value 'hypotheses))))
           (result (recovery-observation-evaluate facts-value))
           (projection (.o facts: facts-value unknown: (recovery-observation-rows result 'Unknown)
             obligations: (recovery-observation-rows result 'Obligation)
             current-content: (recovery-observation-rows result 'CurrentContent)
             history: (recovery-observation-rows result 'HistoricalEffect)
             explore: (recovery-observation-rows result 'Explore)))
           (updated (.o (:: @ value) assessment: projection)))
      (journal-put! journal (workspace-key id) updated) updated))

  (def (workspace-prepare! intent capability)
    (let* ((owned (require-command! intent 'workspace-effect)) (id (.ref owned 'identity))
           (body (.ref owned 'body)) (attempt-value (.ref body 'attempt)) (effect (.ref body 'effect))
           (row (find (lambda (r) (equal? (.ref r 'identity) (.ref attempt-value 'session)))
                      (.ref (context-host-checkpoint host) 'entries)))
           (old (journal-get journal (workspace-key id))))
      (if old (.o accepted?: #f reason: 'reconciliation-required)
        (begin
          (unless (and row (eq? (.ref (.ref row 'schedule) 'status) 'running)
                       (equal? (journal-pack attempt-value) (journal-pack (.ref (.ref row 'schedule) 'active)))
                       (equal? (.ref capability 'workspace) (.ref effect 'workspace))
                       (equal? (.ref capability 'path) (.ref effect 'path))
                       (equal? (.ref capability 'scope-digest) (.ref (.ref attempt-value 'input) 'scope-digest))
                       (.slot? capability '.apply!) (procedure? (.ref capability '.apply!)))
            (error "Workspace handoff requires its current Attempt and separately scoped live Host"))
          (unless (.ref (agentic-ai-lab-ai-agentic-context-session-host-revalidate! host
                           (.ref attempt-value 'session) (.ref (.ref row 'schedule) 'revision) (.ref row 'generation)) 'accepted?)
            (error "Workspace handoff has stale Context premises"))
          (workspace-assess! (.o kind: 'context.workspace-effect-state.v1 intent: owned
            origin-epoch: (journal-epoch journal) phase: 'handed-off observation: #f
            recovery-binding: recovery-binding-value
            hypotheses: '() execution-receipt: #f))
          (.o accepted?: #t reason: 'handoff-reserved intent: owned)))))

  (def (workspace-observe! intent capability (operation 'workspace-observe))
    (let* ((owned (require-command! intent operation)) (id (.ref (.ref owned 'body) 'effect))
           (value (workspace-state id)) (effect (.ref (.ref (.ref value 'intent) 'body) 'effect)))
      ;; The live read capability is supplied by the trusted embedding, never
      ;; reconstructed from old write authority or supplied as inert wire data.
      (unless (and (equal? (.ref capability 'workspace) (.ref effect 'workspace))
                   (equal? (.ref capability 'path) (.ref effect 'path)))
        (error "Workspace observation scope mismatch"))
      (let* ((witness (.call capability .read! capability))
             (bytes-value (.ref witness 'bytes))
             (coherent-value (.ref witness 'coherent?))
             (digest-value (journal-hash bytes-value))
             (content-value (cond ((equal? bytes-value (.ref effect 'desired)) 'matches-desired)
                            ((equal? bytes-value (.ref effect 'before)) 'matches-base) (else 'other)))
             (read-value (.o identity: (.ref owned 'identity) digest: digest-value bytes: bytes-value content: content-value
               coherent?: coherent-value owner-epoch: (journal-epoch journal)
               cut: (journal-hash (journal-pack (list (.ref owned 'identity) (journal-epoch journal) digest-value))))))
        (let* ((key (string-append "workspace-read:" (.ref owned 'identity)))
               (old (journal-get journal key)))
          (when (and old (not (equal? (journal-pack old) (journal-pack read-value))))
            (error "Workspace observation identity substitution"))
          (unless old (journal-put! journal key read-value)))
        (workspace-assess! (.o (:: @ value) observation: read-value)))))

  (def (workspace-recovery-row original)
    (find (lambda (entry) (equal? (.ref entry 'identity) (.ref original 'session)))
          (.ref (context-host-checkpoint host) 'entries)))

  (def (workspace-retry-head-key effect-id)
    (string-append "workspace-retry-head:" effect-id))

  (def (workspace-retry-head effect-id)
    (journal-get journal (workspace-retry-head-key effect-id)))

  (def (workspace-recovery-cut value row predecessor)
    (journal-hash (journal-pack
      (list (journal-epoch journal) recovery-binding-value
            (journal-hash (journal-pack (.ref value 'intent)))
            (.ref (.ref value 'observation) 'cut)
            (.ref (.ref row 'schedule) 'revision) (.ref row 'generation)
            (.ref value 'execution-receipt) predecessor))))

  (def (workspace-retry-premises original-intent predecessor)
    (and recovery-effect-host
         (let (host-value recovery-effect-host)
           (journal-unpack (journal-pack
             (.call host-value .retry-premises host-value original-intent predecessor))))))

  ;; Reads run inside the fenced owner transaction. This check is evidence
  ;; currentness only; no token is minted or consumed by returning the bytes.
  (def (workspace-recovery-current id expected-digest (live-spend #f))
    (unless (journal-active? journal) (error "Recovery receipt requires a fenced owner transaction"))
    (let* ((input (journal-input journal id))
           (receipt (journal-get journal (string-append "service-decision:" id))))
      (and input receipt
           (equal? (.ref input 'status) "applied")
           (eq? (.ref receipt 'kind) 'context.workspace-recovery-decision.v1)
           (equal? (.ref receipt 'identity) id)
           (eq? (.ref (.ref input 'payload) 'kind) 'context.durable-command.v1)
           (eq? (.ref (.ref input 'payload) 'operation) 'workspace-recovery-assess)
           (= (.ref receipt 'owner-epoch) (journal-epoch journal))
           (equal? (.ref receipt 'binding) recovery-binding-value)
           (let* ((packed (journal-pack receipt))
                  (evidence (.ref receipt 'evidence))
                  (effect-id (.ref evidence 'effect))
                  (body (.ref (.ref input 'payload) 'body))
                  (value (workspace-state effect-id))
                  (head (workspace-retry-head effect-id))
                  (predecessor (and (.slot? receipt 'predecessor) (.ref receipt 'predecessor)))
                  (original (.ref (.ref (.ref value 'intent) 'body) 'attempt))
                  (row (workspace-recovery-row original)))
             (and (or (not expected-digest) (equal? expected-digest (journal-hash packed)))
                  (equal? effect-id (.ref body 'effect))
                  (= (.ref body 'owner-epoch) (journal-epoch journal))
                  row (.ref value 'observation)
                  (equal? (.ref original 'identity) (.ref evidence 'attempt))
                  (or (equal? head predecessor)
                      (and live-spend head
                           (equal? head (.ref live-spend 'token-digest))
                           (equal? predecessor (.ref live-spend 'predecessor))))
                  (equal? (.ref evidence 'cut) (workspace-recovery-cut value row predecessor))
                  packed)))))

  (def (workspace-recovery-assess! intent capability)
    (let* ((owned (require-command! intent 'workspace-recovery-assess))
           (decision-id (.ref owned 'identity))
           (effect-id (.ref (.ref owned 'body) 'effect))
           (before (workspace-state effect-id))
           (original (.ref (.ref (.ref before 'intent) 'body) 'attempt))
           (epoch-value (journal-epoch journal))
           (row (workspace-recovery-row original)))
      (unless (and recovery-policy
                   (= epoch-value (.ref (.ref owned 'body) 'owner-epoch))
                   (> epoch-value (.ref before 'origin-epoch))
                   row
                   (equal? (.ref capability 'scope-digest)
                           (.ref (.ref original 'input) 'scope-digest))
                   (or (.ref before 'execution-receipt)
                       (let (schedule (.ref row 'schedule))
                         (and (eq? (.ref schedule 'status) 'recovering)
                              (find (lambda (attempt)
                                      (equal? (journal-pack attempt) (journal-pack original)))
                                    (.ref schedule 'obligations))))))
        (error "Recovery assessment requires the current owner and original Attempt"))
      (let* ((after (workspace-observe! owned capability 'workspace-recovery-assess))
             (observed (.ref after 'observation))
             (outcome-value (if (.ref after 'execution-receipt) 'succeeded 'unknown))
             (binding-matches (and recovery-binding-value (.slot? after 'recovery-binding)
                                   (equal? recovery-binding-value (.ref after 'recovery-binding))))
             (prior-spend (workspace-retry-head effect-id))
             (cut-value (workspace-recovery-cut after row prior-spend))
             (premises-value (workspace-retry-premises (.ref after 'intent) prior-spend))
             (permission-value (and premises-value (eq? #t (.ref premises-value 'current-permission?))))
             (safe-value
               (and premises-value (eq? #t (.ref premises-value 'repeat-safe?))
                    (or (not prior-spend)
                        (and (.slot? premises-value 'reconciled-spend)
                             (equal? prior-spend (.ref premises-value 'reconciled-spend))))))
             (input-value (.o attempt: (.ref original 'identity) effect: effect-id cut: cut-value
                              binding-matches?: binding-matches recorded-outcome: outcome-value
                              outcome-observations: (if (eq? #t (.ref observed 'coherent?))
                                                      (list observed) '())
                              ;; A scoped read admits evidence, not write authority
                              ;; or a guarantee that another dispatch is safe.
                              current-permission?: permission-value repeat-safe?: safe-value))
             (result-value (durable-recovery-decision recovery-policy input-value))
             (receipt-value (.o kind: 'context.workspace-recovery-decision.v1
                               identity: decision-id owner-epoch: epoch-value
                               binding: recovery-binding-value premises: premises-value predecessor: prior-spend
                               evidence: input-value decision: result-value)))
        (journal-put! journal (string-append "service-decision:" decision-id) receipt-value)
        receipt-value)))

  (def (retry-key nonce)
    (string-append "workspace-retry-spend:" (journal-hash (journal-pack nonce))))

  ;; A second token must not consume the same assessment again. The
  ;; receipt fence is separate from the global nonce fence.
  (def (retry-decision-key intent)
    (string-append "workspace-retry-decision:"
                   (.ref (.ref intent 'body) 'decision-digest)))

  (def (workspace-retry-decision-used? intent)
    (let* ((id (journal-get journal (retry-decision-key intent)))
           (input (and id (journal-input journal id)))
           (prior (and input (.ref input 'payload))))
      (and prior (equal? (.ref input 'status) "applied")
           (= (.ref (.ref intent 'body) 'owner-epoch) (journal-epoch journal))
           (equal? (journal-pack (.ref prior 'body))
                   (journal-pack (.ref intent 'body))))))

  (def (workspace-retry-context-current? original)
    (let* ((session-id (.ref original 'session))
           (row (workspace-recovery-row original))
           (schedule (and row (.ref row 'schedule))))
      (and schedule
           (eq? (.ref schedule 'status) 'recovering)
           (find (lambda (obligation)
                   (equal? (journal-pack obligation) (journal-pack original)))
                 (.ref schedule 'obligations))
           (.ref (agentic-ai-lab-ai-agentic-context-session-host-observe
                   host session-id (.ref schedule 'revision) (.ref row 'generation))
                 'accepted?))))

  (def (workspace-retry-read-current? host-value value)
    (and (.slot? host-value '.read!)
         (procedure? (.ref host-value '.read!))
         (let* ((observed (.ref value 'observation))
                (current (.call host-value .read! host-value)))
           (and (eq? #t (.ref observed 'coherent?))
                (eq? #t (.ref current 'coherent?))
                (equal? (.ref current 'bytes) (.ref observed 'bytes))))))

  (def (workspace-authorization-request intent packed)
    (let* ((body (.ref intent 'body))
           (digest-value (.ref body 'decision-digest))
           (receipt (and packed (journal-unpack packed))))
      (and receipt
           (equal? (.ref body 'effect) (.ref (.ref receipt 'evidence) 'effect))
           (= (.ref body 'owner-epoch) (journal-epoch journal))
           (eq? #t (.ref (.ref receipt 'decision) 'retry-eligible?))
           (let (original-intent (.ref (workspace-state (.ref body 'effect)) 'intent))
             (.o command: intent original: original-intent
                 receipt: packed digest: digest-value)))))

  (def (workspace-retry-admission intent token (live-spend #f))
    (let* ((body (.ref intent 'body))
           (expected-digest (.ref body 'decision-digest))
           (packed (and (command-identity? expected-digest)
                        (workspace-recovery-current (.ref body 'decision) expected-digest live-spend)))
           (receipt (and packed (journal-unpack packed))))
      (and receipt recovery-effect-host
           (let* ((decision (.ref receipt 'decision))
                  (effect-id (.ref (.ref receipt 'evidence) 'effect))
                  (value (workspace-state effect-id))
                  (original-intent (.ref value 'intent))
                  (original-body (.ref original-intent 'body))
                  (original-attempt (.ref original-body 'attempt))
                  (effect (.ref original-body 'effect))
                  (binding (.ref token 'binding))
                  (root (.ref token 'semantic-root))
                  (intent-digest (journal-hash (journal-pack intent)))
                  (host-value recovery-effect-host))
             (and (not (.ref value 'execution-receipt))
                  (equal? (.ref host-value 'workspace) (.ref effect 'workspace))
                  (equal? (.ref host-value 'path) (.ref effect 'path))
                  (equal? (.ref host-value 'scope-digest)
                          (.ref (.ref original-attempt 'input) 'scope-digest))
                  (workspace-retry-read-current? host-value value)
                  (workspace-retry-context-current? original-attempt)
                  (not (equal? (.ref intent 'identity) (.ref original-attempt 'identity)))
                  (eq? #t (.ref decision 'retry-eligible?))
                  (.slot? host-value '.consume-retry-authorization!)
                  (procedure? (.ref host-value '.consume-retry-authorization!))
                  (not (eq? (.ref decision 'outcome) 'succeeded))
                  (equal? (.ref body 'effect) effect-id)
                  (= (.ref body 'owner-epoch) (journal-epoch journal))
                  (eq? (.ref token 'durability) 'strict)
                  (= (.ref binding 'bundle-epoch) (journal-epoch journal))
                  (equal? (.ref binding 'attempt-id) (.ref original-attempt 'identity))
                  (equal? (.ref binding 'session-id) (.ref original-attempt 'session))
                  (equal? (.ref binding 'intent-digest) intent-digest)
                  ;; The signed authority decision has its own digest.
                  ;; The canonical intent binds the Durable receipt digest.
                  (equal? (.ref root 'intent-digest) intent-digest)
                  (equal? (.ref root 'decision-digest) (.ref binding 'decision-digest))
                  (equal? (.ref root 'digest)
                          (.ref (agentic-ai-lab-semantic-root
                                  (.ref binding 'bundle-digest)
                                  (.ref binding 'policy-digest)
                                  (.ref binding 'entity-digest)
                                  (.ref binding 'decision-digest)
                                  intent-digest)
                                'digest))
                  (.slot? receipt 'premises)
                  (.ref receipt 'premises)
                  (equal? (journal-pack (.ref receipt 'premises))
                          (journal-pack (workspace-retry-premises original-intent (.ref receipt 'predecessor))))
                  ;; The live authorization owner verifies the issuer and
                  ;; returns its current token validation context, or refuses.
                  (let* ((request (workspace-authorization-request intent packed))
                         (validation (.call host-value .retry-authorization host-value request token)))
                    (and validation
                         (.o original: original-intent context: validation
                             predecessor: (.ref receipt 'predecessor) authorization-request: request))))))))

  (def (workspace-retry-consume! intent token)
    (let* ((owned (require-command! intent 'workspace-retry-consume))
           (body (.ref owned 'body))
           (id-value (.ref owned 'identity))
           (digest-value (.ref body 'decision-digest))
           (packed (and (command-identity? digest-value)
                        (workspace-recovery-current (.ref body 'decision) digest-value)))
           (receipt (and packed (journal-unpack packed)))
           (decision (and receipt (.ref receipt 'decision)))
           (reason-value
             (cond
               ;; The committed spend advances the head, so the original
               ;; receipt cannot pass the current-cut check a second time.
               ((workspace-retry-decision-used? owned) 'decision-reuse)
               ((or (not receipt)
                    (not (= (.ref body 'owner-epoch) (journal-epoch journal)))
                    (not (equal? (.ref body 'effect) (.ref (.ref receipt 'evidence) 'effect))))
                'stale-or-mismatched-decision)
               ((eq? (.ref decision 'outcome) 'succeeded) 'effect-already-succeeded)
               ((not (eq? #t (.ref decision 'retry-eligible?))) 'recovery-ineligible)
               ((not (and (object? token) (.slot? token 'kind)
                          (eq? (.ref token 'kind) 'agentic-ai-lab-authorized-effect-token)))
                'missing-current-capability)
               ((journal-get journal (retry-key (.ref token 'nonce))) 'token-reuse)
               (else #f)))
           (spent? (and (not reason-value) (workspace-retry-consume-authorized! owned token)))
           (status-value (if spent? 'consumed (or reason-value 'current-authority-refused))))
      ;; Commit the refusal or the spend under the same inbox identity. A
      ;; historical ACK still cannot recreate a live dispatch handoff.
      (journal-put! journal (string-append "service-decision:" id-value)
        (.o kind: 'context.workspace-retry-decision.v1 identity: id-value
            owner-epoch: (journal-epoch journal) recovery-digest: digest-value
            reason: status-value action-authorized?: #f))
      spent?))

  (def (workspace-retry-consume-authorized! owned token)
    (when (>= (hash-length live-retry-handoffs) 128)
      (error "Workspace retry handoff capacity"))
    (let* ((key (retry-key (.ref token 'nonce)))
           (admission (and (not (journal-get journal key))
                           (not (journal-get journal (retry-decision-key owned)))
                           (workspace-retry-admission owned token))))
      (and admission
           (let* ((context (.ref admission 'context))
                  (root (journal-hash (journal-pack owned)))
                  (state-value (agentic-ai-lab-strict-mediation-state
                                 root 0 '() (.ref context 'revocation-epoch)))
                  ;; A nonce spend has no outcome evidence at this boundary.
                  (transition (agentic-ai-lab-strict-mediate state-value token context root #f))
                  (receipt (agentic-ai-lab-strict-mediation-result-receipt transition)))
             (and (.ref receipt 'accepted?)
                  (let ((id-value (.ref owned 'identity))
                        (prior-spend (.ref admission 'predecessor))
                        (effect-id (.ref (.ref owned 'body) 'effect))
                        (token-digest-value (agentic-ai-lab-authorized-effect-token-digest token)))
                    (journal-put! journal key
                      (.o command: id-value token-digest: token-digest-value
                          owner-epoch: (journal-epoch journal) consumption: receipt
                          predecessor: prior-spend))
                    (journal-put! journal (workspace-retry-head-key effect-id) token-digest-value)
                    (journal-put! journal (retry-decision-key owned) id-value)
                    (hash-put! live-retry-handoffs id-value token)
                    #t))))))

  (def (workspace-retry-dispatch! dispatch intent token)
    (let* ((owned (require-command! dispatch 'workspace-retry-dispatch))
           (id (.ref intent 'identity)))
      (and (equal? id (.ref (.ref owned 'body) 'consumption))
           (eq? token (hash-get live-retry-handoffs id))
           (begin
             (hash-remove! live-retry-handoffs id)
             (workspace-retry-dispatch-live! intent token)))))

  (def (workspace-retry-dispatch-live! intent token)
    (let* ((id (.ref intent 'identity))
           (spend (journal-get journal (retry-key (.ref token 'nonce))))
           (input (journal-input journal id))
           (admission
             (and spend input (equal? (.ref input 'status) "applied")
                  (equal? (journal-pack (.ref input 'payload)) (journal-pack intent))
                  (equal? (.ref spend 'command) id)
                  (equal? (journal-get journal (retry-decision-key intent)) id)
                  (= (.ref spend 'owner-epoch) (journal-epoch journal))
                  (equal? (.ref spend 'token-digest)
                          (agentic-ai-lab-authorized-effect-token-digest token))
                  (not (journal-get journal (string-append "workspace-retry-handoff:" id)))
                  (workspace-retry-admission intent token spend))))
      (and admission
           (let* ((context (.ref admission 'context))
                  ;; The nonce is already spent by this exact live handoff.
                  ;; Validate time, binding and revocation again without
                  ;; treating the committed spend as renewed authority.
                  (validation (agentic-ai-lab-authorized-effect-token-validate
                    token (.o (:: @ context) consumed-nonces:
                              (filter (lambda (nonce) (not (equal? nonce (.ref token 'nonce))))
                                      (.ref context 'consumed-nonces))))))
             (and (.ref validation 'accepted?)
                  (let* ((host-value recovery-effect-host)
                         ;; An issuer check is not an issuer spend. The
                         ;; journal spend is already committed at this point.
                         (handoff (.call host-value .consume-retry-authorization!
                                    host-value (.ref admission 'authorization-request) token)))
                    (and handoff
                         (begin
                           (journal-put! journal (string-append "workspace-retry-handoff:" id)
                                         (.o owner-epoch: (journal-epoch journal) outcome: 'unknown))
                           ;; Pass the consumed handoff, never the original grant.
                           (.call host-value .dispatch-retry! host-value intent (.ref admission 'original) handoff)
                           #t))))))))

  (def (workspace-propose! intent)
    (let* ((owned (require-command! intent 'workspace-propose)) (body (.ref owned 'body))
           (value (workspace-state (.ref body 'effect))) (proposal (.ref body 'proposal))
           (previous (.ref value 'hypotheses)))
      (unless (and (command-identity? (.ref proposal 'identity)) (string? (.ref proposal 'question))
                   (< 0 (string-length (.ref proposal 'question)) 4097) (< (length previous) 32)
                   (not (find (lambda (p) (equal? (.ref p 'identity) (.ref proposal 'identity))) previous)))
        (error "Invalid or substituted recovery hypothesis"))
      (workspace-assess! (.o (:: @ value) hypotheses: (append previous (list proposal))))))

  (def (workspace-complete! intent observation)
    (let* ((owned (require-command! intent 'workspace-result)) (id (.ref (.ref owned 'body) 'effect))
           (value (workspace-state id)) (body (.ref (.ref value 'intent) 'body))
           (attempt-value (.ref body 'attempt)) (effect (.ref body 'effect))
           (evidence (context-observation-evidence host (.ref attempt-value 'session) observation))
           (payload (journal-unpack (.ref evidence 'payload)))
           (row (find (lambda (r) (equal? (.ref r 'identity) (.ref attempt-value 'session)))
                      (.ref (context-host-checkpoint host) 'entries))))
      (unless (and (equal? (journal-pack attempt-value) (journal-pack (.ref evidence 'attempt)))
                   (eq? (.ref payload 'kind) 'context.workspace-write-observation.v1)
                   (equal? (.ref payload 'command) id)
                   (equal? (.ref payload 'workspace) (.ref effect 'workspace))
                   (equal? (.ref payload 'path) (.ref effect 'path))
                   (equal? (.ref payload 'before-digest) (journal-hash (.ref effect 'before)))
                   (equal? (.ref payload 'after-digest) (journal-hash (.ref effect 'desired))))
        (error "Workspace result requires its actual qualified worker observation"))
      (let (result (agentic-ai-lab-ai-agentic-context-session-host-commit-result! host
                    (.ref attempt-value 'session) (.ref (.ref row 'schedule) 'revision) (.ref row 'generation) observation))
        (unless (.ref result 'runtime-result-published?) (error "Workspace worker terminal refused"))
        (workspace-assess! (.o (:: @ value) phase: 'returned execution-receipt:
          (.o identity: (.ref owned 'identity) observation: evidence terminal: (.ref result 'terminal)))))))

  (def (apply-source! intent)
    (unless catalog-value (error "Source change requires a catalog owner"))
    (let* ((owned-input (require-command! intent 'query-source))
           (body (.ref owned-input 'body))
           (source-value (.ref body 'source))
           (id-value (.ref owned-input 'identity))
           ;; Look up this source head, not a copy/scan of every historical
           ;; Query and proof. Dependency propagation stays with its runtime owner.
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
        ;; Reuse runtime authority observers and the captured-version dependency
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
    (let* ((anchor (journal-get journal "anchor")) (now (monotonic-seconds)))
      (unless (and anchor (equal? (.ref anchor 'boot) (runtime-boot-identity))
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
        ;; The runtime Host owns deadline replacement and dependency-directed
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
    (let* ((anchor (journal-get journal "anchor")) (now (monotonic-seconds)))
      (unless (and anchor (equal? (.ref anchor 'boot) (runtime-boot-identity)) (>= now (.ref anchor 'epoch)))
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
              ;; External workspace handoff is never replayed on restore.
              ;; Pending result/read/proposal messages also need their live
              ;; capabilities or fresh admission; identifiers cannot recreate them.
              ((result cancel recover workspace-effect workspace-result workspace-observe workspace-propose workspace-recovery-assess workspace-retry-consume workspace-retry-dispatch) #t)
              (else (error "Unknown durable command requires explicit recovery")))))) (journal-rows journal))
      (let (id (string-append "owner-recovery:" (number->string (journal-epoch journal))))
        (journal-receive! journal id (.o kind: 'context.owner-recovered.v1))
        (journal-begin! journal id)
        (for-each (lambda (row)
          (let (payload (.ref row 'payload))
            (when (and (eq? (.ref payload 'kind) 'context.durable-command.v1)
                       (eq? (.ref payload 'operation) 'workspace-effect)
                       (journal-get journal (workspace-key (.ref row 'id))))
              (workspace-assess! (workspace-state (.ref row 'id)))))) (journal-rows journal))
        (save!) (journal-commit! journal))))
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
    .workspace-prepare!: (lambda (self intent capability) (workspace-prepare! intent capability))
    .workspace-observe!: (lambda (self intent capability) (workspace-observe! intent capability))
    .workspace-retry-consume!: (lambda (self intent token) (workspace-retry-consume! intent token))
    .workspace-retry-dispatch!: (lambda (self dispatch intent token) (workspace-retry-dispatch! dispatch intent token))
    .workspace-recovery-current: (lambda (self id digest) (workspace-recovery-current id digest))
    .workspace-authorization-request:
    (lambda (self intent)
      (let (body (.ref intent 'body))
        (workspace-authorization-request intent
          (workspace-recovery-current (.ref body 'decision) (.ref body 'decision-digest)))))
    .workspace-recovery-assess!: (lambda (self intent capability) (workspace-recovery-assess! intent capability))
    .workspace-propose!: (lambda (self intent) (workspace-propose! intent))
    .workspace-complete!: (lambda (self intent observation) (workspace-complete! intent observation))
    .workspace-state: (lambda (self id) (workspace-state id))
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
