;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: hygienic authoring macros for the functional flow kernel.
;;; Invariant: macros expand to public flow/plan combinators, not a workflow DSL.

(import :poo-flow/modules/workflow/control-plane/flow
        :poo-flow/modules/workflow/control-plane/plan)

(export defpoo-flow-arr
        defpoo-flow-identity
        defpoo-flow-compose
        defpoo-flow-map
        defpoo-flow-bind
        defpoo-flow-kleisli
        defpoo-flow-fanout
        defpoo-flow-dag
        defpoo-flow-dag-artifacts
        defpoo-flow-try
        defpoo-flow-first
        defpoo-flow-second)

;; defpoo-flow-define-binding-macro
;;   : (-> Identifier Identifier SyntaxList MacroDefinition)
;;   | doc m%
;;       Internal macro family generator for public flow binding forms. It
;;       keeps the hygienic quoting/binding pattern in one place while each
;;       exported macro still names its constructor and argument surface.
;;
;;       # Examples
;;       ```scheme
;;       (defpoo-flow-define-binding-macro defpoo-flow-arr flow-arr
;;         (proc input-contract output-contract))
;;       ;; => macro definition for an arrow-flow binding form
;;       ```
;;     %
(defrules defpoo-flow-define-binding-macro ()
  ((_ macro-name constructor (arg ...))
   (defrules macro-name ()
     ((_ binding flow-name arg ...)
      (def binding
        (constructor 'flow-name arg ...))))))

;; defpoo-flow-arr
;;   : (-> Identifier Identifier ProcedureExpr ContractExpr ContractExpr FlowBinding)
;;   | doc m%
;;       `defpoo-flow-arr` defines a pure arrow flow with an identifier-owned
;;       flow name while leaving the procedure and contracts as caller
;;       expressions.
;;
;;       # Examples
;;       ```scheme
;;       (defpoo-flow-arr parse-flow parse-request parse request-contract result-contract)
;;       ;; => flow binding
;;       ```
;;     %
(defpoo-flow-define-binding-macro
 defpoo-flow-arr
 flow-arr
 (proc input-contract output-contract))

;; defpoo-flow-identity
;;   : (-> Identifier Identifier ContractExpr FlowBinding)
;;   | doc m%
;;       `defpoo-flow-identity` defines a category identity flow for one
;;       contract boundary.
;;
;;       # Examples
;;       ```scheme
;;       (defpoo-flow-identity id-flow identity request-contract)
;;       ;; => identity flow binding
;;       ```
;;     %
(defpoo-flow-define-binding-macro
 defpoo-flow-identity
 flow-identity
 (contract))

;; defpoo-flow-compose
;;   : (-> Identifier Identifier FlowExpr FlowExpr FlowBinding)
;;   | doc m%
;;       `defpoo-flow-compose` defines sequential composition over already-built
;;       flows.
;;
;;       # Examples
;;       ```scheme
;;       (defpoo-flow-compose checked-flow checked parse-flow validate-flow)
;;       ;; => composed flow binding
;;       ```
;;     %
(defpoo-flow-define-binding-macro
 defpoo-flow-compose
 flow-then
 (left right))

;; defpoo-flow-map
;;   : (-> Identifier Identifier FlowExpr ProcedureExpr ContractExpr FlowBinding)
;;   | doc m%
;;       `defpoo-flow-map` defines a functional output map over an existing
;;       flow.
;;
;;       # Examples
;;       ```scheme
;;       (defpoo-flow-map rendered render checked-flow render-result output-contract)
;;       ;; => mapped flow binding
;;       ```
;;     %
(defpoo-flow-define-binding-macro
 defpoo-flow-map
 flow-map
 (source proc output-contract))

;; defpoo-flow-bind
;;   : (-> Identifier Identifier FlowExpr ProcedureExpr ContractExpr FlowBinding)
;;   | doc m%
;;       `defpoo-flow-bind` defines a Kleisli bind where the binder returns the
;;       next flow.
;;
;;       # Examples
;;       ```scheme
;;       (defpoo-flow-bind routed route source-flow choose-flow output-contract)
;;       ;; => bound flow binding
;;       ```
;;     %
(defpoo-flow-define-binding-macro
 defpoo-flow-bind
 flow-bind
 (source binder output-contract))

;; defpoo-flow-kleisli
;;   : (-> Identifier Identifier FlowExpr ProcedureExpr ContractExpr FlowBinding)
;;   | doc m%
;;       `defpoo-flow-kleisli` is the authoring-layer alias for the Kleisli bind
;;       form.
;;
;;       # Examples
;;       ```scheme
;;       (defpoo-flow-kleisli routed route source-flow choose-flow output-contract)
;;       ;; => bound flow binding
;;       ```
;;     %
(defpoo-flow-define-binding-macro
 defpoo-flow-kleisli
 flow-kleisli
 (source binder output-contract))

;; defpoo-flow-fanout
;;   : (-> Identifier Identifier FlowExpr FlowExpr FlowBinding)
;;   | doc m%
;;       `defpoo-flow-fanout` defines Arrow-style fanout without selecting a
;;       scheduler.
;;
;;       # Examples
;;       ```scheme
;;       (defpoo-flow-fanout split-flow split left-flow right-flow)
;;       ;; => fanout flow binding
;;       ```
;;     %
(defpoo-flow-define-binding-macro
 defpoo-flow-fanout
 flow-fanout
 (left right))

;; defpoo-flow-dag
;;   : (-> Identifier Identifier FlowExpr FlowExpr FlowBinding)
;;   | doc m%
;;       `defpoo-flow-dag` defines a functional DAG flow as Arrow fanout while
;;       keeping receipt and manifest projection separate.
;;
;;       # Examples
;;       ```scheme
;;       (defpoo-flow-dag dag-flow dag left-flow right-flow)
;;       ;; => dag flow binding
;;       ```
;;     %
(defpoo-flow-define-binding-macro
 defpoo-flow-dag
 flow-fanout
 (left right))

;; defpoo-flow-dag-artifacts
;;   : (-> Identifier Identifier FlowExpr RequestIdExpr DagArtifactBindings)
;;   | doc m%
;;       `defpoo-flow-dag-artifacts` defines report-only DAG artifacts for an
;;       existing flow binding without executing runtime work.
;;
;;       # Examples
;;       ```scheme
;;       (defpoo-flow-dag-artifacts receipt manifest dag-flow request-id)
;;       ;; => artifact bindings
;;       ```
;;     %
(defrules defpoo-flow-dag-artifacts ()
  ((_ receipt-binding manifest-binding source request-id)
   (begin
     (def receipt-binding
       (flow->dag-receipt source))
     (def manifest-binding
       (flow->dag-runtime-manifest source request-id)))))

;; defpoo-flow-try
;;   : (-> Identifier Identifier FlowExpr FlowBinding)
;;   | doc m%
;;       `defpoo-flow-try` defines a Funflow-style try boundary over an existing
;;       flow.
;;
;;       # Examples
;;       ```scheme
;;       (defpoo-flow-try guarded-flow guarded source-flow)
;;       ;; => try flow binding
;;       ```
;;     %
(defpoo-flow-define-binding-macro
 defpoo-flow-try
 try-flow
 (source))

;; defpoo-flow-first
;;   : (-> Identifier Identifier FlowExpr ContractExpr FlowBinding)
;;   | doc m%
;;       `defpoo-flow-first` defines Arrow `first` over a pair-shaped value.
;;
;;       # Examples
;;       ```scheme
;;       (defpoo-flow-first first-flow first source-flow second-contract)
;;       ;; => first flow binding
;;       ```
;;     %
(defpoo-flow-define-binding-macro
 defpoo-flow-first
 flow-first
 (source second-contract))

;; defpoo-flow-second
;;   : (-> Identifier Identifier FlowExpr ContractExpr FlowBinding)
;;   | doc m%
;;       `defpoo-flow-second` defines Arrow `second` over a pair-shaped value.
;;
;;       # Examples
;;       ```scheme
;;       (defpoo-flow-second second-flow second source-flow first-contract)
;;       ;; => second flow binding
;;       ```
;;     %
(defpoo-flow-define-binding-macro
 defpoo-flow-second
 flow-second
 (source first-contract))
