;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: invalid Funflow POO configs fail at the declarative contract.

(import (only-in :tao3k/yuanxu/modules/funflow/config-adapter yuanxu-funflow-poo-pipeline->check-map)
        (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :tao3k/yuanxu/modules/funflow/config-prototypes funflow-check funflow-pipeline)
         (only-in :std/test check-equal? test-suite)
        :agentic-ai-lab/modules/workflow/scenario/configuration/entrypoints
        :agentic-ai-lab/modules/workflow/scenario/configuration/presentation-config
        :agentic-ai-lab/modules/workflow/scenario/configuration/selection-policy
        :agentic-ai-lab/modules/workflow/funflow-config)

(export funflow-config-pipeline-error-test)

;; : Boolean
(def agentic-ai-lab-import-side-effect-test-suite? #t)

;; : (-> (-> Unit Object) Boolean)
(def (funflow-config-error? thunk)
  (let (failure (with-catch (lambda (failure) failure) thunk))
    (error-object? failure)))

;; : (-> Unit [PooUserModuleSelection])
(def (funflow-config-workflow-category-selection)
  (agentic-ai-lab-product-use-module 'workflow '()))

;; : (-> Unit [PooUserModuleSelection])
(def (funflow-config-bad-dependency-selection)
  (let ()
    (.def (funflow-test/bad @ funflow-check)
      check-name: 'bad
      profile-ref: 'ci/check
      command-vector: '("gerbil" "build")
      dependency-refs: '("build"))
    (.def (funflow-test/bad-pipeline @ funflow-pipeline)
      pipeline-name: 'bad
      checks: (list funflow-test/bad))
    (agentic-ai-lab-product-use-module 'funflow
      (agentic-ai-lab-funflow-config-flags
        (yuanxu-funflow-poo-pipeline->check-map funflow-test/bad-pipeline)
        (list ':config funflow-test/bad-pipeline)))))

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
