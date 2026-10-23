;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: config tests cover preflight policy without reading real secrets.
;;; Invariant: failure details expose missing key identity, never config values.

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
        :yuanxu/modules/funflow/control-plane/api)

(export config-test)

;;; Capture stays local to this owner so failure-shape assertions inspect the
;;; structured control-plane object rather than stderr or process status.
;; : (-> Thunk Value)
(def (capture-config-failure thunk)
  (with-catch (lambda (failure) failure)
              thunk))

;;; This suite protects config preflight as a pure policy gate: required keys
;;; are visible in diagnostics, while actual secret values never leave config.
;; : TestSuite
(def config-test
  (test-suite "external config policy"
    (yuanxu-test-case "reports missing keys without secret values"
      (let* ((requirement (make-config-requirement 'env 'TOKEN #t))
             (config (make-run-config
                      'needs-token
                      (make-local-eager-strategy)
                      (make-request-only-adapter)
                      (list (cons 'config-requirements (list requirement)))))
             (preflight (run-config-preflight config))
             (missing (car (config-preflight-missing preflight)))
             (missing-shape (config-requirement->alist missing)))
        (check-equal? (config-preflight-status preflight) 'missing)
        (check-equal? (cdr (assoc 'source missing-shape)) 'env)
        (check-equal? (cdr (assoc 'key missing-shape)) 'TOKEN)
        (check-equal? (assoc 'value missing-shape) #f)))
    (yuanxu-test-case "runs when required source keys are present"
      (let* ((requirement (make-config-requirement 'env 'TOKEN #t))
             (options (list (cons 'config-requirements (list requirement))
                            (cons 'config-source
                                  (list (cons 'env
                                              (list (cons 'TOKEN "secret")))))))
             (config (make-run-config 'has-token
                                      (make-local-eager-strategy)
                                      (make-request-only-adapter)
                                      options))
             (flow (pure-flow 'inc (lambda (x) (+ x 1)) 'number 'number))
             (result (run-flow-with-config config flow 1)))
        (check-equal? (config-preflight-ok? (run-config-preflight config)) #t)
        (check-equal? (run-result-value result) 2)))
    (yuanxu-test-case "raises typed failure before runtime submission when missing"
      (let* ((requirement (make-config-requirement 'env 'TOKEN #t))
             (config (make-run-config
                      'missing-token
                      (make-local-eager-strategy)
                      (make-request-only-adapter)
                      (list (cons 'config-requirements (list requirement)))))
             (flow (external-flow 'remote 'submit '((payload . value)) 'value 'value))
             (failure (capture-config-failure
                       (lambda ()
                         (run-flow-with-config config flow 'input))))
             (missing (cdr (assoc 'missing
                                  (execution-failure-detail failure)))))
        (check-equal? (execution-failure? failure) #t)
        (check-equal? (execution-failure-owner failure) 'config)
        (check-equal? (execution-failure-code failure) 'missing-config-keys)
        (check-equal? (cdr (assoc 'key (car missing))) 'TOKEN)))
    (yuanxu-test-case "derives requirements from configurable arguments"
      (let* ((arguments (list (make-config-argument 'literal "--threads" #f)
                              (make-config-argument 'env 'TOKEN #t)
                              (make-config-argument 'file 'CONFIG #f)
                              (make-config-argument 'placeholder 'input #f)))
             (requirements (config-arguments->requirements arguments)))
        (check-equal? (length requirements) 2)
        (check-equal? (config-requirement-source (car requirements)) 'env)
        (check-equal? (config-requirement-key (cadr requirements)) 'CONFIG)))
    (yuanxu-test-case "renders configurable arguments without leaking secrets"
      (let* ((source (list (cons 'env
                                 (list (cons 'TOKEN "secret")
                                       (cons 'MODE "release")))
                           (cons 'file
                                 (list (cons 'CONFIG "config-path")))))
             (arguments (list (make-config-argument 'literal "--mode" #f)
                              (make-config-argument 'env 'MODE #f)
                              (make-config-argument 'env 'TOKEN #t)
                              (make-config-argument 'file 'CONFIG #f)
                              (make-config-argument 'placeholder 'input #f)))
             (rendered (render-config-arguments source arguments)))
        (check-equal? (car rendered) "--mode")
        (check-equal? (cadr rendered) "release")
        (check-equal? (cdr (assoc 'secret (caddr rendered))) #t)
        (check-equal? (assoc 'value (caddr rendered)) #f)
        (check-equal? (cadddr rendered) "config-path")
        (check-equal? (cdr (assoc 'placeholder (car (cddddr rendered)))) 'input)))))
