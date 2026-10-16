;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: tests the public CI/CD POO authoring gate user config.
;;; Invariant: assertions inspect formal use-module data, not runtime work.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        :core/module-system/selection/objects
        :poo-flow/modules/workflow/scenario/configuration/interface
        :poo-flow/modules/workflow/scenario/configuration/init-syntax
        :poo-flow/modules/workflow/interface
        (only-in "../user-interface/custom/my-module/cases/poo-introspection"
                 poo-flow-custom-my-module-poo-introspection-case))

(export user-interface-poo-introspection-case-test)

;; : (-> Alist Symbol Value)
(def (poo-introspection-test-alist-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;; : (-> [UserModuleFlagEntry] Symbol Value)
(def (poo-introspection-test-flag flags key)
  (cond
   ((null? flags) #f)
   ((and (pair? (car flags))
         (equal? (caar flags) key))
    (cdar flags))
   (else
    (poo-introspection-test-flag (cdr flags) key))))

;; : TestSuite
(def user-interface-poo-introspection-case-test
  (test-suite "poo-flow user interface POO authoring gate case"
    (poo-flow-test-case "loads as a formal funflow module configuration"
      (let* ((selection (car poo-flow-custom-my-module-poo-introspection-case))
             (flags (poo-flow-user-module-selection-flags selection))
             (pipeline
              (poo-introspection-test-flag flags ':workflow-pipeline))
             (user-config
              (poo-introspection-test-flag flags ':user-config))
             (checks (poo-flow-cicd-check-map-checks pipeline))
             (profile-authoring-check (car checks))
             (funflow-readiness-check (cadr checks)))
        (check-equal? (poo-flow-user-module-selection-key selection)
                      '(flow . funflow))
        (check-equal? (poo-flow-cicd-check-map? pipeline) #t)
        (check-equal? (poo-flow-cicd-check-map-name pipeline)
                      'poo-authoring-gate)
        (check-equal? (.ref pipeline 'runtime-executed) #f)
        (check-equal? (car user-config) ':config)
        (check-equal? (caadr user-config) '.def)
        (check-equal? (map poo-flow-cicd-check-name checks)
                      '(profile-authoring funflow-readiness))
        (check-equal? (poo-flow-cicd-check-profile
                       profile-authoring-check)
                      'ci/build)
        (check-equal? (poo-flow-cicd-check-profile
                       funflow-readiness-check)
                      'ci/check)))
    (poo-flow-test-case "keeps POO authoring observability on check metadata"
      (let* ((selection (car poo-flow-custom-my-module-poo-introspection-case))
             (flags (poo-flow-user-module-selection-flags selection))
             (pipeline
              (poo-introspection-test-flag flags ':workflow-pipeline))
             (checks (poo-flow-cicd-check-map-checks pipeline))
             (profile-authoring-check (car checks))
             (funflow-readiness-check (cadr checks))
             (profile-authoring-metadata
              (.ref profile-authoring-check 'metadata))
             (funflow-readiness-metadata
              (.ref funflow-readiness-check 'metadata)))
        (check-equal? (poo-flow-cicd-check-command
                       profile-authoring-check)
                      '("gxpkg"
                        "env"
                        "gxtest"
                        "t/sandbox-core-profile-authoring-diagnostics-test.ss"))
        (check-equal? (poo-flow-cicd-check-command
                       funflow-readiness-check)
                      '("gxpkg"
                        "env"
                        "gxtest"
                        "t/user-interface-cicd-pipeline-run-test.ss"))
        (check-equal? (poo-flow-cicd-check-dependency-refs
                       profile-authoring-check)
                      '())
        (check-equal? (poo-flow-cicd-check-dependency-refs
                       funflow-readiness-check)
                      '(profile-authoring))
        (check-equal? (poo-introspection-test-alist-ref
                       profile-authoring-metadata
                       'observability)
                      'poo-slot-authoring-summary)
        (check-equal? (poo-introspection-test-alist-ref
                       profile-authoring-metadata
                       'observes)
                      '(profile-slots
                        object-extension
                        funflow-check-metadata))
        (check-equal? (poo-introspection-test-alist-ref
                       profile-authoring-metadata
                       'guards)
                      '(self-referential-slot-initializer
                        primitive-shadow-slot))
        (check-equal? (poo-introspection-test-alist-ref
                       profile-authoring-metadata
                       'report)
                      'authoring-report)
        (check-equal? (poo-introspection-test-alist-ref
                       funflow-readiness-metadata
                       'observability)
                      #f)))))
