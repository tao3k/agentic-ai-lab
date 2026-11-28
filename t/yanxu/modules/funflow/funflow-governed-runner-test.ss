;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Step 4 Focused Integration Suite:
;;; Verifies `modules/funflow/governed-runner.ss` wiring `control-plane/runner.ss`
;;; onto Slice 52 `FunflowCasStore.` (singleflight + atomic rename + pinned GC),
;;; real `modules/nono-sandbox/profile-interface.ss` (`nono-sandbox-profile`)
;;; sandbox admission (env-digest pinning & Lethal-Trifecta blocking), and
;;; `FencedEffect.` idempotency-only skip rules.

(import :std/test
        (only-in :std/io/tempfile make-temporary-file-name)
        (only-in :clan/poo/object .o .ref object?)
        (only-in :clan/poo/number Integer)
        (only-in :tao3k/agentic-ai-lab/modules/nono-sandbox/profile-interface
                 nono-sandbox-profile)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/api
                 make-pure-task make-external-task
                 Fun AdapterResult adapter-result-value task-flow flow-then
                 make-runner make-local-eager-strategy
                 make-request-only-adapter make-runtime-adapter
                 runtime-adapter-fetcher runtime-adapter-store-putter runtime-adapter-store-getter
                 make-adapter-result)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/cas-store
                 make-funflow-cas-store funflow-cas-lookup funflow-cas-gc-sweep!)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/governed-runner
                 sandbox-profile->external-binding
                 make-governed-funflow-runner
                 governed-funflow-run))

(export funflow-governed-runner-test)

(def funflow-governed-runner-test
  (test-suite "FunFlow Governed Runner x FunflowCasStore x nono-sandbox Gate"

    (test-case "Pure flow runs via singleflight CAS, pins to AuditCapsule, and survives GC"
      (let* ((tmp-dir (make-temporary-file-name "ff-gov-cas-"))
             (store (make-funflow-cas-store root-dir: tmp-dir))
             (exec-count (box 0))
             (sig (Fun Integer <- Integer))
             (t-inc (make-pure-task 'inc sig
                      (lambda (x)
                        (set-box! exec-count (+ 1 (unbox exec-count)))
                        (+ x 1))))
             (t-dbl (make-pure-task 'dbl sig (lambda (x) (* x 2))))
             (flow (flow-then 'inc-then-dbl (task-flow 'inc t-inc) (task-flow 'dbl t-dbl)))
             (base-runner (make-runner (make-local-eager-strategy)
                                       (make-request-only-adapter)))
             (gov (make-governed-funflow-runner
                   base-runner
                   cas-store: store
                   env-digest: "sha256:nix-env-v1"
                   source-cut: "cut-1"
                   premise-gen: 1)))
        (dynamic-wind
          (lambda () (void))
          (lambda ()
            (let* ((r1 (governed-funflow-run gov flow 5 capsule-id: "capsule-cut-1"))
                   (r2 (governed-funflow-run gov flow 5 capsule-id: "capsule-cut-1"))
                   (gc (funflow-cas-gc-sweep! store)))
              (check-equal? (.ref r1 'admitted?) #t)
              (check-equal? (.ref r1 'executed?) #t)
              (check-equal? (.ref r1 'cas-hit?) #f)
              (check-equal? (.ref r1 'value) 12)
              ;; Second identical run hits singleflight CAS without recomputing!
              (check-equal? (.ref r2 'admitted?) #t)
              (check-equal? (.ref r2 'executed?) #f)
              (check-equal? (.ref r2 'cas-hit?) #t)
              (check-equal? (.ref r2 'value) 12)
              (check-equal? (unbox exec-count) 1)
              ;; AuditCapsule-pinned entry survives aggressive GC sweep!
              (check-equal? (length (.ref gc 'evicted-keys)) 0)
              (check-equal? (length (.ref gc 'preserved-pinned-keys)) 1)
              (check-equal? (object? (funflow-cas-lookup store (.ref r1 'cas-key))) #t)
              ;; Env digest drift busts CAS key cleanly
              (let ((r3 (governed-funflow-run gov flow 5 env-digest-override: "sha256:nix-env-v2")))
                (check-equal? (.ref r3 'cas-hit?) #f)
                (check-equal? (equal? (.ref r1 'cas-key) (.ref r3 'cas-key)) #f)
                (check-equal? (unbox exec-count) 2))))
          (lambda ()
            (when (file-exists? tmp-dir)
              (for-each (lambda (f) (delete-file (path-expand f tmp-dir)))
                        (directory-files tmp-dir))
              (delete-directory tmp-dir))))))

    (test-case "ExternalTask gated by real nono-sandbox-profile blocks unpinned env & Lethal Trifecta BEFORE adapter call"
      (let* ((adapter-calls (box 0))
             (sig (Fun AdapterResult <- Integer))
             (t-ext (make-external-task 'deploy 'run-cmd '(deploy) sig))
             (ext-flow (task-flow 'deploy t-ext))
             (orig-adapter (make-request-only-adapter))
             (adapter (make-runtime-adapter
                       'mock-nono
                       '(external)
                       (lambda (_req)
                         (set-box! adapter-calls (+ 1 (unbox adapter-calls)))
                         (make-adapter-result '(request deploy external) 'completed 42 #f #f))
                       (runtime-adapter-fetcher orig-adapter)
                       (runtime-adapter-store-putter orig-adapter)
                       (runtime-adapter-store-getter orig-adapter)))
             (base-runner (make-runner (make-local-eager-strategy) adapter))
             ;; 1. Unpinned env-digest on real nono-sandbox-profile -> REFUSED
             (bind-unpinned (sandbox-profile->external-binding nono-sandbox-profile))
             ;; 2. Lethal Trifecta (untrusted + private + egress, unendorsed) -> REFUSED
             (egress-profile (.o (:: @ nono-sandbox-profile)
                                 capabilities: '(process-run filesystem-read network-egress)))
             (bind-trifecta (sandbox-profile->external-binding
                             egress-profile
                             env-digest: "sha256:nono-oci-v1"
                             has-untrusted-input?: #t
                             has-private-data?: #t
                             egress-endorsed?: #f))
             ;; 3. Pinned real nono-sandbox-profile (no network egress!) -> ADMITTED
             (bind-safe (sandbox-profile->external-binding
                         nono-sandbox-profile
                         env-digest: "sha256:nono-oci-v1"
                         has-untrusted-input?: #t
                         has-private-data?: #t))
             (gov (make-governed-funflow-runner
                   base-runner
                   sandbox-profile: bind-safe
                   env-digest: "sha256:nono-oci-v1"
                   source-cut: "cut-2")))
        (let* ((r-unpinned (governed-funflow-run gov ext-flow 1 sandbox-override: bind-unpinned))
               (r-trifecta (governed-funflow-run gov ext-flow 1 sandbox-override: bind-trifecta)))
          (check-equal? (.ref r-unpinned 'admitted?) #f)
          (check-equal? (.ref r-unpinned 'executed?) #f)
          (check-equal? (.ref r-trifecta 'admitted?) #f)
          (check-equal? (.ref r-trifecta 'reason) 'lethal-trifecta-sandbox-blocked)
          ;; Adapter was NEVER called for rejected profiles!
          (check-equal? (unbox adapter-calls) 0))
        ;; Safe pinned nono-sandbox executes live; FencedEffect NEVER skips on plain CAS
        (let* ((r-live-1 (governed-funflow-run gov ext-flow 1 idempotency-key: "idem-deploy-1"))
               (r-live-2 (governed-funflow-run gov ext-flow 1 idempotency-key: "idem-deploy-1"))
               ;; Only skips when explicit idempotency commit receipt is supplied!
               (r-idem (governed-funflow-run gov ext-flow 1
                                             idempotency-key: "idem-deploy-1"
                                             idempotency-commits: '(("idem-deploy-1" . 42)))))
          (check-equal? (.ref r-live-1 'admitted?) #t)
          (check-equal? (.ref r-live-1 'executed?) #t)
          (check-equal? (adapter-result-value (.ref r-live-1 'value)) 42)
          (check-equal? (.ref r-live-2 'executed?) #t)
          (check-equal? (unbox adapter-calls) 2)
          (check-equal? (.ref r-idem 'admitted?) #t)
          (check-equal? (.ref r-idem 'executed?) #f)
          (check-equal? (.ref r-idem 'idempotency-reused?) #t)
          (check-equal? (.ref r-idem 'value) 42)
          (check-equal? (unbox adapter-calls) 2))))))
