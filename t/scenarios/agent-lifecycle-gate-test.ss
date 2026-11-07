;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: AI agent lifecycle proof gate scenario tests.
;;; Invariant: lifecycle gates reject unsafe session/sandbox/loop/subagent policy.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        :agentic-ai-lab/modules/session/lifecycle-gate)


(export agent-lifecycle-gate-test)

;; : (-> Symbol Alist MaybeValue)
(def (alist-value key entries)
  (cond
   ((null? entries) #f)
   ((equal? key (caar entries)) (cdar entries))
   (else
    (alist-value key (cdr entries)))))

;; : (-> Unit AgenticAILabAgentLifecycleReceipt)
(def lifecycle-accepted-receipt
  (agentic-ai-lab-agent-lifecycle-receipt
   'session-main
   'nono-restricted
   'governed-loop
   '(codex-worker review-worker)
   '(read-workspace write-owned-files shell-limited)
   '(agent-lifecycle-gate-test)
   '(lake-build-agent-lifecycle)
   #t
   #t
   #t
   #t
   #t
   #t
   #t
   #t
   #t
   #t
   #t
   #t))

;; : (-> Unit AgenticAILabAgentLifecycleReceipt)
(def lifecycle-unparented-subagent-receipt
  (agentic-ai-lab-agent-lifecycle-receipt
   'session-child
   'nono-restricted
   'governed-loop
   '(codex-worker)
   '(read-workspace)
   '(agent-lifecycle-gate-test)
   '(lake-build-agent-lifecycle)
   #t
   #f
   #t
   #t
   #t
   #t
   #t
   #t
   #f
   #t
   #t
   #t))

;; : (-> Unit AgenticAILabAgentLifecycleReceipt)
(def lifecycle-sandbox-leak-receipt
  (agentic-ai-lab-agent-lifecycle-receipt
   'session-main
   'nono-wide
   'governed-loop
   '(codex-worker)
   '(read-workspace write-any-file)
   '(agent-lifecycle-gate-test)
   '(lake-build-agent-lifecycle)
   #t
   #t
   #t
   #f
   #f
   #t
   #t
   #t
   #t
   #t
   #t
   #f))

;; : (-> Unit AgenticAILabAgentLifecycleReceipt)
(def lifecycle-loop-open-receipt
  (agentic-ai-lab-agent-lifecycle-receipt
   'session-main
   'nono-restricted
   'unbounded-loop
   '(codex-worker)
   '(read-workspace)
   '(agent-lifecycle-gate-test)
   '(lake-build-agent-lifecycle)
   #t
   #t
   #t
   #t
   #t
   #t
   #f
   #f
   #t
   #t
   #t
   #f))

;; : (-> Unit AgenticAILabAgentLifecycleGate)
(def lifecycle-accepted-gate
  (agentic-ai-lab-agent-lifecycle-gate
   'session-sandbox-loop-subagent
   'public
   lifecycle-accepted-receipt
   '((owner . agent-lifecycle-gate-test))))

;; : (-> Unit AgenticAILabAgentLifecycleGate)
(def lifecycle-unparented-subagent-gate
  (agentic-ai-lab-agent-lifecycle-gate
   'unparented-subagent
   'public
   lifecycle-unparented-subagent-receipt
   '((owner . agent-lifecycle-gate-test)
     (bad-case . unparented-subagent))))

;; : (-> Unit AgenticAILabAgentLifecycleGate)
(def lifecycle-sandbox-leak-gate
  (agentic-ai-lab-agent-lifecycle-gate
   'sandbox-scope-leak
   'public
   lifecycle-sandbox-leak-receipt
   '((owner . agent-lifecycle-gate-test)
     (bad-case . sandbox-scope-leak))))

;; : (-> Unit AgenticAILabAgentLifecycleGate)
(def lifecycle-loop-open-gate
  (agentic-ai-lab-agent-lifecycle-gate
   'loop-without-exit
   'public
   lifecycle-loop-open-receipt
   '((owner . agent-lifecycle-gate-test)
     (bad-case . loop-without-exit))))

;; : TestSuite
(def agent-lifecycle-gate-test
  (test-suite "agentic-ai-lab AI agent lifecycle proof gate"
    (yuanxu-test-case "accepts complete session sandbox loop subagent lifecycle"
      (let* ((gate lifecycle-accepted-gate)
             (facts (agentic-ai-lab-agent-lifecycle-gate->lean-facts gate)))
        (check-equal? (agentic-ai-lab-agent-lifecycle-gate? gate) #t)
        (check-equal? (agentic-ai-lab-agent-lifecycle-receipt?
                       lifecycle-accepted-receipt)
                      #t)
        (check-equal? (agentic-ai-lab-agent-lifecycle-gate-name gate)
                      'session-sandbox-loop-subagent)
        (check-equal? (agentic-ai-lab-agent-lifecycle-gate-accepted? gate) #t)
        (check-equal?
         (agentic-ai-lab-agent-lifecycle-lean-fact-contract-complete? facts)
         #t)
        (check-equal? (alist-value
                       'ai.lifecycle/reusable-policy-surface
                       facts)
                      #t)
        (check-equal? (alist-value 'ai.session/created facts) #t)
        (check-equal? (alist-value 'ai.sandbox/scope-contained facts) #t)
        (check-equal? (alist-value 'ai.loop/exit-defined facts) #t)
        (check-equal? (alist-value 'ai.subagent/parented facts) #t)
        (check-equal? (alist-value 'ai.topology/scope-order-sound facts) #t)
        (check-equal? (alist-value 'ai.topology/tool-scope-sound facts) #t)
        (check-equal? (alist-value 'ai.topology/loop-transition-sound facts)
                      #t)
        (check-equal? (alist-value 'ai.topology/subagent-session-sound facts)
                      #t)))
    (yuanxu-test-case "rejects subagents without parent session binding"
      (let* ((gate lifecycle-unparented-subagent-gate)
             (facts (agentic-ai-lab-agent-lifecycle-gate->lean-facts gate)))
        (check-equal? (agentic-ai-lab-agent-lifecycle-gate-accepted? gate) #f)
        (check-equal?
         (agentic-ai-lab-agent-lifecycle-lean-fact-contract-complete? facts)
         #t)
        (check-equal? (alist-value 'ai.session/parent-bound facts) #f)
        (check-equal? (alist-value 'ai.subagent/parented facts) #f)
        (check-equal? (alist-value 'ai.topology/subagent-session-sound facts)
                      #f)
        (check-equal? (alist-value
                       'ai.lifecycle/reusable-policy-surface
                       facts)
                      #f)))
    (yuanxu-test-case "rejects sandbox and tool scope leaks"
      (let* ((gate lifecycle-sandbox-leak-gate)
             (facts (agentic-ai-lab-agent-lifecycle-gate->lean-facts gate)))
        (check-equal? (agentic-ai-lab-agent-lifecycle-gate-accepted? gate) #f)
        (check-equal?
         (agentic-ai-lab-agent-lifecycle-lean-fact-contract-complete? facts)
         #t)
        (check-equal? (alist-value 'ai.sandbox/scope-contained facts) #f)
        (check-equal? (alist-value 'ai.tool/permissions-contained facts) #f)
        (check-equal? (alist-value 'ai.topology/scope-order-sound facts) #f)
        (check-equal? (alist-value 'ai.topology/tool-scope-sound facts) #f)
        (check-equal? (alist-value 'ai.counterexample/rejected facts) #f)
        (check-equal? (alist-value
                       'ai.lifecycle/reusable-policy-surface
                       facts)
                      #f)))
    (yuanxu-test-case "rejects loop policies without exit and handoff guards"
      (let* ((gate lifecycle-loop-open-gate)
             (facts (agentic-ai-lab-agent-lifecycle-gate->lean-facts gate)))
        (check-equal? (agentic-ai-lab-agent-lifecycle-gate-accepted? gate) #f)
        (check-equal?
         (agentic-ai-lab-agent-lifecycle-lean-fact-contract-complete? facts)
         #t)
        (check-equal? (alist-value 'ai.loop/start-guarded facts) #t)
        (check-equal? (alist-value 'ai.loop/exit-defined facts) #f)
        (check-equal? (alist-value 'ai.loop/handoff-guarded facts) #f)
        (check-equal? (alist-value 'ai.topology/loop-transition-sound facts)
                      #f)
        (check-equal? (alist-value
                       'ai.lifecycle/reusable-policy-surface
                       facts)
                      #f)))))
