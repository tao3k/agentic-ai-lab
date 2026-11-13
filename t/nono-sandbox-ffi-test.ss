;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: runtime nono FFI tests call the C ABI through Gambit, not the CLI.
;;; Invariant: irreversible sandbox apply is never performed by this test.

(import (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check
                 check-eq?
                 check-equal?
                 check-false
                 check-not-equal?
                 check-output
                 check-true
                 test-error
                 test-suite)
        :tao3k/yuanxu/modules/funflow/control-plane/api
        :tao3k/agentic-ai-lab/modules/agent-sandbox/api
        :tao3k/agentic-ai-lab/modules/agent-sandbox/nono
        :tao3k/agentic-ai-lab/modules/nono-sandbox/c-binding)

(export nono-sandbox-ffi-test)

;; : (-> Alist Symbol Value)
(def (test-ref alist key)
  (cdr (assoc key alist)))

;; : (-> Alist Symbol Value)
(def (test-maybe-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;; : (-> AgentSandboxRuntimeManifest)
(def (make-ffi-test-runtime-manifest)
  (agent-sandbox-request->runtime-manifest
   (agent-sandbox-request
    (make-nono-agent-sandbox-profile 'runtime/ffi-test)
    (command "sh")
    (args '("-lc" "printf ffi"))
    (workdir ".")
    (mounts '(((path . ".") (kind . directory) (mode . read))))
    (network-policy '((mode . blocked)))
    (capabilities '((allow-commands . ("sh"))))
    (metadata '((test . ffi))))))

;;; This suite keeps runtime FFI receipt shape observable even when the library
;;; is absent on a developer machine.
;; : TestSuite
(def nono-sandbox-ffi-test
  (test-suite "nono-sandbox runtime FFI"
    (yuanxu-test-case "skips cleanly when an explicit runtime library path is absent"
      (let* ((runtime-manifest (make-ffi-test-runtime-manifest))
             (receipt
              (nono-c-binding-ffi-live-test
               runtime-manifest
               '((library-path . "run/no-such-libnono_ffi.dylib")))))
        (check-equal? (test-ref receipt 'schema)
                      +nono-c-binding-ffi-live-test-receipt-schema+)
        (check-equal? (test-ref receipt 'ok?) #t)
        (check-equal? (test-ref receipt 'enabled?) #f)
        (check-equal? (test-ref receipt 'skipped?) #t)
        (check-equal? (test-ref receipt 'skip-reason)
                      'runtime-library-not-found)
        (check-equal? (test-ref receipt 'runtime-executed) #f)
        (check-equal? (test-ref receipt 'cli-executed) #f)
        (check-equal? (test-maybe-ref receipt 'command) #f)))
    (yuanxu-test-case "calls runtime nono C ABI when libnono_ffi is available"
      (let* ((runtime-manifest (make-ffi-test-runtime-manifest))
             (receipt
              (nono-c-binding-ffi-live-test runtime-manifest)))
        (check-equal? (test-ref receipt 'schema)
                      +nono-c-binding-ffi-live-test-receipt-schema+)
        (check-equal? (test-ref receipt 'ok?) #t)
        (check-equal? (test-ref receipt 'cli-executed) #f)
        (check-equal? (test-ref receipt 'runtime-executed) #f)
        (check-equal? (test-ref receipt 'would-apply?) #f)
        (check-equal? (test-ref receipt 'irreversible-apply?) #f)
        (check-equal? (test-maybe-ref receipt 'command) #f)
        (if (test-ref receipt 'enabled?)
          (begin
            (check-equal? (test-ref receipt 'skipped?) #f)
            (check-equal? (test-ref receipt 'runtime-executed) #t)
            (check-equal? (test-ref receipt 'runtime-loaded?) #t)
            (check-equal? (test-ref receipt 'apply-symbol)
                          'nono_sandbox_apply)
            (check-equal? (test-ref receipt 'apply-null-only?) #t)
            (check-equal? (test-ref receipt 'apply-null-code)
                          +nono-c-binding-ffi-apply-null-error-code+)
            (check-equal? (test-ref receipt 'capability-roundtrip-code) 0)
            (check-equal? (string? (test-ref receipt 'platform)) #t)
            (check-equal? (string? (test-ref receipt 'details)) #t))
          (begin
            (check-equal? (test-ref receipt 'skipped?) #t)
            (check-equal? (test-ref receipt 'skip-reason)
                          'runtime-library-not-found)))))))
