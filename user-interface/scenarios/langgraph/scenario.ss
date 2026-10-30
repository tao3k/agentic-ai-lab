;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .def .o)
        (only-in :yuanxu/profile-composition/profile-bundle
                 profiles compose)
        :yuanxu/profile-composition/selection-syntax
        :agentic-ai-lab/modules/workflow/scenario/composition-syntax
        :agentic-ai-lab/user-interface/profiles/langgraph)
(export LangGraphProductionProfile langgraph-scenario)

(.def LangGraphProductionProfile
  (identity 'langgraph-production)
  (stages
   (.o production:
       (.o graph: 'langgraph-state-graph
           loop: (.o fuel: 8 exit: 'terminal-edge)
           proofs:
           (.o declared-branch-targets: #t
               typed-state-merge: #t
               bounded-loop-progress: #t
               explicit-runtime-handoff: #t)
           handoff: 'marlin-control-plane))))

(user-composition langgraph-scenario
  (compose profiles
    (use-module LangGraphModule as graph
      session state router agent-node tool-node bounded-loop runtime-handoff)
    LangGraphProductionProfile))
