;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: foundational session policy family projection performance gate.
;;; Invariant: POO-native policy constructors project to bounded rows before
;;; effective validation, without runtime, tool, hook, provider, or sandbox work.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run)
        "../support/performance"
        :agentic-ai-lab/modules/session/config)

(export session-policy-family-performance-test)

;; : String
(def session-policy-family-fixture-path
  "t/scenarios/performance/session-policy-family/benchmark.ss")

;; Stable identifiers are benchmark inputs, not part of policy construction.
;; Intern them once so repeated samples measure POO construction/projection
;; instead of string formatting and symbol-table growth.
(def session-policy-family-performance-id-cache
  (make-hash-table))

;; : Alist
(def session-policy-family-fixture
  (call-with-input-file session-policy-family-fixture-path read))

;; : (-> Alist Symbol MaybeValue)
(def (session-policy-family-performance-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;; : (-> Alist Void)
(def (session-policy-family-performance-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] session-policy-family ")
  (write receipt)
  (newline)
  (force-output))

;; : (-> String Integer Symbol)
(def (session-policy-family-performance-id prefix index)
  (let* ((key (cons prefix index))
         (cached (hash-get session-policy-family-performance-id-cache key)))
    (if cached
      cached
      (let (identifier
            (string->symbol
             (string-append prefix "/" (number->string index))))
        (hash-put! session-policy-family-performance-id-cache key identifier)
        identifier))))

;; : (-> Integer [PooSessionToolGrant])
(def (session-policy-family-performance-tool-grants index)
  (list
   (agentic-ai-lab-session-tool-grant
    (session-policy-family-performance-id "grant/read" index)
    'read-workspace-file
    '(read)
    '(project-workspace)
    '(agent-turn hook/pre-check))
   (agentic-ai-lab-session-tool-grant
    (session-policy-family-performance-id "grant/build" index)
    'run-build-command
    '(run)
    '(project-workspace build-cache)
    '(agent-turn))))

;; : (-> Integer [PooSessionPolicy])
(def (session-policy-family-performance-policies index)
  (let* ((scope-ref
          (session-policy-family-performance-id "session/perf" index))
         (agent-ref
          (session-policy-family-performance-id "agent/perf" index))
         (tool-grants
          (session-policy-family-performance-tool-grants index))
         (isolation-ref
          (session-policy-family-performance-id "policy/isolation" index))
         (sandbox-ref
          (session-policy-family-performance-id "policy/sandbox" index))
         (context-ref
          (session-policy-family-performance-id "policy/context" index))
         (resource-ref
          (session-policy-family-performance-id "policy/resource" index))
         (model-ref
          (session-policy-family-performance-id "policy/model" index))
         (prompt-ref
          (session-policy-family-performance-id "policy/prompt" index))
         (tool-ref
          (session-policy-family-performance-id "policy/tools" index))
         (hook-ref
          (session-policy-family-performance-id "policy/hooks" index)))
    (list
     (agentic-ai-lab-session-isolation-policy
      isolation-ref
      scope-ref
      'strict
      'deny
      'append-summary
      'via-supervisor)
     (agentic-ai-lab-session-sandbox-policy
      sandbox-ref
      scope-ref
      'sandbox/nono-build
      'parent-profile
      'isolated-filesystem)
     (agentic-ai-lab-session-context-policy
      context-ref
      scope-ref
      'parent-summary-only
      '(session/root session/audit))
     (agentic-ai-lab-session-history-policy
      (session-policy-family-performance-id "policy/history" index)
      scope-ref
      'bounded
      '(record/last-failure record/build-log))
     (agentic-ai-lab-session-communication-policy
      (session-policy-family-performance-id "policy/communication" index)
      scope-ref
      '(channel/build-root channel/build-audit)
      '(session/root session/audit))
     (agentic-ai-lab-session-sharing-policy
      (session-policy-family-performance-id "policy/sharing" index)
      scope-ref
      '(memory/project)
      '(artifact/build-log)
      '(tool-result/test-summary)
      '("build/" "reports/"))
     (agentic-ai-lab-session-resource-policy
      resource-ref
      scope-ref
      '(budget/build-agent)
      '(capability/cache-read capability/cache-write)
      scope-ref)
     (agentic-ai-lab-session-model-policy
      model-ref
      scope-ref
      'marlin/provider
      'marlin/model/build-review
      '(tool-calling structured-output)
      'budget/build-agent)
     (agentic-ai-lab-session-prompt-policy
      prompt-ref
      scope-ref
      'session/system
      '(system-instruction build-contract)
      'parent-summary-only)
     (agentic-ai-lab-session-tool-permission-policy
      tool-ref
      scope-ref
      tool-grants
      '(write-workspace-file)
      'deny)
     (agentic-ai-lab-session-hook-tool-permission-policy
      hook-ref
      scope-ref
      '(hook/pre-check)
      (list (car tool-grants))
      'human-approval-on-escalation
      'deny)
     (agentic-ai-lab-session-resource-sharing-policy
      (session-policy-family-performance-id "policy/resource-sharing" index)
      scope-ref
      '((project-workspace
         (access . read)
         (accounting . session/root))
        (build-cache
         (access . read-write)
         (accounting . session/perf)))
      'deny)
     (agentic-ai-lab-session-agent-execution-policy
      (session-policy-family-performance-id "policy/execution" index)
      agent-ref
      scope-ref
      model-ref
      prompt-ref
      tool-ref
      hook-ref
      context-ref
      resource-ref))))

;; : (-> [PooSessionPolicy] [Alist] [Alist])
(def (session-policy-family-performance-project/rev policies rows)
  (if (null? policies)
    rows
    (session-policy-family-performance-project/rev
     (cdr policies)
     (cons (agentic-ai-lab-session-policy->alist (car policies)) rows))))

;; : (-> [[PooSessionPolicy]] [Alist] [Alist])
(def (session-policy-family-performance-rows/rev families rows)
  (if (null? families)
    rows
    (session-policy-family-performance-rows/rev
     (cdr families)
     (session-policy-family-performance-project/rev
      (car families)
      rows))))

;; Stable policy declarations are constructed once, as they are in a real
;; module profile. Repeated benchmark samples measure the bounded projection
;; boundary instead of rebuilding immutable configuration objects.
(def session-policy-family-performance-families
  (agentic-ai-lab-performance-build-list
   96
   session-policy-family-performance-policies))

;; session-policy-family-performance-rows
;;   : (-> [[PooSessionPolicy]] [SessionPolicyFamilyPerformanceRow])
;;   | doc m%
;;       Build the policy family projection rows used by the performance test
;;       from the generated session policy objects.
;;
;;       # Examples
;;       ```scheme
;;       (length (session-policy-family-performance-rows '()))
;;       ;; => 0
;;       ```
;;     %
(def (session-policy-family-performance-rows families)
  (reverse
   (session-policy-family-performance-rows/rev families '())))

;; session-policy-family-performance-count-kind
;;   : (-> [SessionPolicyFamilyPerformanceRow] SessionPolicyFamilyKindSymbol Integer)
;;   | doc m%
;;       Count rows by policy kind so the benchmark verifies composition shape
;;       and not only total row volume.
;;
;;       # Examples
;;       ```scheme
;;       (session-policy-family-performance-count-kind '() 'missing)
;;       ;; => 0
;;       ```
;;     %
(def (session-policy-family-performance-count-kind rows policy-kind)
  (length
   (filter (lambda (row)
             (eq? (session-policy-family-performance-ref row 'policy-kind)
                  policy-kind))
           rows)))

;; : (-> [[PooSessionPolicy]] Alist)
(def (session-policy-family-performance-summary families)
  (let* ((family-count (length families))
         (rows (session-policy-family-performance-rows families))
         (policy-count (length rows))
         (first-row (car rows))
         (last-row (list-ref rows (- policy-count 1))))
    (list
     (cons 'family-count family-count)
     (cons 'policy-count policy-count)
     (cons 'first-kind
           (session-policy-family-performance-ref first-row 'policy-kind))
     (cons 'last-kind
           (session-policy-family-performance-ref last-row 'policy-kind))
     (cons 'sandbox-count
           (session-policy-family-performance-count-kind
            rows
            'session-sandbox))
     (cons 'sharing-count
           (session-policy-family-performance-count-kind
            rows
            'session-sharing))
     (cons 'runtime-executed
           (session-policy-family-performance-ref
            first-row
            'runtime-executed)))))

;; : TestSuite
(def session-policy-family-performance-test
  (test-suite "session policy family performance"
    (yuanxu-test-case "keeps foundational policy projection inside benchmark contract"
      (let* ((families session-policy-family-performance-families)
             (family-count (length families))
             (summary
              (session-policy-family-performance-summary families))
             (receipt
              (benchmark-run
               session-policy-family-fixture
               (lambda ()
                 (session-policy-family-performance-summary
                  families)))))
        (check-equal?
         (benchmark-fixture-contract-pass? session-policy-family-fixture)
         #t)
        (check-equal?
         (session-policy-family-performance-ref summary 'family-count)
         family-count)
        (check-equal?
         (session-policy-family-performance-ref summary 'policy-count)
         (* family-count 13))
        (check-equal?
         (session-policy-family-performance-ref summary 'first-kind)
         'session-isolation)
        (check-equal?
         (session-policy-family-performance-ref summary 'last-kind)
         'agent-execution)
        (check-equal?
         (session-policy-family-performance-ref summary 'sandbox-count)
         family-count)
        (check-equal?
         (session-policy-family-performance-ref summary 'sharing-count)
         family-count)
        (check-equal?
         (session-policy-family-performance-ref summary 'runtime-executed)
         #f)
        (session-policy-family-performance-display-receipt receipt)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
