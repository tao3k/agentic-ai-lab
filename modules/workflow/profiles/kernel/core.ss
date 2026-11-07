;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: minimal kernel profile data for root profile projection.
;;; Invariant: no init syntax, doctor, or presentation owners are imported here.

(import (only-in :yuanxu/module-system/selection/objects
                 yuanxu-settings)
        (only-in :yuanxu/profile-composition/user-profile
                 yuanxuUserProfile
                 yuanxuUserProfileSet
                 yuanxu-user-profile-modules)
        (only-in "bundles.ss"
                 agentic-ai-lab-kernel-module-bundles))

(export agentic-ai-lab-kernel-module-bundles
        agentic-ai-lab-kernel-profile-module-bundles
        agentic-ai-lab-kernel-profile
        agentic-ai-lab-kernel-profile-set
        agentic-ai-lab-kernel-profile-modules)

;;; Kernel profile bundles are loaded through profile composition.
;; : (-> Unit [[PooUserModuleSelection]])
(def agentic-ai-lab-kernel-profile-module-bundles
  agentic-ai-lab-kernel-module-bundles)

;;; The kernel profile is inspectable user-profile data, not descriptor activation.
;; : (-> Unit PooUserProfile)
(def agentic-ai-lab-kernel-profile
  (yuanxuUserProfile
   'kernel
   agentic-ai-lab-kernel-profile-module-bundles
   (yuanxu-settings
    surface: "agentic-ai-lab"
    profile: "kernel"
    profile-kind: 'kernel)
   '(surface
     profile
     profile-kind)))

;;; Kernel profile set mirrors Doom's profiles.el registry shape while staying
;;; upstream-owned and declarative.
;; : (-> Unit PooUserProfileSet)
(def agentic-ai-lab-kernel-profile-set
  (yuanxuUserProfileSet
   'kernel-profiles
   'kernel
   (list agentic-ai-lab-kernel-profile)))

;; : (-> Unit [PooUserModuleSelection])
(def agentic-ai-lab-kernel-profile-modules
  (yuanxu-user-profile-modules agentic-ai-lab-kernel-profile))
