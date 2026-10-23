;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: module-system helpers for root user declaration profiles.
;;; Invariant: root user-interface files declare rows; this module projects them.

(import (only-in :agentic-ai-lab/modules/workflow/profiles/kernel/core
                 agentic-ai-lab-kernel-profile)
        (only-in :yuanxu/profile-composition/user-profile
                 yuanxuUserProfileExtend
                 yuanxuUserProfileSet
                 yuanxu-user-profile-set-default-profile
                 yuanxu-user-profile-modules
                 yuanxu-user-profile-settings
                 yuanxu-user-profile-setting-keys
                 yuanxuUserConfigFromProfile)
        (only-in :agentic-ai-lab/modules/workflow/scenario/configuration/profile-presentation-config
                 agenticAiLabUserProfileSetPresentation)
        (only-in :agentic-ai-lab/modules/workflow/scenario/configuration/presentation-config
                 agenticAiLabUserConfigPresentation))

(export agentic-ai-lab-root-profile-name
        agentic-ai-lab-root-profile-set-name
        agenticAiLabRootProfile
        agenticAiLabRootProfileSet
        agenticAiLabRootSelectedProfile
        agenticAiLabRootProfileSetPresentation
        agenticAiLabRootModules
        agenticAiLabRootSettings
        agenticAiLabRootSettingKeys
        agenticAiLabRootConfig
        agenticAiLabRootConfigPresentation)

(def agentic-ai-lab-root-profile-name 'users)

(def agentic-ai-lab-root-profile-set-name 'users)

;; : (-> [[PooUserModuleSelection]] PooUserProfile)
(def (agenticAiLabRootProfile module-bundles)
  (yuanxuUserProfileExtend
   agentic-ai-lab-root-profile-name
   agentic-ai-lab-kernel-profile
   module-bundles))

;; : (-> PooUserProfile PooUserProfileSet)
(def (agenticAiLabRootProfileSet profile)
  (yuanxuUserProfileSet
   agentic-ai-lab-root-profile-set-name
   agentic-ai-lab-root-profile-name
   (list profile)))

;; : (-> PooUserProfileSet MaybePooUserProfile)
(def (agenticAiLabRootSelectedProfile profile-set)
  (yuanxu-user-profile-set-default-profile profile-set))

;; : (-> PooUserProfileSet POOObject)
(def (agenticAiLabRootProfileSetPresentation profile-set)
  (agenticAiLabUserProfileSetPresentation profile-set))

;; : (-> PooUserProfile [PooUserModuleSelection])
(def (agenticAiLabRootModules profile)
  (yuanxu-user-profile-modules profile))

;; : (-> PooUserProfile POOObject)
(def (agenticAiLabRootSettings profile)
  (yuanxu-user-profile-settings profile))

;; : (-> PooUserProfile [Symbol])
(def (agenticAiLabRootSettingKeys profile)
  (yuanxu-user-profile-setting-keys profile))

;; : (-> [[PooUserModuleSelection]] PooUserConfig)
(def (agenticAiLabRootConfig module-bundles)
  (yuanxuUserConfigFromProfile
   (agenticAiLabRootProfile module-bundles)))

;;; Visible payload sent across the root user-interface boundary. It expands
;;; init declarations into the shallow config presentation without descriptor
;;; realization or runtime execution.
;; : (-> [[PooUserModuleSelection]] POOObject)
(def (agenticAiLabRootConfigPresentation module-bundles)
  (let* ((profile (agenticAiLabRootProfile module-bundles))
         (config (yuanxuUserConfigFromProfile profile)))
    (agenticAiLabUserConfigPresentation
     config
     (yuanxu-user-profile-setting-keys profile))))
