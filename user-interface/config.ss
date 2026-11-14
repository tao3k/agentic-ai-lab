(import (only-in :tao3k/yuanxu/modules/funflow/scenario Scenario)
        (only-in :tao3k/agentic-ai-lab/init tao3k/agentic-ai-lab.init.exports)
        (only-in :clan/poo/object .get))
;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Final User Composition: one thin binding over maintained Profiles.

(import (only-in :tao3k/yuanxu/profile-composition/profile-bundle
                 profiles compose)
        :tao3k/yuanxu/profile-composition/selection-syntax

        :tao3k/agentic-ai-lab/modules/workflow/scenario/configuration/default-agent-control-plane-profile
        )


(export default-agent-control-plane)

(def default-agent-control-plane
  (.new Scenario name: 'default-agent-control-plane
        config: (let ((LangGraphModule (.get tao3k/agentic-ai-lab.init.exports Profiles langgraph profile))
        (ToolCallingModule (.get tao3k/agentic-ai-lab.init.exports Profiles tool-calling profile)))
    (compose profiles
    (use-module LangGraphModule as control
      session state router agent-node tool-node bounded-loop runtime-handoff)
    (use-module ToolCallingModule as tools
      tool-request tool-schema tool-permission sandbox-scope
      argument-validation untrusted-observation tool-cooldown result-contract
      runtime-binding receipt-gate observability)
    DefaultAgentControlPlaneProfile))))
