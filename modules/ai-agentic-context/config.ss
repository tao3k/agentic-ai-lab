;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Native Module descriptor carries the qualified Feature manifest, never a registry.
(import (only-in :clan/poo/object .o .ref)
        (only-in :poo-flow/modules/module-authoring/module-interface poo-flow-module-interface)
        (only-in :poo-flow/modules/module-authoring/module-descriptor pooFlowModules)
        (only-in :poo-flow/modules/session/descriptor poo-flow-session-module)
        "funs-features.ss")
(export poo-flow-ai-agentic-context-module)
(def (poo-flow-ai-agentic-context-module memory?)
  (let (profile-value (poo-flow-ai-agentic-context-profile memory?))
    (pooFlowModules
      (poo-flow-module-interface 'ai-agentic-context (.o) '())
      (.o id: 'ai-agentic-context group: 'agentic
          imports: (list (poo-flow-session-module))
          features: (.ref profile-value 'descriptors)
          config: (.o feature-manifest: profile-value)))))
