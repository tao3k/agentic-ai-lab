;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .cc .ref object?)
        (only-in :clan/poo/mop Type.)
        (only-in :clan/poo/type Record)
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-user-config? yuanxu-user-config-modules
                 yuanxu-user-config-settings yuanxu-user-module-selection?))
(export DeveloperConfigContract DeveloperScopeContract)
(def DeveloperConfigContract
  (.cc Type. identity: 'developer/config
       .element?: (lambda (value)
                    (and (yuanxu-user-config? value)
                         (list? (yuanxu-user-config-modules value))
                         (andmap yuanxu-user-module-selection? (yuanxu-user-config-modules value))
                         (object? (yuanxu-user-config-settings value))))))
(def DeveloperScopeContract
  (.cc (Record config: (list DeveloperConfigContract)) identity: 'developer/scope))
