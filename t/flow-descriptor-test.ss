;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: flow descriptor tests cover declaration policy, not execution.

(import :core/composition/roles
        (only-in :core/observability/testing-case poo-flow-test-case)
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
        :poo-flow/modules/workflow/control-plane/api)

;;; This suite keeps flow declaration metadata executable independently from
;;; runner scheduling behavior.
;; : TestSuite
(def flow-descriptor-test
  (test-suite "flow declaration descriptors"
    (poo-flow-test-case "declares POO-backed flow planning policy"
      (check-equal? (flow-declaration-descriptor? branch-flow-descriptor) #t)
      (check-equal? (role-object? sequential-flow-descriptor) #t)
      (check-equal? (flow-declaration-name task-flow-descriptor) 'task-flow)
      (check-equal? (flow-declaration-kind branch-flow-descriptor) 'branch)
      (check-equal? (flow-declaration-planner branch-flow-descriptor) 'linear-dag)
      (check-equal? (flow-extension-policy sequential-flow-descriptor) 'composable)
      (check-equal? (flow-declaration-capability task-flow-descriptor
                                                 'flow-capability
                                                 #f)
                    'workflow-composition)
      (check-equal? (flow-declaration-capability task-flow-descriptor
                                                 'task-capability
                                                 #f)
                    'work-intent)
      (check-equal? (flow-declaration-capability branch-flow-descriptor
                                                 'branch-capability
                                                 #f)
                    'dag-fanout-join)
      (check-equal? (flow-declaration-capability sequential-flow-descriptor
                                                 'branch-capability
                                                 #f)
                    #f))
    (poo-flow-test-case "selects descriptors from flow declaration shape"
      (let* ((inc (pure-flow 'inc (lambda (x) (+ x 1)) 'number 'number))
             (double (scheme-flow 'double (lambda (x) (* x 2)) 'number 'number))
             (pipeline (flow-then 'pipeline inc double))
             (branch (flow-branch 'fanout inc double))
             (empty (flow-compose 'empty '() 'number 'number)))
        (check-equal? (flow-declaration-kind (flow-declaration-descriptor inc)) 'task)
        (check-equal? (flow-declaration-kind (flow-declaration-descriptor pipeline)) 'sequential)
        (check-equal? (flow-declaration-kind (flow-declaration-descriptor branch)) 'branch)
        (check-equal? (flow-declaration-kind (flow-declaration-descriptor empty)) 'empty)
        (check-equal? (flow-task-declaration? inc) #t)
        (check-equal? (flow-sequential-declaration? pipeline) #t)
        (check-equal? (flow-branch-declaration? branch) #t)))
    (poo-flow-test-case "strategy selects planner through flow descriptor policy"
      (let* ((left (pure-flow 'left (lambda (x) (+ x 1)) 'number 'number))
             (right (pure-flow 'right (lambda (x) (* x 2)) 'number 'number))
             (branch (flow-branch 'fanout left right))
             (strategy (make-local-eager-strategy))
             (plan (strategy-plan strategy branch)))
        (check-equal? (flow-declaration-planner
                       (flow-declaration-descriptor branch))
                      'linear-dag)
        (check-equal? (execution-plan-node-ids plan)
                      '((node fanout 0 branch-left left)
                        (node fanout 1 branch-right right)
                        (node fanout 2 branch fanout)))))))
