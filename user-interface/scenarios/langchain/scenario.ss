(import (only-in :yuanxu/modules/funflow/scenario Scenario)
        (only-in :clan/poo/mop .new)
        (only-in :agentic-ai-lab/init agentic-ai-lab.init.exports)
        (only-in :clan/poo/object .get))
;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .def .o)
        (only-in :yuanxu/profile-composition/profile-bundle
                 profiles compose)
        :yuanxu/profile-composition/selection-syntax
        )

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

(def langchain-scenario
  (.new Scenario name: 'langchain-scenario
        config: (let ((LangChainModule (.get agentic-ai-lab.init.exports Profiles langchain profile)))
    (compose profiles
    (use-module LangChainModule as chain memory prompt model parser no-tool)
    LangChainProductionProfile))))
