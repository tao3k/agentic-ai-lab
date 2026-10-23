;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Funflow user-interface pipeline benchmark gate.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run/result)
        (only-in "../../user-interface/custom/my-module/profiles/cicd"
                 agentic-ai-lab-custom-my-module-cicd-module)
        (only-in "../../user-interface/custom/my-module/cases/funflow-cicd"
                 agentic-ai-lab-custom-my-module-funflow-cicd-case)
        "../support/funflow-config-pipeline-performance")

(export funflow-config-pipeline-performance-test)

;; : String
(def funflow-config-pipeline-fixture-path
  "t/scenarios/performance/funflow-config-pipeline/benchmark.ss")

;; : Alist
(def funflow-config-pipeline-fixture
  (call-with-input-file funflow-config-pipeline-fixture-path read))

;; : (-> Alist Void)
(def (funflow-config-pipeline-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] funflow-config-pipeline ")
  (write receipt)
  (newline)
  (force-output))

;; : (-> [[PooUserModuleSelection]])
(def (funflow-config-pipeline-module-bundles)
  (append agentic-ai-lab-custom-my-module-cicd-module
          agentic-ai-lab-custom-my-module-funflow-cicd-case))

;; : TestSuite
(def funflow-config-pipeline-performance-test
  (test-suite "funflow config pipeline performance"
    (yuanxu-test-case "keeps user-interface Funflow pipeline projection inside benchmark contract"
      (let-values (((receipt summary)
                    (benchmark-run/result
                     funflow-config-pipeline-fixture
                     (lambda ()
                       (funflow-performance-summary
                        (funflow-config-pipeline-module-bundles)
                        funflow-config-pipeline-scenario-count)))))
        (check-equal?
         (benchmark-fixture-contract-pass? funflow-config-pipeline-fixture)
         #t)
        (check-equal?
         (funflow-performance-summary-contract-pass? summary)
         #t)
        (funflow-config-pipeline-display-receipt receipt)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
