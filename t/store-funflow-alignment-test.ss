;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Store tests align Scheme declarations with Funflow CAS concepts.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
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

(export store-funflow-alignment-test)

;;; Payload lookup keeps store flow assertions focused on emitted contract
;;; fields rather than alist traversal noise.
;; : (-> Symbol Alist Value)
(def (store-test-payload-ref key payload)
  (let (entry (assoc key payload))
    (if entry (cdr entry) #f)))

;;; Failure capture keeps store validation checks on typed control-plane errors.
;; : (-> Thunk Value)
(def (store-test-capture-failure thunk)
  (with-catch (lambda (failure) failure)
              thunk))

;;; This suite keeps store-oriented funflow alignment executable without
;;; requiring a backing artifact store.
;; : TestSuite
(def store-funflow-alignment-test
  (test-suite "store funflow alignment"
    (yuanxu-test-case "declares Funflow-style directory store arrows"
      (let* ((put (put-dir-flow 'put-source-dir))
             (get (get-dir-flow 'get-source-dir))
             (put-task (car (flow-steps put)))
             (get-task (car (flow-steps get))))
        (check-equal? (flow-name put) 'put-source-dir)
        (check-equal? (flow-input-contract put) 'abs-dir)
        (check-equal? (flow-output-contract put) 'cas-item)
        (check-equal? (task-store-operation put-task) 'put)
        (check-equal? (task-store-put? put-task) #t)
        (check-equal? (store-test-payload-ref 'store-task
                                              (task-store-payload put-task))
                      'put-dir)
        (check-equal? (flow-input-contract get) 'cas-item)
        (check-equal? (flow-output-contract get) 'abs-dir)
        (check-equal? (task-store-operation get-task) 'get)
        (check-equal? (task-store-get? get-task) #t)
        (check-equal? (store-test-payload-ref 'content-kind
                                              (task-store-payload get-task))
                      'directory)))
    (yuanxu-test-case "projects report-only content-address evidence"
      (let* ((flow (put-dir-flow 'snapshot-source))
             (receipt (store-flow->content-address-receipt
                       flow
                       'sha256
                       'hash-abc123)))
        (check-equal? (store-content-address-receipt? receipt) #t)
        (check-equal? (store-content-address-receipt-schema receipt)
                      +store-content-address-receipt-schema+)
        (check-equal? (store-content-address-receipt-flow receipt)
                      'snapshot-source)
        (check-equal? (store-content-address-receipt-operation receipt)
                      'put)
        (check-equal? (store-content-address-receipt-input-contract receipt)
                      'abs-dir)
        (check-equal? (store-content-address-receipt-output-contract receipt)
                      'cas-item)
        (check-equal? (store-content-address-receipt-address-algorithm receipt)
                      'sha256)
        (check-equal? (store-content-address-receipt-content-address receipt)
                      'hash-abc123)
        (check-equal? (store-content-address-receipt-runtime-executed receipt)
                      #f)))
    (yuanxu-test-case "aligns Funflow external config preflight and rendering"
      (let* ((arguments
              (list (make-config-argument 'literal "echo" #f)
                    (make-config-argument 'file 'ourMessage #f)
                    (make-config-argument 'env 'SECOND_GREETING #f)
                    (make-config-argument 'placeholder 'par3 #f)))
             (requirements (config-arguments->requirements arguments))
             (source
              (list (cons 'file
                          (list (cons 'ourMessage "Hello from file")))
                    (cons 'env
                          (list (cons 'SECOND_GREETING "and env")))))
             (rendered (render-config-arguments source arguments))
             (config
              (make-run-config
               'external-config-alignment
               (make-local-eager-strategy)
               (make-request-only-adapter)
               (list (cons 'config-requirements requirements)
                     (cons 'config-source source)))))
        (check-equal? (length requirements) 2)
        (check-equal? (config-requirement-source (car requirements)) 'file)
        (check-equal? (config-requirement-key (car requirements)) 'ourMessage)
        (check-equal? (config-requirement-source (cadr requirements)) 'env)
        (check-equal? (config-requirement-key (cadr requirements))
                      'SECOND_GREETING)
        (check-equal? (config-preflight-ok? (run-config-preflight config)) #t)
        (check-equal? rendered
                      '("echo"
                        "Hello from file"
                        "and env"
                        ((placeholder . par3))))))
    (yuanxu-test-case "fails before runtime work when Funflow config keys are missing"
      (let* ((arguments
              (list (make-config-argument 'file 'ourMessage #f)
                    (make-config-argument 'env 'SECOND_GREETING #f)))
             (requirements (config-arguments->requirements arguments))
             (config
              (make-run-config
               'missing-external-config
               (make-local-eager-strategy)
               (make-request-only-adapter)
               (list (cons 'config-requirements requirements)
                     (cons 'config-source
                           (list (cons 'file '())
                                 (cons 'env '()))))))
             (flow (external-flow 'config-runtime-proof
                                  'docker-echo
                                  '((image . "alpine:latest"))
                                  'unit
                                  'unit))
             (failure
              (store-test-capture-failure
               (lambda ()
                 (run-flow-with-config config flow 'unit))))
             (missing (cdr (assoc 'missing
                                  (execution-failure-detail failure)))))
        (check-equal? (execution-failure? failure) #t)
        (check-equal? (execution-failure-owner failure) 'config)
        (check-equal? (execution-failure-code failure) 'missing-config-keys)
        (check-equal? (map (lambda (entry) (cdr (assoc 'key entry)))
                           missing)
                      '(ourMessage SECOND_GREETING))))))
