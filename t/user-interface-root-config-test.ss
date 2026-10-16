;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: top-level root profile and modules-directory facade.
;;; Invariant: root config stays declarative and does not load test fixtures.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test check-equal? test-suite)
        (only-in :poo-flow/user-interface/init
                 poo-flow-user-module-bundles)
        (only-in :core/profile-composition/user-profile
                 pooFlowUserConfigFromProfile
                 poo-flow-user-profile?
                 poo-flow-user-profile-name
                 poo-flow-user-profile-module-bundles)
        (only-in :clan/poo/object .ref)
        (only-in :poo-flow/testing-api
                 +poo-flow-testing-interface+
                 poo-flow-testing-admit-user-profile!)
        (only-in :poo-flow/modules/workflow/scenario/configuration/root-profile
                 pooFlowRootProfile)
        (only-in :core/module-system/selection/objects
                 poo-flow-user-config-modules
                 poo-flow-user-config-module-keys
                 poo-flow-user-module-selection-key
                 poo-flow-user-module-selection-flags
                 poo-flow-user-module-selection-entrypoint))

(export user-interface-root-config-test)

(def root-config-profile
  (pooFlowRootProfile poo-flow-user-module-bundles))

(def root-config
  (pooFlowUserConfigFromProfile root-config-profile))

(def root-config-expected-module-keys
  '((flow . funflow)
    (session . session)
    (loop . governor)
    (sandbox . nono-sandbox)
    (sandbox . cubeSandbox)
    (sandbox . docker-sandbox)
    (flow . loop-engine)
    (custom . my-module)))

(def (root-config-module-selection-by-key modules key)
  (cond
   ((null? modules) #f)
   ((equal? (poo-flow-user-module-selection-key (car modules)) key)
    (car modules))
   (else
    (root-config-module-selection-by-key (cdr modules) key))))

(def user-interface-root-config-test
  (test-suite "poo-flow user interface root config"
    (poo-flow-test-case "loads modules directory facade through top-level config"
      (let* ((root-modules (poo-flow-user-config-modules root-config))
             (root-flow-module
              (root-config-module-selection-by-key root-modules
                                                   '(flow . funflow)))
             (root-custom-module
              (root-config-module-selection-by-key root-modules
                                                   '(custom . my-module))))
        (check-equal? (poo-flow-user-profile? root-config-profile) #t)
        (check-equal? (poo-flow-user-profile-name root-config-profile) 'users)
        (check-equal?
         (.ref (poo-flow-testing-admit-user-profile!
                +poo-flow-testing-interface+
                root-config-profile)
               'admitted?)
         #t)
        (check-equal? (length (poo-flow-user-profile-module-bundles
                               root-config-profile))
                      8)
        (check-equal? (length poo-flow-user-module-bundles) 5)
        (check-equal? (length root-modules) 8)
        (check-equal? (poo-flow-user-config-module-keys root-config)
                      root-config-expected-module-keys)
        (check-equal? (poo-flow-user-module-selection-flags root-flow-module)
                      '(+functional +dag +typed-receipts +runtime-manifest
                        (+cicd
                         (checks +parallel +typed-receipts)
                         (artifacts +export)
                         (release +manual-gate)
                         (webhook +server)
                         (runtime +manifest-handoff))))
        (check-equal? (poo-flow-user-module-selection-key root-custom-module)
                      '(custom . my-module))
        (check-equal?
         (poo-flow-user-module-selection-entrypoint root-custom-module)
         "./custom/my-module/interface.ss")))))
