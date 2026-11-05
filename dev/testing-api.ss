;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Optional ASP policy composition belongs to the development package only.
(import (only-in :clan/poo/object .cc .call .slot?)
        (only-in :asp-gerbil-scheme/testing-api +asp-testing-interface+)
        :yuanxu/observability/testing-case
        "./modules/testing/testing-extension"
        (only-in :yuanxu/profile-composition/policy
                 yuanxu-user-profile-policy-admit yuanxu-user-profile-set-policy-admit
                 yuanxu-user-profile-policy-admitted? yuanxu-user-profile-set-policy-admitted?))
(export (import: :yuanxu/observability/testing-case)
        (import: "./modules/testing/testing-extension")
        agentic-ai-lab-testing-check-user-profile agentic-ai-lab-testing-check-user-profile-set
        agentic-ai-lab-testing-admit-user-profile! agentic-ai-lab-testing-admit-user-profile-set!
        +agentic-ai-lab-testing-interface+)
(def +agentic-ai-lab-testing-interface+
  (.cc (agentic-ai-lab-testing-observability-extension +asp-testing-interface+)
       .check-user-profile: yuanxu-user-profile-policy-admit
       .check-user-profile-set: yuanxu-user-profile-set-policy-admit))

(def (agentic-ai-lab-testing-check-user-profile testing profile)
  (unless (.slot? testing '.check-user-profile)
    (error "testing interface has no user profile policy" testing))
  (.call testing .check-user-profile profile))

(def (agentic-ai-lab-testing-check-user-profile-set testing profile-set)
  (unless (.slot? testing '.check-user-profile-set)
    (error "testing interface has no user profile-set policy" testing))
  (.call testing .check-user-profile-set profile-set))

(def (agentic-ai-lab-testing-admit-user-profile! testing profile)
  (let (receipt (agentic-ai-lab-testing-check-user-profile testing profile))
    (unless (yuanxu-user-profile-policy-admitted? receipt)
      (error "Agentic AI Lab user profile policy rejected declaration" receipt))
    receipt))

(def (agentic-ai-lab-testing-admit-user-profile-set! testing profile-set)
  (let (receipt (agentic-ai-lab-testing-check-user-profile-set testing profile-set))
    (unless (yuanxu-user-profile-set-policy-admitted? receipt)
      (error "Agentic AI Lab user profile-set policy rejected declaration" receipt))
    receipt))
