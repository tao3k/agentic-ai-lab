;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: tests verify Funflow CI/CD user intent presentation.
;;; Invariant: CI/CD facts stay declarative and never execute adapters.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-user-module-selection-key
                 yuanxu-user-module-selection-flag-entry)
        (only-in :agentic-ai-lab/modules/workflow/scenario/configuration/presentation-config
                 agenticAiLabUserConfigPresentation)
        (only-in :agentic-ai-lab/modules/workflow/cicd-config
                 agentic-ai-lab-user-config-cicd-intents
                 agentic-ai-lab-user-workflow-cicd-marlin-handoff-receipt-bundle)
        (only-in "../user-interface/custom/my-module/cases/cicd"
                 agentic-ai-lab-custom-my-module-cicd-case)
        (only-in "./support/user-interface-cicd-runtime-fixture"
                 user-interface-cicd-runtime-fixture-config))

(export user-interface-cicd-test)

;; : (-> Symbol Alist Value)
(def (alist-value key entries)
  (let (entry (assoc key entries))
    (if entry (cdr entry) #f)))

;; : (-> [Alist] Symbol MaybeAlist)
(def (user-interface-cicd-trace-stage trace stage)
  (cond
   ((null? trace) #f)
   ((equal? (alist-value 'stage (car trace)) stage) (car trace))
   (else
    (user-interface-cicd-trace-stage (cdr trace) stage))))

;; : (-> Unit TestSuite)
;;; This suite keeps CI/CD user-interface assembly separate from runtime
;;; execution.
(def user-interface-cicd-test
  (test-suite "agentic-ai-lab user interface cicd payload"
    (yuanxu-test-case "presents Funflow CI/CD payload as user intent data"
      (let* ((intents
              (agentic-ai-lab-user-config-cicd-intents
               (user-interface-cicd-runtime-fixture-config)))
             (intent (car intents)))
        (check-equal? (length intents) 1)
        (check-equal? (alist-value 'key intent) '(flow . funflow))
        (check-equal? (alist-value 'feature intent) '+cicd)
        (check-equal? (alist-value 'checks intent)
                      '(+parallel +typed-receipts))
        (check-equal? (alist-value 'artifacts intent) '(+export))
        (check-equal? (alist-value 'release intent) '(+manual-gate))
        (check-equal? (alist-value 'webhook intent) '(+server))
        (check-equal? (alist-value 'runtime intent) '(+manifest-handoff))
        (check-equal? (alist-value 'runtime-handoff intent)
                      'runtime-command-manifest)
        (check-equal? (alist-value 'runtime-owner intent)
                      "marlin-agent-core")
        (check-equal? (alist-value 'runtime-executed intent) #f)))
    (yuanxu-test-case "imports downstream CI/CD case through its module owner"
      (let* ((selection (car agentic-ai-lab-custom-my-module-cicd-case))
             (inherits
              (yuanxu-user-module-selection-flag-entry selection ':inherits))
             (command
              (yuanxu-user-module-selection-flag-entry selection ':command))
             (nono
              (yuanxu-user-module-selection-flag-entry selection ':nono)))
        (check-equal? (yuanxu-user-module-selection-key selection)
                      '(sandbox . nono-sandbox))
        (check-equal? inherits '(:inherits . ci/build))
        (check-equal? command
                      '(:command
                        (program . "gxpkg")
                        (args . ("build"))))
        (check-equal? nono
                      '(:nono
                        (network . blocked)
                        (audit . disabled)))))
    (yuanxu-test-case "traces CI/CD presentation projection without runtime work"
      (let* ((presentation
              (agenticAiLabUserConfigPresentation
               (user-interface-cicd-runtime-fixture-config)))
             (trace (.ref presentation 'presentation-trace))
             (cicd-step
              (user-interface-cicd-trace-stage trace 'cicd-intents))
             (dag-step
              (user-interface-cicd-trace-stage
               trace
               'workflow-cicd-functional-dags)))
        (check-equal? (.ref presentation 'cicd-intent-count) 1)
        (check-equal? (alist-value 'stage cicd-step) 'cicd-intents)
        (check-equal? (alist-value 'count cicd-step) 1)
        (check-equal? (alist-value 'descriptor-realized? cicd-step) #f)
        (check-equal? (alist-value 'runtime-executed cicd-step) #f)
        (check-equal? (alist-value 'stage dag-step)
                      'workflow-cicd-functional-dags)
        (check-equal? (alist-value 'count dag-step) 1)))
    (yuanxu-test-case "presents Funflow pipeline and functional DAG"
      (let* ((presentation
              (agenticAiLabUserConfigPresentation
               (user-interface-cicd-runtime-fixture-config)))
             (dags (.ref presentation 'workflow-cicd-functional-dags))
             (dag (car dags))
             (composition-steps (alist-value 'composition-steps dag))
             (first-composition-step (car composition-steps))
             (first-bind-step (car (cdddr composition-steps)))
             (edges (alist-value 'edges dag))
             (edge (car edges)))
        (check-equal? (.ref presentation 'workflow-cicd-pipeline-count) 1)
        (check-equal? (.ref presentation 'workflow-cicd-functional-dag-count)
                      1)
        (check-equal? (alist-value 'kind dag)
                      'yuanxu.funflow.functional-dag.prototype)
        (check-equal? (alist-value 'composition-style dag)
                      'arrow-kleisli)
        (check-equal? (alist-value 'composition-step-count dag) 5)
        (check-equal? (alist-value 'step-kind first-composition-step)
                      'arrow-node)
        (check-equal? (alist-value 'check-name first-composition-step)
                      'build)
        (check-equal? (alist-value 'composition-style first-composition-step)
                      'arrow)
        (check-equal? (alist-value 'step-kind first-bind-step)
                      'kleisli-bind)
        (check-equal? (alist-value 'from first-bind-step) 'build)
        (check-equal? (alist-value 'to first-bind-step) 'test)
        (check-equal? (alist-value 'composition-style first-bind-step)
                      'kleisli)
        (check-equal? (alist-value 'nodes dag) '(build test package))
        (check-equal? (alist-value 'entry-nodes dag) '(build))
        (check-equal? (alist-value 'terminal-nodes dag) '(package))
        (check-equal? (alist-value 'ready-order dag) '(build test package))
        (check-equal? (alist-value 'runtime-owner dag) "marlin-agent-core")
        (check-equal? (alist-value 'runtime-executed dag) #f)
        (check-equal? (alist-value 'from edge) 'build)
        (check-equal? (alist-value 'to edge) 'test)))
    (yuanxu-test-case "projects user config into Marlin runtime handoff ABI"
      (let* ((presentation
              (agenticAiLabUserConfigPresentation
               (user-interface-cicd-runtime-fixture-config)))
             (abis (.ref presentation
                         'workflow-cicd-marlin-runtime-handoff-abis))
             (summaries
              (.ref presentation
                    'workflow-cicd-marlin-runtime-handoff-summaries))
             (bundle
              (.ref presentation
                    'workflow-cicd-marlin-handoff-receipt-bundle))
             (abi (car abis))
             (summary (car summaries))
             (required-fields (alist-value 'required-fields abi))
             (entries (alist-value 'entries abi))
             (entry (car entries))
             (request (alist-value 'request entry)))
        (check-equal? (.ref presentation
                            'workflow-cicd-marlin-runtime-handoff-abi-count)
                      1)
        (check-equal? (.ref presentation
                            'workflow-cicd-marlin-runtime-handoff-summary-count)
                      1)
        (check-equal? (alist-value 'kind abi)
                      'agentic-ai-lab.workflow.cicd.marlin-runtime-handoff-abi)
        (check-equal? (alist-value 'runtime-owner abi)
                      "marlin-agent-core")
        (check-equal? (alist-value 'runtime-executed abi) #f)
        (check-equal? (alist-value 'runtime-parses-scheme-source abi) #f)
        (check-equal? (alist-value 'scheme-manufactures-runtime-handlers abi)
                      #f)
        (check-equal? (alist-value 'manifest-count abi) 3)
        (check-equal? (not (not (member 'durable-task-id required-fields)))
                      #t)
        (check-equal? (not (not (member 'artifact-provenance required-fields)))
                      #t)
        (check-equal? (not (not (member 'checkpoint-ref required-fields)))
                      #t)
        (check-equal? (length entries) 3)
        (check-equal? (alist-value 'runtime-owner entry)
                      "marlin-agent-core")
        (check-equal? (alist-value 'runtime-executed entry) #f)
        (check-equal? (alist-value 'durable-task-id entry)
                      'task/build)
        (check-equal? (alist-value 'action-class entry)
                      'idempotent)
        (check-equal? (alist-value 'artifact-refs entry)
                      '(build-log))
        (check-equal? (alist-value 'artifact-retention entry)
                      'project-retained)
        (check-equal? (alist-value 'sandbox-refs entry)
                      '(ci/build))
        (check-equal? (alist-value 'checkpoint-ref entry)
                      '(workflow-cicd-check build))
        (check-equal? (alist-value 'kind request)
                      'agentic-ai-lab.workflow.cicd.runtime-manifest-ready)
        (check-equal? (alist-value 'kind summary)
                      'workflow-cicd-marlin-runtime-handoff-abi-summary)
        (check-equal? (alist-value 'entry-count summary) 3)
        (check-equal? (alist-value 'runtime-owner summary)
                      "marlin-agent-core")
        (check-equal? (alist-value 'runtime-executed summary) #f)
        (check-equal? (alist-value 'kind bundle)
                      'workflow-cicd-marlin-handoff-receipt-bundle)
        (check-equal? (alist-value 'alignment-gate-id bundle)
                      'stage-23-user-interface-marlin-handoff-projection)
        (check-equal? (alist-value 'manifest-agreement-valid? bundle) #t)
        (check-equal? (alist-value 'marlin-runtime-handoff-abi-count bundle)
                      1)
        (check-equal? (alist-value 'marlin-runtime-handoff-summary-count bundle)
                      1)
        (check-equal? (alist-value 'receipt-count bundle) 3)
        (check-equal? (alist-value 'runtime-owner bundle)
                      "marlin-agent-core")
        (check-equal? (alist-value 'runtime-executed bundle) #f)))
    (yuanxu-test-case "projects empty Marlin handoff bundle entry count"
      (let ((bundle
             (agentic-ai-lab-user-workflow-cicd-marlin-handoff-receipt-bundle
              '()
              '()
              '((valid? . #t)
                (diagnostics . ())
                (rows . ()))
              '()
              '()
              '())))
        (check-equal? (alist-value 'kind bundle)
                      'workflow-cicd-marlin-handoff-receipt-bundle)
        (check-equal? (alist-value 'handoff-required bundle) #f)
        (check-equal? (alist-value 'marlin-runtime-handoff-entry-count bundle)
                      0)
        (check-equal? (alist-value 'runtime-executed bundle) #f)))))
