;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object
        "control-plane/signatures.ss"
        (only-in "control-plane/flow.ss" FlowContract FlowOperationsContract)
        (only-in "control-plane/receipt.ss" receipt?)
        "config-prototypes.ss")
(export FunflowScopeContract JobConfigContract JobResultContract)

(def Pipeline (.cc Type. sexp: 'FunflowPipeline '.element? yuanxu-funflow-poo-pipeline?))
(def FunctionalDag (.cc Type. sexp: 'FunflowFunctionalDag '.element? yuanxu-funflow-functional-dag?))
(def Receipt (.cc Type. sexp: 'FunflowReceipt '.element? receipt?))
(def JobResultContract (Record steps: (list (Record)) flow-receipt: (list Receipt)))
(def JobConfigContract
  (Record name: (list Symbol) tasks: (list (Record))
          selected: (list (List Symbol)) finalizers: (list (List Symbol))))
(def StoreOperations
  (Record put-dir-flow: (list (Fun FlowContract <- Symbol))
          get-dir-flow: (list (Fun FlowContract <- Symbol))
          store-flow: (list (Fun FlowContract <- Symbol Symbol Any OperationSignature))))
;; Prototypes remain receiver-aware templates. Their .run formulas install runtime
;; Functions for the derived receiver; Scope admission must not freeze a parent's
;; computed method into a constant wrapper inherited by every child.
(def ScopeFields
  (Record config: (list JobConfigContract)
          types: (list (Record Scenario: (list Type)))
          runtime-vocabulary: (list (Record))
          flow: (list FlowOperationsContract) store: (list StoreOperations)
          durable-dag: (list (Record))
          pipeline-graph: (list (Fun FunctionalDag <- Pipeline))
          prototypes: (list (Record Task: (list (Record)) Job: (list (Record))
                                    check: (list (Record)) pipeline: (list (Record))))))
(def FunflowScopeContract (.cc ScopeFields identity: 'funflow/scope))
