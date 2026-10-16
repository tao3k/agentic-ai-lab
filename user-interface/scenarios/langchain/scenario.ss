;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .def .o)
        (only-in :core/profile-composition/profile-bundle
                 profiles compose)
        :core/profile-composition/selection-syntax
        :poo-flow/modules/workflow/scenario/composition-syntax
        :poo-flow/user-interface/profiles/langchain)
(export LangChainProductionProfile langchain-scenario)

(.def LangChainProductionProfile
  (identity 'langchain-production)
  (stages
   (.o production:
       (.o graph: 'langchain-linear-chain
           loop: (.o fuel: 1 exit: 'parsed-output)
           proofs:
           (.o chain-order: #t
               prompt-before-model: #t
               parser-after-model: #t
               no-implicit-tool-branch: #t)))))

(user-composition langchain-scenario
  (compose profiles
    (use-module LangChainModule as chain memory prompt model parser no-tool)
    LangChainProductionProfile))
