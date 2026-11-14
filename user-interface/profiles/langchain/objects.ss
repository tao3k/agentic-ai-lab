;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; User Interface reusable Profile library: LangChain-style linear chain.

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
   (yuanxu-semantic-identity 'user-interface 'langchain)
   profiles:
   (yuanxu-module-profiles
    (yuanxu-profile-export 'memory (.ref config 'memory))
    (yuanxu-profile-export 'prompt (.ref config 'prompt))
    (yuanxu-profile-export 'model (.ref config 'model))
    (yuanxu-profile-export 'parser (.ref config 'parser))
    (yuanxu-profile-export 'no-tool (.ref config 'no-tool)))))
