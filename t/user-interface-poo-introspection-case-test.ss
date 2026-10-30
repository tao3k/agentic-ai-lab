;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: tests the public CI/CD POO authoring gate user config.
;;; Invariant: assertions inspect formal use-module data, not runtime work.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        :yuanxu/module-system/selection/objects
        :agentic-ai-lab/modules/workflow/scenario/configuration/interface
        :agentic-ai-lab/modules/workflow/scenario/configuration/init-syntax
        :agentic-ai-lab/modules/workflow/interface
        (only-in "../user-interface/custom/my-module/cases/poo-introspection"
                 agentic-ai-lab-custom-my-module-poo-introspection-case))

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
  (test-suite "agentic-ai-lab user interface POO authoring gate case"
    (yuanxu-test-case "loads as a formal funflow module configuration"
      (let* ((selection (car agentic-ai-lab-custom-my-module-poo-introspection-case))
             (flags (yuanxu-user-module-selection-flags selection))
             (pipeline
              (poo-introspection-test-flag flags ':workflow-pipeline))
             (user-config
              (poo-introspection-test-flag flags ':user-config))
             (checks (yuanxu-cicd-check-map-checks pipeline))
             (profile-authoring-check (car checks))
             (funflow-readiness-check (cadr checks)))
        (check-equal? (yuanxu-user-module-selection-key selection)
                      '(flow . funflow))
        (check-equal? (yuanxu-cicd-check-map? pipeline) #t)
        (check-equal? (yuanxu-cicd-check-map-name pipeline)
                      'poo-authoring-gate)
        (check-equal? (.ref pipeline 'runtime-executed) #f)
        (check-equal? (car user-config) ':config)
        (check-equal? (caadr user-config) '.def)
        (check-equal? (map yuanxu-cicd-check-name checks)
                      '(profile-authoring funflow-readiness))
        (check-equal? (yuanxu-cicd-check-profile
                       profile-authoring-check)
                      'ci/build)
        (check-equal? (yuanxu-cicd-check-profile
                       funflow-readiness-check)
                      'ci/check)))
    (yuanxu-test-case "keeps POO authoring observability on check metadata"
      (let* ((selection (car agentic-ai-lab-custom-my-module-poo-introspection-case))
             (flags (yuanxu-user-module-selection-flags selection))
             (pipeline
              (poo-introspection-test-flag flags ':workflow-pipeline))
             (checks (yuanxu-cicd-check-map-checks pipeline))
             (profile-authoring-check (car checks))
             (funflow-readiness-check (cadr checks))
             (profile-authoring-metadata
              (.ref profile-authoring-check 'metadata))
             (funflow-readiness-metadata
              (.ref funflow-readiness-check 'metadata)))
        (check-equal? (yuanxu-cicd-check-command
                       profile-authoring-check)
                      '("gxpkg"
                        "env"
                        "gxtest"
                        "t/sandbox-core-profile-authoring-diagnostics-test.ss"))
        (check-equal? (yuanxu-cicd-check-command
                       funflow-readiness-check)
                      '("gxpkg"
                        "env"
                        "gxtest"
                        "t/user-interface-cicd-pipeline-run-test.ss"))
        (check-equal? (yuanxu-cicd-check-dependency-refs
                       profile-authoring-check)
                      '())
        (check-equal? (yuanxu-cicd-check-dependency-refs
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
