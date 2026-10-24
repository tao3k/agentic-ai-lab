;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Native Module descriptor carries the qualified Feature manifest, never a registry.
(import (only-in :clan/poo/object .o .ref)
        (only-in :agentic-ai-lab/modules/module-authoring/module-interface yuanxu-module-interface)
        (only-in :agentic-ai-lab/modules/module-authoring/module-descriptor agenticAiLabModules)
        (only-in :agentic-ai-lab/modules/session/descriptor agentic-ai-lab-session-module)
        "funs-features.ss")
(export agentic-ai-lab-ai-agentic-context-module)
(def (agentic-ai-lab-ai-agentic-context-module memory?)
  (let (profile-value (agentic-ai-lab-ai-agentic-context-profile memory?))
    (agenticAiLabModules
      (yuanxu-module-interface 'ai-agentic-context (.o) '())
      (.o id: 'ai-agentic-context group: 'agentic
          imports: (list (agentic-ai-lab-session-module))
          features: (.ref profile-value 'descriptors)
          config: (.o feature-manifest: profile-value)))))
