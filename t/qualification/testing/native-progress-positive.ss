;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (for-syntax (only-in :yuanxu/observability/testing-source install-test-source-observation!)))
(begin-syntax (install-test-source-observation!))
(import :std/test
        (only-in :gerbil/expander current-expander-module-import
                 core-resolve-identifier core-context-root feature-binding?)
        (only-in :yuanxu/observability/testing-source
                 test-source-observation-active? stop-test-source-observation!))
(export progress-test)
(def progress-test
  (test-suite "Native Gerbil progress control"
    (test-case "real Case completes" (check-equal? 42 42))
    (test-case "Gerbil completion observer restores its parameter ownership"
      (def enabled? (test-source-observation-active?))
      (check-equal? enabled?
        (feature-binding? (core-resolve-identifier
                           'yuanxu-module-test-observation 0 (core-context-root))))
      (def observing (current-expander-module-import))
      (stop-test-source-observation!)
      (check-equal? (test-source-observation-active?) #f)
      (when enabled? (check-equal? (eq? observing (current-expander-module-import)) #f))
      (def stopped (current-expander-module-import))
      (stop-test-source-observation!)
      (check-equal? (eq? stopped (current-expander-module-import)) #t))))
