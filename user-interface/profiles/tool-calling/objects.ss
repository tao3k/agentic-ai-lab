;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; -*- Gerbil -*-

(import (only-in :clan/poo/object .def .o .ref)
        (only-in :tao3k/yuanxu/module-system/schema/relations yuanxu-semantic-identity)
        (only-in :tao3k/yuanxu/module-system/authoring/roles
                 yuanxu-semantic-module)
        (only-in :tao3k/yuanxu/profile-composition/profile-bundle
                 yuanxu-profile-export
                 yuanxu-module-profiles))



(export Profile.)
(.def (Profile. @ [] config)
  defaults: config
  profile: (yuanxu-semantic-module
   (yuanxu-semantic-identity 'user-interface 'tool-calling)
   profiles:
   (yuanxu-module-profiles
    (yuanxu-profile-export 'tool-request (.ref config 'tool-request))
    (yuanxu-profile-export 'tool-schema (.ref config 'tool-schema))
    (yuanxu-profile-export 'tool-permission (.ref config 'tool-permission))
    (yuanxu-profile-export 'sandbox-scope (.ref config 'sandbox-scope))
    (yuanxu-profile-export 'argument-validation (.ref config 'argument-validation))
    (yuanxu-profile-export 'untrusted-observation (.ref config 'untrusted-observation))
    (yuanxu-profile-export 'tool-cooldown (.ref config 'tool-cooldown))
    (yuanxu-profile-export 'result-contract (.ref config 'result-contract))
    (yuanxu-profile-export 'runtime-binding (.ref config 'runtime-binding))
    (yuanxu-profile-export 'receipt-gate (.ref config 'receipt-gate))
    (yuanxu-profile-export 'observability (.ref config 'observability)))))
