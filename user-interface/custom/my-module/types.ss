;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(export +agentic-ai-lab-custom-my-module-identity+)

(def +agentic-ai-lab-custom-my-module-identity+ 'my-module)

(import (only-in :clan/poo/object .cc)
        (only-in :clan/poo/type Record Symbol))
(export MyModuleScopeContract)
(def MyModuleScopeContract
  (.cc (Record config: (list (Record identity: (list Symbol)
                                    profile-source: (list Symbol)
                                    scenario-source: (list Symbol))))
       identity: 'my-module/scope))
