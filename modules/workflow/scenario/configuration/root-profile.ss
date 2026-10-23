;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: module-system helpers for root user declaration profiles.
;;; Invariant: root user-interface files declare rows; this module projects them.

(import (only-in :poo-flow/modules/workflow/profiles/kernel/core
                 poo-flow-kernel-profile)
        (only-in :yuanxu/profile-composition/user-profile
                 yuanxuUserProfileExtend
                 yuanxuUserProfileSet
                 yuanxu-user-profile-set-default-profile
                 yuanxu-user-profile-modules
                 yuanxu-user-profile-settings
                 yuanxu-user-profile-setting-keys
                 yuanxuUserConfigFromProfile)
        (only-in :poo-flow/modules/workflow/scenario/configuration/profile-presentation-config
                 pooFlowUserProfileSetPresentation)
        (only-in :poo-flow/modules/workflow/scenario/configuration/presentation-config
                 pooFlowUserConfigPresentation))

(export poo-flow-root-profile-name
        poo-flow-root-profile-set-name
        pooFlowRootProfile
        pooFlowRootProfileSet
        pooFlowRootSelectedProfile
        pooFlowRootProfileSetPresentation
        pooFlowRootModules
        pooFlowRootSettings
        pooFlowRootSettingKeys
        pooFlowRootConfig
        pooFlowRootConfigPresentation)

(def poo-flow-root-profile-name 'users)

(def poo-flow-root-profile-set-name 'users)

;; : (-> [[PooUserModuleSelection]] PooUserProfile)
(def (pooFlowRootProfile module-bundles)
  (yuanxuUserProfileExtend
   poo-flow-root-profile-name
   poo-flow-kernel-profile
   module-bundles))

;; : (-> PooUserProfile PooUserProfileSet)
(def (pooFlowRootProfileSet profile)
  (yuanxuUserProfileSet
   poo-flow-root-profile-set-name
   poo-flow-root-profile-name
   (list profile)))

;; : (-> PooUserProfileSet MaybePooUserProfile)
(def (pooFlowRootSelectedProfile profile-set)
  (yuanxu-user-profile-set-default-profile profile-set))

;; : (-> PooUserProfileSet POOObject)
(def (pooFlowRootProfileSetPresentation profile-set)
  (pooFlowUserProfileSetPresentation profile-set))

;; : (-> PooUserProfile [PooUserModuleSelection])
(def (pooFlowRootModules profile)
  (yuanxu-user-profile-modules profile))

;; : (-> PooUserProfile POOObject)
(def (pooFlowRootSettings profile)
  (yuanxu-user-profile-settings profile))

;; : (-> PooUserProfile [Symbol])
(def (pooFlowRootSettingKeys profile)
  (yuanxu-user-profile-setting-keys profile))

;; : (-> [[PooUserModuleSelection]] PooUserConfig)
(def (pooFlowRootConfig module-bundles)
  (yuanxuUserConfigFromProfile
   (pooFlowRootProfile module-bundles)))

;;; Visible payload sent across the root user-interface boundary. It expands
;;; init declarations into the shallow config presentation without descriptor
;;; realization or runtime execution.
;; : (-> [[PooUserModuleSelection]] POOObject)
(def (pooFlowRootConfigPresentation module-bundles)
  (let* ((profile (pooFlowRootProfile module-bundles))
         (config (yuanxuUserConfigFromProfile profile)))
    (pooFlowUserConfigPresentation
     config
     (yuanxu-user-profile-setting-keys profile))))
