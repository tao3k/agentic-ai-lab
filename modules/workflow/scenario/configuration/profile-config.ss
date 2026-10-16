;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: public facade for profile config, policy, and presentation.
;;; Invariant: profile objects, diagnostics, and presentations live in leaf owners.

(import :core/module-system/selection/objects
        :poo-flow/modules/sandbox-core/profile-catalog
        :poo-flow/modules/sandbox-core/backend-capability-catalog
        :poo-flow/modules/workflow/cicd-config
        :poo-flow/modules/workflow/scenario/configuration/presentation-config
        :core/profile-composition/user-profile
        :core/profile-composition/gate
        :core/profile-composition/policy
        :poo-flow/modules/workflow/scenario/configuration/profile-presentation-config)

(export (import: :core/module-system/selection/objects)
        (import: :poo-flow/modules/sandbox-core/profile-catalog)
        (import: :poo-flow/modules/sandbox-core/backend-capability-catalog)
        (import: :poo-flow/modules/workflow/cicd-config)
        (import: :poo-flow/modules/workflow/scenario/configuration/presentation-config)
        poo-flow-user-profile-kind
        poo-flow-user-profile-set-kind
        poo-flow-user-profile-diagnostic-kind
        poo-flow-user-profile-presentation-kind
        poo-flow-user-profile-set-presentation-kind
        poo-flow-user-profile-policy-receipt-kind
        poo-flow-user-profile-set-policy-receipt-kind
        poo-flow-user-interface-profile-gate-kind
        poo-flow-user-interface-profile-gate-receipt-kind
        poo-flow-user-interface-profile-gate-fact-keys
        poo-flow-user-interface-profile-proof-statuses
        pooFlowUserProfile
        pooFlowUserProfileSet
        pooFlowUserProfileExtend
        poo-flow-user-interface-profile-gate-receipt
        poo-flow-user-interface-profile-gate
        poo-flow-user-interface-profile-gate/receipt
        pooFlowUserInterfaceProfileGateReceipt
        pooFlowUserInterfaceProfileGate
        pooFlowUserInterfaceProfileGateWithReceipt
        pooFlowDefaultUserSettings
        poo-flow-default-user-setting-keys
        pooFlowUserConfigFromProfile
        poo-flow-user-profile-policy-admit
        poo-flow-user-profile-set-policy-admit
        pooFlowUserProfilePresentation
        pooFlowUserProfileSetPresentation
        poo-flow-user-profile-policy-admitted?
        poo-flow-user-profile-set-policy-admitted?
        poo-flow-user-profile?
        poo-flow-user-profile-set?
        poo-flow-user-profile-name
        poo-flow-user-profile-set-name
        poo-flow-user-profile-set-default-profile-name
        poo-flow-user-profile-set-profiles
        poo-flow-user-profile-set-profile-names
        poo-flow-user-profile-set-find-profile
        poo-flow-user-profile-set-default-profile
        poo-flow-user-profile-module-bundles
        poo-flow-user-profile-modules
        poo-flow-user-profile-settings
        poo-flow-user-profile-setting-keys
        poo-flow-user-interface-profile-gate?
        poo-flow-user-interface-profile-gate-receipt?
        poo-flow-user-interface-profile-gate-profile-name
        poo-flow-user-interface-profile-gate-accepted?
        poo-flow-user-interface-profile-gate->lean-facts
        poo-flow-user-interface-profile-lean-fact-contract-complete?
        poo-flow-user-profile-diagnostics
        poo-flow-user-profile-set-diagnostics
        poo-flow-user-profile-diagnostic->alist)
