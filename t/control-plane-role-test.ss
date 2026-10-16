;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO role descriptors are control-plane metadata, not runtime work.

(import :core/composition/roles
        (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        :poo-flow/modules/workflow/control-plane/api)

(export control-plane-role-test)

;;; This suite keeps POO role projection aligned with the public workflow
;;; surface.
;; : TestSuite
(def control-plane-role-test
  (test-suite "poo role descriptors"
    (poo-flow-test-case "declares control-plane roles as Gerbil POO objects"
      (check-equal? (role-object? flow-role) #t)
      (check-equal? (role-name flow-role) 'flow)
      (check-equal? (role-kind branch-role) 'composition)
      (check-equal? (role-kind strategy-role) 'policy)
      (check-equal? (role-kind execution-policy-role) 'policy-envelope)
      (check-equal? (role-kind run-config-role) 'configuration)
      (check-equal? (role-kind replay-role) 'policy)
      (check-equal? (role-runtime-owner runtime-adapter-role)
                    'rust-or-external-runtime)
      (check-equal? (role-responsibility branch-role) 'dag-fanout-join)
      (check-equal? (role-responsibility execution-policy-role)
                    'runtime-policy-handoff)
      (check-equal? (role-responsibility run-config-role)
                    'configured-runner-assembly)
      (check-equal? (role-responsibility replay-role) 'audit-validation)
      (check-equal? (role-responsibility receipt-role)
                    'execution-explanation))
    (poo-flow-test-case "composes role prototypes with leftmost precedence"
      (let ((composed (role-compose runtime-adapter-role flow-role)))
        (check-equal? (role-object? composed) #t)
        (check-equal? (role-name composed) 'runtime-adapter)
        (check-equal? (role-runtime-owner composed)
                      'rust-or-external-runtime)))))
