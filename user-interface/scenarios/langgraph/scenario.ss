(import (only-in :tao3k/yuanxu/modules/funflow/scenario Scenario)
        (only-in :clan/poo/mop .new)
        (only-in :agentic-ai-lab/init agentic-ai-lab.init.exports)
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

(def langgraph-scenario
  (.new Scenario name: 'langgraph-scenario
        config: (let ((LangGraphModule (.get agentic-ai-lab.init.exports Profiles langgraph profile)))
    (compose profiles
    (use-module LangGraphModule as graph
      session state router agent-node tool-node bounded-loop runtime-handoff)
    LangGraphProductionProfile))))
