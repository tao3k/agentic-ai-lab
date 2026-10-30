;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: user-interface presentation hot path stays bounded.
;;; Invariant: public authoring remains POO-native; generated runtime receipts
;;; are fixed structs until Marlin ABI handoff serialization.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run/result)
        (only-in :clan/poo/object .ref .slot? object?)
        "../support/performance"
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-settings
                 yuanxu-user-module-bundles->modules
                 yuanxuUserConfig)
        (only-in :agentic-ai-lab/modules/workflow/scenario/configuration/presentation-config
                 agenticAiLabUserConfigPresentation)
        (only-in :agentic-ai-lab/modules/loop-engine/runtime
                 loop-engine-capability-receipt?)
        (only-in "../../user-interface/custom/my-module/cases/loop-engine-owner"
                 agentic-ai-lab-custom-my-module-loop-engine-case))

(export user-interface-presentation-performance-test)

;; : String
(def user-interface-presentation-fixture-path
  "t/scenarios/performance/user-interface-presentation-batch-projection/benchmark.ss")

;; : UserInterfacePresentationFixture
(def user-interface-presentation-fixture
  (call-with-input-file user-interface-presentation-fixture-path read))

;; : Integer
(def user-interface-presentation-module-count 7)

;; : (-> UserInterfacePresentationRow UserInterfacePresentationKey UserInterfacePresentationValue)
(def (user-interface-presentation-ref value key)
  (cond
   ((and (object? value) (.slot? value key))
    (.ref value key))
   ((pair? value)
    (let (entry (assoc key value))
      (and entry (cdr entry))))
   (else #f)))

;; : (-> [UserInterfacePresentationValue] Bool)
(def (user-interface-presentation-all-capability-receipts? values)
  (cond
   ((null? values) #t)
   ((loop-engine-capability-receipt? (car values))
    (user-interface-presentation-all-capability-receipts? (cdr values)))
   (else #f)))

;; : (-> [UserInterfacePresentationValue] Bool)
(def (user-interface-presentation-all-alists? values)
  (cond
   ((null? values) #t)
   ((and (pair? (car values))
         (not (object? (car values))))
    (user-interface-presentation-all-alists? (cdr values)))
   (else #f)))

;; : (-> Integer [[PooUserModuleSelection]])
(def (user-interface-presentation-module-bundles count)
  (agentic-ai-lab-performance-build-list
   count
   (lambda (_index)
     agentic-ai-lab-custom-my-module-loop-engine-case)))

;; : (-> Integer UserInterfacePresentationObject)
(def (user-interface-presentation-build count)
  (agenticAiLabUserConfigPresentation
   (yuanxuUserConfig
    (yuanxu-user-module-bundles->modules
     (user-interface-presentation-module-bundles count))
    (yuanxu-settings))))

;; : (-> Integer UserInterfacePresentationSummary)
(def (user-interface-presentation-summary count)
  (let* ((presentation
          (user-interface-presentation-build count))
         (capability-receipts
          (.ref presentation 'loop-engine-capability-receipts))
         (runtime-handoffs
          (.ref presentation 'loop-engine-runtime-handoffs))
         (runtime-handoff-capability-receipts
          (map (lambda (handoff)
                 (user-interface-presentation-ref
                  handoff
                  'capability-receipt))
               runtime-handoffs)))
    (list
     (cons 'module-count (.ref presentation 'module-count))
     (cons 'loop-engine-intent-count
           (.ref presentation 'loop-engine-intent-count))
     (cons 'loop-engine-runtime-handoff-count
           (.ref presentation 'loop-engine-runtime-handoff-count))
     (cons 'capability-receipt-count (length capability-receipts))
     (cons 'struct-capability-receipts?
           (user-interface-presentation-all-capability-receipts?
            capability-receipts))
     (cons 'runtime-handoff-capability-receipts-serialized?
           (user-interface-presentation-all-alists?
            runtime-handoff-capability-receipts))
     (cons 'presentation-trace-kind
           (user-interface-presentation-ref
            (.ref presentation 'presentation-trace)
            'kind))
     (cons 'runtime-executed (.ref presentation 'runtime-executed)))))

;; : (-> UserInterfacePresentationSummary ReceiptDisplayResult)
(def (user-interface-presentation-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] user-interface-presentation-batch-projection ")
  (write receipt)
  (newline)
  (force-output))

;; : TestSuite
(def user-interface-presentation-performance-test
  (test-suite "user-interface presentation performance"
    (yuanxu-test-case "keeps batch presentation projection inside benchmark contract"
      (let-values (((receipt summary)
                    (benchmark-run/result
                     user-interface-presentation-fixture
                     (lambda ()
                       (user-interface-presentation-summary
                        user-interface-presentation-module-count)))))
        (check-equal?
         (benchmark-fixture-contract-pass? user-interface-presentation-fixture)
         #t)
        (check-equal?
         (user-interface-presentation-ref summary 'module-count)
         user-interface-presentation-module-count)
        (check-equal?
         (user-interface-presentation-ref summary 'loop-engine-intent-count)
         user-interface-presentation-module-count)
        (check-equal?
         (user-interface-presentation-ref
          summary
          'loop-engine-runtime-handoff-count)
         user-interface-presentation-module-count)
        (check-equal?
         (user-interface-presentation-ref summary 'capability-receipt-count)
         user-interface-presentation-module-count)
        (check-equal?
         (user-interface-presentation-ref summary 'struct-capability-receipts?)
         #t)
        (check-equal?
         (user-interface-presentation-ref
          summary
          'runtime-handoff-capability-receipts-serialized?)
         #t)
        (check-equal?
         (user-interface-presentation-ref summary 'runtime-executed)
         #f)
        (user-interface-presentation-display-receipt receipt)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
