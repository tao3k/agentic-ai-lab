;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: static module config declarations lower to native POO objects.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test check-equal? test-suite)
        (only-in :clan/poo/object .all-slots .ref .slot? object?)
        :agentic-ai-lab/modules/module-authoring/module-config-syntax)

(export module-config-prototype-syntax-test)

(def module-config-prototype-evaluation-count 0)

(def (module-config-prototype-counted-value)
  (set! module-config-prototype-evaluation-count
        (1+ module-config-prototype-evaluation-count))
  'evaluated-once)

(defpoo-module-config-prototype
  module-config-prototype-syntax-fixture
  (slots ((kind 'module-config-prototype-syntax-fixture)
          (enabled? #t)
          (metadata '((owner . module-config-prototype-syntax-test)))
          (counted-value (module-config-prototype-counted-value)))))

(def module-config-prototype-syntax-test
  (test-suite "module config prototype syntax"
    (yuanxu-test-case "lowers bounded constant rows to one native POO object"
      (check-equal? (object? module-config-prototype-syntax-fixture) #t)
      (check-equal? (.ref module-config-prototype-syntax-fixture 'kind)
                    'module-config-prototype-syntax-fixture)
      (check-equal? (.ref module-config-prototype-syntax-fixture 'enabled?) #t)
      (check-equal? (.ref module-config-prototype-syntax-fixture 'metadata)
                    '((owner . module-config-prototype-syntax-test)))
      (check-equal? (.ref module-config-prototype-syntax-fixture 'counted-value)
                    'evaluated-once)
      (check-equal? module-config-prototype-evaluation-count 1)
      (check-equal? (length (.all-slots module-config-prototype-syntax-fixture))
                    4)
      (check-equal? (.slot? module-config-prototype-syntax-fixture 'kind) #t)
      (check-equal? (.slot? module-config-prototype-syntax-fixture 'enabled?) #t)
      (check-equal? (.slot? module-config-prototype-syntax-fixture 'metadata) #t)
      (check-equal?
       (.slot? module-config-prototype-syntax-fixture 'counted-value)
       #t))))
