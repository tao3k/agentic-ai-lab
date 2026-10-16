;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: focused user-interface loop-engine capability backend checks.
;;; Invariant: capability backends name registry backend-kind values, never
;;; runtime owners.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run)
        (only-in :clan/poo/object .ref .slot? object?)
        :core/module-system/selection/objects
        :poo-flow/modules/workflow/scenario/configuration/presentation-config
        (only-in :poo-flow/modules/loop-engine/runtime
                 loop-engine-capability-receipt?
                 poo-flow-user-loop-engine-capability-receipt-ref)
        :poo-flow/modules/workflow/scenario/configuration/init-syntax)

(export user-interface-custom-loop-engine-capability-test)

;;; Generated runtime receipts are fixed Scheme structs internally and project
;;; to bounded alists at presentation and runtime handoff boundaries. User POO
;;; authoring remains native.
;; | LoopEngineIntentRow = (Or POOObject LoopEngineCapabilityReceipt Alist)
;; | LoopEngineIntentKey = Symbol
;; : (-> LoopEngineIntentRow LoopEngineIntentKey MaybeValue)
(def (test-ref value key)
  (cond
   ((loop-engine-capability-receipt? value)
    (poo-flow-user-loop-engine-capability-receipt-ref value key #f))
   ((and (object? value) (.slot? value key)) (.ref value key))
   ((pair? value)
    (let (entry (assoc key value))
      (if entry (cdr entry) #f)))
   (else #f)))

;;; Field extraction keeps capability diagnostics readable across POO and
;;; serialized receipt shapes.
;; : (-> [Alist] Symbol [Value])
(def (test-field-values rows key)
  (map (lambda (row) (test-ref row key)) rows))

;; : String
(def invalid-capability-benchmark-path
  "t/scenarios/performance/loop-engine-invalid-capability-presentation/benchmark.ss")

;; : Alist
(def invalid-capability-benchmark
  (call-with-input-file invalid-capability-benchmark-path read))

;;; Invalid capability backend fixture protects the sandbox backend contract:
;;; user-facing backend names are static backend-kind values from the selected
;;; capability registry, not the Marlin runtime owner.
;; : [PooUserModuleSelection]
(def custom-loop-invalid-capability-module
  (use-module loop-engine
    :config
    (.def (invalid-capability-loop @ loop-engine-use-case name workflow)
      name: 'invalid-capability-loop
      workflow: 'funflow-cicd)

    (.def (invalid-capability-policy @ loop-engine-capability-policy
                                      backend required)
      backend: 'marlin-sandbox
      required: '(command-run))

    (.def (invalid-capability-profile @ loop-engine-profile
                                      use-case capability-policy)
      use-case: invalid-capability-loop
      capability-policy: invalid-capability-policy)))

;;; Presentation construction mirrors downstream use-module config: the test
;;; never calls private loop-engine lowering helpers directly.
;; : (-> [PooUserModuleSelection] POOObject)
(def (custom-loop-presentation module-bundle)
  (let* ((modules
          (poo-flow-user-module-bundles->modules (list module-bundle)))
         (config
          (pooFlowUserConfig modules (poo-flow-settings))))
    (pooFlowUserConfigPresentation config)))

;; : (-> Alist)
(def (custom-loop-invalid-capability-summary)
  (let* ((presentation
          (custom-loop-presentation custom-loop-invalid-capability-module))
         (receipt
          (car (.ref presentation 'loop-engine-capability-receipts))))
    (list
     (cons 'valid? (test-ref receipt 'valid?))
     (cons 'diagnostic-count (test-ref receipt 'diagnostic-count))
     (cons 'supported-backends (test-ref receipt 'supported-backends)))))

;; : (-> Alist Void)
(def (display-invalid-capability-benchmark receipt)
  (display "[poo-flow-benchmark] loop-engine-invalid-capability-presentation ")
  (write receipt)
  (newline)
  (force-output))

;;; Capability policy validates backend names through the selected static
;;; backend capability registry. Marlin is the runtime owner, not a backend
;;; capability value.
;; : TestCase
(def (user-interface-custom-loop-engine-invalid-capability-case)
  (poo-flow-test-case "diagnoses invalid loop-engine capability backend"
    (let* ((presentation
            (custom-loop-presentation custom-loop-invalid-capability-module))
           (intent
            (car (.ref presentation 'loop-engine-intents)))
           (capability-receipt
            (test-ref intent 'capability-receipt))
           (runtime-manifest
            (test-ref intent 'runtime-command-manifest))
           (runtime-manifest-request
            (test-ref runtime-manifest 'request))
           (diagnostics
            (test-ref capability-receipt 'diagnostics)))
      (check-equal? (test-ref capability-receipt 'backend) 'marlin-sandbox)
      (check-equal? (test-ref capability-receipt 'backend-kind) #f)
      (check-equal? (test-ref capability-receipt 'backend-capabilities) '())
      (check-equal? (test-ref capability-receipt 'valid?) #f)
      (check-equal? (test-ref capability-receipt 'diagnostic-count) 1)
      (check-equal? (test-field-values diagnostics 'code)
                    '(unsupported-capability-backend))
      (check-equal? (test-ref capability-receipt 'supported-backends)
                    '(sandbox))
      (check-equal? (test-ref (test-ref runtime-manifest-request
                                         'capability-receipt)
                              'valid?)
                    #f)
      (let (presentation-capability-receipt
            (car (.ref presentation 'loop-engine-capability-receipts)))
        (check-equal? (test-ref presentation-capability-receipt 'backend)
                      (test-ref capability-receipt 'backend))
        (check-equal? (test-ref presentation-capability-receipt 'valid?)
                      (test-ref capability-receipt 'valid?)))
      (check-equal? (test-ref intent 'runtime-executed) #f))))

;; : TestCase
(def (user-interface-custom-loop-engine-invalid-capability-performance-case)
  (poo-flow-test-case "keeps invalid capability presentation inside benchmark contract"
    (let* ((summary
            (custom-loop-invalid-capability-summary))
           (receipt
            (benchmark-run
             invalid-capability-benchmark
             custom-loop-invalid-capability-summary)))
      (check-equal?
       (benchmark-fixture-contract-pass? invalid-capability-benchmark)
       #t)
      (check-equal? (test-ref summary 'valid?) #f)
      (check-equal? (test-ref summary 'diagnostic-count) 1)
      (check-equal? (test-ref summary 'supported-backends) '(sandbox))
      (display-invalid-capability-benchmark receipt)
      (check-equal? (benchmark-receipt-pass? receipt) #t))))

;; : TestSuite
(def user-interface-custom-loop-engine-capability-test
  (test-suite "poo-flow custom loop-engine capability policy"
    (user-interface-custom-loop-engine-invalid-capability-case)
    (user-interface-custom-loop-engine-invalid-capability-performance-case)))
