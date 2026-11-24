;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: hygienic authoring macros for the functional flow kernel.
;;; Invariant: macros expand to public flow/plan combinators, not a workflow DSL.

(import :tao3k/agentic-ai-lab/modules/funflow/control-plane/flow
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/graph)

(export defyuanxu-arr
        defyuanxu-identity
        defyuanxu-compose
        defyuanxu-map
        defyuanxu-bind
        defyuanxu-kleisli
        defyuanxu-fanout
        defyuanxu-dag
        defyuanxu-dag-artifacts
        defyuanxu-try
        defyuanxu-first
        defyuanxu-second)

;; defyuanxu-define-binding-macro
;;   : (-> Identifier Identifier SyntaxList MacroDefinition)
;;   | doc m%
;;       Internal macro family generator for public flow binding forms. It
;;       keeps the hygienic quoting/binding pattern in one place while each
;;       exported macro still names its constructor and argument surface.
;;
;;       # Examples
;;       ```scheme
;;       (defyuanxu-define-binding-macro defyuanxu-arr flow-arr
;;         (signature proc))
;;       ;; => macro definition for an arrow-flow binding form
;;       ```
;;     %
(defrules defyuanxu-define-binding-macro ()
  ((_ macro-name constructor (arg ...))
   (defrules macro-name ()
     ((_ binding flow-name arg ...)
      (def binding
        (constructor 'flow-name arg ...))))))

;; defyuanxu-arr
;;   : (-> Identifier Identifier FunctionTypeExpr ProcedureExpr FlowBinding)
;;   | doc m%
;;       `defyuanxu-arr` defines a pure arrow flow with an identifier-owned
;;       flow name while leaving the procedure and contracts as caller
;;       expressions.
;;
;;       # Examples
;;       ```scheme
;;       (defyuanxu-arr parse-flow parse-request (Fun result-contract <- request-contract) parse)
;;       ;; => flow binding
;;       ```
;;     %
(defyuanxu-define-binding-macro
 defyuanxu-arr
 flow-arr
 (signature proc))

;; defyuanxu-identity
;;   : (-> Identifier Identifier ContractExpr FlowBinding)
;;   | doc m%
;;       `defyuanxu-identity` defines a category identity flow for one
;;       contract boundary.
;;
;;       # Examples
;;       ```scheme
;;       (defyuanxu-identity id-flow identity request-contract)
;;       ;; => identity flow binding
;;       ```
;;     %
(defyuanxu-define-binding-macro
 defyuanxu-identity
 flow-identity
 (contract))

;; defyuanxu-compose
;;   : (-> Identifier Identifier FlowExpr FlowExpr FlowBinding)
;;   | doc m%
;;       `defyuanxu-compose` defines sequential composition over already-built
;;       flows.
;;
;;       # Examples
;;       ```scheme
;;       (defyuanxu-compose checked-flow checked parse-flow validate-flow)
;;       ;; => composed flow binding
;;       ```
;;     %
(defyuanxu-define-binding-macro
 defyuanxu-compose
 flow-then
 (left right))

;; defyuanxu-map
;;   : (-> Identifier Identifier FlowExpr FunctionTypeExpr ProcedureExpr FlowBinding)
;;   | doc m%
;;       `defyuanxu-map` defines a functional output map over an existing
;;       flow.
;;
;;       # Examples
;;       ```scheme
;;       (defyuanxu-map rendered render checked-flow (Fun output-contract <- input-contract) render-result)
;;       ;; => mapped flow binding
;;       ```
;;     %
(defyuanxu-define-binding-macro
 defyuanxu-map
 flow-map
 (source signature proc))

;; defyuanxu-bind
;;   : (-> Identifier Identifier FlowExpr FunctionTypeExpr ProcedureExpr FlowBinding)
;;   | doc m%
;;       `defyuanxu-bind` defines a Kleisli bind where the binder returns the
;;       next flow.
;;
;;       # Examples
;;       ```scheme
;;       (defyuanxu-bind routed route source-flow choose-flow output-contract)
;;       ;; => bound flow binding
;;       ```
;;     %
(defyuanxu-define-binding-macro
 defyuanxu-bind
 flow-bind
 (source output-contract binder))

;; defyuanxu-kleisli
;;   : (-> Identifier Identifier FlowExpr FunctionTypeExpr ProcedureExpr FlowBinding)
;;   | doc m%
;;       `defyuanxu-kleisli` is the authoring-layer alias for the Kleisli bind
;;       form.
;;
;;       # Examples
;;       ```scheme
;;       (defyuanxu-kleisli routed route source-flow choose-flow output-contract)
;;       ;; => bound flow binding
;;       ```
;;     %
(defyuanxu-define-binding-macro
 defyuanxu-kleisli
 flow-kleisli
 (source output-contract binder))

;; defyuanxu-fanout
;;   : (-> Identifier Identifier FlowExpr FlowExpr FlowBinding)
;;   | doc m%
;;       `defyuanxu-fanout` defines Arrow-style fanout without selecting a
;;       scheduler.
;;
;;       # Examples
;;       ```scheme
;;       (defyuanxu-fanout split-flow split left-flow right-flow)
;;       ;; => fanout flow binding
;;       ```
;;     %
(defyuanxu-define-binding-macro
 defyuanxu-fanout
 flow-fanout
 (left right))

;; defyuanxu-dag
;;   : (-> Identifier Identifier FlowExpr FlowExpr FlowBinding)
;;   | doc m%
;;       `defyuanxu-dag` defines a functional DAG flow as Arrow fanout while
;;       keeping receipt and manifest projection separate.
;;
;;       # Examples
;;       ```scheme
;;       (defyuanxu-dag dag-flow dag left-flow right-flow)
;;       ;; => dag flow binding
;;       ```
;;     %
(defyuanxu-define-binding-macro
 defyuanxu-dag
 flow-fanout
 (left right))

;; defyuanxu-dag-artifacts
;;   : (-> Identifier Identifier FlowExpr RequestIdExpr DagArtifactBindings)
;;   | doc m%
;;       `defyuanxu-dag-artifacts` defines report-only DAG artifacts for an
;;       existing flow binding without executing runtime work.
;;
;;       # Examples
;;       ```scheme
;;       (defyuanxu-dag-artifacts receipt manifest dag-flow request-id)
;;       ;; => artifact bindings
;;       ```
;;     %
(defrules defyuanxu-dag-artifacts ()
  ((_ receipt-binding manifest-binding source request-id)
   (begin
     (def receipt-binding
       (flow->dag-receipt source))
     (def manifest-binding
       (flow->dag-runtime-manifest source request-id)))))

;; defyuanxu-try
;;   : (-> Identifier Identifier FlowExpr FlowBinding)
;;   | doc m%
;;       `defyuanxu-try` defines a Funflow-style try boundary over an existing
;;       flow.
;;
;;       # Examples
;;       ```scheme
;;       (defyuanxu-try guarded-flow guarded source-flow)
;;       ;; => try flow binding
;;       ```
;;     %
(defyuanxu-define-binding-macro
 defyuanxu-try
 try-flow
 (source))

;; defyuanxu-first
;;   : (-> Identifier Identifier FlowExpr ContractExpr FlowBinding)
;;   | doc m%
;;       `defyuanxu-first` defines Arrow `first` over a pair-shaped value.
;;
;;       # Examples
;;       ```scheme
;;       (defyuanxu-first first-flow first source-flow second-contract)
;;       ;; => first flow binding
;;       ```
;;     %
(defyuanxu-define-binding-macro
 defyuanxu-first
 flow-first
 (source second-contract))

;; defyuanxu-second
;;   : (-> Identifier Identifier FlowExpr ContractExpr FlowBinding)
;;   | doc m%
;;       `defyuanxu-second` defines Arrow `second` over a pair-shaped value.
;;
;;       # Examples
;;       ```scheme
;;       (defyuanxu-second second-flow second source-flow first-contract)
;;       ;; => second flow binding
;;       ```
;;     %
(defyuanxu-define-binding-macro
 defyuanxu-second
 flow-second
 (source first-contract))
