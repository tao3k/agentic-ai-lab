;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Declarative managed Module publication; the source wrapper owns role imports.
(.def D2
  identity: 'd2
  tags: '(graph diagram)
  core:
  (.o requires: (.o)
      scope-contract: D2ScopeContract
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
