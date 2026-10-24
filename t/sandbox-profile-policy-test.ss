;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: sandbox profile policy tests stay projection-only.
;;; Invariant: backend capability checks never execute sandbox runtimes.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref .slot? object?)
        (only-in :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/policy
                 agentic-ai-lab-durable-policy)
        :agentic-ai-lab/modules/sandbox-core/profile-support/policy)

(export sandbox-profile-policy-test)

;; : (-> Alist Symbol Value Value)
(def (test-ref entries key default-value)
  (cond
   ((object? entries)
    (if (.slot? entries key)
      (.ref entries key)
      default-value))
   (else
    (let (entry (assoc key entries))
      (if entry (cdr entry) default-value)))))

;; : (-> Alist [Symbol])
(def (test-diagnostic-codes validation)
  (map (lambda (diagnostic)
         (test-ref diagnostic 'code #f))
       (test-ref validation 'diagnostics '())))

;; : Alist
(def test-project-resource-policy
  '((filesystem
     (scope . project-workspace)
     (paths
      ((role . project-workspace)
       (source . ".")
       (project-marker . "gerbil.pkg")
       (target . "/workspace/project")
       (mode . read-write)))
     (access . read-write))
    (cpu . 2)))

;; : TestSuite
(def sandbox-profile-policy-test
  (test-suite "agentic-ai-lab sandbox profile policy"
    (yuanxu-test-case "publishes static POO backend capability objects"
      (check-equal?
       (agentic-ai-lab-sandbox-backend-capability?
        agentic-ai-lab-sandbox-backend-capability/nono)
       #t)
      (check-equal?
       (agentic-ai-lab-sandbox-backend-capability/backend-kind
        agentic-ai-lab-sandbox-backend-capability/nono)
       'nono)
      (check-equal?
       (agentic-ai-lab-sandbox-backend-capability-supports?
        agentic-ai-lab-sandbox-backend-capability/nono
        'process-run)
       #t)
      (check-equal?
       (agentic-ai-lab-sandbox-backend-capability-supports?
        agentic-ai-lab-sandbox-backend-capability/nono
        'gpu-device)
       #f))
    (yuanxu-test-case "returns structured capability diagnostics"
      (let* ((policy
              (agentic-ai-lab-sandbox-profile-policy '(process-run gpu-device)))
             (validation
              (agentic-ai-lab-sandbox-profile-policy-validation
               'agent/gpu
               'nono
               'agent/gpu
               agentic-ai-lab-sandbox-backend-capability/nono
               policy
               '(process-run tmpdir))))
        (check-equal?
         (agentic-ai-lab-sandbox-profile-policy-validation-valid? validation)
         #f)
        (check-equal? (test-ref validation 'diagnostic-count #f) 1)
        (check-equal? (test-diagnostic-codes validation)
                      '(missing-backend-capability))))
    (yuanxu-test-case "validates backend capability for profile candidates"
      (let ((validation
             (agentic-ai-lab-sandbox-profile-policy-validation
              'agent/sandbox
              'sandbox
              'agent/sandbox
              agentic-ai-lab-sandbox-backend-capability/sandbox
              agentic-ai-lab-sandbox-profile-policy/default
              '(process-run filesystem-read tmpdir)
              test-project-resource-policy)))
        (check-equal?
         (agentic-ai-lab-sandbox-profile-policy-validation-valid? validation)
         #t)
        (check-equal? (test-ref validation 'diagnostic-count #f) 0))
      (let ((validation
             (agentic-ai-lab-sandbox-profile-policy-validation
              'agent/gpu
              'sandbox
              'agent/gpu
              agentic-ai-lab-sandbox-backend-capability/sandbox
              agentic-ai-lab-sandbox-profile-policy/default
              '(process-run gpu-device))))
        (check-equal?
         (agentic-ai-lab-sandbox-profile-policy-validation-valid? validation)
         #f)
        (check-equal? (test-diagnostic-codes validation)
                      '(missing-backend-capability))))
    (yuanxu-test-case "projects profile policy receipts without runtime execution"
      (let* ((projection
              (agentic-ai-lab-sandbox-profile-policy-projection
               'agent/sandbox
               'sandbox
               'agent/sandbox
               (agentic-ai-lab-sandbox-backend-capability-ref
                'sandbox)
               agentic-ai-lab-sandbox-profile-policy/default
               '(process-run filesystem-read tmpdir)
               test-project-resource-policy))
             (durable-summary
              (test-ref projection 'durable-policy-summary '())))
        (check-equal? (test-ref projection 'kind #f)
                      agentic-ai-lab-sandbox-profile-policy-projection-kind)
        (check-equal? (test-ref projection 'valid? #f) #t)
        (check-equal? (test-ref projection 'durable-policy-ref #f)
                      'durable/default)
        (check-equal? (test-ref projection 'durable-valid? #f) #t)
        (check-equal? (test-ref durable-summary 'journal-owner #f)
                      'runtime/fact-log)
        (check-equal? (test-ref durable-summary 'checkpoint-store #f)
                      'runtime/checkpoint-store)
        (check-equal? (test-ref durable-summary 'repair-mode #f)
                      'fail-closed)
        (check-equal? (test-ref durable-summary 'sandbox-handle-class #f)
                      'sandbox/profile-handle)
        (check-equal? (test-ref projection 'runtime-owner #f)
                      "marlin-agent-core")
        (check-equal? (test-ref projection 'runtime-executed #t) #f)))
    (yuanxu-test-case "rejects missing sandbox durable placement policy"
      (let* ((policy
              (agentic-ai-lab-sandbox-profile-policy
               '(process-run)
               '((durable-policy . #f))))
             (validation
              (agentic-ai-lab-sandbox-profile-policy-validation
               'agent/missing-durable
               'sandbox
               'agent/missing-durable
               agentic-ai-lab-sandbox-backend-capability/sandbox
               policy
               '(process-run tmpdir))))
        (check-equal?
         (agentic-ai-lab-sandbox-profile-policy-validation-valid? validation)
         #f)
        (check-equal? (test-ref validation 'durable-valid? #t) #f)
        (check-equal? (test-diagnostic-codes validation)
                      '(missing-durable-placement-policy))))
    (yuanxu-test-case "rejects invalid inherited durable placement policy"
      (let* ((invalid-durable
              (agentic-ai-lab-durable-policy
               'durable/invalid-sandbox
               'sandbox/test
               '((checkpoint-store . #f))))
             (policy
              (agentic-ai-lab-sandbox-profile-policy
               '(process-run)
               (list (cons 'durable-policy invalid-durable))))
             (validation
              (agentic-ai-lab-sandbox-profile-policy-validation
               'agent/invalid-durable
               'sandbox
               'agent/invalid-durable
               agentic-ai-lab-sandbox-backend-capability/sandbox
               policy
               '(process-run tmpdir))))
        (check-equal?
         (agentic-ai-lab-sandbox-profile-policy-validation-valid? validation)
         #f)
        (check-equal? (test-ref validation 'durable-valid? #t) #f)
        (check-equal? (test-diagnostic-codes validation)
                      '(invalid-durable-placement-policy))))))
