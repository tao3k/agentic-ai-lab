;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; User Interface reusable Profile library: LangChain-style linear chain.

(import (only-in :clan/poo/object .def .o .ref)
        (only-in :core/module-system/schema/relations poo-flow-semantic-identity)
        (only-in :core/module-system/authoring/roles
                 poo-flow-semantic-module)
        (only-in :core/profile-composition/profile-bundle
                 poo-flow-profile-export
                 poo-flow-module-profiles))
(export langchain LangChainModule)

(.def langchain
    (memory (.o (identity 'memory)
                (name 'langchain-stateless-memory)
                (contract 'no-cross-turn-state)
                (policy 'memory-is-optional)))
    (prompt (.o (identity 'prompt)
                (name 'langchain-prompt-template)
                (contract 'input-to-prompt)
                (policy 'prompt-before-model)))
    (model (.o (identity 'model)
               (name 'langchain-chat-model)
               (contract 'single-turn-input-output)
               (policy 'model-call-is-terminal)))
    (parser (.o (identity 'parser)
                (name 'langchain-output-parser)
                (contract 'model-output-to-value)
                (policy 'parser-after-model)))
    (no-tool (.o (identity 'no-tool)
                 (name 'langchain-no-tool)
                 (contract 'model-only-chain)
                 (policy 'no-tool-call-branch))))

(def LangChainModule
  (poo-flow-semantic-module
   (poo-flow-semantic-identity 'user-interface 'langchain)
   profiles:
   (poo-flow-module-profiles
    (poo-flow-profile-export 'memory (.ref langchain 'memory))
    (poo-flow-profile-export 'prompt (.ref langchain 'prompt))
    (poo-flow-profile-export 'model (.ref langchain 'model))
    (poo-flow-profile-export 'parser (.ref langchain 'parser))
    (poo-flow-profile-export 'no-tool (.ref langchain 'no-tool)))))
