;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; -*- Gerbil -*-

(import (only-in :clan/poo/object .def .o .ref)
        (only-in :yuanxu/module-system/schema/relations yuanxu-semantic-identity)
        (only-in :yuanxu/module-system/authoring/roles
                 yuanxu-semantic-module)
        (only-in :yuanxu/profile-composition/profile-bundle
                 yuanxu-profile-export
                 yuanxu-module-profiles))



(export Profile.)
(.def (Profile. @ [] config)
  defaults: config
  profile: (yuanxu-semantic-module
   (yuanxu-semantic-identity 'user-interface 'crewai)
   profiles:
   (yuanxu-module-profiles
    (yuanxu-profile-export 'agent (.ref config 'agent))
    (yuanxu-profile-export 'task (.ref config 'task))
    (yuanxu-profile-export 'crew (.ref config 'crew))
    (yuanxu-profile-export 'planning (.ref config 'planning))
    (yuanxu-profile-export 'memory (.ref config 'memory))
    (yuanxu-profile-export 'knowledge (.ref config 'knowledge))
    (yuanxu-profile-export 'sequential-process (.ref config 'sequential-process))
    (yuanxu-profile-export 'hierarchical-process (.ref config 'hierarchical-process))
    (yuanxu-profile-export 'flow-state (.ref config 'flow-state))
    (yuanxu-profile-export 'flow-router (.ref config 'flow-router))
    (yuanxu-profile-export 'flow-persist (.ref config 'flow-persist))
    (yuanxu-profile-export 'guardrail (.ref config 'guardrail))
    (yuanxu-profile-export 'human-input (.ref config 'human-input))
    (yuanxu-profile-export 'observability (.ref config 'observability))
    (yuanxu-profile-export 'runtime-handoff (.ref config 'runtime-handoff)))))
