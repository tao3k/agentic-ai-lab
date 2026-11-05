;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: workflow presentation uses one POO projection constructor.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test check-equal? test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run/result)
        (only-in :clan/poo/object .ref)
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-settings
                 yuanxuUserConfig)
        (only-in :agentic-ai-lab/modules/workflow/scenario/configuration/presentation-config
                 agenticAiLabUserConfigPresentation)
        (only-in "../../user-interface/custom/my-module/cases/cicd-owner"
                 agentic-ai-lab-custom-my-module-cicd-module
                 agentic-ai-lab-custom-my-module-funflow-cicd-case))

(export workflow-presentation-runtime-projection-performance-test)

(def workflow-presentation-runtime-projection-fixture
  (call-with-input-file
   "t/scenarios/performance/workflow-presentation-runtime-projection/benchmark.ss"
   read))

(def (workflow-presentation-runtime-projection-summary)
  (let (presentation
        (agenticAiLabUserConfigPresentation
         (yuanxuUserConfig
          (append agentic-ai-lab-custom-my-module-cicd-module
                  agentic-ai-lab-custom-my-module-funflow-cicd-case)
          (yuanxu-settings))))
    (list
     (cons 'pipeline-count
           (.ref presentation 'workflow-cicd-pipeline-count))
     (cons 'manifest-count
           (.ref presentation
                 'workflow-cicd-runtime-command-manifest-summary-count))
     (cons 'handoff-abi-count
           (.ref presentation
                 'workflow-cicd-marlin-runtime-handoff-abi-count))
     (cons 'agreement-valid?
           (.ref presentation
                 'workflow-cicd-runtime-command-manifest-agreement-valid?))
     (cons 'runtime-executed (.ref presentation 'runtime-executed)))))

(def (workflow-presentation-runtime-projection-ref row key)
  (let (entry (assq key row))
    (and entry (cdr entry))))

(def workflow-presentation-runtime-projection-performance-test
  (test-suite "workflow presentation runtime projection performance"
    (yuanxu-test-case "keeps one runtime workflow projection inside the fixed gate"
      (let-values (((receipt summary)
                    (benchmark-run/result
                     workflow-presentation-runtime-projection-fixture
                     workflow-presentation-runtime-projection-summary)))
        (check-equal?
         (benchmark-fixture-contract-pass?
          workflow-presentation-runtime-projection-fixture)
         #t)
        (check-equal?
         (workflow-presentation-runtime-projection-ref summary 'pipeline-count)
         1)
        (check-equal?
         (workflow-presentation-runtime-projection-ref summary 'manifest-count)
         3)
        (check-equal?
         (workflow-presentation-runtime-projection-ref summary 'handoff-abi-count)
         1)
        (check-equal?
         (workflow-presentation-runtime-projection-ref summary 'agreement-valid?)
         #t)
        (check-equal?
         (workflow-presentation-runtime-projection-ref summary 'runtime-executed)
         #f)
        (display "[agentic-ai-lab-benchmark] workflow-presentation-runtime-projection ")
        (write receipt)
        (newline)
        (force-output)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
