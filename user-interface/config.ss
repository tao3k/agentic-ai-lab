;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Final User Composition: one thin binding over maintained Profiles.

(import (only-in :core/profile-composition/profile-bundle
                 profiles compose)
        :core/profile-composition/selection-syntax
        :poo-flow/modules/workflow/scenario/composition-syntax
        :poo-flow/modules/workflow/scenario/configuration/default-agent-control-plane-profile
        :poo-flow/user-interface/profiles/langgraph
        :poo-flow/user-interface/profiles/tool-calling)

(export default-agent-control-plane)

(user-composition default-agent-control-plane
  (compose profiles
    (use-module LangGraphModule as control
      session state router agent-node tool-node bounded-loop runtime-handoff)
    (use-module ToolCallingModule as tools
      tool-request tool-schema tool-permission sandbox-scope
      argument-validation untrusted-observation tool-cooldown result-contract
      runtime-binding receipt-gate observability)
    DefaultAgentControlPlaneProfile))
