;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/modules/funflow/control-plane/signatures
                 Fun Any Number Integer String Symbol List Pair Null Unit)
        (only-in :yuanxu/modules/funflow/control-plane/flow flow-output-contract)
        (only-in :yuanxu/modules/funflow/control-plane/runtime-protocol AdapterResult))
;;; Boundary: flow descriptor tests cover declaration policy, not execution.

(import :yuanxu/composition/roles
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
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
        :yuanxu/modules/funflow/control-plane/api)

;;; This suite keeps flow declaration metadata executable independently from
;;; runner scheduling behavior.
;; : TestSuite
(export flow-descriptor-test)

(def flow-descriptor-test
  (test-suite "flow declaration descriptors"
    (yuanxu-test-case "declares POO-backed flow planning policy"
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
    (yuanxu-test-case "selects descriptors from flow declaration shape"
      (let* ((inc (pure-flow
		   'inc
		   (Fun Number <- Number)
		   (lambda (x) (+ x 1))))
             (double (scheme-flow
		      'double
		      (Fun Number <- Number)
		      (lambda (x) (* x 2))))
             (pipeline (flow-then 'pipeline inc double))
             (branch (flow-branch 'fanout inc double))
             (empty (flow-compose
		     'empty
		     '()
		     (Fun Number <- Number))))
        (check-equal? (flow-declaration-kind (flow-declaration-descriptor inc)) 'task)
        (check-equal? (flow-declaration-kind (flow-declaration-descriptor pipeline)) 'sequential)
        (check-equal? (flow-declaration-kind (flow-declaration-descriptor branch)) 'branch)
        (check-equal? (flow-declaration-kind (flow-declaration-descriptor empty)) 'empty)
        (check-equal? (flow-task-declaration? inc) #t)
        (check-equal? (flow-sequential-declaration? pipeline) #t)
        (check-equal? (flow-branch-declaration? branch) #t)))
    (yuanxu-test-case "strategy selects planner through flow descriptor policy"
      (let* ((left (pure-flow
		    'left
		    (Fun Number <- Number)
		    (lambda (x) (+ x 1))))
             (right (pure-flow
		     'right
		     (Fun Number <- Number)
		     (lambda (x) (* x 2))))
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
