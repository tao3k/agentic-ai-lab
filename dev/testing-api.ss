;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Optional ASP policy composition belongs to the development package only.
(import (only-in :clan/poo/object .cc)
        (only-in :asp-gerbil-scheme/testing-api +asp-testing-interface+)
        :poo-flow/testing-api
        "./modules/testing/testing-extension"
        (only-in :yuanxu/profile-composition/policy
                 yuanxu-user-profile-policy-admit yuanxu-user-profile-set-policy-admit))
(export (import: :poo-flow/testing-api)
        (import: "./modules/testing/testing-extension")
        +poo-flow-testing-interface+)
(def +poo-flow-testing-interface+
  (.cc (poo-flow-testing-observability-extension +asp-testing-interface+)
       .check-user-profile: yuanxu-user-profile-policy-admit
       .check-user-profile-set: yuanxu-user-profile-set-policy-admit))
