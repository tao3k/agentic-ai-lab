;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: report-only POO-native authoring diagnostics for sandbox profiles.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        :agentic-ai-lab/modules/sandbox-core/objects)

(export sandbox-core-profile-authoring-diagnostics-test)

;; : [SandboxProfileForm]
(def clean-profile-authoring-rows
  '((resources (filesystem
                (scope . project-workspace)
                (paths
                 ((role . project-workspace)
                  (source . ".")
                  (project-marker . "gerbil.pkg")
                  (target . "/workspace/project")
                  (mode . read-write)))))
    (metadata (runtime-executed . #f)
              (intent . clean))))

;; : [SandboxProfileForm]
(def advanced-profile-authoring-rows
  '((resources :append (timeout-ms . 300000))
    (metadata (runtime-executed . #t))
    (resources :compute (lambda (self super) (super)))))

;; : (-> Symbol Alist MaybeValue)
(def (alist-value key entries)
  (cond
   ((null? entries) #f)
   ((equal? key (caar entries)) (cdar entries))
   (else
    (alist-value key (cdr entries)))))

;; : TestSuite
(def sandbox-core-profile-authoring-diagnostics-test
  (test-suite "sandbox-core profile authoring diagnostics"
    (yuanxu-test-case "keeps POO-native rows diagnostic-free"
      (let ((diagnostics
             (agentic-ai-lab-sandbox-profile-object-authoring-diagnostics
              agentic-ai-lab-sandbox-core-profile-object
              clean-profile-authoring-rows)))
        (check-equal? diagnostics '())))
    (yuanxu-test-case "reports advanced and non-native authoring shapes"
      (let ((diagnostics
             (agentic-ai-lab-sandbox-profile-object-authoring-diagnostics
              agentic-ai-lab-sandbox-core-profile-object
              advanced-profile-authoring-rows)))
        (check-equal? (map (lambda (diagnostic)
                             (alist-value 'code diagnostic))
                           diagnostics)
                      '(advanced-row-operator
                        runtime-executed-marker
                        raw-compute-hook))
        (check-equal? (alist-value 'slot (car diagnostics))
                      'resource-policy)
        (check-equal? (alist-value 'operator (car diagnostics))
                      ':append)
        (check-equal? (alist-value 'expected (cadr diagnostics)) #f)
        (check-equal? (alist-value 'recommendation (caddr diagnostics))
                      'poo-slot-operator-or-helper)))))
