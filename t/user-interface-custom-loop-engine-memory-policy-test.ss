;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: tests verify loop-engine memory-policy declaration contracts.
;;; Invariant: malformed memory policy rows fail before runtime projection.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        :yuanxu/module-system/selection/objects
        :agentic-ai-lab/modules/workflow/scenario/configuration/interface
        :agentic-ai-lab/modules/workflow/scenario/configuration/init-syntax)

(export user-interface-custom-loop-engine-memory-policy-test)

;;; Custom loop fixtures are tested through the public config presentation so
;;; memory-policy failures stay tied to real `use-module` declarations.
;; : (-> PooUserModuleSelection POOObject)
(def (custom-loop-memory-policy-presentation module-bundle)
  (agenticAiLabUserConfigPresentation
   (yuanxuUserConfig
    (yuanxu-user-module-bundles->modules (list module-bundle))
    (yuanxu-settings))))

;;; Duplicate memory policies for one loop case would make Marlin guess which
;;; state spine to bind. The POO lowering rejects that shape before receipt
;;; projection.
;; : (-> [PooUserModuleSelection])
(def (custom-loop-duplicate-memory-policy-module)
  (use-module loop-engine
    :config
    (.def (duplicate-memory-loop @ loop-engine-use-case name workflow)
      name: 'duplicate-memory-loop
      workflow: 'funflow-cicd)

    (.def (duplicate-memory-policy-a @ loop-engine-memory-policy use-case)
      use-case: 'duplicate-memory-loop)

    (.def (duplicate-memory-policy-b @ loop-engine-memory-policy use-case)
      use-case: 'duplicate-memory-loop)

    (.def (duplicate-memory-profile @ loop-engine-profile
                                     use-case memory-policies)
      use-case: duplicate-memory-loop
      memory-policies: (list duplicate-memory-policy-a
                             duplicate-memory-policy-b))))

;;; Memory policies are use-case-specific. A policy naming an undeclared loop is
;;; structurally invalid because no selected branch can bind it deterministically.
;; : (-> [PooUserModuleSelection])
(def (custom-loop-unmatched-memory-policy-module)
  (use-module loop-engine
    :config
    (.def (unmatched-memory-loop @ loop-engine-use-case name workflow)
      name: 'unmatched-memory-loop
      workflow: 'funflow-cicd)

    (.def (unmatched-memory-policy @ loop-engine-memory-policy use-case)
      use-case: 'missing-loop)

    (.def (unmatched-memory-profile @ loop-engine-profile
                                     use-case memory-policies)
      use-case: unmatched-memory-loop
      memory-policies: (list unmatched-memory-policy))))

;;; Duplicate policy coverage ensures a selected use-case has exactly one memory
;;; contract before receipts are emitted for Marlin.
;; : TestCase
(def (user-interface-custom-loop-engine-duplicate-memory-policy-case)
  (yuanxu-test-case "rejects duplicate loop-engine memory-policies"
    (check-equal?
     (with-catch
      (lambda (_) #t)
      (lambda ()
        (custom-loop-memory-policy-presentation
         (custom-loop-duplicate-memory-policy-module))
        #f))
     #t)))

;;; Unmatched policy coverage rejects dangling memory contracts so typoed
;;; use-case names do not become inert but misleading runtime handoff data.
;; : TestCase
(def (user-interface-custom-loop-engine-unmatched-memory-policy-case)
  (yuanxu-test-case "rejects loop-engine memory-policy for undeclared use-case"
    (check-equal?
     (with-catch
      (lambda (_) #t)
      (lambda ()
        (custom-loop-memory-policy-presentation
         (custom-loop-unmatched-memory-policy-module))
        #f))
     #t)))

;;; The suite isolates memory-policy contract failures from the larger custom
;;; loop-engine presentation test, keeping negative POO-native cases explicit.
;; : TestSuite
(def user-interface-custom-loop-engine-memory-policy-test
  (test-suite "agentic-ai-lab custom loop-engine memory-policy contracts"
    (user-interface-custom-loop-engine-duplicate-memory-policy-case)
    (user-interface-custom-loop-engine-unmatched-memory-policy-case)))
