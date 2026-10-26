;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Explicit in-process coordinator. Its serialized owner enrolls source snapshots.
;;; Local claim publication is neither provider disclosure nor MRR/Data admission.
(import (only-in :clan/poo/object .o .ref .slot? object? object<-alist .call)
        (only-in :std/list/list every find delete-duplicates/hash)
        (only-in :agentic-ai-lab/modules/session/funs-attempt agentic-ai-lab-session-schedule
                 agentic-ai-lab-session-claim agentic-ai-lab-session-recover
                 agentic-ai-lab-session-complete agentic-ai-lab-session-reconcile agentic-ai-lab-session-close)
        (only-in :agentic-ai-lab/modules/temporal-causality/evaluator/proof-host agentic-ai-lab-temporal-proof-host-current agentic-ai-lab-temporal-proof-host-watch! agentic-ai-lab-temporal-proof-host-unwatch! agentic-ai-lab-temporal-proof-host-policy agentic-ai-lab-temporal-proof-host-retained-digest agentic-ai-lab-temporal-proof-host-source-snapshot
                 agentic-ai-lab-temporal-proof-host-refresh!)
        (only-in :agentic-ai-lab/modules/temporal-causality/truth-maintenance/objects agentic-ai-lab-temporal-derivation)
        (only-in :agentic-ai-lab/modules/temporal-causality/truth-maintenance/funs agentic-ai-lab-temporal-dependency-index agentic-ai-lab-temporal-reverse-dependency-plan)
        (only-in :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy-host
          agentic-ai-lab-temporal-support-policy-host-watch! agentic-ai-lab-temporal-support-policy-host-unwatch!)
        (only-in :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy
          agentic-ai-lab-temporal-support-policy-status)
        "funs-scope.ss" "funs-features.ss" "funs-projection.ss" "funs-session.ss" "use-host.ss"
        "query-provider.ss"
        (only-in :agentic-ai-lab/modules/query/semantic/context-restriction agentic-ai-lab-context-flow-decision))
(export agentic-ai-lab-ai-agentic-context-session-host
        agentic-ai-lab-ai-agentic-context-session-host-enroll!
        agentic-ai-lab-ai-agentic-context-session-host-refresh!
        agentic-ai-lab-ai-agentic-context-session-host-current
        agentic-ai-lab-ai-agentic-context-session-host-claim!
        agentic-ai-lab-ai-agentic-context-session-host-observe
        agentic-ai-lab-ai-agentic-context-session-host-require-proof!
        agentic-ai-lab-ai-agentic-context-session-host-revalidate!
        agentic-ai-lab-ai-agentic-context-session-host-attach-worker!
        agentic-ai-lab-ai-agentic-context-session-host-observe-worker!
        agentic-ai-lab-ai-agentic-context-session-host-commit-result!
        agentic-ai-lab-ai-agentic-context-session-host-cancel!
        agentic-ai-lab-ai-agentic-context-session-host-recover!
        agentic-ai-lab-ai-agentic-context-session-host-reconcile!
        agentic-ai-lab-ai-agentic-context-session-host-close!
        agentic-ai-lab-ai-agentic-context-session-host-outcomes
        agentic-ai-lab-ai-agentic-context-session-host-enable-propagation!
        agentic-ai-lab-ai-agentic-context-session-host-depend-on!
        agentic-ai-lab-ai-agentic-context-session-host-propagations
        context-host-dispose! context-host-disposed? context-host-subscription-count
        context-host-checkpoint context-host-session? context-host-restore! context-host-query-provider context-observation-evidence
        context-host-enroll-query! context-host-refresh-query!)
(defstruct session-owner-state (entries owner grants policies proofs proof-required? workers observations propagation-enabled? watchers parents propagation-log disposed?))
;;; The schedule and immutable terminal history publish through ONE row pointer.
(defstruct owner-publication (schedule terminals propagation))
(defstruct source-entry (generation source scope restriction profile task-revision ids
                        projection task publication grant-id grant-generation authority query))
(defstruct proof-binding (host registration state-generation policy-generation policy-digest budget source-generation digest parents authority admission query))
(defstruct native-worker (session attempt source-generation proof-digest registration original-proof thread observation mode query))
(defstruct native-observation (worker payload))
(defstruct context-parent (session binding parents))
;;; Native Provider ownership is kept outside the portable lineage.
(defstruct query-binding (owner observation))
(def (source-entry-schedule row) (owner-publication-schedule (source-entry-publication row)))
(def (publish-schedule! row schedule)
  (set! (source-entry-publication row)
    (make-owner-publication schedule (owner-publication-terminals (source-entry-publication row))
      (owner-publication-propagation (source-entry-publication row)))))
(def (text? x) (and (string? x) (< 0 (string-length x) 257)))
(def (coordinate? x) (and (exact-integer? x) (<= 0 x 65535)))
(def (agentic-ai-lab-ai-agentic-context-session-host grants policies proof-required-value (eager-value #t))
  (unless (and (boolean? proof-required-value) (boolean? eager-value)) (error "Context proof requirement must be explicit"))
  (let (runtime-value (make-session-owner-state (make-hash-table test: equal?)
                         (current-thread) grants policies (make-hash-table test: equal?) proof-required-value
                         (make-hash-table-eq) (make-hash-table-eq) eager-value (make-hash-table-eq) (make-hash-table) '() #f))
    (.o kind: 'agentic-ai-lab.ai-agentic-context.session-host.v1 private-runtime-state: runtime-value)))
(def (state host (allow-disposed? #f))
  (unless (and (object? host) (.slot? host 'kind)
               (eq? (.ref host 'kind) 'agentic-ai-lab.ai-agentic-context.session-host.v1)
               (.slot? host 'private-runtime-state)
               (session-owner-state? (.ref host 'private-runtime-state))) (error "Invalid Context Session Host"))
  (let (runtime-value (.ref host 'private-runtime-state))
    (when (and (session-owner-state-disposed? runtime-value) (not allow-disposed?))
      (error "Context runtime is disposed"))
    (unless (or (session-owner-state-disposed? runtime-value)
                (eq? (session-owner-state-owner runtime-value) (current-thread)))
      (error "Context Session Host requires its serialized owner thread")) runtime-value))
;;; Disposal releases this runtime's observer leases only. It is deliberately
;;; separate from Session close/cancel: durable work obligations and terminal
;;; evidence are not rewritten, nor are independent endpoint workers killed.
(def (context-host-disposed? host)
  (session-owner-state-disposed? (state host #t)))
(def (context-host-subscription-count host)
  (hash-length (session-owner-state-watchers (state host #t))))
(def (context-host-dispose! host)
  (let (s (state host #t))
    (unless (session-owner-state-disposed? s)
      (for-each (lambda (publisher)
        (let (observer (hash-ref (session-owner-state-watchers s) publisher))
          (case (.ref publisher 'kind)
            ((temporal.proof-host.v1)
             (agentic-ai-lab-temporal-proof-host-unwatch! publisher observer))
            ((agentic-ai-lab.context-use-host.v1)
             (agentic-ai-lab-context-use-host-unwatch! publisher observer))
            ((agentic-ai-lab.temporal-causality.policy-host.v1)
             (agentic-ai-lab-temporal-support-policy-host-unwatch! publisher observer))
            ((context.query-provider-host.v1) (context-query-unwatch! publisher observer))
            (else (error "Unknown Context observer owner")))))
        (hash-keys (session-owner-state-watchers s)))
      (set! (session-owner-state-watchers s) (make-hash-table-eq))
      (set! (session-owner-state-entries s) (make-hash-table))
      (set! (session-owner-state-proofs s) (make-hash-table))
      (set! (session-owner-state-workers s) (make-hash-table-eq))
      (set! (session-owner-state-observations s) (make-hash-table-eq))
      (set! (session-owner-state-parents s) (make-hash-table))
      (set! (session-owner-state-propagation-log s) '())
      (set! (session-owner-state-grants s) #f)
      (set! (session-owner-state-policies s) #f)
      (set! (session-owner-state-owner s) #f)
      (set! (session-owner-state-disposed? s) #t))
    #t))

(def (entry runtime-value session-id)
  (or (hash-get (session-owner-state-entries runtime-value) session-id) (error "Unknown enrolled Session")))
;;; Snapshot only closed native schemas. No live object/string aliases escape.
(def (copy-value value)
  (cond ((string? value) (string-copy value))
        ((pair? value) (map copy-value value))
        ((object? value)
         (let (keys (case (.ref value 'kind)
           ((agentic-ai-lab.ai-agentic-context.propagation.v1)
            '(kind event source generation changed-subjects proof-index context-index affected-contexts
              affected? invalidated? previous-revision revision previous-cut revised-cut previous-program revised-program))
           ((agentic-ai-lab.ai-agentic-context.terminal.v1)
            '(kind session attempt generation request input-digest source-generation proof-binding
              proof-registration proof-digest applicability-digest proof-state-generation proof-state-digest
              support-guard support-evaluation support-program journal-cut journal-projection query-lineage
              policy-digest grant-id grant-generation purpose destination revision outcome payload propagation-event))
           ((context.query-lineage.v1)
            '(kind source generation source-digest contract contract-revision query-digest
              result-digest org-ids proof-digests support-digest journal-digest semantic-digest))
           ((agentic-ai-lab.session.schedule.v1) '(kind identity revision generation status active obligations completed))
           ((agentic-ai-lab.session.attempt.v1) '(kind session task task-revision identity generation turn request input anchor-refs))
           ((agentic-ai-lab.session.input-ref.v1) '(kind producer contract identity digest scope-digest source-vector-digest
              query-digest restriction-digest profile-digest receipt-ref complete? consumer-session consumer-turn))
           ((agentic-ai-lab.session.task.v1) '(kind identity revision input anchor-refs anchor-bindings))
           ((agentic-ai-lab.ai-agentic-context.org-anchor.v1) '(kind org-id container-kind container-start value-start value-end
              source-digest parser-identity projection-digest scope-digest session turn semantic-digest
              source-authenticated? action-authorized?))
           (else (error "Unsupported Host snapshot schema"))))
           (object<-alist
             (map (lambda (key) (cons key (copy-value (.ref value key))))
               (filter (lambda (key) (or (not (eq? key 'query-lineage)) (.slot? value key))) keys)))))
        (else value)))
(def (view row accepted-value reason-value published-value)
  (let ((schedule-value (copy-value (source-entry-schedule row)))
        (task-value (and (source-entry-task row) (copy-value (source-entry-task row))))
        (source-generation-value (source-entry-generation row)))
    (.o kind: 'agentic-ai-lab.ai-agentic-context.session-host-receipt.v1 accepted?: accepted-value reason: reason-value
        source-generation: source-generation-value schedule: schedule-value task: task-value
        context-state: (if (row-invalidated? row) 'invalidated 'admitted)
        propagation: (copy-value (owner-publication-propagation (source-entry-publication row)))
        runtime-published?: published-value source-authenticated?: #f action-authorized?: #f
        provider-disclosed?: #f provider-result-admitted?: #f durable?: #f
        query-lineage: (and (source-entry-query row)
          (copy-value (context-query-lineage (query-binding-observation (source-entry-query row))))))))
(def (build-task source scope restriction profile revision ids grant-id grant-generation (proof-digest #f) (query-binding-value #f))
  (let* ((projection-value (agentic-ai-lab-ai-agentic-context-org-project scope source restriction profile))
         (receipt-value (agentic-ai-lab-ai-agentic-context-digest
             (append
               (list 'session-host-producer-reference-v1 (.ref projection-value 'semantic-digest)
                 grant-id grant-generation revision ids proof-digest)
               (if query-binding-value
                 (list (.ref (query-binding-observation query-binding-value) 'semantic-digest))
                 '()))))
         (base-task (agentic-ai-lab-ai-agentic-context-session-task
                      source projection-value scope receipt-value revision ids))
         (task-value
           (if query-binding-value
             (bind-query-task base-task query-binding-value)
             base-task)))
    (values projection-value task-value)))
(def (observe-grant runtime-value row)
  (let* ((observation-value (agentic-ai-lab-context-use-host-observe (session-owner-state-grants runtime-value)
           (session-owner-state-policies runtime-value) (source-entry-grant-id row)
           (source-entry-grant-generation row) 'display))
         (contract-value (.ref (.ref observation-value 'grant) 'contract))
         (scope-value (source-entry-scope row))
         (projection-value (source-entry-projection row))
         (flow-value (agentic-ai-lab-context-flow-decision (source-entry-restriction row)
           (.ref projection-value 'source-digest) (.ref projection-value 'semantic-digest)
           (.ref scope-value 'actor) (.ref scope-value 'destination)
           (.ref (.ref (.ref observation-value 'policy-snapshot) 'effective-at) 'coordinate))))
    (and (eq? (.ref flow-value 'status) 'eligible)
         (eq? (.ref observation-value 'decision) 'allowed)
         (equal? (.ref contract-value 'actor) (.ref scope-value 'actor))
         (equal? (.ref contract-value 'task) (.ref scope-value 'task)))))
(def (agentic-ai-lab-ai-agentic-context-session-host-enroll! host source-generation source scope restriction profile
                                                      task-revision ids grant-id grant-generation)
  (unless (and (coordinate? source-generation) (string? source) (text? grant-id)
               (coordinate? grant-generation) (> grant-generation 0)) (error "Invalid Session source enrollment"))
  (let* ((runtime-value (state host)) (scope-value (agentic-ai-lab-ai-agentic-context-scope-admit scope))
         (session-value (.ref scope-value 'session)) (source-value (string-copy source))
         (ids-value (map string-copy ids)) (grant-value (string-copy grant-id)))
    (unless (and (text? session-value) (not (hash-get (session-owner-state-entries runtime-value) session-value))
                 (< (hash-length (session-owner-state-entries runtime-value)) 128)) (error "Session enrollment conflict or capacity"))
    (let-values (((projection-value task-value) (build-task source-value scope-value restriction profile
                         task-revision ids-value grant-value grant-generation)))
      (let (row (make-source-entry source-generation source-value scope-value
                       (.ref projection-value 'restriction)
                       (agentic-ai-lab-ai-agentic-context-profile (if (memq 'ai-agentic-context/memory (.ref projection-value 'feature-ids)) #t #f)) task-revision ids-value projection-value task-value
                       (make-owner-publication (agentic-ai-lab-session-schedule session-value) '() #f) grant-value grant-generation
                       (capture-authority runtime-value grant-value grant-generation) #f))
        (unless (observe-grant runtime-value row) (error "Session enrollment requires current matching registered grant"))
        (when (session-owner-state-propagation-enabled? runtime-value)
          (ensure-authority-observers! host))
        (hash-put! (session-owner-state-entries runtime-value) session-value row)
        (view row #t 'enrolled #t)))))
(def (context-host-session? host session-id)
  ;; Consult the existing owner table; a transport adapter must not maintain
  ;; a second Session registry or poison its owner on an unknown wire target.
  (if (hash-get (session-owner-state-entries (state host)) session-id) #t #f))
(def (agentic-ai-lab-ai-agentic-context-session-host-current host session-id)
  (view (entry (state host) session-id) #t 'current #f))
(def (agentic-ai-lab-ai-agentic-context-session-host-refresh! host session-id expected-source-generation
                                                      new-source-generation source new-scope)
  (let* ((runtime-value (state host)) (old (entry runtime-value session-id))
         (scope-value (agentic-ai-lab-ai-agentic-context-scope-admit new-scope)))
    (when (source-entry-query old)
      (error "Provider-backed Context requires explicit Query re-admission"))
    (unless (and (equal? expected-source-generation (source-entry-generation old))
                 (coordinate? new-source-generation) (> new-source-generation expected-source-generation)
                 (string? source)) (error "Stale or invalid source revision"))
    (unless (every (lambda (key) (equal? (.ref scope-value key) (.ref (source-entry-scope old) key)))
                '(bundle organization epoch project worktree actor task destination session turn))
      (error "Source refresh cannot retarget consumer Scope"))
    (let* ((source-value (string-copy source))
           (schedule-value (source-entry-schedule old))
           (recovery (and (.ref schedule-value 'active)
                      (agentic-ai-lab-session-recover schedule-value (.ref schedule-value 'revision)))))
      (when (and recovery (not (.ref recovery 'accepted?))) (error "Recovery coordinate exhausted; source refresh refused"))
      ;; Source removal/invalidity must invalidate old input, even when no new Task can be constructed.
      (let-values (((projection-value task-value)
        (with-catch (lambda (exception) (values #f #f))
          (lambda () (build-task source-value scope-value (source-entry-restriction old) (source-entry-profile old)
                           (source-entry-task-revision old) (source-entry-ids old)
                           (source-entry-grant-id old) (source-entry-grant-generation old))))))
        (let (row (make-source-entry new-source-generation source-value scope-value
                         (source-entry-restriction old) (source-entry-profile old)
                         (source-entry-task-revision old) (source-entry-ids old) projection-value task-value
                         (make-owner-publication (if recovery (.ref recovery 'schedule) schedule-value)
                           (owner-publication-terminals (source-entry-publication old))
                           (owner-publication-propagation (source-entry-publication old)))
                         (source-entry-grant-id old) (source-entry-grant-generation old) (source-entry-authority old) #f))
          (hash-put! (session-owner-state-entries runtime-value) session-id row)
          (view row #t (if task-value 'source-refreshed 'source-blocked) #t))))))
(def (agentic-ai-lab-ai-agentic-context-session-host-observe host session-id expected-revision expected-source-generation)
  (let* ((runtime-value (state host)) (row (entry runtime-value session-id)))
    (cond ((not (equal? expected-revision (.ref (source-entry-schedule row) 'revision))) (view row #f 'stale-revision #f))
          ((not (equal? expected-source-generation (source-entry-generation row))) (view row #f 'stale-source #f))
          ((row-invalidated? row) (view row #f 'context-invalidated #f))
          ((not (source-entry-task row)) (view row #f 'source-blocked #f))
          ((not (query-current? (source-entry-query row)))
           (view row #f 'context-query-denied #f))
          ((not (bound-parents-current? runtime-value session-id)) (view row #f 'context-dependency-denied #f))
          ((not (observe-proof runtime-value row session-id)) (view row #f 'temporal-proof-denied #f))
          ((not (observe-grant runtime-value row)) (view row #f 'current-grant-denied #f))
          (else (view row #t 'current-input-eligible #f)))))
(def (agentic-ai-lab-ai-agentic-context-session-host-claim! host session-id expected-revision expected-source-generation
                                                    attempt-id request-id)
  (let* ((runtime-value (state host)) (row (entry runtime-value session-id))
         (observed (agentic-ai-lab-ai-agentic-context-session-host-observe host session-id expected-revision expected-source-generation)))
    (if (not (.ref observed 'accepted?)) observed
      (let (proposal (agentic-ai-lab-session-claim (source-entry-schedule row) expected-revision (source-entry-task row)
                        attempt-id request-id (.ref (source-entry-scope row) 'turn)))
        (if (not (.ref proposal 'accepted?)) (view row #f (.ref proposal 'reason) #f)
          (begin (publish-schedule! row (.ref proposal 'schedule))
                 (view row #t 'claim-published #t)))))))

;;; Proof requirements are owner-enrolled capabilities, never wire verdicts.
;;; A binding change fences prepared claims through the same Session revision CAS.
(def (current-proof binding)
  (agentic-ai-lab-temporal-proof-host-current (proof-binding-host binding)
    (proof-binding-registration binding) (proof-binding-state-generation binding)
    (proof-binding-policy-generation binding) (proof-binding-policy-digest binding)
    (proof-binding-budget binding)))
(def (observe-proof runtime-value row session-id)
  (let (binding (hash-get (session-owner-state-proofs runtime-value) session-id))
    (or (and (not binding) (not (session-owner-state-proof-required? runtime-value)))
        (and binding (query-current? (proof-binding-query binding))
             (= (source-entry-generation row) (proof-binding-source-generation binding))
             (with-catch (lambda (exception) #f)
               (lambda () (.ref (current-proof binding) 'current?)))))))
(def (agentic-ai-lab-ai-agentic-context-session-host-require-proof! host session-id expected-revision
        expected-source-generation proof-host registration state-generation policy-generation policy-digest budget)
  (unless (and (text? registration) (text? policy-digest) (coordinate? state-generation)
               (coordinate? policy-generation) (exact-integer? budget) (<= 0 budget 4096))
    (error "Invalid Context proof requirement"))
  (let* ((runtime-value (state host)) (row (entry runtime-value session-id))
         (schedule-value (source-entry-schedule row)))
    (unless (and (parents-current? runtime-value session-id) (= expected-revision (.ref schedule-value 'revision))
                 (= expected-source-generation (source-entry-generation row))
                 (eq? (.ref schedule-value 'status) 'idle) (source-entry-task row)
                 (observe-grant runtime-value row)
                 (query-current? (source-entry-query row)))
      (error "Proof binding requires current idle Session input"))
    (let* ((binding (make-proof-binding proof-host (string-copy registration) state-generation
                      policy-generation (string-copy policy-digest) budget expected-source-generation #f
                      (or (hash-get (session-owner-state-parents runtime-value) session-id) '())
                      (source-entry-authority row) #f (source-entry-query row)))
           (applicability (current-proof binding)))
      (unless (.ref applicability 'current?) (error "Context requires current original Temporal proof"))
      (set! (proof-binding-admission binding) applicability)
      (set! (proof-binding-digest binding)
        (agentic-ai-lab-ai-agentic-context-digest (list 'context-temporal-binding-v1
          (.ref (source-entry-scope row) 'semantic-digest) expected-source-generation
          (.ref (.ref (source-entry-task row) 'input) 'digest)
          (.ref applicability 'semantic-digest) (proof-binding-authority binding)
          (map (lambda (parent) (proof-binding-digest (context-parent-binding parent)))
            (or (hash-get (session-owner-state-parents runtime-value) session-id) '())))))
      (let-values (((projection-value task-value)
        (build-task (source-entry-source row) (source-entry-scope row) (source-entry-restriction row)
          (source-entry-profile row) (source-entry-task-revision row) (source-entry-ids row)
          (source-entry-grant-id row) (source-entry-grant-generation row) (proof-binding-digest binding)
          (source-entry-query row))))
        (let (fence (agentic-ai-lab-session-recover schedule-value expected-revision))
          (unless (.ref fence 'accepted?) (error "Proof binding coordinate exhausted"))
          ;; Enroll the mandatory source feed BEFORE publishing any input/head.
          ;; Capacity/pending failures must leave the old Context untouched.
          (when (session-owner-state-propagation-enabled? runtime-value)
            (ensure-source-observer! host proof-host)
            (let-values (((policy-owner policy-id) (agentic-ai-lab-temporal-proof-host-policy proof-host registration)))
              (ensure-policy-observer! host policy-owner)))
          (hash-put! (session-owner-state-proofs runtime-value) (string-copy session-id) binding)
          (set! (source-entry-projection row) projection-value)
          (set! (source-entry-task row) task-value)
          (set! (source-entry-publication row)
            (make-owner-publication (.ref fence 'schedule)
              (owner-publication-terminals (source-entry-publication row)) #f))
          (view row #t 'proof-bound #t))))))
(def (agentic-ai-lab-ai-agentic-context-session-host-revalidate! host session-id expected-revision expected-source-generation)
  (let* ((runtime-value (state host)) (row (entry runtime-value session-id))
         (observed (agentic-ai-lab-ai-agentic-context-session-host-observe host session-id expected-revision expected-source-generation)))
    (if (and (memq (.ref observed 'reason) '(temporal-proof-denied current-grant-denied source-blocked context-dependency-denied))
             (.ref (source-entry-schedule row) 'active))
      (let (fence (agentic-ai-lab-session-recover (source-entry-schedule row) expected-revision))
        (unless (.ref fence 'accepted?) (error "Invalidation coordinate exhausted"))
        (publish-schedule! row (.ref fence 'schedule))
        (view row #f (.ref observed 'reason) #t))
      observed)))

;;; Native endpoint publication. Enrollment is an explicit trusted Host action;
;;; a joined endpoint authenticates only that endpoint's bytes, not their truth.
;;; All participating proof/grant/source Hosts require this same owner thread.
(def (binding-digest runtime-value session-id)
  (let (binding (hash-get (session-owner-state-proofs runtime-value) session-id))
    (and binding (proof-binding-digest binding))))
(def (owner-match row revision generation)
  (and (equal? revision (.ref (source-entry-schedule row) 'revision))
       (equal? generation (source-entry-generation row))))
(def (worker-for runtime-value token session-id)
  (let (worker (hash-get (session-owner-state-workers runtime-value) token))
    (unless (and worker (equal? session-id (native-worker-session worker)))
      (error "Unknown or foreign native worker capability")) worker))
(def (observation-for runtime-value token session-id)
  (let (observation (hash-get (session-owner-state-observations runtime-value) token))
    (unless (and observation (equal? session-id (native-worker-session (native-observation-worker observation))))
      (error "Unknown or foreign native observation capability")) observation))
(def (agentic-ai-lab-ai-agentic-context-session-host-attach-worker! host session-id revision generation endpoint)
  (let* ((runtime-value (state host)) (row (entry runtime-value session-id))
         (schedule (source-entry-schedule row)) (attempt (.ref schedule 'active)))
    (unless (and (owner-match row revision generation) attempt (thread? endpoint)
                 (not (eq? endpoint (current-thread)))
                 (bound-parents-current? runtime-value session-id)
                 (query-current? (source-entry-query row))
                 (observe-proof runtime-value row session-id) (observe-grant runtime-value row)
                 (< (hash-length (session-owner-state-workers runtime-value)) 128))
      (error "Native worker enrollment requires exact active current input"))
    (when (find (lambda (w) (or (eq? endpoint (native-worker-thread w))
                     (and (equal? session-id (native-worker-session w))
                          (equal? (.ref attempt 'identity) (.ref (native-worker-attempt w) 'identity)))))
                (hash-values (session-owner-state-workers runtime-value)))
      (error "Native endpoint or Attempt already enrolled"))
    (let ((token (.o kind: 'agentic-ai-lab.ai-agentic-context.worker-capability.v1))
          (worker (let* ((binding (hash-get (session-owner-state-proofs runtime-value) session-id))
                         (proof (and binding (current-proof binding))))
                    (make-native-worker (string-copy session-id) (copy-value attempt) generation
                      (binding-digest runtime-value session-id)
                      (and binding (string-copy (proof-binding-registration binding)))
                      (and proof (string-copy (.ref proof 'proof-digest))) endpoint #f 'running
                      (and (source-entry-query row)
                        (context-query-lineage (query-binding-observation (source-entry-query row))))))))
      (hash-put! (session-owner-state-workers runtime-value) token worker) token)))
(def (agentic-ai-lab-ai-agentic-context-session-host-observe-worker! host session-id worker-token)
  (let* ((runtime-value (state host)) (worker (worker-for runtime-value worker-token session-id)))
    (or (native-worker-observation worker)
      (let* ((pending (list 'native-worker-pending))
             ;; Nonblocking actual join: a timeout never issues a terminal seal.
             (payload (thread-join! (native-worker-thread worker) 0 pending)))
        (if (eq? pending payload) #f
          (begin
            (unless (and (string? payload) (<= (string-length payload) 65536))
              (error "Native worker result requires bounded immutable text"))
            (let ((token (.o kind: 'agentic-ai-lab.ai-agentic-context.observation-capability.v1))
                  (observation (make-native-observation worker (string-copy payload))))
              (hash-put! (session-owner-state-observations runtime-value) token observation)
              (set! (native-worker-observation worker) token) token)))))))
(def (terminal-publication! runtime-value row session-id observation proposal outcome-value applicability)
  (let* ((worker (native-observation-worker observation)) (attempt-value (native-worker-attempt worker))
         (schedule (.ref proposal 'schedule))
         (terminal-value (.o kind: 'agentic-ai-lab.ai-agentic-context.terminal.v1
           session: (string-copy session-id) attempt: (string-copy (.ref attempt-value 'identity))
           generation: (.ref attempt-value 'generation) request: (string-copy (.ref attempt-value 'request))
           input-digest: (string-copy (.ref (.ref attempt-value 'input) 'digest))
           source-generation: (native-worker-source-generation worker)
           query-lineage: (native-worker-query worker)
           proof-binding: (native-worker-proof-digest worker)
           proof-registration: (native-worker-registration worker)
           proof-digest: (native-worker-original-proof worker)
           applicability-digest: (and applicability (string-copy (.ref applicability 'semantic-digest)))
           proof-state-generation: (and applicability (.ref applicability 'state-generation))
           proof-state-digest: (and applicability (string-copy (.ref applicability 'current-state-digest)))
           support-guard: (and applicability (string-copy (.ref (.ref applicability 'guard) 'semantic-digest)))
           support-evaluation: (and applicability (string-copy (.ref (.ref (.ref applicability 'guard) 'evaluation) 'semantic-digest)))
           support-program: (and applicability (string-copy (.ref (.ref (.ref applicability 'guard) 'evaluation) 'program-digest)))
           journal-cut: (and applicability (string-copy (.ref (.ref (.ref applicability 'guard) 'evaluation) 'cut-digest)))
           journal-projection: (and applicability (string-copy (.ref (.ref (.ref applicability 'guard) 'evaluation) 'projection-digest)))
           policy-digest: (and applicability (string-copy (.ref (.ref applicability 'guard) 'policy-digest)))
           grant-id: (string-copy (source-entry-grant-id row)) grant-generation: (source-entry-grant-generation row)
           purpose: 'display destination: (string-copy (.ref (source-entry-scope row) 'destination))
           propagation-event: (let (p (owner-publication-propagation (source-entry-publication row)))
                                (and p (string-copy (.ref p 'event))))
           revision: (.ref schedule 'revision) outcome: outcome-value
           payload: (string-copy (native-observation-payload observation))))
         ;; Force and copy the closed POO schema before the state pointer changes.
         (terminal-snapshot (copy-value terminal-value))
         (publication (make-owner-publication schedule
                        (cons terminal-value (owner-publication-terminals (source-entry-publication row)))
                        (owner-publication-propagation (source-entry-publication row)))))
    ;; Everything above is checked/allocated before the one-pointer owner CAS.
    ;; No caller callback, foreign I/O, yield or receipt resolver follows the guard.
    (set! (source-entry-publication row) publication)
    (.o (:: @ (view row #t outcome-value #t)) terminal: terminal-snapshot
        native-result-published?: (eq? outcome-value 'completed))))
(def (agentic-ai-lab-ai-agentic-context-session-host-commit-result! host session-id revision generation observation-token)
  (let* ((runtime-value (state host)) (row (entry runtime-value session-id))
         (observation (observation-for runtime-value observation-token session-id))
         (worker (native-observation-worker observation)))
    (if (not (owner-match row revision generation)) (view row #f 'stale-revision #f)
      (let ((observed (agentic-ai-lab-ai-agentic-context-session-host-revalidate! host session-id revision generation)))
        (if (not (.ref observed 'accepted?)) observed
          (if (not (and (= generation (native-worker-source-generation worker))
                        (equal? (binding-digest runtime-value session-id) (native-worker-proof-digest worker))
                        (eq? (native-worker-mode worker) 'running)))
            (view row #f 'stale-worker-input #f)
            (let* ((proposal (agentic-ai-lab-session-complete (source-entry-schedule row) revision
                                (native-worker-attempt worker)))
                   (binding (hash-get (session-owner-state-proofs runtime-value) session-id))
                   (applicability (and binding (current-proof binding))))
              (cond ((not (.ref proposal 'accepted?)) (view row #f (.ref proposal 'reason) #f))
                    ;; Commit is in this serialized owner, including proof/grant owners.
                    ((not (and (owner-match row revision generation)
                               (or (not binding) (.ref applicability 'current?))
                               (observe-grant runtime-value row) (bound-parents-current? runtime-value session-id)))
                     (view row #f 'commit-fence-changed #f))
                    (else (terminal-publication! runtime-value row session-id observation proposal 'completed applicability))))))))))
(def (recover-owner! host session-id revision generation mode)
  (let* ((runtime-value (state host)) (row (entry runtime-value session-id)))
    (if (not (owner-match row revision generation)) (view row #f 'stale-revision #f)
      (let* ((schedule (source-entry-schedule row))
             (active (or (.ref schedule 'active)
                       (and (pair? (.ref schedule 'obligations)) (car (.ref schedule 'obligations)))))
             (proposal (agentic-ai-lab-session-recover (source-entry-schedule row) revision)))
        (if (or (not (.ref proposal 'accepted?)) (and (eq? mode 'cancelled) (not active)))
          (view row #f (if (.ref proposal 'accepted?) 'no-active-attempt (.ref proposal 'reason)) #f)
          (begin
            (publish-schedule! row (.ref proposal 'schedule))
            (for-each (lambda (worker)
              (when (and active (equal? session-id (native-worker-session worker))
                         (equal? (.ref active 'identity) (.ref (native-worker-attempt worker) 'identity)))
                (unless (eq? (native-worker-mode worker) 'cancelled)
                  (set! (native-worker-mode worker) mode))
                (when (eq? mode 'cancelled)
                  ;; Failure to deliver leaves the already-published obligation.
                  (with-catch (lambda (exception) #f)
                    (lambda () (thread-send (native-worker-thread worker) 'cancel))))))
              (hash-values (session-owner-state-workers runtime-value)))
            (view row #t (if (eq? mode 'cancelled) 'cancellation-requested 'recovery-published) #t)))))))
(def (agentic-ai-lab-ai-agentic-context-session-host-cancel! host session-id revision generation)
  (recover-owner! host session-id revision generation 'cancelled))
(def (agentic-ai-lab-ai-agentic-context-session-host-recover! host session-id revision generation)
  (recover-owner! host session-id revision generation 'reconciled))
(def (agentic-ai-lab-ai-agentic-context-session-host-reconcile! host session-id revision generation observation-token)
  (let* ((runtime-value (state host)) (row (entry runtime-value session-id))
         (observation (observation-for runtime-value observation-token session-id))
         (worker (native-observation-worker observation)))
    (if (not (owner-match row revision generation)) (view row #f 'stale-revision #f)
      (let (proposal (agentic-ai-lab-session-reconcile (source-entry-schedule row) revision (native-worker-attempt worker)))
        (if (not (.ref proposal 'accepted?)) (view row #f (.ref proposal 'reason) #f)
          ;; Cleanup can resolve revoked inputs, but cannot admit their result.
          (terminal-publication! runtime-value row session-id observation proposal
            (if (eq? (native-worker-mode worker) 'cancelled) 'cancelled 'reconciled) #f))))))
(def (agentic-ai-lab-ai-agentic-context-session-host-close! host session-id revision generation)
  (let* ((runtime-value (state host)) (row (entry runtime-value session-id)))
    (if (not (owner-match row revision generation)) (view row #f 'stale-revision #f)
      (let (proposal (agentic-ai-lab-session-close (source-entry-schedule row) revision))
        (if (not (.ref proposal 'accepted?)) (view row #f (.ref proposal 'reason) #f)
          (begin (publish-schedule! row (.ref proposal 'schedule)) (view row #t 'closed #t)))))))
(def (agentic-ai-lab-ai-agentic-context-session-host-outcomes host session-id)
  (let* ((runtime-value (state host)) (row (entry runtime-value session-id))
         (terminals (owner-publication-terminals (source-entry-publication row)))
         ;; Cleanup/history without a completed result has no current-use grant.
         ;; Only completed results need current proof/support/grant evaluation.
         (eligible (and (not (row-invalidated? row)) (find (lambda (terminal) (eq? (.ref terminal 'outcome) 'completed)) terminals)
                    (not (eq? (.ref (source-entry-schedule row) 'status) 'closed))
                    (source-entry-task row) (query-current? (source-entry-query row))
                    (observe-proof runtime-value row session-id) (observe-grant runtime-value row)
                    (bound-parents-current? runtime-value session-id))))
    (map (lambda (terminal)
      (.o (:: @ (copy-value terminal))
        current-use?: (and eligible (eq? (.ref terminal 'outcome) 'completed)
          (= (source-entry-generation row) (.ref terminal 'source-generation))
          (equal? (binding-digest runtime-value session-id) (.ref terminal 'proof-binding)))))
      (reverse terminals))))

;;; Source-driven Context invalidation. Query/commit guards remain independent
;;; defenses; delivery mutates the cached Context and Session schedule eagerly.
(def (row-invalidated? row)
  (let (p (owner-publication-propagation (source-entry-publication row)))
    (and p (.ref p 'invalidated?))))
(def (parent-list-current? s parents)
  (def (valid? parent)
    (let* ((id (context-parent-session parent)) (row (entry s id))
           (captured (context-parent-binding parent))
           (live (hash-get (session-owner-state-proofs s) id)))
      (and (not (and live (equal? (proof-binding-digest live) (proof-binding-digest captured))
                       (row-invalidated? row)))
           (with-catch (lambda (exception) #f) (lambda () (.ref (current-proof captured) 'current?)))
           (captured-authority-current? s (proof-binding-authority captured))
           (query-current? (proof-binding-query captured))
           (every valid? (context-parent-parents parent)))))
  (every valid? parents))
(def (bound-parents-current? s session-id)
  (let (binding (hash-get (session-owner-state-proofs s) session-id))
    (parent-list-current? s (if binding (proof-binding-parents binding)
      (or (hash-get (session-owner-state-parents s) session-id) '())))))
(def (parents-current? s session-id)
  (parent-list-current? s (or (hash-get (session-owner-state-parents s) session-id) '())))
(def (agentic-ai-lab-ai-agentic-context-session-host-depend-on! host session-id revision generation parents)
  (let* ((s (state host)) (row (entry s session-id)) (schedule (source-entry-schedule row)))
    (unless (and (owner-match row revision generation) (eq? (.ref schedule 'status) 'idle)
                 (list? parents) (<= (length parents) 128) (every text? parents)
                 (not (member session-id parents))
                 (= (length parents) (length (delete-duplicates/hash parents))))
      (error "Context dependency declaration requires an exact idle owner"))
    (let (captured (map (lambda (parent)
                     (entry s parent)
                     (let (binding (hash-get (session-owner-state-proofs s) parent))
                       (unless binding (error "Context dependency requires a registered original proof"))
                       (make-context-parent (string-copy parent) binding (proof-binding-parents binding)))) parents))
      (unless (parent-list-current? s captured) (error "Context dependency is not currently admitted"))
      ;; This stages exact immutable version references for the NEXT admission.
      ;; An existing current binding keeps its original parents until re-admitted.
      (hash-put! (session-owner-state-parents s) (string-copy session-id) captured)
      (view row #t (if (hash-get (session-owner-state-proofs s) session-id)
                    'dependencies-staged 'dependencies-enrolled) #f))))
(def (agentic-ai-lab-ai-agentic-context-session-host-enable-propagation! host)
  (let ((s (state host)) (seen (make-hash-table-eq)))
    (def (visit binding)
      (unless (hash-get seen binding)
        (hash-put! seen binding #t)
        (ensure-source-observer! host (proof-binding-host binding))
        (let-values (((policy-owner policy-id) (agentic-ai-lab-temporal-proof-host-policy
                       (proof-binding-host binding) (proof-binding-registration binding))))
          (ensure-policy-observer! host policy-owner))
        ;; Retired parent heads can still be required by current descendants.
        (for-each (lambda (parent) (visit (context-parent-binding parent))) (proof-binding-parents binding))))
    (ensure-authority-observers! host)
    (for-each (lambda (row)
      (when (source-entry-query row)
        (ensure-query-observer! host (query-binding-owner (source-entry-query row)))))
      (hash-values (session-owner-state-entries s)))
    (for-each visit (hash-values (session-owner-state-proofs s)))
    (set! (session-owner-state-propagation-enabled? s) #t) #t))
(def (ensure-source-observer! host proof-host)
  (let (s (state host))
    (unless (hash-get (session-owner-state-watchers s) proof-host)
      (let (observer (.o kind: 'temporal.source-observer.v1
               .prepare: (lambda (self event) (prepare-propagation host proof-host event))))
        (agentic-ai-lab-temporal-proof-host-watch! proof-host observer)
        (hash-put! (session-owner-state-watchers s) proof-host observer)))))
(def (prepare-propagation host proof-host event)
  (let* ((s (state host)) (ids (list-sort string<? (hash-keys (session-owner-state-entries s))))
         (event-proofs (.ref event 'proof-identities))
         (old-cut (.ref event 'previous-cut)) (new-cut (.ref event 'revised-cut))
         (projection (.ref event 'previous-program)) (event-id (.ref event 'semantic-digest))
         (versions (make-hash-table)) (nodes '()) (bindings '()) (seen-bindings (make-hash-table-eq)))
    (unless (and (eq? (.ref event 'kind) 'temporal.source-change.v1) (.ref event 'inventory-complete?))
      (error "Context propagation requires complete selected support inventory"))
    (def (related? binding)
      (and (eq? proof-host (proof-binding-host binding))
           (member (proof-binding-registration binding) event-proofs)))
    (def (version! binding parents)
      (let (id (string-append "version:" (proof-binding-digest binding)))
        (unless (hash-get versions id)
          (hash-put! versions id #t)
          (let (parent-ids (map (lambda (parent) (version! (context-parent-binding parent) (context-parent-parents parent))) parents))
            (set! nodes (cons (agentic-ai-lab-temporal-derivation id old-cut projection "context"
              (if (related? binding) (list (proof-binding-registration binding)) '()) parent-ids) nodes)))
          (when (and (related? binding) (not (hash-get seen-bindings binding)))
            (hash-put! seen-bindings binding #t) (set! bindings (cons binding bindings)))) id))
    (def (consumer-id id) (string-append "consumer:" id))
    (for-each (lambda (id)
      (let* ((binding (hash-get (session-owner-state-proofs s) id))
             (parents (if binding (proof-binding-parents binding)
                        (or (hash-get (session-owner-state-parents s) id) '())))
             (dependencies (if binding (list (version! binding parents))
               (map (lambda (parent) (version! (context-parent-binding parent) (context-parent-parents parent))) parents))))
        (set! nodes (cons (agentic-ai-lab-temporal-derivation (consumer-id id) old-cut projection "context" '() dependencies) nodes)))) ids)
    (let* ((index (agentic-ai-lab-temporal-dependency-index "context-versions-and-consumers" old-cut projection #t nodes))
           (stale (map proof-binding-registration (filter (lambda (b)
                    (not (= (.ref event 'previous-generation) (proof-binding-state-generation b)))) bindings)))
           (roots (delete-duplicates/hash (append (.ref event 'affected-proofs) stale)))
           ;; Event identity is the revised ROUTING projection, not a replacement
           ;; program digest. This also routes a generation-only owner advance.
           (plan (agentic-ai-lab-temporal-reverse-dependency-plan index new-cut event-id roots))
           (all-plan (agentic-ai-lab-temporal-reverse-dependency-plan index new-cut event-id event-proofs))
           (affected (filter (lambda (id) (member (consumer-id id) (.ref plan 'affected-conclusion-identities))) ids))
           (related (filter (lambda (id) (member (consumer-id id) (.ref all-plan 'affected-conclusion-identities))) ids)))
      (when (> (+ (length (session-owner-state-propagation-log s)) (length related)) 128)
        (error "Context propagation receipt capacity"))
      (.o kind: 'temporal.source-propagation-batch.v1
        .publish!: (lambda (self) (publish-propagation! host event related affected (.ref index 'semantic-digest) bindings))))))
(def (publish-propagation! host event-value related affected index-digest bindings)
  (let* ((s (state host)) (event-id (.ref event-value 'semantic-digest))
         (ids (list-sort string<? (delete-duplicates/hash (append related affected))))
         (plans (map (lambda (id)
            (let* ((row (entry s id)) (old (source-entry-publication row))
                   (previous (owner-publication-propagation old))
                   (schedule (owner-publication-schedule old))
                   (hit? (if (member id affected) #t #f))
                   (same? (and previous (equal? (.ref previous 'event) event-id)))
                   (proposal (and hit? (not same?) (.ref schedule 'active)
                               (agentic-ai-lab-session-recover schedule (.ref schedule 'revision))))
                   (next (if proposal (.ref proposal 'schedule) schedule)))
              (when (and proposal (not (.ref proposal 'accepted?))) (error "Propagation fencing exhausted"))
              (let* ((receipt (.o kind: 'agentic-ai-lab.ai-agentic-context.propagation.v1
                        event: (string-copy event-id) source: (string-copy (.ref event-value 'source))
                        previous-cut: (string-copy (.ref event-value 'previous-cut)) revised-cut: (string-copy (.ref event-value 'revised-cut))
                        previous-program: (string-copy (.ref event-value 'previous-program)) revised-program: (string-copy (.ref event-value 'revised-program))
                        generation: (.ref event-value 'generation) changed-subjects: (map string-copy (.ref event-value 'changed-subjects))
                        proof-index: (string-copy (.ref event-value 'index-digest)) context-index: (string-copy index-digest)
                        affected-contexts: (map string-copy affected) affected?: hit?
                        invalidated?: (if (or hit? (row-invalidated? row)) #t #f)
                        previous-revision: (.ref schedule 'revision) revision: (.ref next 'revision)))
                     (owned (copy-value (if same? previous receipt)))
                     (publication (if same? old (make-owner-publication next (owner-publication-terminals old) owned))))
                (list row publication id #f owned)))) ids)))
    ;; Compute every row first. Retries rebase on actual cancellation/recovery /
    ;; cleanup state; they never overwrite a newer terminal or restore old allow.
    (for-each (lambda (plan)
      (set! (source-entry-publication (car plan)) (cadr plan))) plans)
    (for-each (lambda (binding) (set! (proof-binding-state-generation binding) (.ref event-value 'generation))) bindings)
    (unless (find (lambda (receipt) (equal? (.ref receipt 'event) event-id)) (session-owner-state-propagation-log s))
      (set! (session-owner-state-propagation-log s)
        (append (map (lambda (plan) (list-ref plan 4)) plans) (session-owner-state-propagation-log s))))
    #t))
(def (agentic-ai-lab-ai-agentic-context-session-host-propagations host)
  (map copy-value (reverse (session-owner-state-propagation-log (state host)))))

;;; Exact authority dependencies belong to an admitted Context VERSION.
(def (capture-authority s id generation)
  (let (grant-value (agentic-ai-lab-context-use-host-current (session-owner-state-grants s) id))
    (unless (= generation (.ref grant-value 'generation)) (error "Stale grant at admission"))
    (map (lambda (v) (if (string? v) (string-copy v) v))
      (list id generation (.ref grant-value 'policy-identity) (.ref grant-value 'policy-digest)))))
(def (captured-authority-current? s captured)
  (with-catch (lambda (exception) #f)
    (lambda () (eq? (.ref (agentic-ai-lab-context-use-host-observe (session-owner-state-grants s)
      (session-owner-state-policies s) (car captured) (cadr captured) 'display) 'decision) 'allowed))))
(def (ensure-authority-observers! host)
  (let* ((s (state host)) (owner (session-owner-state-grants s)))
    (unless (hash-get (session-owner-state-watchers s) owner)
      (let (observer (.o kind: 'temporal.source-observer.v1
          .prepare: (lambda (self event) (prepare-authority-propagation host owner event))))
        (agentic-ai-lab-context-use-host-watch! owner observer)
        (hash-put! (session-owner-state-watchers s) owner observer)))
    (ensure-policy-observer! host (session-owner-state-policies s))))
(def (ensure-policy-observer! host owner)
  (let (s (state host))
    (unless (hash-get (session-owner-state-watchers s) owner)
      (let (observer (.o kind: 'temporal.source-observer.v1
          .prepare: (lambda (self event) (prepare-authority-propagation host owner event))))
        (agentic-ai-lab-temporal-support-policy-host-watch! owner observer)
        (hash-put! (session-owner-state-watchers s) owner observer)))))
(def (prepare-authority-propagation host authority-owner event-value)
  (let* ((s (state host)) (ids (list-sort string<? (hash-keys (session-owner-state-entries s))))
         (old-cut (.ref event-value 'previous-cut)) (projection (.ref event-value 'previous-program))
         (kind-value (.ref event-value 'authority-kind)) (identity-value (.ref event-value 'identity))
         (revised (.ref event-value 'revised)) (versions (make-hash-table)) (nodes '()))
    (unless (eq? (.ref event-value 'kind) 'temporal.authority-change.v1) (error "Invalid authority event"))
    (def (use-hit? captured)
      (case kind-value
        ((grant) (and (eq? authority-owner (session-owner-state-grants s))
                      (equal? identity-value (car captured))
                      (not (= (cadr captured) (.ref revised 'generation)))))
        ((policy) (and (eq? authority-owner (session-owner-state-policies s))
                       (equal? identity-value (list-ref captured 2))
                       (not (eq? (agentic-ai-lab-temporal-support-policy-status
                         (.ref revised 'policy) (list-ref captured 3) (.ref revised 'effective-at)) 'applicable))))
        (else (error "Unknown authority event kind"))))
    (def (proof-hit? binding)
      (and (eq? kind-value 'policy)
        (let-values (((policy-owner policy-id) (agentic-ai-lab-temporal-proof-host-policy
                       (proof-binding-host binding) (proof-binding-registration binding))))
          (and (eq? policy-owner authority-owner) (equal? policy-id identity-value)
               (not (= (proof-binding-policy-generation binding) (.ref revised 'generation)))))))
    (def (version! binding)
      (let (id (string-append "version:" (proof-binding-digest binding)))
        (unless (hash-get versions id)
          (hash-put! versions id #t)
          (let ((parents (map (lambda (p) (version! (context-parent-binding p))) (proof-binding-parents binding)))
                (hit? (or (use-hit? (proof-binding-authority binding)) (proof-hit? binding))))
            (set! nodes (cons (agentic-ai-lab-temporal-derivation id old-cut projection "authority"
              (if hit? '("authority-root") '()) parents) nodes)))) id))
    (for-each (lambda (id)
      (let* ((row (entry s id)) (binding (hash-get (session-owner-state-proofs s) id))
             (parents (if binding (list (version! binding))
               (map (lambda (p) (version! (context-parent-binding p)))
                 (or (hash-get (session-owner-state-parents s) id) '())))))
        (set! nodes (cons (agentic-ai-lab-temporal-derivation (string-append "consumer:" id) old-cut projection
          "authority" (if (use-hit? (source-entry-authority row)) '("authority-root") '()) parents) nodes)))) ids)
    (let* ((index (agentic-ai-lab-temporal-dependency-index "authority-context-versions" old-cut projection #t nodes))
           (plan (agentic-ai-lab-temporal-reverse-dependency-plan index (.ref event-value 'revised-cut)
                   (.ref event-value 'semantic-digest) '("authority-root")))
           (affected (filter (lambda (id) (member (string-append "consumer:" id)
                        (.ref plan 'affected-conclusion-identities))) ids))
           (related (if (pair? affected) ids '())))
      (when (> (+ (length related) (length (session-owner-state-propagation-log s))) 128)
        (error "Context authority receipt capacity"))
      (.o kind: 'temporal.source-propagation-batch.v1
          .publish!: (lambda (self)
            (publish-propagation! host event-value related affected (.ref index 'semantic-digest) '()))))))

;;; Trusted recovery projection. No worker/observation capability is serialized.
(def (context-observation-evidence host sid token)
  (let* ((s (state host)) (o (observation-for s token sid)) (w (native-observation-worker o)))
    (.o kind: 'context.native-observation-evidence.v1 session: (string-copy sid)
      attempt: (copy-value (native-worker-attempt w)) payload: (string-copy (native-observation-payload o))
      proof: (native-worker-original-proof w) binding: (native-worker-proof-digest w))))
(def (context-host-checkpoint host)
  (let (s (state host))
    (def (binding b)
      (and b (let ((registration-value (proof-binding-registration b))
                   (source-generation-value (proof-binding-source-generation b))
                   (state-generation-value (proof-binding-state-generation b))
                   (policy-generation-value (proof-binding-policy-generation b))
                   (policy-digest-value (proof-binding-policy-digest b)) (budget-value (proof-binding-budget b))
                   (digest-value (proof-binding-digest b)) (authority-value (proof-binding-authority b))
                   (parents-value (map parent (proof-binding-parents b))) (admission-value (proof-binding-admission b))
                   (source-snapshot-value (agentic-ai-lab-temporal-proof-host-source-snapshot (proof-binding-host b) (proof-binding-registration b)))
                   (original-value (agentic-ai-lab-temporal-proof-host-retained-digest (proof-binding-host b) (proof-binding-registration b))))
        (.o registration: registration-value source-generation: source-generation-value state-generation: state-generation-value
          policy-generation: policy-generation-value policy-digest: policy-digest-value budget: budget-value digest: digest-value
          authority: authority-value parents: parents-value original-proof: original-value admission: admission-value source-snapshot: source-snapshot-value
          query: (export-query (proof-binding-query b))))))
    (def (parent p)
      (let ((sid (context-parent-session p)) (bound (binding (context-parent-binding p))))
        (.o session: sid binding: bound)))
    (let ((rows (map (lambda (id)
      (let* ((r (entry s id)) (b (hash-get (session-owner-state-proofs s) id))
             (id-value id) (generation-value (source-entry-generation r)) (source-value (source-entry-source r))
             (scope-value (source-entry-scope r)) (restriction-value (source-entry-restriction r))
             (memory-value (if (memq 'ai-agentic-context/memory (.ref (source-entry-projection r) 'feature-ids)) #t #f))
             (task-revision-value (source-entry-task-revision r)) (ids-value (source-entry-ids r))
             (grant-value (source-entry-grant-id r)) (grant-generation-value (source-entry-grant-generation r))
             (authority-value (source-entry-authority r)) (binding-value (binding b))
             (parents-value (map parent (or (hash-get (session-owner-state-parents s) id) '())))
             (task-value (copy-value (source-entry-task r))) (schedule-value (copy-value (source-entry-schedule r)))
             (terminals-value (map copy-value (owner-publication-terminals (source-entry-publication r))))
             (propagation-value (copy-value (owner-publication-propagation (source-entry-publication r)))))
        (.o identity: id-value generation: generation-value source: source-value scope: scope-value restriction: restriction-value
          memory?: memory-value task-revision: task-revision-value ids: ids-value grant: grant-value grant-generation: grant-generation-value
          authority: authority-value binding: binding-value parents: parents-value task: task-value schedule: schedule-value
          terminals: terminals-value propagation: propagation-value
          query: (export-query (source-entry-query r)))))
      (list-sort string<? (hash-keys (session-owner-state-entries s)))))
      (log-value (session-owner-state-propagation-log s)))
      (.o kind: 'context.owner-checkpoint.v1 entries: rows propagation-log: log-value))))
(def (context-host-restore! host checkpoint resolver (query-provider #f))
  (let* ((s (state host)) (versions (make-hash-table)) (rows (make-hash-table)))
    (unless (and (eq? (.ref checkpoint 'kind) 'context.owner-checkpoint.v1)
                 (<= (length (.ref checkpoint 'entries)) 128)) (error "Invalid Context checkpoint"))
    (define restored-query-owners (make-hash-table))
    (def (restore-query saved)
      (and saved
        (let* ((key (agentic-ai-lab-ai-agentic-context-digest
                     (map (lambda (cut) (.ref cut 'semantic-digest)) (.ref saved 'history))))
               (known (or query-provider (hash-get restored-query-owners key))))
          (let-values (((provider observed) (context-query-restore saved known)))
            ;; A catalog root is not a consumer's Query observation. Restoring
            ;; sources alone must never manufacture an admitted Context binding.
            (unless observed (error "Context consumer requires a Query observation"))
            (hash-put! restored-query-owners key provider)
            (make-query-binding provider observed)))))
    (def (binding value)
      (and value
        (or (hash-get versions (.ref value 'digest))
          (let* ((proof (resolver (.ref value 'registration)))
                 (original (agentic-ai-lab-temporal-proof-host-retained-digest proof (.ref value 'registration)))
                 (saved-source (.ref value 'source-snapshot))
                 (_ (agentic-ai-lab-temporal-proof-host-refresh! proof (.ref saved-source 'identity) (.ref saved-source 'generation)
                      (.ref saved-source 'program) (.ref saved-source 'journal)))
                 (parents (map parent (.ref value 'parents)))
                 (b (make-proof-binding proof (.ref value 'registration) (.ref value 'state-generation)
                    (.ref value 'policy-generation) (.ref value 'policy-digest) (.ref value 'budget)
                    (.ref value 'source-generation) (.ref value 'digest) parents (.ref value 'authority) (.ref value 'admission)
                    (restore-query (and (.slot? value 'query) (.ref value 'query))))))
            (unless (equal? original (.ref value 'original-proof)) (error "Recovered original proof mismatch"))
            (hash-put! versions (.ref value 'digest) b) b))))
    (def (parent p)
      (let (b (binding (.ref p 'binding)))
        (make-context-parent (.ref p 'session) b (proof-binding-parents b))))
    (for-each (lambda (value)
      (let* ((b (binding (.ref value 'binding)))
             (qb (restore-query (and (.slot? value 'query) (.ref value 'query))))
             (schedule (.ref value 'schedule))
             ;; Owner death alone is no terminal/isolation evidence.
             (recovered (if (.ref schedule 'active)
               (.ref (agentic-ai-lab-session-recover schedule (.ref schedule 'revision)) 'schedule) schedule)))
        (let-values (((projection task) (build-task (.ref value 'source) (.ref value 'scope) (.ref value 'restriction)
          (agentic-ai-lab-ai-agentic-context-profile (.ref value 'memory?)) (.ref value 'task-revision) (.ref value 'ids)
          (.ref value 'grant) (.ref value 'grant-generation) (and b (proof-binding-digest b)) qb)))
          (unless (equal? (.ref (.ref task 'input) 'digest) (.ref (.ref (.ref value 'task) 'input) 'digest))
            (error "Recovered Context source/input mismatch"))
          (hash-put! rows (.ref value 'identity)
            (make-source-entry (.ref value 'generation) (.ref value 'source) (.ref value 'scope) (.ref value 'restriction)
              (agentic-ai-lab-ai-agentic-context-profile (.ref value 'memory?)) (.ref value 'task-revision) (.ref value 'ids)
              projection task (make-owner-publication recovered (.ref value 'terminals) (.ref value 'propagation))
              (.ref value 'grant) (.ref value 'grant-generation) (.ref value 'authority) qb))
          (when b (hash-put! (session-owner-state-proofs s) (.ref value 'identity) b))
          (hash-put! (session-owner-state-parents s) (.ref value 'identity) (map parent (.ref value 'parents))))))
      (.ref checkpoint 'entries))
    (set! (session-owner-state-entries s) rows)
    (set! (session-owner-state-workers s) (make-hash-table-eq))
    (set! (session-owner-state-observations s) (make-hash-table-eq))
    (set! (session-owner-state-propagation-log s) (.ref checkpoint 'propagation-log))
    (agentic-ai-lab-ai-agentic-context-session-host-enable-propagation! host)))

;;; The Session input records this Provider's actual GQL and lineage digest.
;;; Session remains a pure consumer of an admitted input reference; it never
;;; parses Org, runs a Query or owns the Provider's source catalog.
(def (bind-query-task task binding)
  (let* ((observed (query-binding-observation binding))
         (lineage (context-query-lineage observed))
         (base-input (.ref task 'input))
         (query-digest-value (.ref lineage 'query-digest))
         (identity-value
           (agentic-ai-lab-ai-agentic-context-digest
             (list 'query-context-input-v1
                   (.ref base-input 'identity)
                   (.ref lineage 'semantic-digest))))
         (digest-value
           (agentic-ai-lab-ai-agentic-context-digest
             (list 'query-session-input-v1
                   "org-query-projection-v1"
                   (.ref base-input 'digest)
                   identity-value
                   query-digest-value)))
         (input-value
           (.o (:: @ base-input)
               identity: identity-value
               contract: "org-query-projection-v1"
               digest: digest-value
               query-digest: query-digest-value)))
    (.o (:: @ task) input: input-value)))

(def (query-current? binding)
  (or (not binding)
      (context-query-current?
        (query-binding-owner binding)
        (query-binding-observation binding))))

(def (export-query binding)
  (and binding
       (context-query-export
         (query-binding-owner binding)
         (query-binding-observation binding))))

;;; This initial Provider profile has one catalog owner per Context coordinator.
;;; Source identities are qualified within that catalog. Silently merging two
;;; independently mutable catalogs with equal labels would lose dependency edges.
(def (context-host-query-provider host)
  (let (provider-value #f)
    (for-each
     (lambda (row)
       (let (binding (source-entry-query row))
         (when binding
           (let (candidate (query-binding-owner binding))
             (when (and provider-value (not (eq? candidate provider-value)))
               (error "Context coordinator contains different Query owners"))
             (set! provider-value candidate)))))
     (hash-values (session-owner-state-entries (state host))))
    provider-value))

(def (check-query-owner! runtime-value provider)
  (for-each
    (lambda (row)
      (let (q (source-entry-query row))
        (when (and q (not (eq? provider (query-binding-owner q))))
          (error "Context Query catalog owner cannot be silently replaced"))))
    (hash-values (session-owner-state-entries runtime-value))))

(def (install-query-task! host row provider observed)
  (let* ((s (state host))
         (binding (make-query-binding provider observed)))
    (let-values (((projection task)
                  (build-task
                    (source-entry-source row)
                    (source-entry-scope row)
                    (source-entry-restriction row)
                    (source-entry-profile row)
                    (source-entry-task-revision row)
                    (source-entry-ids row)
                    (source-entry-grant-id row)
                    (source-entry-grant-generation row)
                    #f
                    binding)))
      ;; Register the mandatory source feed before publishing the new input.
      (when (session-owner-state-propagation-enabled? s)
        (ensure-query-observer! host provider))
      (set! (source-entry-query row) binding)
      (set! (source-entry-projection row) projection)
      (set! (source-entry-task row) task))))

(def (context-host-enroll-query! host provider source-id query scope restriction
                                profile task-revision grant-id grant-generation)
  (let* ((s (state host))
         (scope-value (agentic-ai-lab-ai-agentic-context-scope-admit scope))
         (session-id (.ref scope-value 'session)))
    (check-query-owner! s provider)
    (unless (and (text? session-id) (text? grant-id)
                 (coordinate? grant-generation) (> grant-generation 0)
                 (not (hash-get (session-owner-state-entries s) session-id))
                 (< (hash-length (session-owner-state-entries s)) 128))
      (error "Invalid Query consumer enrollment"))
    ;; Source bytes are supplied by an admitted in-memory catalog, never opened
    ;; by this adapter. Consumer authority is checked before Query evaluation.
    (let* ((grant-view
             (agentic-ai-lab-context-use-host-observe
               (session-owner-state-grants s) (session-owner-state-policies s)
               grant-id grant-generation 'display))
           (contract (.ref (.ref grant-view 'grant) 'contract)))
      (unless (and (eq? (.ref grant-view 'decision) 'allowed)
                   (equal? (.ref contract 'actor) (.ref scope-value 'actor))
                   (equal? (.ref contract 'task) (.ref scope-value 'task)))
        (error "Query consumer requires current matching authority")))
    (let* ((observed (context-query-execute provider source-id query))
           (cut (.ref observed 'source-cut))
           (ids (.ref (context-query-lineage observed) 'org-ids))
           (binding (make-query-binding provider observed)))
      (unless (and (pair? ids) (query-current? binding))
        (error "Query requires a current nonempty Context selection"))
      (when (.ref cut 'session-identity)
        (unless (equal? (.ref cut 'session-identity) session-id)
          (error "Consumer Org Contract belongs to another Session")))
      (let-values (((projection task)
                    (build-task
                      (.ref cut 'source) scope-value restriction profile
                      task-revision ids grant-id grant-generation #f binding)))
        (let (row
                (make-source-entry
                  (.ref cut 'generation) (.ref cut 'source) scope-value
                  (.ref projection 'restriction) profile task-revision ids
                  projection task
                  (make-owner-publication (agentic-ai-lab-session-schedule session-id) '() #f)
                  (string-copy grant-id) grant-generation
                  (capture-authority s grant-id grant-generation) binding))
          (unless (observe-grant s row)
            (error "Query Context flow restriction denied"))
          ;; Every Task/anchor and subscriber is prepared before the sole row
          ;; publication. A subscription failure cannot leave a legacy unbound
          ;; input behind, even when the caller disabled the domain-proof gate.
          (when (session-owner-state-propagation-enabled? s)
            (ensure-query-observer! host provider)
            (ensure-authority-observers! host))
          (hash-put! (session-owner-state-entries s) session-id row)
          (view row #t 'query-enrolled #t))))))

;;; Re-admission updates Context input within the existing independent Session.
;;; Pending workers must first be reconciled; re-querying is not termination
;;; evidence and cannot erase an old Attempt obligation.
(def (context-host-refresh-query! host session-id revision generation query)
  (let* ((s (state host))
         (old (entry s session-id))
         (q (source-entry-query old))
         (schedule (source-entry-schedule old)))
    (unless (and q (owner-match old revision generation)
                 (eq? (.ref schedule 'status) 'idle)
                 (null? (.ref schedule 'obligations)))
      (error "Query re-admission requires a current idle Session"))
    (let* ((provider (query-binding-owner q))
           (source-id (.ref (.ref (query-binding-observation q) 'source-cut) 'identity))
           (observed (context-query-execute provider source-id query))
           (cut (.ref observed 'source-cut))
           (ids (.ref (context-query-lineage observed) 'org-ids)))
      (when (.ref cut 'session-identity)
        (unless (equal? (.ref cut 'session-identity)
                       (.ref (source-entry-scope old) 'session))
          (error "Consumer Org Contract cannot change Session during re-admission")))
      (unless (and (> (.ref cut 'generation) generation) (pair? ids))
        (error "Query re-admission requires a new source version and selected IDs"))
      (let (row
              (make-source-entry
                (.ref cut 'generation) (.ref cut 'source)
                (source-entry-scope old) (source-entry-restriction old)
                (source-entry-profile old) (source-entry-task-revision old)
                ids #f #f
                (make-owner-publication schedule
                  (owner-publication-terminals (source-entry-publication old)) #f)
                (source-entry-grant-id old) (source-entry-grant-generation old)
                (source-entry-authority old) #f))
        (install-query-task! host row provider observed)
        (unless (observe-grant s row)
          (error "Query re-admission requires a current grant"))
        (hash-remove! (session-owner-state-proofs s) session-id)
        (hash-put! (session-owner-state-entries s) session-id row)
        (view row #t 'query-readmitted #t)))))

(def (ensure-query-observer! host provider)
  (let (s (state host))
    (unless (hash-get (session-owner-state-watchers s) provider)
      (let (observer
              (.o kind: 'temporal.source-observer.v1
                  .prepare:
                  (lambda (self event)
                    (prepare-query-propagation host provider event))))
        (context-query-watch! provider observer)
        (hash-put! (session-owner-state-watchers s) provider observer)))))

;;; Build the real reverse-dependency inventory over captured Context versions,
;;; not merely over current Session labels. A consumer of a recalled parent
;;; version stays linked to that version even when its own source is different.
(def (prepare-query-propagation host provider event)
  (let* ((s (state host))
         (ids (list-sort string<? (hash-keys (session-owner-state-entries s))))
         (old-cut (.ref event 'previous-cut))
         (projection (.ref event 'previous-program))
         (source-id (.ref event 'identity))
         (versions (make-hash-table))
         (nodes '()))
    (unless (eq? (.ref event 'authority-kind) 'org-source)
      (error "Expected an Org source event"))
    (def (hit? q)
      (and q
           (eq? provider (query-binding-owner q))
           (equal? source-id
             (.ref (.ref (query-binding-observation q) 'source-cut) 'identity))))
    (def (version! binding)
      (let (id (string-append "version:" (proof-binding-digest binding)))
        (unless (hash-get versions id)
          (hash-put! versions id #t)
          (let (parents
                  (map
                    (lambda (p) (version! (context-parent-binding p)))
                    (proof-binding-parents binding)))
            (set! nodes
              (cons
                (agentic-ai-lab-temporal-derivation
                  id old-cut projection "org-query-version"
                  (if (hit? (proof-binding-query binding)) '("org-source-root") '())
                  parents)
                nodes))))
        id))
    (for-each
      (lambda (id)
        (let* ((row (entry s id))
               (binding (hash-get (session-owner-state-proofs s) id))
               (parents
                 (if binding
                   (list (version! binding))
                   (map
                     (lambda (p) (version! (context-parent-binding p)))
                     (or (hash-get (session-owner-state-parents s) id) '())))))
          (set! nodes
            (cons
              (agentic-ai-lab-temporal-derivation
                (string-append "consumer:" id) old-cut projection
                "org-query-consumer"
                (if (hit? (source-entry-query row)) '("org-source-root") '())
                parents)
              nodes))))
      ids)
    (let* ((index
             (agentic-ai-lab-temporal-dependency-index
               "org-query-versions" old-cut projection #t nodes))
           (plan
             (agentic-ai-lab-temporal-reverse-dependency-plan
               index (.ref event 'revised-cut) (.ref event 'semantic-digest)
               '("org-source-root")))
           (affected
             (filter
               (lambda (id)
                 (member (string-append "consumer:" id)
                   (.ref plan 'affected-conclusion-identities)))
               ids)))
      (when (> (+ (length ids) (length (session-owner-state-propagation-log s))) 128)
        (error "Query propagation receipt capacity"))
      (.o kind: 'temporal.source-propagation-batch.v1
          .publish!:
          (lambda (self)
            (publish-propagation!
              host event (if (pair? affected) ids '()) affected
              (.ref index 'semantic-digest) '()))))))
