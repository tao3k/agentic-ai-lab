;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: test verifies durable sandbox config projection without runtime work.
;;; Invariant: assertions inspect user-interface metadata only.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        (only-in :clan/poo/object .ref .slot?)
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-user-module-selection-key
                 yuanxu-user-module-selection-flag-entry)
        (only-in "../user-interface/custom/my-module/cases/sandbox-durable"
                 agentic-ai-lab-custom-my-module-sandbox-durable-case))

(export user-interface-custom-sandbox-durable-test)

;; : (-> Alist Symbol Object)
(def (test-ref row key)
  (let (entry (assoc key row))
    (if entry (cdr entry) #f)))

;; : Alist
(def expected-sandbox-durable-metadata
  '((backend . nono-sandbox)
    (intent . durable-sandbox-build)
    (scope . custom-module)
    (durable-policy . durable/default)
    (runtime-executed . #f)))

;; : (-> Alist Symbol Object Symbol Void)
(def (check-metadata! metadata key expected label)
  (let (actual (test-ref metadata key))
    (unless (equal? actual expected)
      (error "metadata check failed" label actual expected))))

;; : (-> Alist Alist Void)
(def (check-metadata-fields! metadata expected-fields)
  (for-each
   (lambda (entry)
     (check-metadata! metadata (car entry) (cadr entry) (caddr entry)))
   (map (lambda (entry)
          (list (car entry) (cdr entry) (car entry)))
        expected-fields)))

;; : (-> Object Object)
(def (sandbox-config module-selection-bundle)
  (let* ((selection (car module-selection-bundle))
         (entry
          (yuanxu-user-module-selection-flag-entry selection ':config)))
    (and entry
         (pair? (cdr entry))
         (car (cdr entry)))))

;; : TestSuite
(def user-interface-custom-sandbox-durable-test
  (test-suite "agentic-ai-lab custom user-interface sandbox-durable case"
    (yuanxu-test-case "projects durable sandbox config without runtime work"
      (let* ((selection (car agentic-ai-lab-custom-my-module-sandbox-durable-case))
             (config (sandbox-config
                      agentic-ai-lab-custom-my-module-sandbox-durable-case))
             (metadata (.ref config 'metadata)))
        (check-equal? (yuanxu-user-module-selection-key selection)
                      '(sandbox . nono-sandbox))
        (check-equal? (.slot? config 'name) #t)
        (check-equal? (.slot? config 'metadata) #t)
        (check-equal? (.ref config 'name) 'agent/durable-build)
        (check-metadata-fields! metadata expected-sandbox-durable-metadata)))))
