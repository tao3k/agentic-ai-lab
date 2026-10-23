;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: invalid Funflow POO configs fail at the declarative contract.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :yuanxu/modules/funflow/config-prototypes funflow-check funflow-pipeline)
         (only-in :std/test check-equal? test-suite)
        :agentic-ai-lab/modules/workflow/scenario/configuration/interface
        :agentic-ai-lab/modules/workflow/scenario/configuration/init-syntax)

(export funflow-config-pipeline-error-test)

;; : Boolean
(def agentic-ai-lab-import-side-effect-test-suite? #t)

;; : (-> (-> Unit Object) Boolean)
(def (funflow-config-error? thunk)
  (let (failure (with-catch (lambda (failure) failure) thunk))
    (error-object? failure)))

;; : (-> Unit [PooUserModuleSelection])
(def (funflow-config-workflow-category-selection)
  (use-module workflow
    :config
    (pipeline default)))

;; : (-> Unit [PooUserModuleSelection])
(def (funflow-config-bad-dependency-selection)
  (use-module funflow
    :config
    (.def (funflow-test/bad @ funflow-check
                            check-name profile-ref command-vector
                            dependency-refs)
      check-name: 'bad
      profile-ref: 'ci/check
      command-vector: '("gerbil" "build")
      dependency-refs: '("build"))
    (.def (funflow-test/bad-pipeline @ funflow-pipeline
                                     pipeline-name checks)
      pipeline-name: 'bad
      checks: (list funflow-test/bad))))

;; : (-> Unit Symbol)
(def (run-funflow-config-pipeline-error-checks)
  (check-equal?
   (funflow-config-error?
    (lambda ()
      (funflow-config-workflow-category-selection)
      #f))
   #t)
  (check-equal?
   (funflow-config-error?
   (lambda ()
     (funflow-config-bad-dependency-selection)
     #f))
   #t)
  'ok)

(def funflow-config-pipeline-error-test
  (test-suite "agentic-ai-lab Funflow config contract errors"
    (yuanxu-test-case "rejects invalid Funflow POO declarations"
      (check-equal? (run-funflow-config-pipeline-error-checks) 'ok))))
