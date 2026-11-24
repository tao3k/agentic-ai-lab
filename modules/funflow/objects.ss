;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object
        (only-in "control-plane/agent-harness-vocabulary.ss"
                 +yuanxu-agent-operation-kinds+ +yuanxu-runtime-snapshot-statuses+)
        (only-in "job-prototypes.ss" Task. Job.)
        ;; This role publishes these combinators, not the aggregate control
        ;; plane (including Agent harnesses and unrelated syntax facades).
        (only-in "control-plane/flow.ss"
                 flow-arr flow-then flow-fanout flow-map flow-bind
                 flow-first flow-second conditional-flow try-flow
                 return-flow cached-pure-flow)
        (only-in "store-flow.ss" put-dir-flow get-dir-flow store-flow)
        (only-in "durable-dag.ss" FunflowDurableDagExports)
        "config-prototypes.ss" "graph-projection.ss"
        (only-in "scenario.ss" Scenario))
(export Task. Job. FunflowModule.)
(.def FunflowModule.
  types: (.o (Scenario))
  runtime-vocabulary:
  (.o operation-kinds: +yuanxu-agent-operation-kinds+
      snapshot-statuses: +yuanxu-runtime-snapshot-statuses+)
  store: (.o (put-dir-flow) (get-dir-flow) (store-flow))
  flow: (.o (flow-arr) (flow-then) (flow-fanout) (flow-map) (flow-bind)
            (flow-first) (flow-second) (conditional-flow) (try-flow)
            (return-flow) (cached-pure-flow))
  durable-dag: FunflowDurableDagExports
  pipeline-graph: yuanxu-funflow-poo-pipeline->functional-dag
  prototypes: (.o Task: Task. Job: Job. check: funflow-check pipeline: funflow-pipeline))
