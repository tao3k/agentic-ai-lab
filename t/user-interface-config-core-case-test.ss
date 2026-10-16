;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: core cases exercise the thin declarative user-interface surface.
;;; These checks intentionally stop before sandbox realization or runtime work.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        "user-interface-fixtures.ss"
        (only-in :core/profile-composition/user-profile
                 pooFlowUserConfigFromProfile
                 poo-flow-user-profile?
                 poo-flow-user-profile-name
                 poo-flow-user-profile-module-bundles)
        (only-in :poo-flow/testing-api
                 +poo-flow-testing-interface+
                 poo-flow-testing-admit-user-profile!)
        (only-in :core/module-system/selection/objects
                 poo-flow-user-config?
                 poo-flow-user-config-modules
                 poo-flow-user-config-module-keys
                 poo-flow-user-config-feature-facts
                 poo-flow-user-module-selection-key
                 poo-flow-user-module-selection-flags
                 poo-flow-user-module-selection-entrypoint
                 poo-flow-user-module-selection-source-ref)
        (only-in :core/module-system/source/objects
                 poo-flow-module-source-ref-kind
                 poo-flow-module-source-ref-value))

(export user-interface-config-core-case-test)

;; : (-> Unit [Pair])
(def expected-poo-flow-core-module-keys
  '((flow . funflow)
    (session . session)
    (loop . governor)
    (sandbox . nono-sandbox)
    (sandbox . cubeSandbox)
    (sandbox . docker-sandbox)
    (flow . loop-engine)))

;; : (-> [PooUserModuleSelection] Pair MaybePooUserModuleSelection)
(def (module-selection-by-key modules key)
  (cond
   ((null? modules) #f)
   ((equal? (poo-flow-user-module-selection-key (car modules)) key)
    (car modules))
   (else
    (module-selection-by-key (cdr modules) key))))

;; : (-> [Alist] Pair MaybeAlist)
(def (feature-fact-by-key facts key)
  (cond
   ((null? facts) #f)
   ((equal? (alist-value 'key (car facts)) key)
    (car facts))
   (else
    (feature-fact-by-key (cdr facts) key))))

;; : (-> Unit TestSuite)
;;; This suite guards the core user config case as the minimal declarative
;;; surface exposed to downstream users.
(def user-interface-config-core-case-test
  (test-suite "poo-flow user interface core config"
    (poo-flow-test-case "keeps user practice config thin and inspectable"
      (check-equal? (poo-flow-user-profile? test-poo-flow-user-profile) #t)
      (check-equal? (poo-flow-user-profile-name test-poo-flow-user-profile)
                    'developer)
      (check-equal? (length (poo-flow-user-profile-module-bundles
                             test-poo-flow-user-profile))
                    7)
      (check-equal? (poo-flow-user-config? test-poo-flow-user-config) #t)
      (check-equal? (poo-flow-user-config-module-keys test-poo-flow-user-config)
                    expected-poo-flow-core-module-keys))
    (poo-flow-test-case "loads custom module bundles through init-style declarations"
      (let* ((custom-config
              (pooFlowUserConfigFromProfile test-poo-flow-user-custom-profile))
             (custom-modules
              (poo-flow-user-config-modules custom-config))
             (custom-module
              (module-selection-by-key custom-modules
                                       '(custom . my-module)))
             (custom-facts
              (poo-flow-user-config-feature-facts custom-config))
             (custom-fact
              (feature-fact-by-key custom-facts
                                   '(custom . my-module)))
             (custom-source
              (poo-flow-user-module-selection-source-ref custom-module)))
        (check-equal? (length custom-modules) 7)
        (check-equal? (poo-flow-user-module-selection-key custom-module)
                      '(custom . my-module))
        (check-equal? (poo-flow-user-module-selection-flags custom-module)
                      '(+private +doctor))
        (check-equal? (poo-flow-user-module-selection-entrypoint custom-module)
                      "./custom/my-module/interface.ss")
        (check-equal? (poo-flow-module-source-ref-kind custom-source) 'local)
        (check-equal? (poo-flow-module-source-ref-value custom-source)
                      "./custom/my-module/interface.ss")
        (check-equal? (alist-value 'entrypoint custom-fact)
                      "./custom/my-module/interface.ss")
        (check-equal? (alist-value 'declaration-index custom-fact)
                      6)
        (check-equal? (alist-value 'declaration-phase custom-fact)
                      'init-selection)
        (check-equal? (alist-value 'package-management? custom-fact)
                      #f)
        (check-equal? (alist-value 'loader-executed? custom-fact)
                      #f)
        (check-equal?
         (.ref (poo-flow-testing-admit-user-profile!
                +poo-flow-testing-interface+
                test-poo-flow-user-custom-profile)
               'admitted?)
         #t)))))
