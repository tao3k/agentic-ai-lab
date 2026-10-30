;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO performance cases for tool-calling control-plane objects.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-ref
                 benchmark-receipt-pass?)
        "../support/poo-performance-fixtures"
        "../support/poo-performance-object-scenarios"
        "../support/poo-performance"
        :agentic-ai-lab/modules/tool-core/calling-control)

(export tool-calling-test)

;; : (-> Alist Unit)
(def (module-system-poo-performance-tool-calling-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] ")
  (write (benchmark-fixture-ref receipt 'feature))
  (display " ")
  (write receipt)
  (newline)
  (force-output))

;; : (-> String Integer Symbol)
(def (module-system-poo-performance-tool-calling-symbol prefix index)
  (string->symbol (string-append prefix "-" (number->string index))))

;; : (-> Integer Pair)
(def (module-system-poo-performance-tool-calling-pair index)
  (let* ((session
          (module-system-poo-performance-tool-calling-symbol "session" index))
         (tool
          (module-system-poo-performance-tool-calling-symbol "search-tool"
                                                            index))
         (runtime
          (module-system-poo-performance-tool-calling-symbol
           "python-runtime-tool-plane"
           index))
         (trace '(tool-request
                  permission-check
                  argument-validation
                  runtime-call
                  tool-result))
         (plan
          (agentic-ai-lab-tool-call-plan
           'tool-calling-agent-loop
           session
           tool
           '(query limit cursor)
           '(query)
           'allow-search
           'sandbox-readonly
           'retry-after-policy-window
           'search-result
           runtime
           trace))
         (runtime-receipt
          (agentic-ai-lab-tool-call-runtime-receipt
           'tool-calling-agent-loop
           session
           tool
           '(query limit)
           #t
           #t
           #t
           #t
           #t
           runtime
           trace
           #f
           'completed)))
    (cons plan runtime-receipt)))

;; : (-> Integer [Pair])
(def (module-system-poo-performance-tool-calling-pairs count)
  (poo-performance-build-list
   count
   module-system-poo-performance-tool-calling-pair))

;; : (-> Pair Boolean)
(def (module-system-poo-performance-tool-calling-valid-pair? pair)
  (let* ((plan (car pair))
         (runtime-receipt (cdr pair))
         (facts
          (agentic-ai-lab-tool-call-runtime-validation-proof-facts
           plan
           runtime-receipt))
         (fact-family
          (agentic-ai-lab-tool-call-fact-family
           'agentic-ai-lab-tool-call-runtime-validation-proof-facts
           'agentic-ai-lab.tool-calling.control.runtime)))
    (and
     (agentic-ai-lab-tool-call-fact-family-ref
      fact-family
      facts
      'plan-valid)
     (agentic-ai-lab-tool-call-fact-family-ref
      fact-family
      facts
      'runtime-receipt-matches-tool-plan)
     (agentic-ai-lab-tool-call-fact-family-ref
      fact-family
      facts
      'tool-output-cannot-authorize-policy))))

;; module-system-poo-performance-tool-calling-valid-proof-count
;;   : (-> [Pair] Integer Integer)
;;   | doc m%
;;       Reuses prebuilt tool-call POO pairs and counts proof-valid pairs across
;;       scalar benchmark rounds.
;;
;;       # Examples
;;       ```scheme
;;       (module-system-poo-performance-tool-calling-valid-proof-count
;;        (module-system-poo-performance-tool-calling-pairs 1)
;;        1)
;;       ;; => 1
;;       ```
;;     %
(def (module-system-poo-performance-tool-calling-valid-proof-count pairs rounds)
  (* rounds
     (length
      (filter module-system-poo-performance-tool-calling-valid-pair?
              pairs))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-tool-calling-object-list-control-case)
  (yuanxu-test-case "validates tool-call proof objects through stable POO lists"
    (let* ((pair-count 96)
           (rounds 4)
           (pairs
            (module-system-poo-performance-tool-calling-pairs pair-count))
           (expected (* pair-count rounds))
           (first-pair (car pairs))
           (first-plan (car first-pair))
           (first-runtime-receipt (cdr first-pair))
           (first-facts
            (agentic-ai-lab-tool-call-runtime-validation-proof-facts
             first-plan
             first-runtime-receipt))
           (receipt
            (poo-performance-run-gate
             (poo-performance-tool-calling-object-list-control-fixture)
             (lambda ()
               (module-system-poo-performance-tool-calling-valid-proof-count
                pairs
                rounds)))))
      (check-equal? (agentic-ai-lab-tool-call-fact-ref first-facts 'plan-valid)
                    #t)
      (check-equal?
       (agentic-ai-lab-tool-call-fact-ref first-facts 'fact-family)
       'agentic-ai-lab-tool-call-runtime-validation-proof-facts)
      (check-equal?
       (agentic-ai-lab-tool-call-fact-ref first-facts
                                    'runtime-receipt-matches-tool-plan)
       #t)
      (check-equal?
       (module-system-poo-performance-tool-calling-valid-proof-count
        pairs
        rounds)
       expected)
      (module-system-poo-performance-tool-calling-display-receipt receipt)
      (check-equal? (benchmark-receipt-pass? receipt) #t))))

;; : TestSuite
(def tool-calling-test
  (test-suite "agentic-ai-lab module system POO tool-calling performance"
    (module-system-poo-performance-tool-calling-object-list-control-case)))
