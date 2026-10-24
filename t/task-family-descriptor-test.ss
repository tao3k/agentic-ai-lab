;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/modules/funflow/control-plane/signatures
                 Fun Any Number Integer String Symbol List Pair Null Unit)
        (only-in :yuanxu/modules/funflow/control-plane/flow flow-output-contract)
        (only-in :yuanxu/modules/funflow/control-plane/runtime-protocol AdapterResult))
;;; Boundary: task-family descriptor tests stay separate from flow execution.

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
        :yuanxu/modules/funflow/control-plane/api
        :yuanxu/modules/funflow/store)

;;; This suite keeps task-family routing policy executable without invoking
;;; runtime adapters, so descriptor regressions fail at the control-plane edge.
;; : TestSuite
(export task-family-descriptor-test)

(def task-family-descriptor-test
  (test-suite "task family descriptors"
    (yuanxu-test-case "declares POO-backed task family policy"
      (check-equal? (task-family-descriptor? pure-task-family-descriptor) #t)
      (check-equal? (role-object? store-task-family-descriptor) #t)
      (check-equal? (task-family-name scheme-task-family-descriptor) 'scheme)
      (check-equal? (task-family-capability store-task-family-descriptor) 'store)
      (check-equal? (task-family-route pure-task-family-descriptor) 'local)
      (check-equal? (task-family-route external-task-family-descriptor) 'adapter)
      (check-equal? (task-family-runtime-owner store-task-family-descriptor)
                    'rust-or-external-runtime)
      (check-equal? (task-family-adapter-dispatch external-task-family-descriptor)
                    'submit))
    (yuanxu-test-case "routes tasks through descriptor policy"
      (let ((registry (make-store-task-family-registry))
            (pure (make-pure-task
  'inc
  (Fun Number <- Number)
  (lambda (x) (+ x 1))))
            (put (make-store-task
		  'put-cache
		  'put
		  'cache-handle
		  (Fun AdapterResult <- Any)))
            (get (make-store-task
		  'get-cache
		  'get
		  'cache-handle
		  (Fun AdapterResult <- Any)))
            (external (make-external-task
		       'compile
		       'rust-build
		       '((crate . "agentic-ai-lab"))
		       (Fun AdapterResult <- Any))))
        (check-equal? (task-family-name (task-descriptor pure)) 'pure)
        (check-equal? (task-capability-in registry put) 'store)
        (check-equal? (task-route pure) 'local)
        (check-equal? (task-route external) 'adapter)
        (check-equal? (task-runtime-owner external) 'rust-or-external-runtime)
        (check-equal? (task-adapter-operation-in registry put) 'store-put)
        (check-equal? (task-adapter-operation-in registry get) 'store-get)
        (check-equal? (task-adapter-operation external) 'submit)))))
