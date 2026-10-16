;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: focused user-interface loop-engine result contract diagnostics.
;;; Invariant: invalid result contracts are reported, never executed.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        :core/module-system/selection/objects
        :poo-flow/modules/workflow/scenario/configuration/interface
        :poo-flow/modules/workflow/scenario/configuration/init-syntax)

(export user-interface-custom-loop-engine-result-contract-test)

;;; Result-contract diagnostics are validated through presentation rows so the
;;; test covers the same public shape that downstream agents inspect.
;; : (-> Alist Symbol MaybeValue)
(def (test-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;;; Diagnostic code extraction keeps assertions focused on the public receipt
;;; data instead of depending on private validator internals.
;; : (-> [Alist] Symbol [Value])
(def (test-field-values rows key)
  (map (lambda (row) (test-ref row key)) rows))

;;; Invalid result contract fixture is intentionally minimal: it exercises the
;;; result-contract validator without introducing unrelated sandbox resolution.
;; : [PooUserModuleSelection]
(def custom-loop-invalid-result-module
  (use-module loop-engine
    :config
    (.def (invalid-result-loop @ loop-engine-use-case name workflow)
      name: 'invalid-result-loop
      workflow: 'funflow-cicd)

    (.def (invalid-result-human-audit @ loop-engine-human-audit actions)
      actions: '(+manual-gate))

    (.def (invalid-result-contract @ loop-engine-result
                                   human-audit format required-fields)
      human-audit: 'bad-contract
      format: 'structured-alist
      required-fields: '())

    (.def (invalid-result-runtime @ loop-engine-runtime capabilities)
      capabilities: '(+manifest-handoff))

    (.def (invalid-result-profile @ loop-engine-profile
                                  use-case human-audit result runtime)
      use-case: invalid-result-loop
      human-audit: invalid-result-human-audit
      result: invalid-result-contract
      runtime: invalid-result-runtime)))

;;; Presentation construction mirrors downstream use-module config and avoids
;;; calling result-contract validators directly.
;; : (-> [PooUserModuleSelection] POOObject)
(def (custom-loop-presentation module-bundle)
  (pooFlowUserConfigPresentation
   (pooFlowUserConfig
    (poo-flow-user-module-bundles->modules (list module-bundle))
    (poo-flow-settings))))

;;; Invalid result contracts remain reportable config data: presentation and
;;; runtime manifests surface diagnostics, but no runtime work is executed.
;; : TestCase
(def (user-interface-custom-loop-engine-invalid-result-case)
  (poo-flow-test-case "diagnoses invalid loop-engine result contract"
    (let* ((presentation
            (custom-loop-presentation custom-loop-invalid-result-module))
           (intent
            (car (.ref presentation 'loop-engine-intents)))
           (result-contract
            (test-ref intent 'result-contract))
           (runtime-manifest
            (test-ref intent 'runtime-command-manifest))
           (runtime-manifest-request
            (test-ref runtime-manifest 'request))
           (diagnostics
            (test-ref result-contract 'diagnostics)))
      (check-equal? (test-ref result-contract 'valid?) #f)
      (check-equal? (test-ref result-contract 'diagnostic-count) 1)
      (check-equal? (test-field-values diagnostics 'code)
                    '(invalid-result-required-fields))
      (check-equal? (test-ref (test-ref runtime-manifest-request
                                         'result-contract)
                              'valid?)
                    #f)
      (check-equal? (car (.ref presentation 'loop-engine-result-contracts))
                    result-contract)
      (check-equal? (test-ref intent 'runtime-executed) #f))))

;; : TestSuite
(def user-interface-custom-loop-engine-result-contract-test
  (test-suite "poo-flow custom loop-engine result contract"
    (user-interface-custom-loop-engine-invalid-result-case)))
