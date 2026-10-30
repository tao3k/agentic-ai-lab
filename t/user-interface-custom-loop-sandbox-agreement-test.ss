;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: focused tests for loop-engine sandbox handoff agreement receipts.
;;; Invariant: sandbox agreement projection is report-only and never starts runtime.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        (only-in :yuanxu/module-system/selection/objects
                 yuanxuUserConfig
                 yuanxu-settings
                 yuanxu-user-module-bundles->modules
                 yuanxu-user-module-selection)
        (only-in :agentic-ai-lab/modules/agent-sandbox/config
                 agentic-ai-lab-sandbox-profile-config)
        (only-in :agentic-ai-lab/modules/workflow/scenario/configuration/presentation-config
                 agenticAiLabUserConfigPresentation)
        (only-in "../user-interface/custom/my-module/cases/loop-engine-owner"
                 agentic-ai-lab-custom-my-module-loop-engine-case))

(export user-interface-custom-loop-sandbox-agreement-test)

;;; Local alist lookup keeps this focused test independent of presentation
;;; internals while still asserting the exact public receipt shape.
;; : (-> Alist Symbol MaybeValue)
(def (test-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;;; Repeated diagnostic assertions stay about field values instead of manual
;;; traversal so the test reads like agreement behavior, not list plumbing.
;; : (-> [Alist] Symbol [Value])
(def (test-field-values rows key)
  (map (lambda (row) (test-ref row key)) rows))

;;; Config presentation is the public boundary for agreement checks; the helper
;;; keeps fixture construction separate from the assertions about receipts.
;; : (-> [PooUserModuleSelection] POOObject)
(def (custom-loop-presentation/bundles module-bundles)
  (agenticAiLabUserConfigPresentation
   (yuanxuUserConfig
    (yuanxu-user-module-bundles->modules module-bundles)
    (yuanxu-settings))))

;;; The concrete loop case references `ci/build`. These focused fixtures use
;;; the public POO profile constructor directly, so agreement qualification
;;; does not expand the aggregate downstream profile syntax owner.
;; : Metadata
(def custom-loop-sandbox-profile-metadata
  '((intent . loop-engine-ci-build)
    (scope . test)))

;; : ResourcePolicy
(def custom-loop-sandbox-resource-policy
  '((filesystem
     (scope . project-workspace)
     (paths
      ((role . project-workspace)
       (source . ".")
       (project-marker . "gerbil.pkg")
       (mode . read-write)))
     (access . read-write))))

;; : (-> PooSandboxProfile)
(def (custom-loop-sandbox-profile)
  (agentic-ai-lab-sandbox-profile-config
   'ci/build
   (list '(backend nono)
         '(network deny-network)
         '(capabilities process-run filesystem-read filesystem-write tmpdir)
         (cons 'resources custom-loop-sandbox-resource-policy)
         (cons 'metadata custom-loop-sandbox-profile-metadata))))

;; : [PooUserModuleSelection]
(def custom-loop-sandbox-profile-module
  (list
   (yuanxu-user-module-selection
    'sandbox
    'nono-sandbox
    (list (cons ':config (list (custom-loop-sandbox-profile)))))))

;;; Invalid sandbox profile keeps the reference resolvable while making the
;;; filesystem capability/resource agreement fail as report-only data.
;; : ResourcePolicy
(def custom-loop-invalid-sandbox-resource-policy
  '((cpu . 2)
    (memory . "4Gi")
    (timeout-ms . 300000)))

;; : Metadata
(def custom-loop-invalid-sandbox-profile-metadata
  '((intent . loop-engine-invalid-ci-build)
    (scope . test)))

;; : (-> PooSandboxProfile)
(def (custom-loop-invalid-sandbox-profile)
  (agentic-ai-lab-sandbox-profile-config
   'ci/build
   (list '(backend nono)
         '(network deny-network)
         '(capabilities filesystem-read process-run)
         (cons 'resources custom-loop-invalid-sandbox-resource-policy)
         (cons 'metadata custom-loop-invalid-sandbox-profile-metadata))))

;; : [PooUserModuleSelection]
(def custom-loop-invalid-sandbox-profile-module
  (list
   (yuanxu-user-module-selection
    'sandbox
    'nono-sandbox
    (list
     (cons ':config (list (custom-loop-invalid-sandbox-profile)))))))

;;; Valid sandbox resolution proves the agreement receipt travels through the
;;; intent, runtime manifest, and public presentation slots unchanged.
;; : TestCase
(def (user-interface-custom-loop-engine-sandbox-case)
  (yuanxu-test-case "resolves sandbox profile summaries into loop-engine manifest"
    (let* ((presentation
            (custom-loop-presentation/bundles
             (list custom-loop-sandbox-profile-module
                   agentic-ai-lab-custom-my-module-loop-engine-case)))
           (intent
            (car (.ref presentation 'loop-engine-intents)))
           (runtime-manifest
            (test-ref intent 'runtime-command-manifest))
           (runtime-manifest-request
            (test-ref runtime-manifest 'request))
           (sandbox-runtime-summaries
            (test-ref intent 'sandbox-runtime-summaries))
           (sandbox-runtime-summary
            (car sandbox-runtime-summaries))
           (sandbox-filesystem
            (test-ref sandbox-runtime-summary 'filesystem))
           (sandbox-handoff-summaries
            (test-ref intent 'sandbox-handoff-summaries))
           (sandbox-handoff-summary
            (car sandbox-handoff-summaries))
           (sandbox-agreement
            (test-ref intent 'sandbox-handoff-agreement)))
      (check-equal? (.ref presentation 'module-count) 2)
      (check-equal? (test-ref intent 'sandbox-profile-refs) '(ci/build))
      (check-equal? (test-ref intent 'sandbox-unresolved-profile-refs) '())
      (check-equal? (test-ref sandbox-runtime-summary 'schema)
                    'agentic-ai-lab.agent-sandbox-profile.runtime-summary.v1)
      (check-equal? (test-ref sandbox-runtime-summary 'profile-name)
                    'ci/build)
      (check-equal? (test-ref sandbox-runtime-summary 'backend-kind) 'nono)
      (check-equal? (test-ref sandbox-runtime-summary 'valid?) #t)
      (check-equal? (test-ref sandbox-filesystem 'path-count) 1)
      (check-equal? (test-ref sandbox-filesystem 'scope) 'project-workspace)
      (check-equal? (test-ref sandbox-handoff-summary 'schema)
                    'agentic-ai-lab.agent-sandbox-profile.handoff-summary.v1)
      (check-equal? (test-ref sandbox-handoff-summary 'profile-name)
                    'ci/build)
      (check-equal? (test-ref sandbox-agreement 'valid?) #t)
      (check-equal? (test-ref sandbox-agreement 'diagnostic-count) 0)
      (check-equal? (test-ref sandbox-agreement 'handoff-summary-count) 1)
      (check-equal? (test-ref runtime-manifest-request
                              'sandbox-runtime-summaries)
                    sandbox-runtime-summaries)
      (check-equal? (test-ref runtime-manifest-request
                              'sandbox-handoff-summaries)
                    sandbox-handoff-summaries)
      (check-equal? (test-ref runtime-manifest-request
                              'sandbox-unresolved-profile-refs)
                    '())
      (check-equal? (test-ref runtime-manifest-request
                              'sandbox-handoff-agreement)
                    sandbox-agreement)
      (check-equal? (car (.ref presentation
                                'loop-engine-sandbox-runtime-summaries))
                    sandbox-runtime-summaries)
      (check-equal? (car (.ref presentation
                                'loop-engine-sandbox-handoff-summaries))
                    sandbox-handoff-summaries)
      (check-equal? (car (.ref presentation
                                'loop-engine-sandbox-handoff-agreements))
                    sandbox-agreement))))

;;; Invalid but resolvable profiles prove agreement diagnostics can report bad
;;; sandbox shapes without throwing from the handoff summary path.
;; : TestCase
(def (user-interface-custom-loop-engine-invalid-sandbox-case)
  (yuanxu-test-case "diagnoses invalid sandbox profile agreement"
    (let* ((presentation
            (custom-loop-presentation/bundles
             (list custom-loop-invalid-sandbox-profile-module
                   agentic-ai-lab-custom-my-module-loop-engine-case)))
           (intent
            (car (.ref presentation 'loop-engine-intents)))
           (runtime-manifest
            (test-ref intent 'runtime-command-manifest))
           (runtime-manifest-request
            (test-ref runtime-manifest 'request))
           (runtime-snapshot
            (test-ref intent 'runtime-snapshot))
           (sandbox-runtime-summaries
            (test-ref intent 'sandbox-runtime-summaries))
           (sandbox-agreement
            (test-ref intent 'sandbox-handoff-agreement)))
      (check-equal? (test-ref intent 'sandbox-unresolved-profile-refs) '())
      (check-equal? (test-ref (car sandbox-runtime-summaries) 'valid?) #f)
      (check-equal? (test-ref intent 'sandbox-handoff-summaries) '())
      (check-equal? (test-ref sandbox-agreement 'valid?) #f)
      (check-equal? (test-ref sandbox-agreement
                              'invalid-runtime-summary-count)
                    1)
      (check-equal? (test-field-values
                     (test-ref sandbox-agreement 'diagnostics)
                     'code)
                    '(invalid-sandbox-runtime-summaries))
      (check-equal? (test-ref runtime-manifest-request
                              'sandbox-handoff-agreement)
                    sandbox-agreement)
      (check-equal? (test-ref (test-ref runtime-snapshot 'metadata)
                              'handoff-ready?)
                    #f)
      (check-equal? (car (.ref presentation
                                'loop-engine-sandbox-handoff-agreements))
                    sandbox-agreement)
      (check-equal? (test-ref intent 'runtime-executed) #f))))

;; : TestSuite
(def user-interface-custom-loop-sandbox-agreement-test
  (test-suite "agentic-ai-lab custom user-interface loop sandbox agreement"
    (user-interface-custom-loop-engine-sandbox-case)
    (user-interface-custom-loop-engine-invalid-sandbox-case)))
