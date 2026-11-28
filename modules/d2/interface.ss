;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .def .o)
        (only-in "./config.ss" D2Config)
        (only-in "./types.ss" D2ScopeContract)
        (only-in "./objects.ss" D2Diagram. D2Node. D2Relation. D2Question.
                 D2Representation. D2AuthoringContext.)
        (only-in "./func.ss" d2-infer d2-review d2-plan-explanation
                 d2-author d2-scene d2-teaching d2-source-for-config
                 ExperienceWindow. context-evolution-evaluate context-evolution-rows))
(export D2)

(.def (D2 @ [] config)
  config: D2Config
  identity: 'd2
  tags: '(graph diagram)
  core:
  (.o scope-contract: D2ScopeContract
      exports:
      (.o config: D2Config
          prototypes: (.o Diagram: D2Diagram. Node: D2Node. Relation: D2Relation.
                          Question: D2Question. Representation: D2Representation.
                          AuthoringContext: D2AuthoringContext.)
          infer: d2-infer review: d2-review plan: d2-plan-explanation
          author: d2-author
          scene: d2-scene
          teaching: d2-teaching
          source: (d2-source-for-config config)
          profiles:
          (.o ContextEvolution:
              (.o Window: ExperienceWindow.
                  evaluate: context-evolution-evaluate
                  rows: context-evolution-rows))))
  features: (.o))
