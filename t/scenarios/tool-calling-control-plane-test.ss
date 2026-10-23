;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test test-suite)
        (only-in :clan/poo/object .o)
        :agentic-ai-lab/modules/tool-core/calling-control
        :agentic-ai-lab/user-interface/profiles/tool-calling
        :agentic-ai-lab/user-interface/scenarios/tool-calling-agent-loop/scenario)

(def tool-calling-control-plane-test
  (test-suite "tool calling control plane"
    (yuanxu-test-case "validates tool call plan and receipt facts"

(unless tool-calling
  (error "Tool calling profile module did not load"))

(unless tool-calling-agent-loop-scenario
  (error "Tool calling composition fragment did not load"))

(def tool-call-plan
  (agentic-ai-lab-tool-call-plan
   'tool-calling-agent-loop
   'session-1
   'search-tool
   '(query limit)
   '(query)
   'allow-search
   'sandbox-readonly
   'retry-after-policy-window
   'search-result
   'python-runtime-tool-plane
   '(tool-request permission-check argument-validation runtime-call tool-result)))

(def tool-call-receipt
  (agentic-ai-lab-tool-call-runtime-receipt
   'tool-calling-agent-loop
   'session-1
   'search-tool
   '(query limit)
   #t
   #t
   #t
   #t
   #t
   'python-runtime-tool-plane
   '(tool-request permission-check argument-validation runtime-call tool-result)
   #f
   'completed))

(def tool-call-facts
  (agentic-ai-lab-tool-call-runtime-validation-proof-facts tool-call-plan
                                                     tool-call-receipt))

(def tool-call-fact-family
  (agentic-ai-lab-tool-call-fact-family
   'agentic-ai-lab-tool-call-runtime-validation-proof-facts
   'agentic-ai-lab.tool-calling.control.runtime))

(unless (equal? (agentic-ai-lab-tool-call-fact-ref tool-call-facts 'fact-family)
                'agentic-ai-lab-tool-call-runtime-validation-proof-facts)
  (error "Tool calling facts should carry reusable fact family identity"))

(unless (agentic-ai-lab-tool-call-fact-family-ref tool-call-fact-family
                                            tool-call-facts
                                            'plan-valid)
  (error "Tool calling fact family should read matching fact sets"))

(unless (agentic-ai-lab-tool-call-fact-ref tool-call-facts 'plan-valid)
  (error "Tool calling plan should be valid"))

(unless (agentic-ai-lab-tool-call-fact-ref tool-call-facts
                                     'runtime-receipt-matches-tool-plan)
  (error "Tool calling runtime facts should prove receipt/plan match"))

(unless (agentic-ai-lab-tool-call-fact-ref tool-call-facts
                                     'tool-output-cannot-authorize-policy)
  (error "Tool output must not authorize policy"))

(void))))
