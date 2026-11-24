;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Step 4 Runtime Convergence Bridge:
;;; Wires FunFlow's declarative `control-plane/runner.ss` directly onto:
;;; 1. Slice 52 `FunflowCasStore.` (thread-safe `lookup-or-wait` singleflight,
;;;    crash-atomic temp-write-then-rename, and `AuditCapsule`-pinned CAS GC).
;;; 2. Real POO Sandbox Profiles (`modules/nono-sandbox/profile-interface.ss`
;;;    / `modules/docker/`) via `sandbox-profile->external-binding` and
;;;    `funflow-admit-external-task-sandbox` (pinning `env-digest` and blocking
;;;    unendorsed Lethal-Trifecta BEFORE invoking any runtime adapter).
;;; 3. EffectClass-gated CAS admission: `PureCAS.` reuses singleflight CAS,
;;;    while `FencedEffect.` (`external`/`store`) NEVER skips on plain CAS hits
;;;    without an explicit idempotency commit receipt.
;;; 4. Capstone 47 deterministic zero-LLM `AuditCapsule` commitment.

(import (only-in :clan/poo/object .def .o .ref .slot? object?)
        (only-in :std/list/list any every filter)
        (only-in "control-plane/flow.ss" flow? flow-name)
        (only-in "control-plane/task.ss" task? task-name task-kind task-request)
        (only-in "control-plane/graph.ss" execution-plan-nodes plan-node-id plan-node-step)
        (only-in "control-plane/runner.ss"
                 runner? runner-plan runner-run run-result-value run-result-receipt)
        (only-in "durable-dag.ss"
                 PureCAS. VerifiedEpistemic. FencedEffect. ExternalSandboxProfile.
                 funflow-canonical-sha256 funflow-admit-external-task-sandbox)
        (only-in "cas-store.ss"
                 funflow-flow->durable-dag make-funflow-cas-store funflow-cas-store?
                 funflow-cas-lookup-or-wait! funflow-cas-pin-capsule!))

(export sandbox-profile->external-binding
        GovernedFunflowRunner.
        make-governed-funflow-runner
        governed-funflow-runner?
        governed-funflow-run
        GovernedFunflowRunnerExports)

(def (opt-ref obj key default)
  (if (and (object? obj) (.slot? obj key))
    (.ref obj key)
    default))

(def (capabilities-allow-egress? caps)
  (and (list? caps)
       (any (lambda (c)
              (memq c '(network-egress egress outbound-network network internet)))
            caps)))

;;; Projects a real POO sandbox profile (e.g. `nono-sandbox-profile` from
;;; `modules/nono-sandbox/profile-interface.ss` or a Docker profile) into
;;; Slice 52's `ExternalSandboxProfile.` admission structure.
(def (sandbox-profile->external-binding
      profile
      env-digest: (env-digest #f)
      has-untrusted-input?: (has-untrusted-input? #f)
      has-private-data?: (has-private-data? #f)
      egress-endorsed?: (egress-endorsed? #f)
      lease-valid?: (lease-valid? #t))
  (let* ((caps (opt-ref profile 'capabilities '()))
         (bk (opt-ref profile 'backend-kind 'unknown))
         (backend-ref (opt-ref profile 'backend-ref #f))
         (resolved-env (or (and (string? env-digest) (> (string-length env-digest) 0) env-digest)
                           (and (string? backend-ref) (> (string-length backend-ref) 0) backend-ref)
                           (and (object? profile) (opt-ref profile 'env-digest #f))
                           ""))
         (egress? (or (and (object? profile) (opt-ref profile 'egress-enabled? #f))
                      (capabilities-allow-egress? caps)))
         (ui? (and has-untrusted-input? #t))
         (pd? (and has-private-data? #t))
         (ee? (and egress-endorsed? #t))
         (lv? (and lease-valid? #t)))
    (.o (:: @ ExternalSandboxProfile.)
        backend-kind: bk
        env-digest: resolved-env
        capabilities: caps
        has-untrusted-input?: ui?
        has-private-data?: pd?
        egress-enabled?: (and egress? #t)
        egress-endorsed?: ee?
        lease-valid?: lv?)))

(.def GovernedFunflowRunner.
  kind: 'agentic-ai-lab.funflow.governed-runner.v1)

(def (make-governed-funflow-runner
      base-runner
      cas-store: (cas-store #f)
      sandbox-profile: (sandbox-profile #f)
      env-digest: (env-digest "")
      source-cut: (source-cut "cut-0")
      premise-gen: (premise-gen 1))
  (unless (runner? base-runner)
    (error "make-governed-funflow-runner expects a FunFlow runner" base-runner))
  (let ((store (or cas-store (make-funflow-cas-store)))
        (br base-runner)
        (sbx sandbox-profile)
        (ed env-digest)
        (sc source-cut)
        (pg premise-gen))
    (unless (funflow-cas-store? store)
      (error "make-governed-funflow-runner expects a FunflowCasStore" store))
    (.o (:: @ GovernedFunflowRunner.)
        kind: 'agentic-ai-lab.funflow.governed-runner.v1
        base-runner: br
        cas-store: store
        sandbox-profile: sbx
        env-digest: ed
        source-cut: sc
        premise-gen: pg)))

(def (governed-funflow-runner? v)
  (and (object? v)
       (.slot? v 'kind)
       (eq? (.ref v 'kind) 'agentic-ai-lab.funflow.governed-runner.v1)))

(def (plan-task-steps plan)
  (filter (lambda (n) (task? (plan-node-step n)))
          (execution-plan-nodes plan)))

(def (fenced-task-node? node)
  (let ((step (plan-node-step node)))
    (and (task? step) (memq (task-kind step) '(external store)))))

(def (pure-task-node? node)
  (let ((step (plan-node-step node)))
    (and (task? step) (eq? (task-kind step) 'pure))))

(def (governed-funflow-run
      governed-runner flow input
      capsule-id: (capsule-id #f)
      idempotency-key: (idempotency-key #f)
      idempotency-commits: (idempotency-commits '())
      step-code-digests: (step-code-digests '())
      sandbox-override: (sandbox-override #f)
      env-digest-override: (env-digest-override #f))
  (unless (governed-funflow-runner? governed-runner)
    (error "governed-funflow-run expects a GovernedFunflowRunner" governed-runner))
  (unless (flow? flow)
    (error "governed-funflow-run expects a FunFlow flow" flow))
  (let* ((base (.ref governed-runner 'base-runner))
         (store (.ref governed-runner 'cas-store))
         (source-cut (.ref governed-runner 'source-cut))
         (premise-gen (.ref governed-runner 'premise-gen))
         (env-dig (or env-digest-override (.ref governed-runner 'env-digest)))
         (raw-sbx (or sandbox-override (.ref governed-runner 'sandbox-profile)))
         (sbx-binding (if (and (object? raw-sbx) (.slot? raw-sbx 'has-untrusted-input?))
                        raw-sbx
                        (and raw-sbx (sandbox-profile->external-binding raw-sbx env-digest: env-dig))))
         (compiled (funflow-flow->durable-dag flow
                                              source-cut: source-cut
                                              env-digest: env-dig
                                              step-code-digests: step-code-digests
                                              sandbox-profile: sbx-binding))
         (dag (.ref compiled 'dag))
         (plan (runner-plan base flow))
         (task-nodes (plan-task-steps plan))
         (fenced-nodes (filter fenced-task-node? task-nodes))
         (has-fenced? (pair? fenced-nodes))
         (pure-only? (and (pair? task-nodes) (every pure-task-node? task-nodes)))
         (cas-key (funflow-canonical-sha256
                   (list 'governed-flow-cas.v1
                         (flow-name flow)
                         env-dig
                         (.ref dag 'fingerprints)
                         input))))
    (cond
     ((not (.ref dag 'valid?))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.funflow.governed-run-result.v1
          admitted?: #f
          executed?: #f
          cas-hit?: #f
          reason: 'invalid-compiled-durable-dag
          cas-key: cas-key
          dag: dag))
     ;; Gate EVERY external/store task against Slice 52 ExternalSandboxProfile BEFORE adapter dispatch
     (has-fenced?
      (let ((sbx-decision (funflow-admit-external-task-sandbox sbx-binding)))
        (if (not (.ref sbx-decision 'admitted?))
          (.o bind-these: #f
              kind: 'agentic-ai-lab.funflow.governed-run-result.v1
              admitted?: #f
              executed?: #f
              cas-hit?: #f
              reason: (.ref sbx-decision 'reason)
              sandbox-decision: sbx-decision
              cas-key: cas-key
              dag: dag)
          ;; Slice 52 BUG-F3: FencedEffect NEVER skips on plain CAS; requires explicit idempotency commit
          (let ((idem-hit (and idempotency-key (assoc idempotency-key idempotency-commits))))
            (if idem-hit
              (let ((cached-val (cdr idem-hit)))
                (.o bind-these: #f
                    kind: 'agentic-ai-lab.funflow.governed-run-result.v1
                    admitted?: #t
                    executed?: #f
                    cas-hit?: #f
                    idempotency-reused?: #t
                    reason: 'fenced-effect-idempotency-commit-reused
                    value: cached-val
                    receipt: #f
                    cas-key: cas-key
                    pinned-keys: '()
                    audit-capsule-commitment: (funflow-canonical-sha256
                                               (list 'funflow-audit-capsule.v1 source-cut (flow-name flow) cas-key cached-val))
                    sandbox-decision: sbx-decision
                    dag: dag))
              (let* ((res (runner-run base flow input))
                     (val (run-result-value res))
                     (rec (run-result-receipt res))
                     (commit (funflow-canonical-sha256
                              (list 'funflow-audit-capsule.v1 source-cut (flow-name flow) cas-key val))))
                (.o bind-these: #f
                    kind: 'agentic-ai-lab.funflow.governed-run-result.v1
                    admitted?: #t
                    executed?: #t
                    cas-hit?: #f
                    idempotency-reused?: #f
                    reason: 'fenced-effect-executed-under-sandbox
                    value: val
                    receipt: rec
                    cas-key: cas-key
                    pinned-keys: '()
                    audit-capsule-commitment: commit
                    sandbox-decision: sbx-decision
                    dag: dag)))))))
     ;; Pure flows execute through FunflowCasStore. singleflight + atomic temp-rename + capsule pinning
     (pure-only?
      (let* ((sf (funflow-cas-lookup-or-wait!
                  store cas-key
                  (lambda ()
                    (let ((res (runner-run base flow input)))
                      (run-result-value res)))
                  premise-gen: premise-gen))
             (val (.ref sf 'value))
             (hit? (.ref sf 'hit?))
             (pinned (if capsule-id
                       (begin
                         (funflow-cas-pin-capsule! store capsule-id (list cas-key))
                         (list cas-key))
                       '()))
             (commit (funflow-canonical-sha256
                      (list 'funflow-audit-capsule.v1 source-cut (flow-name flow) cas-key val))))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.funflow.governed-run-result.v1
            admitted?: #t
            executed?: (not hit?)
            cas-hit?: hit?
            idempotency-reused?: #f
            reason: (if hit? 'pure-cas-singleflight-hit 'pure-cas-singleflight-computed)
            value: val
            receipt: #f
            cas-key: cas-key
            pinned-keys: pinned
            audit-capsule-commitment: commit
            sandbox-decision: #f
            dag: dag)))
     ;; VerifiedEpistemic / mixed local scheme flows run live without plain-CAS skipping
     (else
      (let* ((res (runner-run base flow input))
             (val (run-result-value res))
             (rec (run-result-receipt res))
             (commit (funflow-canonical-sha256
                      (list 'funflow-audit-capsule.v1 source-cut (flow-name flow) cas-key val))))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.funflow.governed-run-result.v1
            admitted?: #t
            executed?: #t
            cas-hit?: #f
            idempotency-reused?: #f
            reason: 'epistemic-flow-executed
            value: val
            receipt: rec
            cas-key: cas-key
            pinned-keys: '()
            audit-capsule-commitment: commit
            sandbox-decision: #f
            dag: dag))))))

(def GovernedFunflowRunnerExports
  (.o bind-these: #f
      sandbox-profile->external-binding: sandbox-profile->external-binding
      GovernedFunflowRunner: GovernedFunflowRunner.
      make-governed-funflow-runner: make-governed-funflow-runner
      governed-funflow-runner?: governed-funflow-runner?
      governed-funflow-run: governed-funflow-run))
