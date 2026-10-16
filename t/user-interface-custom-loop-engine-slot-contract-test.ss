;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: focused user-interface loop-engine POO slot contract failures.
;;; Invariant: malformed slots fail before presentation emits intent rows.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        :core/module-system/selection/objects
        :poo-flow/modules/workflow/scenario/configuration/interface
        :poo-flow/modules/workflow/scenario/configuration/init-syntax)

(export user-interface-custom-loop-engine-slot-contract-test)

;;; Invalid POO slot fixture covers fail-fast structural validation before
;;; malformed objects can be lowered into intent rows or manifests.
;; : (-> [PooUserModuleSelection])
(def (custom-loop-invalid-poo-slot-module)
  (use-module loop-engine
    :config
    (.def (invalid-poo-slot-loop @ loop-engine-use-case name workflow)
      name: 'invalid-poo-slot-loop
      workflow: 'funflow-cicd)

    (.def (invalid-poo-slot-governor @ loop-engine-governor capabilities)
      capabilities: '+strategy)

    (.def (invalid-poo-slot-profile @ loop-engine-profile
                                     use-case governor)
      use-case: invalid-poo-slot-loop
      governor: invalid-poo-slot-governor)))

;;; Memory policy slot validation is intentionally structural: recall and
;;; commit must be symbol lists before the runtime manifest is projected.
;; : (-> [PooUserModuleSelection])
(def (custom-loop-invalid-memory-slot-module)
  (use-module loop-engine
    :config
    (.def (invalid-memory-slot-loop @ loop-engine-use-case name workflow)
      name: 'invalid-memory-slot-loop
      workflow: 'funflow-cicd)

    (.def (invalid-memory-slot-policy @ loop-engine-memory-policy
                                      use-case recall)
      use-case: 'invalid-memory-slot-loop
      recall: 'bad-recall)

    (.def (invalid-memory-slot-profile @ loop-engine-profile
                                        use-case memory-policies)
      use-case: invalid-memory-slot-loop
      memory-policies: (list invalid-memory-slot-policy))))

;;; Compression policy is report-only but still structurally typed.
;; : (-> [PooUserModuleSelection])
(def (custom-loop-invalid-compression-slot-module)
  (use-module loop-engine
    :config
    (.def (invalid-compression-slot-loop @ loop-engine-use-case
                                         name workflow)
      name: 'invalid-compression-slot-loop
      workflow: 'funflow-cicd)

    (.def (invalid-compression-slot-policy
           @ loop-engine-compression-policy
           strategy)
      strategy: "not-a-symbol")

    (.def (invalid-compression-slot-profile @ loop-engine-profile
                                             use-case compression-policy)
      use-case: invalid-compression-slot-loop
      compression-policy: invalid-compression-slot-policy)))

;;; Presentation construction is the public gate under test; private validators
;;; are only reachable through downstream-style `use-module` declarations.
;; : (-> [PooUserModuleSelection] POOObject)
(def (custom-loop-presentation module-bundle)
  (pooFlowUserConfigPresentation
   (pooFlowUserConfig
    (poo-flow-user-module-bundles->modules (list module-bundle))
    (poo-flow-settings))))

;;; POO object slot contracts fail before presentation can emit bad intent rows.
;; : TestCase
(def (user-interface-custom-loop-engine-invalid-poo-slot-case)
  (poo-flow-test-case "rejects invalid loop-engine POO object slot types"
    (check-equal?
     (with-catch
      (lambda (_) #t)
      (lambda ()
        (custom-loop-presentation (custom-loop-invalid-poo-slot-module))
        #f))
     #t)))

;;; Memory policy gets the same POO slot contract treatment as other loop
;;; objects: malformed recall/commit declarations never become receipts.
;; : TestCase
(def (user-interface-custom-loop-engine-invalid-memory-slot-case)
  (poo-flow-test-case "rejects invalid loop-engine memory-policy slot types"
    (check-equal?
     (with-catch
      (lambda (_) #t)
      (lambda ()
        (custom-loop-presentation
         (custom-loop-invalid-memory-slot-module))
        #f))
     #t)))

;;; Compression policy has the same fail-fast POO slot boundary as memory.
;; : TestCase
(def (user-interface-custom-loop-engine-invalid-compression-slot-case)
  (poo-flow-test-case "rejects invalid loop-engine compression-policy slot types"
    (check-equal?
     (with-catch
      (lambda (_) #t)
      (lambda ()
        (custom-loop-presentation
         (custom-loop-invalid-compression-slot-module))
        #f))
     #t)))

;; : TestSuite
(def user-interface-custom-loop-engine-slot-contract-test
  (test-suite "poo-flow custom loop-engine slot contracts"
    (user-interface-custom-loop-engine-invalid-poo-slot-case)
    (user-interface-custom-loop-engine-invalid-memory-slot-case)
    (user-interface-custom-loop-engine-invalid-compression-slot-case)))
