;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Public POO Flow testing policy interface.
;;; ASP owns native gxtest execution and generic profile algebra. POO Flow
;;; extends that one interface once with its package policies; downstream
;;; packages only refine the resulting POO value with local Profiles.

(import (only-in :clan/poo/object .call .cc .slot?)
        (only-in :asp-gerbil-scheme/testing-api +asp-testing-interface+)
        "./modules/testing/testing-extension"
        :core/observability/testing-case
        (only-in :core/profile-composition/policy
                 poo-flow-user-profile-policy-admit
                 poo-flow-user-profile-set-policy-admit
                 poo-flow-user-profile-policy-admitted?
                 poo-flow-user-profile-set-policy-admitted?))

(export (import: "./modules/testing/testing-extension")
        (import: :core/observability/testing-case)
        +poo-flow-testing-interface+
        poo-flow-testing-check-user-profile
        poo-flow-testing-check-user-profile-set
        poo-flow-testing-admit-user-profile!
        poo-flow-testing-admit-user-profile-set!)

;;; One public object owns the ASP -> POO Flow policy extension. Package-local
;;; test interfaces inherit this value instead of rebuilding the chain.
(def +poo-flow-testing-interface+
  (.cc (poo-flow-testing-observability-extension +asp-testing-interface+)
       .check-user-profile: poo-flow-user-profile-policy-admit
       .check-user-profile-set: poo-flow-user-profile-set-policy-admit))

(def (poo-flow-testing-check-user-profile testing profile)
  (unless (.slot? testing '.check-user-profile)
    (error "testing interface has no user profile policy" testing))
  (.call testing .check-user-profile profile))

(def (poo-flow-testing-check-user-profile-set testing profile-set)
  (unless (.slot? testing '.check-user-profile-set)
    (error "testing interface has no user profile-set policy" testing))
  (.call testing .check-user-profile-set profile-set))

(def (poo-flow-testing-admit-user-profile! testing profile)
  (let (receipt (poo-flow-testing-check-user-profile testing profile))
    (unless (poo-flow-user-profile-policy-admitted? receipt)
      (error "POO Flow user profile policy rejected declaration" receipt))
    receipt))

(def (poo-flow-testing-admit-user-profile-set! testing profile-set)
  (let (receipt (poo-flow-testing-check-user-profile-set testing profile-set))
    (unless (poo-flow-user-profile-set-policy-admitted? receipt)
      (error "POO Flow user profile-set policy rejected declaration" receipt))
    receipt))
