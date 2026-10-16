;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: profile-set cases validate selection through Testing Policy.

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
        (only-in :clan/poo/object .ref)
        "user-interface-fixtures.ss"
        (only-in :poo-flow/testing-api
                 +poo-flow-testing-interface+
                 poo-flow-testing-admit-user-profile-set!
                 poo-flow-testing-check-user-profile-set)
        :poo-flow/modules/workflow/scenario/configuration/interface
        :poo-flow/modules/workflow/scenario/configuration/profile-config)

(export user-interface-profile-set-case-test)

;; : (-> Unit TestSuite)
;;; This suite protects profile-set configuration as a downstream case composed
;;; from upstream module contracts.
(def user-interface-profile-set-case-test
  (test-suite "poo-flow user interface profile sets"
    (poo-flow-test-case "manages Doom-style profile sets before realization"
      (let* ((selected-profile
              (poo-flow-user-profile-set-default-profile
               test-poo-flow-user-profile-set))
             (presentation
              (pooFlowUserProfileSetPresentation
               test-poo-flow-user-profile-set)))
        (check-equal? (poo-flow-user-profile-set?
                       test-poo-flow-user-profile-set)
                      #t)
        (check-equal? (poo-flow-user-profile-set-name
                       test-poo-flow-user-profile-set)
                      'workspace)
        (check-equal? (poo-flow-user-profile-set-default-profile-name
                       test-poo-flow-user-profile-set)
                      'developer)
        (check-equal? (poo-flow-user-profile-set-profile-names
                       test-poo-flow-user-profile-set)
                      '(developer custom-developer))
        (check-equal? (poo-flow-user-profile-name selected-profile) 'developer)
        (check-equal? (.ref presentation 'kind)
                      poo-flow-user-profile-set-presentation-kind)
        (check-equal? (.ref presentation 'profile-count) 2)
        (check-equal? (.ref presentation 'selected-profile-name)
                      'developer)
        (check-equal? (.ref presentation 'selected-profile?) #t)
        (check-equal? (not
                       (not
                        (member "poo-flow-profile-set"
                                (.ref presentation 'user-entrypoints))))
                      #t)
        (check-equal? (not
                       (not
                        (member "pooFlowUserProfileSetPresentation"
                                (.ref presentation 'api-entrypoints))))
                      #t)
        (check-equal? (.ref presentation 'package-management?) #f)
        (check-equal? (.ref presentation 'descriptor-realized?) #f)
        (check-equal? (.ref presentation 'runtime-executed) #f)))
    (poo-flow-test-case "admits profile sets through the POO testing policy"
      (let* ((valid-report
              (poo-flow-testing-admit-user-profile-set!
               +poo-flow-testing-interface+
               test-poo-flow-user-profile-set))
             (rejected-receipt
              (poo-flow-testing-check-user-profile-set
               +poo-flow-testing-interface+
               test-poo-flow-user-broken-profile-set))
             (diagnostics (.ref rejected-receipt 'profile-diagnostics)))
        (check-equal? (.ref valid-report 'admitted?) #t)
        (check-equal? (.ref valid-report 'diagnostic-count) 0)
        (check-equal? (.ref rejected-receipt 'policy-status) 'error)
        (check-equal? (.ref rejected-receipt 'admitted?) #f)
        (check-equal? (.ref rejected-receipt 'diagnostic-count) 2)
        (check-equal? (diagnostic-code-member?
                       'duplicate-profile-name
                       diagnostics)
                      #t)
        (check-equal? (diagnostic-code-member?
                       'missing-default-profile
                       diagnostics)
                      #t)
        (check-equal? (.ref rejected-receipt 'runtime-executed) #f)))))
