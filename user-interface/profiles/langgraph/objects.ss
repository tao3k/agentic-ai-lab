;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; User Interface reusable Profile library: LangGraph-style state graph.

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
   (yuanxu-semantic-identity 'user-interface 'langgraph)
   profiles:
   (yuanxu-module-profiles
    (yuanxu-profile-export 'session (.ref config 'session))
    (yuanxu-profile-export 'state (.ref config 'state))
    (yuanxu-profile-export 'router (.ref config 'router))
    (yuanxu-profile-export 'agent-node (.ref config 'agent-node))
    (yuanxu-profile-export 'tool-node (.ref config 'tool-node))
    (yuanxu-profile-export 'bounded-loop (.ref config 'bounded-loop))
    (yuanxu-profile-export 'runtime-handoff (.ref config 'runtime-handoff)))))
