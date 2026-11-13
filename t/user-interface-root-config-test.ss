;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: top-level root profile and modules-directory facade.
;;; Invariant: root config stays declarative and does not load test fixtures.

(import (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test check-equal? test-suite)
        (only-in :agentic-ai-lab/init agentic-ai-lab.init.exports)
        (only-in :clan/poo/object .get .ref)
        (only-in :tao3k/yuanxu/module-system/selection/objects
                 yuanxu-user-config-modules
                 yuanxu-user-config-module-keys
                 yuanxu-user-module-selection-key
                 yuanxu-user-module-selection-flags
                 yuanxu-user-module-selection-entrypoint))

(export user-interface-root-config-test)


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
  (test-suite "agentic-ai-lab user interface root config"
    (yuanxu-test-case "loads modules directory facade through top-level config"
      (def root-scenario (.get agentic-ai-lab.init.exports scenarios developer))
      (def root-config (.get root-scenario config))
      (let* ((root-modules (yuanxu-user-config-modules root-config))
             (root-flow-module
              (root-config-module-selection-by-key root-modules
                                                   '(flow . funflow)))
             (root-custom-module
              (root-config-module-selection-by-key root-modules
                                                   '(custom . my-module))))
        (check-equal? (.get agentic-ai-lab.init.exports modules my-module config identity) 'my-module)
        (check-equal? (eq? root-scenario (.get agentic-ai-lab.init.exports scenarios developer)) #t)
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
