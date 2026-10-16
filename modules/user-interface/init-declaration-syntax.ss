;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: lightweight Doom-style init declaration syntax.
;;; Invariant: the common init.ss path lowers only to declarative module data.

(import :poo-flow/modules/user-interface/module-selection-syntax
        (only-in :poo-flow/modules/user-interface/profile-core
                 pooFlowUserProfile
                 pooFlowUserProfileSet
                 pooFlowUserProfileExtend
                 pooFlowDefaultUserSettings
                 poo-flow-default-user-setting-keys))
(export poo-flow!)

;;; The short form is the normal user entry. The two explicit binding forms
;;; remain available for profile registries without importing the full UI
;;; doctor, presentation, sandbox, and runtime configuration facade.
(defsyntax (poo-flow! stx)
  (syntax-case stx (profile extends)
    ((_ profile-binding
        profile-set-binding
        (profile profile-name (extends base-profile))
        init-clause ...)
     (syntax
      (begin
        (def profile-binding
          (pooFlowUserProfileExtend
           'profile-name
           base-profile
           (poo-flow-modules! init-clause ...)))
        (def profile-set-binding
          (pooFlowUserProfileSet
           'user
           'profile-name
           (list profile-binding))))))
    ((_ profile-binding
        profile-set-binding
        (profile profile-name)
        init-clause ...)
     (syntax
      (begin
        (def profile-binding
          (pooFlowUserProfile
           'profile-name
           (poo-flow-modules! init-clause ...)
           (pooFlowDefaultUserSettings 'profile-name)
           poo-flow-default-user-setting-keys))
        (def profile-set-binding
          (pooFlowUserProfileSet
           'user
           'profile-name
           (list profile-binding))))))
    ((ctx init-clause ...)
     (with-syntax ((module-bundles-binding
                    (datum->syntax (syntax ctx)
                                   'poo-flow-user-module-bundles)))
       (syntax
        (begin
          (def module-bundles-binding
            (poo-flow-modules! init-clause ...))
          (export module-bundles-binding)))))))
