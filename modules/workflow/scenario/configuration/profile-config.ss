;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: public facade for profile config, policy, and presentation.
;;; Invariant: profile objects, diagnostics, and presentations live in leaf owners.

(import :yuanxu/module-system/selection/objects
        :agentic-ai-lab/modules/sandbox-core/profile-catalog
        :agentic-ai-lab/modules/sandbox-core/backend-capability-catalog
        :agentic-ai-lab/modules/workflow/cicd-config
        :agentic-ai-lab/modules/workflow/scenario/configuration/presentation-config
        :yuanxu/profile-composition/user-profile
        :yuanxu/profile-composition/gate
        :yuanxu/profile-composition/policy
        :agentic-ai-lab/modules/workflow/scenario/configuration/profile-presentation-config)

(export (import: :yuanxu/module-system/selection/objects)
        (import: :agentic-ai-lab/modules/sandbox-core/profile-catalog)
        (import: :agentic-ai-lab/modules/sandbox-core/backend-capability-catalog)
        (import: :agentic-ai-lab/modules/workflow/cicd-config)
        (import: :agentic-ai-lab/modules/workflow/scenario/configuration/presentation-config)
        yuanxu-user-profile-kind
        yuanxu-user-profile-set-kind
        yuanxu-user-profile-diagnostic-kind
        yuanxu-user-profile-presentation-kind
        yuanxu-user-profile-set-presentation-kind
        yuanxu-user-profile-policy-receipt-kind
        yuanxu-user-profile-set-policy-receipt-kind
        yuanxu-user-interface-profile-gate-kind
        yuanxu-user-interface-profile-gate-receipt-kind
        yuanxu-user-interface-profile-gate-fact-keys
        yuanxu-user-interface-profile-proof-statuses
        yuanxuUserProfile
        yuanxuUserProfileSet
        yuanxuUserProfileExtend
        yuanxu-user-interface-profile-gate-receipt
        yuanxu-user-interface-profile-gate
        yuanxu-user-interface-profile-gate/receipt
        yuanxuUserInterfaceProfileGateReceipt
        yuanxuUserInterfaceProfileGate
        yuanxuUserInterfaceProfileGateWithReceipt
        yuanxuDefaultUserSettings
        yuanxu-default-user-setting-keys
        yuanxuUserConfigFromProfile
        yuanxu-user-profile-policy-admit
        yuanxu-user-profile-set-policy-admit
        agenticAiLabUserProfilePresentation
        agenticAiLabUserProfileSetPresentation
        yuanxu-user-profile-policy-admitted?
        yuanxu-user-profile-set-policy-admitted?
        yuanxu-user-profile?
        yuanxu-user-profile-set?
        yuanxu-user-profile-name
        yuanxu-user-profile-set-name
        yuanxu-user-profile-set-default-profile-name
        yuanxu-user-profile-set-profiles
        yuanxu-user-profile-set-profile-names
        yuanxu-user-profile-set-find-profile
        yuanxu-user-profile-set-default-profile
        yuanxu-user-profile-module-bundles
        yuanxu-user-profile-modules
        yuanxu-user-profile-settings
        yuanxu-user-profile-setting-keys
        yuanxu-user-interface-profile-gate?
        yuanxu-user-interface-profile-gate-receipt?
        yuanxu-user-interface-profile-gate-profile-name
        yuanxu-user-interface-profile-gate-accepted?
        yuanxu-user-interface-profile-gate->lean-facts
        yuanxu-user-interface-profile-lean-fact-contract-complete?
        yuanxu-user-profile-diagnostics
        yuanxu-user-profile-set-diagnostics
        yuanxu-user-profile-diagnostic->alist)
