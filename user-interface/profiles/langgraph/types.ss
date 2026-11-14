;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .cc)
        (only-in :clan/poo/type Record)
        (only-in :tao3k/yuanxu/module-system/authoring/roles SemanticModuleContract))
(export ScopeContract)
(def ScopeContract (.cc (Record profile: (list SemanticModuleContract)) identity: 'profiles/langgraph))
