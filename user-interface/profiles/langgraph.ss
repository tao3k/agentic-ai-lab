;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; User Interface reusable Profile library: LangGraph-style state graph.

(import (only-in :clan/poo/object .def .o .ref)
        (only-in :yuanxu/module-system/schema/relations yuanxu-semantic-identity)
        (only-in :yuanxu/module-system/authoring/roles
                 yuanxu-semantic-module)
        (only-in :yuanxu/profile-composition/profile-bundle
                 yuanxu-profile-export
                 yuanxu-module-profiles))
(export langgraph LangGraphModule)

(.def langgraph
    (session (.o (identity 'session)
                 (name 'langgraph-multi-agent-session)
                 (contract 'session-spawns-subagents)
                 (policy 'subagent-handoff-is-explicit)))
    (state (.o (identity 'state)
               (name 'langgraph-typed-checkpointed-state)
               (contract 'state-schema-is-closed)
               (policy 'state-updates-are-merged)))
    (router (.o (identity 'router)
                (name 'langgraph-conditional-router)
                (contract 'predicate-selects-next-node)
                (policy 'branch-target-is-declared)))
    (agent-node (.o (identity 'agent-node)
                    (name 'langgraph-agent-node)
                    (contract 'agent-node-reads-state)
                    (policy 'agent-node-writes-state-delta)))
    (tool-node (.o (identity 'tool-node)
                   (name 'langgraph-tool-node)
                   (contract 'tool-node-has-permission-scope)
                   (policy 'tool-node-requires-route)))
    (bounded-loop (.o (identity 'bounded-loop)
                      (name 'langgraph-bounded-loop)
                      (contract 'fuel-decreases-on-step)
                      (policy 'loop-has-progress-measure)))
    (runtime-handoff (.o (identity 'runtime-handoff)
                         (name 'langgraph-runtime-handoff)
                         (contract 'runtime-boundary-is-explicit)
                         (policy 'handoff-after-proof-gate))))

(def LangGraphModule
  (yuanxu-semantic-module
   (yuanxu-semantic-identity 'user-interface 'langgraph)
   profiles:
   (yuanxu-module-profiles
    (yuanxu-profile-export 'session (.ref langgraph 'session))
    (yuanxu-profile-export 'state (.ref langgraph 'state))
    (yuanxu-profile-export 'router (.ref langgraph 'router))
    (yuanxu-profile-export 'agent-node (.ref langgraph 'agent-node))
    (yuanxu-profile-export 'tool-node (.ref langgraph 'tool-node))
    (yuanxu-profile-export 'bounded-loop (.ref langgraph 'bounded-loop))
    (yuanxu-profile-export 'runtime-handoff (.ref langgraph 'runtime-handoff)))))
