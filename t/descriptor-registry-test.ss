;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: descriptor registries are policy extension surfaces.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check
                 check-eq?
                 check-equal?
                 check-false
                 check-not-equal?
                 check-output
                 check-true
                 test-error
                 test-suite)
        (only-in :clan/poo/object .@ .slot? .all-slots)
        :poo-flow/modules/workflow/control-plane/api)

;;; This suite keeps descriptor registry lookup behavior separate from concrete
;;; workflow execution.
;; : TestSuite
(def descriptor-registry-test
  (test-suite "descriptor registries"
    (poo-flow-test-case "extends task family descriptors without editing defaults"
      (let* ((custom (make-task-family-descriptor 'custom-runtime
                                                  'external
                                                  'adapter
                                                  'rust-or-external-runtime
                                                  'submit))
             (registry (task-family-registry-extend
                        default-task-family-registry
                        custom))
             (task (make-task 'build
                              'custom-runtime
                              '(custom build)
                              'artifact
                              'artifact
                              #f)))
        (check-equal? (task-family-registry? registry) #t)
        (check-equal? (task-family-name
                       (task-family-for-kind-in registry 'custom-runtime))
                      'custom-runtime)
        (check-equal? (task-route-in registry task) 'adapter)
        (check-equal? (task-runtime-owner-in registry task)
                      'rust-or-external-runtime)
        (check-equal? (task-adapter-operation-in registry task) 'submit)
        (check-equal? (.slot? custom 'extension-policy) #t)
        (check-equal? (.@ custom extension-policy) 'descriptor-prototype)
        (check-equal? (.slot? registry 'extension-policy) #t)
        (check-equal? (.@ registry extension-policy) 'immutable-registry)
        (check-equal? (and (memq 'extension-policy (.all-slots custom)) #t)
                      #t)
        (check-equal? (length task-family-descriptors) 3)))
    (poo-flow-test-case "extends flow declarations without editing defaults"
      (let* ((remote (make-flow-declaration-descriptor 'remote-flow
                                                       'remote
                                                       'linear-dag
                                                       'extension))
             (registry (flow-declaration-registry-extend
                        default-flow-declaration-registry
                        remote))
             (inc (pure-flow 'inc (lambda (x) (+ x 1)) 'number 'number))
             (planner (strategy-planner-for-flow-in
                       (make-local-eager-strategy)
                       registry
                       inc))
             (plan (planner inc)))
        (check-equal? (flow-declaration-registry? registry) #t)
        (check-equal? (flow-declaration-name
                       (flow-declaration-for-kind-in registry 'remote))
                      'remote-flow)
        (check-equal? (flow-declaration-kind
                       (flow-declaration-descriptor-in registry inc))
                      'task)
        (check-equal? (.slot? remote 'extension-policy) #t)
        (check-equal? (.@ remote extension-policy) 'extension)
        (check-equal? (.slot? registry 'extension-policy) #t)
        (check-equal? (.@ registry extension-policy) 'immutable-registry)
        (check-equal? (and (memq 'planner (.all-slots remote)) #t)
                      #t)
        (check-equal? (execution-plan-node-ids plan)
                      '((node inc 0 pure inc)))
        (check-equal? (length flow-declaration-descriptors) 4)))))
