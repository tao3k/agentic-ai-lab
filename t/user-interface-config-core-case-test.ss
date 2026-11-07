;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: core cases exercise the thin declarative user-interface surface.
;;; These checks intentionally stop before sandbox realization or runtime work.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        "user-interface-fixtures.ss"
        (only-in :yuanxu/profile-composition/user-profile
                 yuanxuUserConfigFromProfile
                 yuanxu-user-profile?
                 yuanxu-user-profile-name
                 yuanxu-user-profile-module-bundles)
        (only-in :agentic-ai-lab/dev/testing-api
                 +agentic-ai-lab-testing-interface+
                 agentic-ai-lab-testing-admit-user-profile!)
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-user-config?
                 yuanxu-user-config-modules
                 yuanxu-user-config-module-keys
                 yuanxu-user-config-feature-facts
                 yuanxu-user-module-selection-key
                 yuanxu-user-module-selection-flags
                 yuanxu-user-module-selection-entrypoint
                 yuanxu-user-module-selection-source-ref)
        (only-in :yuanxu/module-system/source/objects
                 yuanxu-module-source-ref-kind
                 yuanxu-module-source-ref-value))

(export user-interface-config-core-case-test)

;; : (-> Unit [Pair])
(def expected-agentic-ai-lab-core-module-keys
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
   ((equal? (yuanxu-user-module-selection-key (car modules)) key)
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
  (test-suite "agentic-ai-lab user interface core config"
    (yuanxu-test-case "keeps user practice config thin and inspectable"
      (check-equal? (yuanxu-user-profile? test-agentic-ai-lab-user-profile) #t)
      (check-equal? (yuanxu-user-profile-name test-agentic-ai-lab-user-profile)
                    'developer)
      (check-equal? (length (yuanxu-user-profile-module-bundles
                             test-agentic-ai-lab-user-profile))
                    7)
      (check-equal? (yuanxu-user-config? test-agentic-ai-lab-user-config) #t)
      (check-equal? (yuanxu-user-config-module-keys test-agentic-ai-lab-user-config)
                    expected-agentic-ai-lab-core-module-keys))
    (yuanxu-test-case "loads custom module bundles through init-style declarations"
      (let* ((custom-config
              (yuanxuUserConfigFromProfile test-agentic-ai-lab-user-custom-profile))
             (custom-modules
              (yuanxu-user-config-modules custom-config))
             (custom-module
              (module-selection-by-key custom-modules
                                       '(custom . my-module)))
             (custom-facts
              (yuanxu-user-config-feature-facts custom-config))
             (custom-fact
              (feature-fact-by-key custom-facts
                                   '(custom . my-module)))
             (custom-source
              (yuanxu-user-module-selection-source-ref custom-module)))
        (check-equal? (length custom-modules) 7)
        (check-equal? (yuanxu-user-module-selection-key custom-module)
                      '(custom . my-module))
        (check-equal? (yuanxu-user-module-selection-flags custom-module)
                      '(+private +doctor))
        (check-equal? (yuanxu-user-module-selection-entrypoint custom-module)
                      "./custom/my-module/interface.ss")
        (check-equal? (yuanxu-module-source-ref-kind custom-source) 'local)
        (check-equal? (yuanxu-module-source-ref-value custom-source)
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
         (.ref (agentic-ai-lab-testing-admit-user-profile!
                +agentic-ai-lab-testing-interface+
                test-agentic-ai-lab-user-custom-profile)
               'admitted?)
         #t)))))
