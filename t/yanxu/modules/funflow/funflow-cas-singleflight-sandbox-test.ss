;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Wave 3 & Wave 4 Regression Suite for Slice 52 (BUG-F1..BUG-F5):
;;; - BUG-F1: after-start finalizer topological ordering & SCC cycle detection
;;; - BUG-F2: fail-closed premise invalidation on retracted/deleted premises
;;; - BUG-F3: canonical 5-tuple CAS key (code/env sensitivity, input-order invariance)
;;;           and EffectClass-gated CAS reuse (FencedEffect never bypassed by plain CAS)
;;; - BUG-F4: disjoint lease meet bottom & ExternalTask Lethal-Trifecta sandbox rejection
;;; - BUG-F5: pure flow->durable-dag compiler, multi-thread lookup-or-wait singleflight
;;;           with crash takeover, atomic temp-write-then-rename, and AuditCapsule-pinned GC

(import :std/test
        (only-in :std/io/tempfile make-temporary-file-name)
        (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :clan/poo/object .o .ref object?)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/signatures Fun Number String)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/flow
                 pure-flow scheme-flow external-flow flow-then flow-fanout)
        :tao3k/agentic-ai-lab/modules/funflow/durable-dag
        :tao3k/agentic-ai-lab/modules/funflow/cas-store)

(export funflow-cas-singleflight-sandbox-test)

(def (make-temp-dir prefix)
  (let* ((base (make-temporary-file-name prefix)))
    (when (file-exists? base) (delete-file base))
    (create-directory* base)
    base))

(def (cleanup-dir dir)
  (when (file-exists? dir)
    (for-each
     (lambda (name)
       (let ((p (path-expand name dir)))
         (when (file-exists? p)
           (with-catch void (lambda () (delete-file p))))))
     (directory-files dir))
    (with-catch void (lambda () (delete-directory dir)))))

(def funflow-cas-singleflight-sandbox-test
  (test-suite "Slice 52 FunFlow Formal Challenge Repairs (BUG-F1..BUG-F5)"
    (yuanxu-test-case "BUG-F1: Misordered after-start finalizer is NEVER dropped and after-start cycles are caught by SCC"
      ;; Deliberately place finalizer BEFORE its failed trigger in the input list!
      (let* ((fin-node (funflow-dag-node 'cleanup-sandbox after-start: 'deploy-step status: 'todo))
             (trig-node (funflow-dag-node 'deploy-step status: 'failed))
             (dag (funflow-dag-build (list fin-node trig-node)))
             (plan (funflow-resume-plan dag))
             ;; Also test after-start cycle A -> B -> A!
             (cyc-a (funflow-dag-node 'cyc-a after-start: 'cyc-b))
             (cyc-b (funflow-dag-node 'cyc-b after-start: 'cyc-a))
             (cyc-dag (funflow-dag-build (list cyc-a cyc-b))))
        (check (.ref dag 'valid?) => #t)
        ;; Trigger MUST precede finalizer in topological order!
        (check (.ref dag 'topological-order) => '(deploy-step cleanup-sandbox))
        ;; Finalizer MUST be recorded in pending-finalizers, blocking premature archive!
        (check (.ref plan 'pending-finalizers) => '(cleanup-sandbox))
        (check (.ref plan 'complete?) => #f)
        (check (strategy-archive-guard DurableGovernedStrategy. dag plan (.o)) => #f)
        ;; Cycle through after-start MUST be rejected by Tarjan SCC!
        (check (.ref cyc-dag 'valid?) => #f)
        (check (> (length (.ref cyc-dag 'cycle-nodes)) 0) => #t)))

    (yuanxu-test-case "BUG-F2: Retracted/missing premise fails CLOSED and invalidates dependent DAG nodes"
      (let* ((n1 (funflow-dag-node 'fetch-policy
                                   premise-digests: '(("policy-a" . "sha-1") ("policy-b" . "sha-2"))))
             (n2 (funflow-dag-node 'build-plan needs: '(fetch-policy)))
             (n3 (funflow-dag-node 'unrelated premise-digests: '(("policy-a" . "sha-1"))))
             (dag (funflow-dag-build (list n1 n2 n3)))
             ;; "policy-b" is RETRACTED (absent from live-premise-alist)!
             (inv (funflow-invalidate-premises dag '(("policy-a" . "sha-1")))))
        (check (.ref inv 'stale-nodes) => '(fetch-policy build-plan))
        (check (.ref inv 'unaffected-nodes) => '(unrelated))))

    (yuanxu-test-case "BUG-F3: Canonical 5-tuple CAS sensitivity (code/env drift, order invariance) & EffectClass-gated skip"
      (let* ((n-v1 (funflow-dag-node 'step-a
                                     step-code-digest: "code-v1"
                                     env-digest: "nix-drv-1"
                                     input-hashes: '("h-b" "h-a")
                                     premise-digests: '(("p2" . "2") ("p1" . "1"))))
             ;; Same computation with permuted input-hashes & premise-digests -> IDENTICAL key!
             (n-perm (funflow-dag-node 'step-a
                                       step-code-digest: "code-v1"
                                       env-digest: "nix-drv-1"
                                       input-hashes: '("h-a" "h-b")
                                       premise-digests: '(("p1" . "1") ("p2" . "2"))))
             ;; Different node label -> SAME label-free PureCAS content key!
             (n-other-label (funflow-dag-node 'step-renamed
                                              step-code-digest: "code-v1"
                                              env-digest: "nix-drv-1"
                                              input-hashes: '("h-a" "h-b")
                                              premise-digests: '(("p1" . "1") ("p2" . "2"))))
             ;; Code upgrade -> MUST bust CAS key!
             (n-code-v2 (funflow-dag-node 'step-a
                                          step-code-digest: "code-v2"
                                          env-digest: "nix-drv-1"
                                          input-hashes: '("h-a" "h-b")
                                          premise-digests: '(("p1" . "1") ("p2" . "2"))))
             ;; Env/Nix upgrade -> MUST bust CAS key!
             (n-env-v2 (funflow-dag-node 'step-a
                                         step-code-digest: "code-v1"
                                         env-digest: "nix-drv-2"
                                         input-hashes: '("h-a" "h-b")
                                         premise-digests: '(("p1" . "1") ("p2" . "2"))))
             (fp-v1 (funflow-cas-fingerprint n-v1 '()))
             (fp-perm (funflow-cas-fingerprint n-perm '()))
             (fp-code-v2 (funflow-cas-fingerprint n-code-v2 '()))
             (fp-env-v2 (funflow-cas-fingerprint n-env-v2 '())))
        (check fp-v1 => fp-perm)
        (check (funflow-pure-cas-content-key n-v1 '()) => (funflow-pure-cas-content-key n-other-label '()))
        (check (not (equal? fp-v1 fp-code-v2)) => #t)
        (check (not (equal? fp-v1 fp-env-v2)) => #t)
        ;; Hash-table canonical encoding is order-invariant
        (let ((h1 (make-hash-table)) (h2 (make-hash-table)))
          (hash-put! h1 "a" 1) (hash-put! h1 "b" 2)
          (hash-put! h2 "b" 2) (hash-put! h2 "a" 1)
          (check (funflow-canonical-sha256 h1) => (funflow-canonical-sha256 h2)))
        ;; EffectClass-gated CAS skip: plain CAS hit NEVER skips FencedEffect or unendorsed VerifiedEpistemic!
        (let* ((pure-n (funflow-dag-node 'pure-op effect-class: PureCAS.))
               (ep-n (funflow-dag-node 'ep-op effect-class: VerifiedEpistemic. source-cut: "cut-1"))
               (fenced-n (funflow-dag-node 'push-op effect-class: FencedEffect. idempotency-key: "idem-push-1"))
               (dag (funflow-dag-build (list pure-n ep-n fenced-n)))
               (fps (.ref dag 'fingerprints))
               ;; Put ALL THREE fingerprints into plain completed-cas-table!
               (plan-plain (funflow-resume-plan dag completed-cas-table: fps))
               ;; With endorsement on live cut, ep-op can skip, but push-op STILL refuses plain CAS!
               (plan-endorsed (funflow-resume-plan dag
                                                   completed-cas-table: fps
                                                   context: (.o bind-these: #f has-endorsement?: #t live-cut: "cut-1")))
               ;; Only an explicit idempotency commit receipt settles FencedEffect!
               (plan-idem (funflow-resume-plan dag
                                               completed-cas-table: fps
                                               idempotency-commits: '("idem-push-1")
                                               context: (.o bind-these: #f has-endorsement?: #t live-cut: "cut-1"))))
          (check (.ref plan-plain 'skipped-nodes) => '(pure-op))
          (check (.ref plan-endorsed 'skipped-nodes) => '(pure-op ep-op))
          (check (.ref plan-idem 'skipped-nodes) => '(pure-op ep-op push-op)))))

    (yuanxu-test-case "BUG-F4: Disjoint lease meet produces invalid bottom & ExternalTask blocks unpinned/Lethal-Trifecta"
      (let* ((env-p (.o bind-these: #f trust-ceiling: 3 lease-start: 10 lease-end: 20 can-write?: #t can-push?: #t))
             (env-o (.o bind-these: #f trust-ceiling: 3 lease-start: 30 lease-end: 40 can-write?: #t can-push?: #t))
             (met (funflow-envelope-meet env-p env-o))
             (unpinned-sbx (.o (:: @ ExternalSandboxProfile.) bind-these: #f env-digest: ""))
             (trifecta-sbx (.o (:: @ ExternalSandboxProfile.) bind-these: #f
                               env-digest: "oci:sha256:abc"
                               has-untrusted-input?: #t
                               has-private-data?: #t
                               egress-enabled?: #t
                               egress-endorsed?: #f))
             (safe-sbx (.o (:: @ ExternalSandboxProfile.) bind-these: #f
                           env-digest: "oci:sha256:abc"
                           has-untrusted-input?: #t
                           has-private-data?: #t
                           egress-enabled?: #f))
             (fenced-node (funflow-dag-node 'ext-run
                                            effect-class: FencedEffect.
                                            source-cut: "cut-1"
                                            idempotency-key: "ext-1"
                                            sandbox-profile: trifecta-sbx)))
        (check (.ref met 'lease-valid?) => #f)
        (check (.ref met 'can-write?) => #f)
        (check (.ref met 'can-push?) => #f)
        (check (.ref (funflow-admit-external-task-sandbox unpinned-sbx) 'reason) => 'unpinned-external-env-digest)
        (check (.ref (funflow-admit-external-task-sandbox trifecta-sbx) 'reason) => 'lethal-trifecta-sandbox-blocked)
        (check (.ref (funflow-admit-external-task-sandbox safe-sbx) 'admitted?) => #t)
        ;; FencedEffect node carrying a Lethal-Trifecta sandbox MUST fail closed even with token+endorsement!
        (check (.ref (funflow-admit-node-effect fenced-node
                       envelope: (.o bind-these: #f claims-exhaustive?: #t
                                     has-authorized-token?: #t has-endorsement?: #t live-cut: "cut-1"))
                     'reason)
               => 'lethal-trifecta-sandbox-blocked)
        ;; Disjoint lease envelope also fails closed!
        (let ((safe-node (funflow-dag-node 'ext-ok effect-class: FencedEffect.
                                           source-cut: "cut-1" idempotency-key: "ext-2"
                                           sandbox-profile: safe-sbx)))
          (check (.ref (funflow-admit-node-effect safe-node
                         envelope: (.o (:: @ met) bind-these: #f claims-exhaustive?: #t
                                       has-authorized-token?: #t has-endorsement?: #t live-cut: "cut-1"))
                       'reason)
                 => 'restriction-lease-invalid-or-expired))))

    (yuanxu-test-case "BUG-F5: Pure flow->durable-dag compiler + concurrent singleflight + crash-atomic publish + pinned CAS GC"
      ;; 1. Pure flow->durable-dag compilation across pure, scheme, branch fanout, and external tasks
      (let* ((f-pure (pure-flow 'parse (Fun Number <- Number) (lambda (x) (+ x 1))))
             (f-scheme (scheme-flow 'analyze (Fun Number <- Number) (lambda (x) (* x 2))))
             (f-fan (flow-fanout 'dual f-pure f-scheme))
             (f-ext (external-flow 'deploy 'apply '((target . prod)) (Fun String <- String)))
             (c-fan (funflow-flow->durable-dag f-fan source-cut: "cut-52" env-digest: "nix:drv-52"))
             (c-ext (funflow-flow->durable-dag f-ext source-cut: "cut-52" env-digest: "nix:drv-52")))
        (check (.ref c-fan 'valid?) => #t)
        (check (= (length (.ref (.ref c-fan 'dag) 'nodes)) 3) => #t)
        (check (.ref c-ext 'valid?) => #t)
        (let ((ext-node (car (.ref (.ref c-ext 'dag) 'nodes))))
          (check (.ref (.ref ext-node 'effect-class) 'effect-kind) => 'fenced-effect)
          (check (.ref ext-node 'env-digest) => "nix:drv-52")))

      ;; 2. Real multi-thread singleflight, crash-before-rename recovery, and AuditCapsule-pinned CAS GC
      (let* ((tmp-dir (make-temp-dir "funflow-cas-s52-"))
             (store (make-funflow-cas-store root-dir: tmp-dir)))
        (dynamic-wind void
          (lambda ()
            ;; 2a. Two concurrent threads invoke lookup-or-wait! on same key -> compute executes ONCE!
            (let* ((runs (box 0))
                   (m (make-mutex))
                   (thunk (lambda ()
                            (mutex-lock! m)
                            (set-box! runs (+ 1 (unbox runs)))
                            (mutex-unlock! m)
                            (thread-sleep! 0.05)
                            '(artifact . "ok-v1")))
                   (t1 (spawn (lambda () (funflow-cas-lookup-or-wait! store "key-sf-1" thunk premise-gen: 1))))
                   (t2 (spawn (lambda ()
                                (thread-sleep! 0.01)
                                (funflow-cas-lookup-or-wait! store "key-sf-1" thunk premise-gen: 1))))
                   (r1 (thread-join! t1))
                   (r2 (thread-join! t2)))
              (check (unbox runs) => 1)
              (check (.ref r1 'value) => '(artifact . "ok-v1"))
              (check (.ref r2 'value) => '(artifact . "ok-v1"))
              (check (<= (funflow-cas-peak-compute-count store) 1) => #t)
              (check (file-exists? (.ref r1 'file-path)) => #t))

            ;; 2b. Crash before atomic rename leaves CAS completely clean and allows next waiter/caller to succeed!
            (check-exception
             (funflow-cas-lookup-or-wait! store "key-crash-1"
                                          (lambda () (error "simulated mid-compute crash")))
             true)
            (check (funflow-cas-lookup store "key-crash-1") => #f)
            (let ((recovered (funflow-cas-lookup-or-wait! store "key-crash-1" (lambda () 'clean-recovery))))
              (check (.ref recovered 'value) => 'clean-recovery))

            ;; 2c. AuditCapsule-pinned GC preserves cut=1 forensic artifact while evicting unpinned garbage!
            (funflow-cas-lookup-or-wait! store "key-ephemeral" (lambda () 'temp-data))
            (funflow-cas-pin-capsule! store "capsule-cut-1" '("key-sf-1"))
            (let ((gc (funflow-cas-gc-sweep! store active-keys: '())))
              (check (and (member "key-sf-1" (.ref gc 'preserved-pinned-keys)) #t) => #t)
              (check (and (member "key-ephemeral" (.ref gc 'evicted-keys)) #t) => #t)
              (check (object? (funflow-cas-lookup store "key-sf-1")) => #t)
              (check (funflow-cas-lookup store "key-ephemeral") => #f)))
          (lambda ()
            (cleanup-dir tmp-dir)))))))
