;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: profile-set cases validate selection through Testing Policy.

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
        (only-in :clan/poo/object .ref)
        "user-interface-fixtures.ss"
        (only-in :agentic-ai-lab/dev/testing-api
                 +agentic-ai-lab-testing-interface+
                 agentic-ai-lab-testing-admit-user-profile-set!
                 agentic-ai-lab-testing-check-user-profile-set)
        :agentic-ai-lab/modules/workflow/scenario/configuration/interface
        :agentic-ai-lab/modules/workflow/scenario/configuration/profile-config)

(export user-interface-profile-set-case-test)

;; : (-> Unit TestSuite)
;;; This suite protects profile-set configuration as a downstream case composed
;;; from upstream module contracts.
(def user-interface-profile-set-case-test
  (test-suite "agentic-ai-lab user interface profile sets"
    (yuanxu-test-case "manages Doom-style profile sets before realization"
      (let* ((selected-profile
              (yuanxu-user-profile-set-default-profile
               test-agentic-ai-lab-user-profile-set))
             (presentation
              (agenticAiLabUserProfileSetPresentation
               test-agentic-ai-lab-user-profile-set)))
        (check-equal? (yuanxu-user-profile-set?
                       test-agentic-ai-lab-user-profile-set)
                      #t)
        (check-equal? (yuanxu-user-profile-set-name
                       test-agentic-ai-lab-user-profile-set)
                      'workspace)
        (check-equal? (yuanxu-user-profile-set-default-profile-name
                       test-agentic-ai-lab-user-profile-set)
                      'developer)
        (check-equal? (yuanxu-user-profile-set-profile-names
                       test-agentic-ai-lab-user-profile-set)
                      '(developer custom-developer))
        (check-equal? (yuanxu-user-profile-name selected-profile) 'developer)
        (check-equal? (.ref presentation 'kind)
                      yuanxu-user-profile-set-presentation-kind)
        (check-equal? (.ref presentation 'profile-count) 2)
        (check-equal? (.ref presentation 'selected-profile-name)
                      'developer)
        (check-equal? (.ref presentation 'selected-profile?) #t)
        (check-equal? (not
                       (not
                        (member "agentic-ai-lab-profile-set"
                                (.ref presentation 'user-entrypoints))))
                      #t)
        (check-equal? (not
                       (not
                        (member "agenticAiLabUserProfileSetPresentation"
                                (.ref presentation 'api-entrypoints))))
                      #t)
        (check-equal? (.ref presentation 'package-management?) #f)
        (check-equal? (.ref presentation 'descriptor-realized?) #f)
        (check-equal? (.ref presentation 'runtime-executed) #f)))
    (yuanxu-test-case "admits profile sets through the POO testing policy"
      (let* ((valid-report
              (agentic-ai-lab-testing-admit-user-profile-set!
               +agentic-ai-lab-testing-interface+
               test-agentic-ai-lab-user-profile-set))
             (rejected-receipt
              (agentic-ai-lab-testing-check-user-profile-set
               +agentic-ai-lab-testing-interface+
               test-agentic-ai-lab-user-broken-profile-set))
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
