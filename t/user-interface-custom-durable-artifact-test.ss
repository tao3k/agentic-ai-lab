;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: custom user-interface durable artifact policy scenario.
;;; Invariant: user config declares POO artifact policy data and bounded
;;; receipts only; runtime artifact storage/indexing/publishing stays outside
;;; Scheme.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in "../user-interface/custom/my-module/cases/durable-artifact"
                 agentic-ai-lab-custom-my-module-durable-artifact-case))

(export user-interface-custom-durable-artifact-test)

;; : (-> Alist Symbol Object)
(def (test-ref row key)
  (let (entry (assoc key row))
    (if entry (cdr entry) #f)))

;; : TestSuite
(def user-interface-custom-durable-artifact-test
  (test-suite "agentic-ai-lab custom durable artifact case"
    (yuanxu-test-case "projects POO artifact policy to bounded receipts"
      (let* ((row agentic-ai-lab-custom-my-module-durable-artifact-case)
             (profile (test-ref row 'profile))
             (database (test-ref row 'database))
             (artifact (test-ref row 'artifact))
             (policy-receipt (test-ref row 'policy-receipt))
             (manifest-receipt (test-ref row 'manifest-receipt))
             (marlin-handoff (test-ref row 'marlin-handoff)))
        (check-equal? (test-ref row 'kind)
                      'agentic-ai-lab.custom.durable-artifact)
        (check-equal? (test-ref row 'valid?) #t)
        (check-equal? (test-ref row 'runtime-executed) #f)
        (check-equal? (test-ref profile 'name) 'custom-report)
        (check-equal? (test-ref profile 'runtime-executed) #f)
        (check-equal? (test-ref database 'name) 'turso)
        (check-equal? (test-ref database 'source)
                      'agentic-ai-lab.durable.artifact.database)
        (check-equal? (test-ref artifact 'artifact-id)
                      'artifact/custom-report)
        (check-equal? (test-ref artifact 'lifecycle-state) 'created)
        (check-equal? (test-ref artifact 'runtime-executed) #f)
        (check-equal? (test-ref policy-receipt 'artifact-id)
                      'artifact/custom-report)
        (check-equal? (test-ref policy-receipt 'profile-name)
                      'custom-report)
        (check-equal? (test-ref policy-receipt 'database-name) 'turso)
        (check-equal? (test-ref policy-receipt 'valid?) #t)
        (check-equal? (test-ref policy-receipt 'diagnostics) '())
        (check-equal? (test-ref policy-receipt 'runtime-executed) #f)
        (check-equal? (test-ref manifest-receipt 'manifest-id)
                      'artifact-manifest/custom-report)
        (check-equal? (test-ref manifest-receipt 'handoff-required) #t)
        (check-equal? (test-ref manifest-receipt 'runtime-executed) #f)
        (check-equal? (test-ref marlin-handoff 'kind)
                      'agentic-ai-lab.durable.artifact.marlin-handoff)
        (check-equal? (test-ref marlin-handoff 'handoff-ready?) #t)
        (check-equal? (test-ref marlin-handoff 'runtime-executed) #f)
        (check-equal? (test-ref marlin-handoff 'runtime-parses-scheme-source)
                      #f)))))
