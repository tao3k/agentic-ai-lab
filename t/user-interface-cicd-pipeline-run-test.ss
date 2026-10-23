;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: tests inspect Funflow CI/CD pipeline run/result presentation.
;;; Invariant: pipeline results are handoff-readiness data, not execution output.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        (only-in :yuanxu/modules/funflow/config-prototypes funflow-check funflow-pipeline)
        :yuanxu/module-system/selection/objects
        :agentic-ai-lab/modules/workflow/scenario/configuration/presentation-config
        :agentic-ai-lab/modules/workflow/scenario/configuration/init-syntax
        (only-in "../user-interface/custom/my-module/cases/cicd-owner"
                 agentic-ai-lab-custom-my-module-cicd-module
                 agentic-ai-lab-custom-my-module-funflow-cicd-case))

(export user-interface-cicd-pipeline-run-test)

;;; Public presentation rows are plain alists, so tests use the same lookup an
;;; agent or doc renderer would use instead of importing runtime internals.
;; : (-> Alist Symbol Value)
(def (pipeline-run-test-ref entries key)
  (let (entry (assoc key entries))
    (if entry (cdr entry) #f)))

;;; Trace lookup proves the new projection is wired through the user interface
;;; sequence, not just available from a lower-level helper.
;; : (-> [Alist] Symbol MaybeAlist)
(def (pipeline-run-test-trace-stage trace stage)
  (cond
   ((null? trace) #f)
   ((equal? (pipeline-run-test-ref (car trace) 'stage) stage)
    (car trace))
   (else
    (pipeline-run-test-trace-stage (cdr trace) stage))))

;;; This config mirrors the real custom init path: CI sandbox profiles are
;;; selected beside the Funflow pipeline before presentation is built.
;; : (-> Unit PooUserConfig)
(def (pipeline-run-test-config)
  (yuanxuUserConfig
   (append agentic-ai-lab-custom-my-module-cicd-module
           agentic-ai-lab-custom-my-module-funflow-cicd-case)
   (yuanxu-settings)))

;;; Invalid pipeline cases use the same user-facing Funflow POO syntax as
;;; init.ss; only the check graph/profile facts vary between cases.
;; : [PooUserModuleSelection]
(def pipeline-run-test-duplicate-case
  (use-module funflow
    :config
    (.def (pipeline-run-test/duplicate-build @ funflow-check
                                             check-name profile-ref
                                             command-vector result-protocol
                                             runtime-mode)
      check-name: 'build
      profile-ref: 'ci/build
      command-vector: '("true")
      result-protocol: '(read :lines)
      runtime-mode: 'manifest-handoff)
    (.def (pipeline-run-test/duplicate-check @ funflow-check
                                             check-name profile-ref
                                             command-vector result-protocol
                                             runtime-mode)
      check-name: 'build
      profile-ref: 'ci/check
      command-vector: '("true")
      result-protocol: '(read :lines)
      runtime-mode: 'manifest-handoff)
    (.def (pipeline-run-test/duplicate @ funflow-pipeline
                                       pipeline-name checks)
      pipeline-name: 'duplicate
      checks: (list pipeline-run-test/duplicate-build
                    pipeline-run-test/duplicate-check))))

;; : [PooUserModuleSelection]
(def pipeline-run-test-missing-dependency-case
  (use-module funflow
    :config
    (.def (pipeline-run-test/missing-test @ funflow-check
                                          check-name profile-ref
                                          command-vector result-protocol
                                          runtime-mode dependency-refs)
      check-name: 'test
      profile-ref: 'ci/check
      command-vector: '("true")
      result-protocol: '(read :lines)
      runtime-mode: 'manifest-handoff
      dependency-refs: '(missing))
    (.def (pipeline-run-test/missing-dependency @ funflow-pipeline
                                                pipeline-name checks)
      pipeline-name: 'missing-dependency
      checks: (list pipeline-run-test/missing-test))))

;; : [PooUserModuleSelection]
(def pipeline-run-test-cycle-case
  (use-module funflow
    :config
    (.def (pipeline-run-test/cycle-build @ funflow-check
                                         check-name profile-ref command-vector
                                         result-protocol runtime-mode
                                         dependency-refs)
      check-name: 'build
      profile-ref: 'ci/build
      command-vector: '("true")
      result-protocol: '(read :lines)
      runtime-mode: 'manifest-handoff
      dependency-refs: '(test))
    (.def (pipeline-run-test/cycle-test @ funflow-check
                                        check-name profile-ref command-vector
                                        result-protocol runtime-mode
                                        dependency-refs)
      check-name: 'test
      profile-ref: 'ci/check
      command-vector: '("true")
      result-protocol: '(read :lines)
      runtime-mode: 'manifest-handoff
      dependency-refs: '(build))
    (.def (pipeline-run-test/cycle @ funflow-pipeline
                                   pipeline-name checks)
      pipeline-name: 'cycle
      checks: (list pipeline-run-test/cycle-build
                    pipeline-run-test/cycle-test))))

;; : [PooUserModuleSelection]
(def pipeline-run-test-unresolved-sandbox-case
  (use-module funflow
    :config
    (.def (pipeline-run-test/unsafe @ funflow-check
                                    check-name profile-ref command-vector
                                    result-protocol runtime-mode)
      check-name: 'unsafe
      profile-ref: 'ci/missing
      command-vector: '("true")
      result-protocol: '(read :lines)
      runtime-mode: 'manifest-handoff)
    (.def (pipeline-run-test/unresolved-sandbox @ funflow-pipeline
                                                pipeline-name checks)
      pipeline-name: 'unresolved-sandbox
      checks: (list pipeline-run-test/unsafe))))

;;; Bad-case presentations still include the CI profile module so graph errors
;;; and sandbox-profile errors remain distinguishable.
;; : (-> [PooUserModuleSelection] POOObject)
(def (pipeline-run-test-presentation funflow-case)
  (agenticAiLabUserConfigPresentation
   (yuanxuUserConfig
    (append agentic-ai-lab-custom-my-module-cicd-module funflow-case)
    (yuanxu-settings))))

;;; The assertions bind the user-facing result to both trace accounting and the
;;; concrete run rows, preventing future UI changes from reporting fake results.
;; : TestSuite
(def user-interface-cicd-pipeline-run-test
  (test-suite "agentic-ai-lab user interface cicd pipeline run"
    (yuanxu-test-case "projects Funflow pipeline into handoff-ready run/result"
      (let* ((presentation
              (agenticAiLabUserConfigPresentation
               (pipeline-run-test-config)))
             (trace (.ref presentation 'presentation-trace))
             (run-step
              (pipeline-run-test-trace-stage
               trace
               'workflow-cicd-pipeline-runs))
             (result-step
              (pipeline-run-test-trace-stage
               trace
               'workflow-cicd-pipeline-results))
             (run (car (.ref presentation 'workflow-cicd-pipeline-runs)))
             (result
              (car (.ref presentation 'workflow-cicd-pipeline-results)))
             (steps (pipeline-run-test-ref run 'steps)))
        (check-equal? (.ref presentation 'workflow-cicd-pipeline-run-count)
                      1)
        (check-equal? (.ref presentation 'workflow-cicd-pipeline-result-count)
                      1)
        (check-equal? (pipeline-run-test-ref run-step 'count) 1)
        (check-equal? (pipeline-run-test-ref result-step 'count) 1)
        (check-equal? (pipeline-run-test-ref run 'check-map) 'default)
        (check-equal? (pipeline-run-test-ref run 'status) 'admitted)
        (check-equal? (pipeline-run-test-ref run 'ready-order)
                      '(build test package))
        (check-equal? (pipeline-run-test-ref run 'blocked-steps) '())
        (check-equal? (pipeline-run-test-ref run 'step-count) 3)
        (check-equal? (map (lambda (step)
                             (pipeline-run-test-ref step 'status))
                           steps)
                      '(admitted admitted admitted))
        (check-equal? (pipeline-run-test-ref result 'check-map) 'default)
        (check-equal? (pipeline-run-test-ref result 'status) 'handoff-ready)
        (check-equal? (pipeline-run-test-ref result 'valid?) #t)
        (check-equal? (pipeline-run-test-ref result 'runtime-executed) #f)))
    (yuanxu-test-case "blocks invalid pipelines with stable diagnostics"
      (let* ((duplicate-presentation
              (pipeline-run-test-presentation
               pipeline-run-test-duplicate-case))
             (duplicate-run
              (car (.ref duplicate-presentation
                         'workflow-cicd-pipeline-runs)))
             (duplicate-result
              (car (.ref duplicate-presentation
                         'workflow-cicd-pipeline-results)))
             (missing-presentation
              (pipeline-run-test-presentation
               pipeline-run-test-missing-dependency-case))
             (missing-run
              (car (.ref missing-presentation
                         'workflow-cicd-pipeline-runs)))
             (missing-result
              (car (.ref missing-presentation
                         'workflow-cicd-pipeline-results)))
             (cycle-presentation
              (pipeline-run-test-presentation
               pipeline-run-test-cycle-case))
             (cycle-run
              (car (.ref cycle-presentation
                         'workflow-cicd-pipeline-runs)))
             (cycle-result
              (car (.ref cycle-presentation
                         'workflow-cicd-pipeline-results)))
             (sandbox-presentation
              (pipeline-run-test-presentation
               pipeline-run-test-unresolved-sandbox-case))
             (sandbox-run
              (car (.ref sandbox-presentation
                         'workflow-cicd-pipeline-runs)))
             (sandbox-result
              (car (.ref sandbox-presentation
                         'workflow-cicd-pipeline-results))))
        (check-equal? (pipeline-run-test-ref duplicate-run 'status)
                      'blocked)
        (check-equal? (pipeline-run-test-ref duplicate-result 'diagnostics)
                      '(duplicate-nodes blocked-dependency-graph
                        blocked-steps))
        (check-equal? (pipeline-run-test-ref duplicate-result 'valid?) #f)
        (check-equal? (pipeline-run-test-ref missing-run 'status)
                      'blocked)
        (check-equal? (pipeline-run-test-ref missing-result 'diagnostics)
                      '(unresolved-dependency-refs blocked-dependency-graph
                        blocked-steps))
        (check-equal? (pipeline-run-test-ref missing-result 'valid?) #f)
        (check-equal? (pipeline-run-test-ref cycle-run 'status)
                      'blocked)
        (check-equal? (pipeline-run-test-ref cycle-result 'diagnostics)
                      '(cycle-detected blocked-dependency-graph blocked-steps))
        (check-equal? (pipeline-run-test-ref cycle-result 'valid?) #f)
        (check-equal? (pipeline-run-test-ref sandbox-run 'status)
                      'blocked)
        (check-equal? (pipeline-run-test-ref sandbox-result 'diagnostics)
                      '(unresolved-sandbox-profile-refs blocked-steps))
        (check-equal? (pipeline-run-test-ref sandbox-result 'blocked-steps)
                      '(unsafe))
        (check-equal? (pipeline-run-test-ref sandbox-result 'valid?) #f)))))
