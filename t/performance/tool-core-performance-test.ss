;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: tool-core catalog policy validation performance gate.
;;; Invariant: validation resolves POO tool specs and policy refs without
;;; runtime execution or backend startup.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run)
        "../support/performance"
        :agentic-ai-lab/modules/session/config
        :agentic-ai-lab/modules/tool-core/config)

(export tool-core-performance-test)

;; : String
(def tool-core-performance-fixture-path
  "t/scenarios/performance/tool-core-catalog-policy-validation/benchmark.ss")

;; : Alist
(def tool-core-performance-fixture
  (call-with-input-file tool-core-performance-fixture-path read))

;; : Integer
(def tool-core-performance-count 160)

;; : (-> Alist Symbol MaybeValue)
(def (tool-core-performance-ref row key)
  (let (entry (assoc key row))
    (if entry (cdr entry) #f)))

;; : (-> Alist Void)
(def (tool-core-performance-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] tool-core-catalog-policy-validation ")
  (write receipt)
  (newline)
  (force-output))

;; : (-> String Integer Symbol)
(def (tool-core-performance-symbol prefix index)
  (string->symbol
   (string-append prefix "/" (number->string index))))

;; : (-> Integer PooToolSpec)
(def (tool-core-performance-spec index)
  (agentic-ai-lab-tool-spec
   (tool-core-performance-symbol "tool" index)
   'custom
   '(run)
   '((input . string))
   '((output . string))
   "marlin-agent-core"
   'tool/custom
   #f
   #f
   'marlin-tool-adapter))

;; : (-> Integer PooSessionToolGrant)
(def (tool-core-performance-grant index)
  (agentic-ai-lab-session-tool-grant
   (tool-core-performance-symbol "grant" index)
   (tool-core-performance-symbol "tool" index)
   '(run)
   '(session/input)
   '(agent-turn)))

;; : (-> Integer Alist)
(def (tool-core-performance-summary count)
  (let* ((specs
          (agentic-ai-lab-performance-build-list
           count
           tool-core-performance-spec))
         (grants
          (agentic-ai-lab-performance-build-list
           count
           tool-core-performance-grant))
         (catalog (agentic-ai-lab-tool-catalog 'tool-core/performance specs))
         (agent-policy
          (agentic-ai-lab-session-tool-permission-policy
           'policy/tool-core-performance-agent
           'session/tool-core-performance
           grants
           '()
           'deny))
         (hook-policy
          (agentic-ai-lab-session-hook-tool-permission-policy
           'policy/tool-core-performance-hook
           'session/tool-core-performance
           '(hook/pre-check)
           (list (car grants))
           'deny-escalation
           'deny))
         (receipt
          (agentic-ai-lab-tool-policy-catalog-validation-receipt
           'validation/tool-core-performance
           catalog
           agent-policy
           hook-policy)))
    (let* ((valid?
            (agentic-ai-lab-tool-policy-catalog-validation-receipt-valid?
             receipt))
           (diagnostic-count
            (length
             (agentic-ai-lab-tool-policy-catalog-validation-receipt-diagnostics
              receipt))))
      (list
       (cons 'tool-count (agentic-ai-lab-tool-catalog-tool-count catalog))
       (cons 'policy-tool-count (length grants))
       (cons 'resolved-tool-count
             (if valid? (agentic-ai-lab-tool-catalog-tool-count catalog) 0))
       (cons 'unresolved-tool-count diagnostic-count)
       (cons 'action-mismatch-count diagnostic-count)
       (cons 'valid? valid?)
       (cons 'runtime-executed #f)))))

;; : TestSuite
(def tool-core-performance-test
  (test-suite "tool-core performance"
    (yuanxu-test-case "keeps catalog policy validation inside benchmark contract"
      (let* ((summary
              (tool-core-performance-summary tool-core-performance-count))
             (receipt
              (benchmark-run
               tool-core-performance-fixture
               (lambda ()
                 (tool-core-performance-summary tool-core-performance-count)))))
        (check-equal?
         (benchmark-fixture-contract-pass? tool-core-performance-fixture)
         #t)
        (check-equal? (tool-core-performance-ref summary 'tool-count)
                      tool-core-performance-count)
        (check-equal? (tool-core-performance-ref summary 'policy-tool-count)
                      tool-core-performance-count)
        (check-equal? (tool-core-performance-ref summary 'resolved-tool-count)
                      tool-core-performance-count)
        (check-equal? (tool-core-performance-ref summary 'unresolved-tool-count)
                      0)
        (check-equal?
         (tool-core-performance-ref summary 'action-mismatch-count)
         0)
        (check-equal? (tool-core-performance-ref summary 'valid?) #t)
        (check-equal? (tool-core-performance-ref summary 'runtime-executed)
                      #f)
        (tool-core-performance-display-receipt receipt)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
