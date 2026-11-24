;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/type TypeError?))
(import (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/signatures
                 Fun Any Number Integer String Symbol List Pair Null Unit)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/flow flow-output-contract)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/runtime-protocol AdapterResult))
;;; Boundary: Kleisli tests cover value-dependent Functional + Agentic AI Lab binding.
;;; Invariant: binders return ordinary flow declarations; runner owns execution.

(import (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-exception
                 check-equal?
                 test-suite)
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/flow-syntax
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/flow
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/flow-strand
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/failure
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/strategy
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/runtime-adapter
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/runtime-protocol
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/runner
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/config
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/graph
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/roles
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/policy
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/replay
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/receipt
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/task)

(export functional-flow-kleisli-test)

;; : (-> Unit Runner)
(def (kleisli-runner)
  (make-runner (make-local-eager-strategy)
               (make-request-only-adapter)))

;; : (-> Flow Value Value)
(def (kleisli-run flow input)
  (run-result-value (runner-run (kleisli-runner) flow input)))

;; : (-> Symbol Alist MaybeValue)
(def (kleisli-alist-value key entries)
  (cond
   ((null? entries) #f)
   ((equal? key (caar entries)) (cdar entries))
   (else
    (kleisli-alist-value key (cdr entries)))))

(defyuanxu-arr
  kleisli-macro-inc
  kleisli-macro-inc
  (Fun Number <- Number)
  (lambda (x) (+ x 1)))

(defyuanxu-bind
  kleisli-macro-bound
  kleisli-macro-bound
  kleisli-macro-inc
  Number
  (lambda (value)
    (flow-arr
     'kleisli-macro-bound-dynamic
     (Fun Number <- Number)
     (lambda (current) (+ current value)))))

(defyuanxu-kleisli
  kleisli-macro-kleisli
  kleisli-macro-kleisli
  kleisli-macro-inc
  Number
  (lambda (value)
    (flow-arr
     'kleisli-macro-kleisli-dynamic
     (Fun Number <- Number)
     (lambda (current) (+ current value)))))

;;; This suite keeps dependent composition out of the broader Arrow law owner.
;; : TestSuite
(def functional-flow-kleisli-test
  (test-suite "functional flow kleisli"
    (yuanxu-test-case "binds dynamically through the category object"
      (let* ((category default-flow-category)
             (inc (flow-category-arr
		   category
		   'inc
		   (Fun Number <- Number)
		   (lambda (x) (+ x 1))))
             (bound (flow-category-bind
		     category
		     'bind-inc
		     inc
		     Number
		     (lambda (value)
                       (if (> value 3)
                           (flow-arr
			    'dynamic-double
			    (Fun Number <- Number)
			    (lambda (current) (* current 2)))
                           (flow-arr
			    'dynamic-inc
			    (Fun Number <- Number)
			    (lambda (current) (+ current 1)))))))
             (receipt (flow->dag-receipt bound))
             (result (runner-run (kleisli-runner) bound 3))
             (root-receipt (run-result-receipt result))
             (kleisli-receipt (car (receipt-children root-receipt))))
        (check-equal? (flow-step-count bound) 1)
        (check-equal? (kleisli-alist-value 'node-count receipt) 1)
        (check-equal? (kleisli-alist-value 'node-ids receipt)
                      '((node bind-inc 0 kleisli bind-inc)))
        (check-equal? (run-result-value result) 8)
        (check-equal? (receipt-kind kleisli-receipt) 'kleisli)
        (check-equal? (receipt-status kleisli-receipt) 'ok)
        (check-equal? (length (receipt-children kleisli-receipt)) 2)))
    (yuanxu-test-case "rejects binders that do not return flows"
      (let* ((inc (flow-arr
		   'inc
		   (Fun Number <- Number)
		   (lambda (x) (+ x 1))))
             (bad (flow-bind
		   'bad-bind
		   inc
		   Number
		   (lambda (_value) 'not-a-flow)))
             )
        (check-exception (kleisli-run bad 3) TypeError?)))
    (yuanxu-test-case "authors bind flows with hygienic macros"
      (check-equal? (flow-name kleisli-macro-bound) 'kleisli-macro-bound)
      (check-equal? (flow-name kleisli-macro-kleisli) 'kleisli-macro-kleisli)
      (check-equal? (kleisli-run kleisli-macro-bound 3) 8)
      (check-equal? (kleisli-run kleisli-macro-kleisli 2) 6))))
