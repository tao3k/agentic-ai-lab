;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: live nono profile checks use native FFI, not the nono CLI.
;;; Invariant: irreversible sandbox apply is never performed by package tests.

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
        (only-in :clan/poo/object .o)
        :agentic-ai-lab/modules/agent-sandbox/api
        :agentic-ai-lab/modules/agent-sandbox/nono
        :agentic-ai-lab/modules/nono-sandbox/c-binding)

(export nono-sandbox-live-profile-test
        make-custom-cicd-ci-check-profile
        make-custom-cicd-ci-check-runtime-manifest
        nono-live-cicd-receipt)

(def +custom-cicd-profile-source+
  "user-interface/custom/my-module/profiles/cicd.ss")

(def +custom-cicd-ci-check-network-policy+
  '((mode . blocked)
    (source-policy . deny-by-default)))

(def +custom-cicd-ci-check-capabilities+
  '(process-run filesystem-read tmpdir))

(def +custom-cicd-ci-check-resource-policy+
  '((filesystem
     (scope . project-workspace)
     (paths
      ((role . project-workspace)
       (source . ".")
       (project-marker . "gerbil.pkg")
       (target . "/workspace/project")
       (mode . read-only)))
     (access . read-only))
    (cpu . 1)
    (memory . "1Gi")
    (timeout-ms . 90000)))

(def +custom-cicd-ci-check-metadata+
  `((intent . ci-check)
    (scope . cicd)
    (stage . check)
    (source . ,+custom-cicd-profile-source+)))

;; : (-> Alist Symbol Value)
(def (test-ref alist key)
  (cdr (assoc key alist)))

;; : (-> Alist Symbol Value)
(def (test-maybe-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;;; This is the user-interface/custom/my-module/profiles/cicd.ss ci/check
;;; declaration normalized into the backend profile object used by tests.
;; : (-> Unit AgentSandboxProfile)
(def (make-custom-cicd-ci-check-profile)
  (make-nono-agent-sandbox-profile
   'ci/check
   (list (cons 'network-policy +custom-cicd-ci-check-network-policy+)
         (cons 'capabilities +custom-cicd-ci-check-capabilities+)
         (cons 'resource-policy +custom-cicd-ci-check-resource-policy+)
         (cons 'metadata +custom-cicd-ci-check-metadata+))))

;; : (-> Unit AgentSandboxRequest)
(def (make-custom-cicd-ci-check-request)
  (agent-sandbox-request
   (make-custom-cicd-ci-check-profile)
   (command "sh")
   (args '("-lc" "printf agentic-ai-lab-native-cicd"))
   (workdir ".")
   (mounts '(((path . ".")
              (kind . directory)
              (mode . read-write))))
   (network-policy +custom-cicd-ci-check-network-policy+)
   (capabilities '((allow-commands . ("sh" "gxpkg"))))
   (resource-policy '((timeout-ms . 90000)))
   (metadata '((check . native-cicd-probe)))))

;; : (-> Unit AgentSandboxRuntimeManifest)
(def (make-custom-cicd-ci-check-runtime-manifest)
  (agent-sandbox-request->runtime-manifest
   (make-custom-cicd-ci-check-request)))

;; : (-> AgentSandboxRuntimeManifest Alist)
(def (nono-live-cicd-receipt runtime-manifest)
  (nono-c-binding-native-live-test runtime-manifest))

;; : (-> Unit PooUserModuleSelection)
(def (custom-cicd-nono-selection)
  (.o kind: "yuanxu.modules.user-selection.v1"
      user-group: 'sandbox
      user-module: 'nono-sandbox
      selection-flags: '(+native-ffi)
      source-ref: 'none
      entrypoint: 'none
      enabled?: #t))

;;; This suite validates live-profile request shape while keeping irreversible
;;; sandbox apply outside the test path.
;; : TestSuite
(def nono-sandbox-live-profile-test
  (test-suite "nono-sandbox native live user-interface profile"
    (yuanxu-test-case "normalizes custom ci/check profile into POO sandbox policy"
      (let ((profile (make-custom-cicd-ci-check-profile)))
        (check-equal? (agent-sandbox-profile-backend-kind profile) 'nono)
        (check-equal? (agent-sandbox-profile-backend-ref profile) 'ci/check)
        (check-equal? (agent-sandbox-profile-network-policy profile)
                      +custom-cicd-ci-check-network-policy+)
        (check-equal? (agent-sandbox-profile-capabilities profile)
                      +custom-cicd-ci-check-capabilities+)
        (check-equal? (agent-sandbox-profile-resource-policy profile)
                      +custom-cicd-ci-check-resource-policy+)
        (check-equal? (test-ref (agent-sandbox-profile-metadata profile)
                                'source)
                      +custom-cicd-profile-source+)))
    (yuanxu-test-case "projects ci/check into nono C binding manifest with filesystem sandbox"
      (let* ((runtime-manifest
              (make-custom-cicd-ci-check-runtime-manifest))
             (manifest
              (nono-c-binding-runtime-manifest->manifest runtime-manifest))
             (filesystem (test-ref runtime-manifest 'filesystem))
             (mount (car (test-ref filesystem 'mounts)))
             (plan (test-ref manifest 'capability-plan))
             (path-call (cadr plan))
             (network-call (caddr plan)))
        (check-equal? (test-ref runtime-manifest 'schema)
                      +agent-sandbox-runtime-manifest-schema+)
        (check-equal? (test-ref (test-ref runtime-manifest 'backend) 'kind)
                      'nono)
        (check-equal? (test-ref mount 'path) ".")
        (check-equal? (test-ref mount 'mode) 'read-write)
        (check-equal? (test-ref (test-ref runtime-manifest 'network-policy)
                                'mode)
                      'blocked)
        (check-equal? (test-ref path-call 'function)
                      'nono_capability_set_allow_path)
        (check-equal? (test-ref path-call 'access-constant)
                      'NONO_ACCESS_MODE_READ_WRITE)
        (check-equal? (test-ref network-call 'network-constant)
                      'NONO_NETWORK_MODE_BLOCKED)))
    (yuanxu-test-case "checks ci/check through native nono FFI"
      (let* ((runtime-manifest
              (make-custom-cicd-ci-check-runtime-manifest))
             (receipt (nono-live-cicd-receipt runtime-manifest)))
        (check-equal? (test-ref receipt 'schema)
                      +nono-c-binding-native-live-test-receipt-schema+)
        (check-equal? (test-ref receipt 'ok?) #t)
        (check-equal? (test-ref receipt 'cli-executed) #f)
        (check-equal? (test-ref receipt 'runtime-executed) #f)
        (check-equal? (test-ref receipt 'would-apply?) #f)
        (check-equal? (test-ref receipt 'irreversible-apply?) #f)
        (check-equal? (test-maybe-ref receipt 'command) #f)
        (if (test-ref receipt 'enabled?)
          (begin
            (check-equal? (test-ref receipt 'skipped?) #f)
            (check-equal? (test-ref receipt 'native-executed) #t)
            (check-equal? (test-ref receipt 'native-loaded?) #t)
            (check-equal? (test-ref receipt 'apply-symbol)
                          'nono_sandbox_apply)
            (check-equal? (test-ref receipt 'apply-null-only?) #t)
            (check-equal? (test-ref receipt 'apply-null-code)
                          +nono-c-binding-native-apply-null-error-code+)
            (check-equal? (test-ref receipt 'capability-roundtrip-code) 0))
          (begin
            (check-equal? (test-ref receipt 'skipped?) #t)
            (check-equal? (test-ref receipt 'skip-reason)
                          'native-library-not-found)))))
    (yuanxu-test-case "dispatches custom use-module binding to native nono FFI"
      (let* ((selection (custom-cicd-nono-selection))
             (runtime-manifest
              (make-custom-cicd-ci-check-runtime-manifest))
             (receipt
              (nono-c-binding-selection-live-test selection runtime-manifest)))
        (check-equal? (nono-c-binding-selection-binding selection)
                      'native-ffi)
        (check-equal? (test-ref receipt 'binding-source) 'use-module)
        (check-equal? (test-ref receipt 'selection-binding) 'native-ffi)
        (check-equal? (test-ref receipt 'selection-key)
                      '(sandbox . nono-sandbox))
        (check-equal? (test-ref receipt 'schema)
                      +nono-c-binding-native-live-test-receipt-schema+)
        (check-equal? (test-ref receipt 'cli-executed) #f)
        (check-equal? (test-ref receipt 'runtime-executed) #f)
        (check-equal? (test-ref receipt 'would-apply?) #f)
        (if (test-ref receipt 'enabled?)
          (begin
            (check-equal? (test-ref receipt 'native-executed) #t)
            (check-equal? (test-ref receipt 'apply-symbol)
                          'nono_sandbox_apply))
          (begin
            (check-equal? (test-ref receipt 'native-executed) #f)
            (check-equal? (test-ref receipt 'skip-reason)
                          'native-library-not-found)))))))
