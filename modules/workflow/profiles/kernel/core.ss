;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: minimal kernel profile data for root profile projection.
;;; Invariant: no init syntax, doctor, or presentation owners are imported here.

(import (only-in :core/module-system/selection/objects
                 poo-flow-settings)
        (only-in :core/profile-composition/user-profile
                 pooFlowUserProfile
                 pooFlowUserProfileSet
                 poo-flow-user-profile-modules)
        (only-in "bundles.ss"
                 poo-flow-kernel-module-bundles))

(export poo-flow-kernel-module-bundles
        poo-flow-kernel-profile-module-bundles
        poo-flow-kernel-profile
        poo-flow-kernel-profile-set
        poo-flow-kernel-profile-modules)

;;; Kernel profile bundles are loaded through profile composition.
;; : (-> Unit [[PooUserModuleSelection]])
(def poo-flow-kernel-profile-module-bundles
  poo-flow-kernel-module-bundles)

;;; The kernel profile is inspectable user-profile data, not descriptor activation.
;; : (-> Unit PooUserProfile)
(def poo-flow-kernel-profile
  (pooFlowUserProfile
   'kernel
   poo-flow-kernel-profile-module-bundles
   (poo-flow-settings
    surface: "poo-flow"
    profile: "kernel"
    profile-kind: 'kernel)
   '(surface
     profile
     profile-kind)))

;;; Kernel profile set mirrors Doom's profiles.el registry shape while staying
;;; upstream-owned and declarative.
;; : (-> Unit PooUserProfileSet)
(def poo-flow-kernel-profile-set
  (pooFlowUserProfileSet
   'kernel-profiles
   'kernel
   (list poo-flow-kernel-profile)))

;; : (-> Unit [PooUserModuleSelection])
(def poo-flow-kernel-profile-modules
  (poo-flow-user-profile-modules poo-flow-kernel-profile))
