;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .def .o)
        (only-in :yuanxu/profile-composition/profile-bundle
                 profiles compose)
        :yuanxu/profile-composition/selection-syntax
        :agentic-ai-lab/modules/workflow/scenario/composition-syntax
        :agentic-ai-lab/user-interface/profiles/tool-calling)
(export ToolCallingAgentLoopProfile tool-calling-agent-loop-scenario)

(.def ToolCallingAgentLoopProfile
  (identity 'tool-calling-agent-loop-production)
  (stages
   (.o production:
       (.o graph: 'tool-calling-agent-loop-graph
           loop: (.o fuel: 5 exit: 'tool-result-accepted)
           proofs:
           (.o tool-request-has-owner-session: #t
               tool-arguments-match-schema: #t
               tool-permission-before-call: #t
               tool-scope-contained: #t
               validate-arguments-before-runtime: #t
               tool-output-cannot-authorize-policy: #t
               cooldown-before-retry: #t
               tool-result-before-downstream-step: #t
               runtime-binding-matches-tool-contract: #t
               runtime-receipt-matches-tool-plan: #t
               trace-covers-tool-request-call-result: #t)
           handoff: 'python-runtime-tool-plane))))

(user-composition tool-calling-agent-loop-scenario
  (compose profiles
    (use-module ToolCallingModule as tool
      tool-request tool-schema tool-permission sandbox-scope
      argument-validation untrusted-observation tool-cooldown result-contract
      runtime-binding receipt-gate observability)
    ToolCallingAgentLoopProfile))
