;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Core-native test declarations and profile admission; no optional policy engine.
(import (only-in :clan/poo/object .call .slot?)
        :yuanxu/observability/testing-case
        (only-in :yuanxu/profile-composition/policy
                 yuanxu-user-profile-policy-admitted?
                 yuanxu-user-profile-set-policy-admitted?))
(export (import: :yuanxu/observability/testing-case)
        poo-flow-testing-check-user-profile poo-flow-testing-check-user-profile-set
        poo-flow-testing-admit-user-profile! poo-flow-testing-admit-user-profile-set!)

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
    (unless (yuanxu-user-profile-policy-admitted? receipt)
      (error "POO Flow user profile policy rejected declaration" receipt))
    receipt))

(def (poo-flow-testing-admit-user-profile-set! testing profile-set)
  (let (receipt (poo-flow-testing-check-user-profile-set testing profile-set))
    (unless (yuanxu-user-profile-set-policy-admitted? receipt)
      (error "POO Flow user profile-set policy rejected declaration" receipt))
    receipt))
