;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: nono-sandbox C binding tests cover ABI contracts and manifest projection.
;;; Invariant: tests do not load or execute the C library.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
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
        :yuanxu/modules/funflow/control-plane/api
        :agentic-ai-lab/modules/agent-sandbox/api
        :agentic-ai-lab/modules/agent-sandbox/nono
        :agentic-ai-lab/modules/agent-sandbox/cube
        :agentic-ai-lab/modules/nono-sandbox/c-binding)

(export nono-sandbox-c-binding-test)

;; : (-> Alist Symbol Value)
(def (test-ref alist key)
  (cdr (assoc key alist)))

;;; This suite keeps C binding descriptor policy executable without compiling
;;; or loading the native nono library.
;; : TestSuite
(def nono-sandbox-c-binding-test
  (test-suite "nono-sandbox C binding contract"
    (yuanxu-test-case "declares POO descriptor for the generated nono C ABI"
      (let* ((descriptor (make-nono-c-binding-descriptor))
             (contract (nono-c-binding-descriptor->contract descriptor))
             (override (make-nono-c-binding-descriptor
                        (list (cons 'library "nono_ffi_test")))))
        (check-equal? (nono-c-binding-descriptor? descriptor) #t)
        (check-equal? (test-ref contract 'schema)
                      +nono-c-binding-schema+)
        (check-equal? (test-ref contract 'package) "nono-ffi")
        (check-equal? (test-ref contract 'library) "nono_ffi")
        (check-equal? (test-ref contract 'adapter-header)
                      "agentic_ai_lab_nono_binding.h")
        (check-equal? (test-ref contract 'adapter-include-ref)
                      "bindings/nono-c/agentic_ai_lab_nono_binding.h")
        (check-equal? (test-ref contract 'header) "nono.h")
        (check-equal? (test-ref contract 'include-ref)
                      "bindings/nono-c/nono.h")
        (check-equal? (test-ref contract 'probe-ref)
                      "bindings/nono-c/agentic_ai_lab_nono_binding_probe.c")
        (check-equal? (and (memq 'NonoDiagnosticCode
                                 (test-ref contract 'types))
                           #t)
                      #t)
        (check-equal? (and (memq 'nono_last_diagnostic_code
                                 (test-ref contract 'functions))
                           #t)
                      #t)
        (check-equal? (and (memq 'nono_session_diagnostic_report_to_json
                                 (test-ref contract 'functions))
                           #t)
                      #t)
        (check-equal? (and (memq 'nono_capability_set_allow_path
                                 (test-ref contract 'functions))
                           #t)
                      #t)
        (check-equal? (and (memq 'nono_sandbox_apply
                                 (test-ref contract 'functions))
                           #t)
                      #t)
        (check-equal? (nono-c-binding-descriptor-library override)
                      "nono_ffi_test")))
    (yuanxu-test-case "declares POO build descriptor for the C compile probe"
      (let* ((build (make-nono-c-binding-build))
             (contract (nono-c-binding-build->contract build))
             (binding (test-ref contract 'binding))
             (required-inputs (test-ref contract 'required-inputs))
             (override (make-nono-c-binding-build
                        (list (cons 'compiler "cc")
                              (cons 'upstream-include-dirs
                                    '("/opt/nono/include"))
                              (cons 'include-dirs
                                    '("bindings/nono-c"
                                      "/opt/nono/include")))))
             (missing-upstream
              (make-nono-c-binding-build
               (list (cons 'upstream-include-dirs
                           '("run/missing-nono-include"))
                     (cons 'include-dirs
                           '("bindings/nono-c"
                             "run/missing-nono-include")))))
             (missing-errors
              (nono-c-binding-build-input-validation-errors
               missing-upstream)))
        (check-equal? (nono-c-binding-build? build) #t)
        (check-equal? (test-ref contract 'schema)
                      +nono-c-binding-build-schema+)
        (check-equal? (test-ref binding 'library) "nono_ffi")
        (check-equal? (test-ref contract 'compiler) "clang")
        (check-equal? (test-ref contract 'standard) "c11")
        (check-equal? (test-ref contract 'syntax-only?) #t)
        (check-equal? (test-ref contract 'adapter-include-dirs)
                      '("bindings/nono-c"))
        (check-equal? (test-ref contract 'upstream-include-dirs)
                      '())
        (check-equal? (test-ref contract 'include-dirs)
                      '("bindings/nono-c"))
        (check-equal? (test-ref contract 'probe-ref)
                      "bindings/nono-c/agentic_ai_lab_nono_binding_probe.c")
        (check-equal? (map (lambda (input)
                             (test-ref input 'kind))
                           required-inputs)
                      '(adapter-include-dir probe))
        (check-equal? (test-ref contract 'inputs-ok?) #t)
        (check-equal? (nono-c-binding-compile-probe-command)
                      '("clang"
                        "-Qunused-arguments"
                        "-std=c11"
                        "-Wall"
                        "-Wextra"
                        "-Werror"
                        "-fsyntax-only"
                        "-Ibindings/nono-c"
                        "bindings/nono-c/agentic_ai_lab_nono_binding_probe.c"))
        (check-equal? (nono-c-binding-build-compiler override) "cc")
        (check-equal? (nono-c-binding-build-upstream-include-dirs override)
                      '("/opt/nono/include"))
        (check-equal? (test-ref (car missing-errors) 'code)
                      'path-not-found)))
    (yuanxu-test-case "projects nono runtime manifests into C capability plans"
      (let* ((profile (make-nono-agent-sandbox-profile
                       'always-further/opencode))
             (request (agent-sandbox-request
                       profile
                       (command "opencode")
                       (args '("--print" "hello"))
                       (env '((OPENAI_API_KEY . redacted)))
                       (workdir "/workspace")
                       (mounts '(((path . "/workspace")
                                  (kind . directory)
                                  (mode . read-write))
                                 ((path . "/workspace/config.json")
                                  (kind . file)
                                  (mode . read))))
                       (network-policy '((mode . proxy-only)
                                         (proxy-port . 11434)))
                       (capabilities '((allow-commands . ("opencode"))
                                       (block-commands . ("curl"))))
                       (resource-policy '((timeout-ms . 30000)))
                       (output-policy 'artifact)
                       (metadata '((agent . opencode)))))
             (manifest
              (agent-sandbox-request->nono-c-binding-manifest request))
             (binding (test-ref manifest 'binding))
             (backend (test-ref manifest 'backend))
             (process (test-ref manifest 'process))
             (plan (test-ref manifest 'capability-plan))
             (path-call (cadr plan))
             (file-call (caddr plan))
             (network-call (cadddr plan))
             (proxy-call (car (cddddr plan))))
        (check-equal? (test-ref manifest 'schema)
                      +nono-c-binding-schema+)
        (check-equal? (test-ref binding 'library) "nono_ffi")
        (check-equal? (test-ref backend 'kind) 'nono)
        (check-equal? (test-ref process 'argv)
                      '("opencode" "--print" "hello"))
        (check-equal? (test-ref (car plan) 'function)
                      'nono_capability_set_new)
        (check-equal? (test-ref path-call 'function)
                      'nono_capability_set_allow_path)
        (check-equal? (test-ref path-call 'access-constant)
                      'NONO_ACCESS_MODE_READ_WRITE)
        (check-equal? (test-ref file-call 'function)
                      'nono_capability_set_allow_file)
        (check-equal? (test-ref file-call 'access-constant)
                      'NONO_ACCESS_MODE_READ)
        (check-equal? (test-ref network-call 'network-constant)
                      'NONO_NETWORK_MODE_PROXY_ONLY)
        (check-equal? (test-ref proxy-call 'function)
                      'nono_capability_set_set_proxy_port)
        (check-equal? (test-ref (test-ref manifest 'query-plan)
                                'query-path)
                      'nono_query_context_query_path)
        (check-equal? (test-ref (test-ref manifest 'diagnostic-plan)
                                'last-code)
                      'nono_last_diagnostic_code)
        (check-equal? (test-ref (test-ref manifest 'diagnostic-plan)
                                'session-report-json)
                      'nono_session_diagnostic_report_to_json)
        (check-equal? (test-ref (test-ref manifest 'apply-plan)
                                'apply)
                      'nono_sandbox_apply)))
    (yuanxu-test-case "dry-runs and native-tests nono C binding manifests without applying sandbox"
      (let* ((request (agent-sandbox-request
                       (make-nono-agent-sandbox-profile
                        'always-further/opencode)
                       (command "opencode")
                       (args '("--print" "hello"))
                       (workdir "/workspace")
                       (mounts '(((path . "/workspace")
                                  (kind . directory)
                                  (mode . read-write))))
                       (network-policy '((mode . blocked)))))
             (runtime-manifest
              (agent-sandbox-request->runtime-manifest request))
             (dry-run
              (nono-c-binding-dry-run runtime-manifest))
             (smoke
              (nono-c-binding-smoke-test
               runtime-manifest
               '("sh" "-c" "printf nono-smoke")))
             (live-skip
              (nono-c-binding-native-live-test
               runtime-manifest
               '((library-path . "run/no-such-libnono_ffi.dylib"))))
             (live-default
              (nono-c-binding-native-live-test runtime-manifest)))
        (check-equal? (test-ref dry-run 'schema)
                      +nono-c-binding-dry-run-receipt-schema+)
        (check-equal? (test-ref dry-run 'ok?) #t)
        (check-equal? (test-ref dry-run 'would-apply?) #f)
        (check-equal? (test-ref dry-run 'runtime-executed) #f)
        (check-equal? (test-ref dry-run 'apply-function)
                      'nono_sandbox_apply)
        (check-equal? (> (test-ref dry-run 'capability-plan-count) 0)
                      #t)
        (check-equal? (test-ref smoke 'schema)
                      +nono-c-binding-smoke-test-receipt-schema+)
        (check-equal? (test-ref smoke 'ok?) #t)
        (check-equal? (test-ref smoke 'status) 0)
        (check-equal? (test-ref smoke 'output) "nono-smoke")
        (check-equal? (test-ref smoke 'runtime-executed) #f)
        (check-equal? (test-ref (test-ref smoke 'dry-run) 'would-apply?)
                      #f)
        (check-equal? (test-ref live-skip 'schema)
                      +nono-c-binding-native-live-test-receipt-schema+)
        (check-equal? (test-ref live-skip 'ok?) #t)
        (check-equal? (test-ref live-skip 'enabled?) #f)
        (check-equal? (test-ref live-skip 'skipped?) #t)
        (check-equal? (test-ref live-skip 'skip-reason)
                      'native-library-not-found)
        (check-equal? (test-ref live-skip 'native-executed) #f)
        (check-equal? (test-ref live-skip 'cli-executed) #f)
        (check-equal? (test-ref live-skip 'runtime-executed) #f)
        (check-equal? (test-ref live-skip 'would-apply?) #f)
        (check-equal? (test-ref live-default 'schema)
                      +nono-c-binding-native-live-test-receipt-schema+)
        (check-equal? (test-ref live-default 'ok?) #t)
        (check-equal? (or (test-ref live-default 'enabled?)
                          (test-ref live-default 'skipped?))
                      #t)
        (check-equal? (test-ref live-default 'cli-executed) #f)
        (check-equal? (test-ref live-default 'runtime-executed) #f)
        (check-equal? (test-ref live-default 'would-apply?)
                      #f)))
    (yuanxu-test-case "rejects non-nono, unsupported, and legacy mount policy"
      (let* ((cube-request
              (agent-sandbox-request
               (make-cube-agent-sandbox-profile 'python-template)
               (command "python")
               (args '("-c" "print(1)"))
               (workdir "/workspace")
               (mounts '(((path . "/workspace")
                          (kind . directory)
                          (mode . read))))))
             (nono-request
              (agent-sandbox-request
               (make-nono-agent-sandbox-profile 'always-further/opencode)
               (command "opencode")
               (mounts '(((path . "/workspace")
                          (kind . directory)
                          (mode . execute))))))
             (legacy-type-request
              (agent-sandbox-request
               (make-nono-agent-sandbox-profile 'always-further/opencode)
               (command "opencode")
               (mounts '(((path . "/workspace")
                          (type . directory)
                          (mode . read))))))
             (cube-failure
              (with-catch (lambda (failure) failure)
                          (lambda ()
                            (agent-sandbox-request->nono-c-binding-manifest
                             cube-request))))
             (mode-failure
              (with-catch (lambda (failure) failure)
                          (lambda ()
                            (agent-sandbox-request->nono-c-binding-manifest
                             nono-request))))
             (legacy-type-failure
              (with-catch (lambda (failure) failure)
                          (lambda ()
                            (agent-sandbox-request->nono-c-binding-manifest
                             legacy-type-request)))))
        (check-equal? (execution-failure? cube-failure) #t)
        (check-equal? (execution-failure-code cube-failure)
                      'invalid-nono-c-binding-manifest)
        (check-equal? (execution-failure? mode-failure) #t)
        (check-equal? (execution-failure-code mode-failure)
                      'invalid-nono-c-binding-manifest)
        (check-equal? (execution-failure? legacy-type-failure) #t)
        (check-equal? (execution-failure-code legacy-type-failure)
                      'invalid-nono-c-binding-manifest)))))
