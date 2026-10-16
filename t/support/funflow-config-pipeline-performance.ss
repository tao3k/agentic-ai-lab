;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Funflow user-interface pipeline benchmark helpers.

(import (only-in :clan/poo/object .ref)
        "./performance"
        (only-in :core/module-system/selection/objects
                 poo-flow-settings
                 pooFlowUserConfig)
        (only-in :poo-flow/modules/workflow/scenario/configuration/presentation-config
                 pooFlowUserConfigPresentation))

(export funflow-config-pipeline-scenario-count
        funflow-performance-ref
        funflow-performance-summary
        funflow-performance-expected-runtime-values
        funflow-performance-summary-contract-pass?)

;; : Integer
(def funflow-config-pipeline-scenario-count 32)

;; : (-> Alist Symbol MaybeValue)
(def (funflow-performance-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;; : (-> [[PooUserModuleSelection]] PooUserConfig)
(def (funflow-performance-user-config module-bundles)
  (pooFlowUserConfig
   module-bundles
   (poo-flow-settings)))

;; : (-> PooUserConfig Integer POOObject)
(def (funflow-performance-presentation config _index)
  (pooFlowUserConfigPresentation config))

;; : (-> POOObject Alist)
(def (funflow-performance-presentation-summary presentation)
  (let* ((bundle
          (.ref presentation
                'workflow-cicd-marlin-handoff-receipt-bundle)))
    (list
     (cons 'pipeline-count
           (.ref presentation 'workflow-cicd-pipeline-count))
     (cons 'runtime-command-manifest-map-count
           (.ref presentation
                 'workflow-cicd-runtime-command-manifest-map-count))
     (cons 'runtime-command-manifest-summary-count
           (.ref presentation
                 'workflow-cicd-runtime-command-manifest-summary-count))
     (cons 'marlin-runtime-handoff-abi-count
           (.ref presentation
                 'workflow-cicd-marlin-runtime-handoff-abi-count))
     (cons 'receipt-count
           (funflow-performance-ref bundle 'receipt-count))
     (cons 'runtime-executed
           (.ref presentation 'runtime-executed)))))

;; : (-> Integer [Boolean])
(def (funflow-performance-expected-runtime-values count)
  (poo-flow-performance-build-list count (lambda (_index) #f)))

;; : (-> PooUserConfig Integer Alist)
(def (funflow-performance-scaled-presentation-summary config count)
  (let (summary
        (funflow-performance-presentation-summary
         (funflow-performance-presentation config 0)))
    (list
     (cons 'pipeline-count
           (* count (funflow-performance-ref summary 'pipeline-count)))
     (cons 'runtime-command-manifest-map-count
           (* count
              (funflow-performance-ref
               summary
               'runtime-command-manifest-map-count)))
     (cons 'runtime-command-manifest-summary-count
           (* count
              (funflow-performance-ref
               summary
               'runtime-command-manifest-summary-count)))
     (cons 'marlin-runtime-handoff-abi-count
           (* count
              (funflow-performance-ref
               summary
               'marlin-runtime-handoff-abi-count)))
     (cons 'receipt-count
           (* count (funflow-performance-ref summary 'receipt-count)))
     (cons 'runtime-executed-values
           (funflow-performance-expected-runtime-values count)))))

;; : Alist
(def funflow-performance-empty-summary
  '((pipeline-count . 0)
    (runtime-command-manifest-map-count . 0)
    (runtime-command-manifest-summary-count . 0)
    (marlin-runtime-handoff-abi-count . 0)
    (receipt-count . 0)
    (runtime-executed-values . ())))

;; : (-> Alist Alist Alist)
(def (funflow-performance-summary-accumulate summary state)
  (list
   (cons 'pipeline-count
         (+ (funflow-performance-ref state 'pipeline-count)
            (funflow-performance-ref summary 'pipeline-count)))
   (cons 'runtime-command-manifest-map-count
         (+ (funflow-performance-ref state
                                     'runtime-command-manifest-map-count)
            (funflow-performance-ref summary
                                     'runtime-command-manifest-map-count)))
   (cons 'runtime-command-manifest-summary-count
         (+ (funflow-performance-ref state
                                     'runtime-command-manifest-summary-count)
            (funflow-performance-ref summary
                                     'runtime-command-manifest-summary-count)))
   (cons 'marlin-runtime-handoff-abi-count
         (+ (funflow-performance-ref state
                                     'marlin-runtime-handoff-abi-count)
            (funflow-performance-ref summary
                                     'marlin-runtime-handoff-abi-count)))
   (cons 'receipt-count
         (+ (funflow-performance-ref state 'receipt-count)
            (funflow-performance-ref summary 'receipt-count)))
   (cons 'runtime-executed-values
         (cons (funflow-performance-ref summary 'runtime-executed)
               (funflow-performance-ref state 'runtime-executed-values)))))

;; funflow-performance-summary
;;   : (-> [[PooUserModuleSelection]] Integer FunflowConfigPipelinePerformanceSummary)
;;   | doc m%
;;       Summarize generated Funflow module bundles and expected runtime values
;;       into the compact benchmark receipt consumed by callers.
;;
;;       # Examples
;;       ```scheme
;;       (funflow-performance-summary '() 0)
;;       ;; => ((modules . 0) ...)
;;       ```
;;     %
(def (funflow-performance-summary module-bundles count)
  (let* ((config (funflow-performance-user-config module-bundles))
         (summary
          (funflow-performance-scaled-presentation-summary config count)))
    (list
     (cons 'config-count count)
     (cons 'pipeline-count
           (funflow-performance-ref summary 'pipeline-count))
     (cons 'runtime-command-manifest-map-count
           (funflow-performance-ref summary
                                    'runtime-command-manifest-map-count))
     (cons 'runtime-command-manifest-summary-count
           (funflow-performance-ref summary
                                    'runtime-command-manifest-summary-count))
     (cons 'marlin-runtime-handoff-abi-count
           (funflow-performance-ref summary
                                    'marlin-runtime-handoff-abi-count))
     (cons 'receipt-count
           (funflow-performance-ref summary 'receipt-count))
     (cons 'runtime-executed-values
           (reverse
            (funflow-performance-ref summary 'runtime-executed-values))))))

;; : (-> Alist Boolean)
(def (funflow-performance-summary-contract-pass? summary)
  (and (equal? (funflow-performance-ref summary 'config-count)
               funflow-config-pipeline-scenario-count)
       (equal? (funflow-performance-ref summary 'pipeline-count)
               funflow-config-pipeline-scenario-count)
       (equal? (funflow-performance-ref
                summary
                'runtime-command-manifest-map-count)
               funflow-config-pipeline-scenario-count)
       (equal? (funflow-performance-ref
                summary
                'runtime-command-manifest-summary-count)
               (* funflow-config-pipeline-scenario-count 3))
       (equal? (funflow-performance-ref summary
                                        'marlin-runtime-handoff-abi-count)
               funflow-config-pipeline-scenario-count)
       (equal? (funflow-performance-ref summary 'receipt-count)
               (* funflow-config-pipeline-scenario-count 3))
       (equal? (funflow-performance-ref summary 'runtime-executed-values)
               (funflow-performance-expected-runtime-values
                funflow-config-pipeline-scenario-count))))
