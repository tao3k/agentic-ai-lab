;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: top-level root profile and modules-directory facade.
;;; Invariant: root config stays declarative and does not load test fixtures.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test check-equal? test-suite)
        (only-in :poo-flow/user-interface/init
                 yuanxu-user-module-bundles)
        (only-in :yuanxu/profile-composition/user-profile
                 yuanxuUserConfigFromProfile
                 yuanxu-user-profile?
                 yuanxu-user-profile-name
                 yuanxu-user-profile-module-bundles)
        (only-in :clan/poo/object .ref)
        (only-in :poo-flow/dev/testing-api
                 +poo-flow-testing-interface+
                 poo-flow-testing-admit-user-profile!)
        (only-in :poo-flow/modules/workflow/scenario/configuration/root-profile
                 pooFlowRootProfile)
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-user-config-modules
                 yuanxu-user-config-module-keys
                 yuanxu-user-module-selection-key
                 yuanxu-user-module-selection-flags
                 yuanxu-user-module-selection-entrypoint))

(export user-interface-root-config-test)

(def root-config-profile
  (pooFlowRootProfile yuanxu-user-module-bundles))

(def root-config
  (yuanxuUserConfigFromProfile root-config-profile))

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
   ((equal? (yuanxu-user-module-selection-key (car modules)) key)
    (car modules))
   (else
    (root-config-module-selection-by-key (cdr modules) key))))

(def user-interface-root-config-test
  (test-suite "poo-flow user interface root config"
    (yuanxu-test-case "loads modules directory facade through top-level config"
      (let* ((root-modules (yuanxu-user-config-modules root-config))
             (root-flow-module
              (root-config-module-selection-by-key root-modules
                                                   '(flow . funflow)))
             (root-custom-module
              (root-config-module-selection-by-key root-modules
                                                   '(custom . my-module))))
        (check-equal? (yuanxu-user-profile? root-config-profile) #t)
        (check-equal? (yuanxu-user-profile-name root-config-profile) 'users)
        (check-equal?
         (.ref (poo-flow-testing-admit-user-profile!
                +poo-flow-testing-interface+
                root-config-profile)
               'admitted?)
         #t)
        (check-equal? (length (yuanxu-user-profile-module-bundles
                               root-config-profile))
                      8)
        (check-equal? (length yuanxu-user-module-bundles) 5)
        (check-equal? (length root-modules) 8)
        (check-equal? (yuanxu-user-config-module-keys root-config)
                      root-config-expected-module-keys)
        (check-equal? (yuanxu-user-module-selection-flags root-flow-module)
                      '(+functional +dag +typed-receipts +runtime-manifest
                        (+cicd
                         (checks +parallel +typed-receipts)
                         (artifacts +export)
                         (release +manual-gate)
                         (webhook +server)
                         (runtime +manifest-handoff))))
        (check-equal? (yuanxu-user-module-selection-key root-custom-module)
                      '(custom . my-module))
        (check-equal?
         (yuanxu-user-module-selection-entrypoint root-custom-module)
         "./custom/my-module/interface.ss")))))
