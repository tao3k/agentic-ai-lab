(import (only-in :tao3k/yuanxu/modules/funflow/scenario Scenario)
        (only-in :clan/poo/mop .new)
        (only-in :tao3k/agentic-ai-lab/init tao3k/agentic-ai-lab.init.exports)
        (only-in :clan/poo/object .get))
;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .def .o)
        (only-in :tao3k/yuanxu/profile-composition/profile-bundle
                 profiles compose)
        :tao3k/yuanxu/profile-composition/selection-syntax
        )

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

(def tool-calling-agent-loop-scenario
  (.new Scenario name: 'tool-calling-agent-loop-scenario
        config: (let ((ToolCallingModule (.get tao3k/agentic-ai-lab.init.exports Profiles tool-calling profile)))
    (compose profiles
    (use-module ToolCallingModule as tool
      tool-request tool-schema tool-permission sandbox-scope
      argument-validation untrusted-observation tool-cooldown result-contract
      runtime-binding receipt-gate observability)
    ToolCallingAgentLoopProfile))))
