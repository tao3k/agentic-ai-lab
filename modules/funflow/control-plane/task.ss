;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: tasks describe work intent and adapter request shape.
;;; Invariant: only pure/scheme tasks carry an in-process executor.

(import (only-in :clan/poo/object .@ .o .get .ref .slot? object? .cc)
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/signatures
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/projection-syntax
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/roles
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/failure
        :tao3k/yuanxu/object/role-syntax)

(export TaskContract task-signature ExecutionRequestContract
        (import: :tao3k/agentic-ai-lab/modules/funflow/control-plane/signatures)
        make-task
        task?
        task-name
        task-kind
        task-request
        task-input-contract
        task-output-contract
        task-executor
        make-task-family-descriptor
        task-family-descriptor?
        task-family-descriptor-prototype
        make-task-family-registry
        task-family-registry?
        task-family-registry-prototype
        default-task-family-registry
        task-family-registry-name
        task-family-registry-descriptors
        task-family-registry-extend
        pure-task-family-descriptor
        scheme-task-family-descriptor
        external-task-family-descriptor
        task-family-descriptors
        task-family-name
        task-family-capability
        task-family-route
        task-family-runtime-owner
        task-family-adapter-dispatch
        task-family-for-kind-in
        task-family-for-kind
        task-descriptor-in
        task-descriptor
        task-capability-in
        task-capability
        task-route-in
        task-route
        task-runtime-owner-in
        task-runtime-owner
        task-adapter-operation-in
        task-adapter-operation
        task-request-operation
        task-request-payload
        make-pure-task
        make-scheme-task
        make-external-task
        task-local?-in
        task-local?
        task-adapter-routed?-in
        task-adapter-routed?
        task-normalized-request
        task-adapter-request
        make-execution-request
        execution-request?
        execution-request-name
        execution-request-kind
        execution-request-request
        execution-request-input
        execution-request-input-contract
        execution-request-output-contract
        execution-request-plan-id
        execution-request-node-id
        execution-request-frontier
        execution-request-strategy
        execution-request-policy)

;;; The request field is symbolic control-plane data; the executor slot is
;;; present only for local task kinds.
;; : (-> Symbol Symbol Request Function Executor Task)
(def (task-fields signature kind)
  (Record funflow-task?: (list (Exactly #t)) name: (list Symbol)
          kind: (list Symbol) request: (list Any)
          signature: (list OperationSignature)
          executor: (list (if (memq kind '(pure scheme)) signature (OrFalse signature)))))
(def TaskContract
  (.cc Type. sexp: 'FunflowTask
    '.element? (lambda (value)
                 (and (task? value) (element? (task-fields (.get value signature) (.get value kind)) value)))
    '.validate (lambda (value)
                 (unless (task? value) (raise-type-error TaskContract value))
                 (validate (task-fields (admit-operation-signature (.get value signature)) (.get value kind)) value))))
(def (task? value)
  (and (object? value) (.slot? value 'funflow-task?) (.ref value 'funflow-task?)))
(def (make-task name kind request signature executor)
  (validate TaskContract
    (.o bind-these: #f funflow-task?: #t name: name kind: kind request: request
        signature: signature executor: executor)))
(def (task-name value) (.ref value 'name))
(def (task-kind value) (.ref value 'kind))
(def (task-request value) (.ref value 'request))
(def (task-signature value) (.ref value 'signature))
(def (task-input-contract value) (operation-input (task-signature value)))
(def (task-output-contract value) (operation-output (task-signature value)))
(def (task-executor value) (.ref value 'executor))

;;; Task-family descriptors are POO objects because extension policy should be
;;; data-driven at the task boundary, not hard-coded in the runner.
;; : (-> Unit TaskFamilyDescriptorPrototype)
(def task-family-descriptor-prototype
  (poo-core-role-object
   (slots ((kind 'task-family)
           (capability #f)
           (route 'local)
           (runtime-owner 'gerbil)
           (adapter-dispatch #f)
           (extension-policy 'descriptor-prototype)))
   (supers task-role)))

;; : (-> Symbol Symbol Symbol Symbol AdapterDispatch TaskFamilyDescriptor)
(def (make-task-family-descriptor family-name family-capability family-route family-runtime-owner family-adapter-dispatch)
  (poo-core-role-object
   (slots ((name family-name)
           (capability family-capability)
           (route family-route)
           (runtime-owner family-runtime-owner)
           (adapter-dispatch
            (validate (OrFalse (Union Symbol (Fun Symbol <- TaskContract)))
                      family-adapter-dispatch))
           (responsibility
            (list 'task-family family-route family-capability))))
   (supers task-family-descriptor-prototype)))

;; : (-> TaskFamilyDescriptorCandidate Boolean)
(def (task-family-descriptor? descriptor)
  (and (object? descriptor)
       (eq? (.@ descriptor kind) 'task-family)))

;;; Registries are immutable POO policy bundles; extension code gets a new
;;; registry value instead of mutating the default control-plane registry.
;; : (-> Unit TaskFamilyRegistryPrototype)
(def task-family-registry-prototype
  (poo-core-role-object
   (slots ((kind 'task-family-registry)
           (descriptors '())
           (extension-policy 'immutable-registry)))
   (supers task-role)))

;; : (-> Symbol [TaskFamilyDescriptor] TaskFamilyRegistry)
(def (make-task-family-registry registry-name registry-descriptors)
  (poo-core-role-object
   (slots ((name registry-name)
           (descriptors registry-descriptors)
           (responsibility
            (list 'task-family-registry registry-name))))
   (supers task-family-registry-prototype)))

;; : (-> TaskFamilyRegistryCandidate Boolean)
(def (task-family-registry? registry)
  (and (object? registry)
       (eq? (.@ registry kind) 'task-family-registry)))

;; : (-> TaskFamilyRegistry Symbol)
(def (task-family-registry-name registry)
  (.@ registry name))

;; : (-> TaskFamilyRegistry [TaskFamilyDescriptor])
(def (task-family-registry-descriptors registry)
  (.@ registry descriptors))

;; : (-> TaskFamilyRegistry TaskFamilyDescriptor TaskFamilyRegistry)
(def (task-family-registry-extend registry descriptor)
  (make-task-family-registry
   (task-family-registry-name registry)
   (append (task-family-registry-descriptors registry)
           (list descriptor))))

;; : (-> Unit TaskFamilyDescriptor)
(def pure-task-family-descriptor
  (make-task-family-descriptor 'pure 'pure 'local 'gerbil #f))

;; : (-> Unit TaskFamilyDescriptor)
(def scheme-task-family-descriptor
  (make-task-family-descriptor 'scheme 'scheme 'local 'gerbil #f))

;; : (-> Unit TaskFamilyDescriptor)
(def external-task-family-descriptor
  (make-task-family-descriptor 'external 'external 'adapter 'rust-or-external-runtime 'submit))

;; : (-> Unit TaskFamilyRegistry)
(def default-task-family-registry
  (make-task-family-registry
   'default-task-families
   (list pure-task-family-descriptor
         scheme-task-family-descriptor
         external-task-family-descriptor)))

;; : (-> Unit [TaskFamilyDescriptor])
(def task-family-descriptors
  (task-family-registry-descriptors default-task-family-registry))

;; : (-> TaskFamilyDescriptor Symbol)
(def (task-family-name descriptor)
  (.@ descriptor name))

;; : (-> TaskFamilyDescriptor Symbol)
(def (task-family-capability descriptor)
  (.@ descriptor capability))

;; : (-> TaskFamilyDescriptor Symbol)
(def (task-family-route descriptor)
  (.@ descriptor route))

;; : (-> TaskFamilyDescriptor Symbol)
(def (task-family-runtime-owner descriptor)
  (.@ descriptor runtime-owner))

;; : (-> TaskFamilyDescriptor AdapterDispatch)
(def (task-family-adapter-dispatch descriptor)
  (validate (OrFalse (Union Symbol (Fun Symbol <- TaskContract)))
            (.@ descriptor adapter-dispatch)))

;;; Boundary: find task family is the policy-visible edge for core behavior,
;;; keeping validation, lookup, or projection responsibilities centralized for
;;; callers.
;; : (-> Symbol [TaskFamilyDescriptor] MaybeTaskFamilyDescriptor)
(def (find-task-family kind descriptors)
  (cond
   ((null? descriptors) #f)
   ((eq? kind (task-family-name (car descriptors))) (car descriptors))
   (else (find-task-family kind (cdr descriptors)))))

;;; Boundary: task family for kind in is the policy-visible edge for core
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> TaskFamilyRegistry Symbol Alist)
(defpoo-core-receipt-projection
  unknown-task-family-detail (registry kind)
  (bindings ())
  (fields ((registry (task-family-registry-name registry))
           (kind kind))))

;; : (-> Symbol TaskFamilyDescriptor)
(def (task-family-for-kind-in registry kind)
  (let ((descriptor (find-task-family kind (task-family-registry-descriptors registry))))
    (if descriptor
      descriptor
      (raise-control-plane-failure
       'task-registry
       'unknown-task-family
       "unknown task family"
       (unknown-task-family-detail registry kind)))))

;; : (-> Symbol TaskFamilyDescriptor)
(def (task-family-for-kind kind)
  (task-family-for-kind-in default-task-family-registry kind))

;; : (-> TaskFamilyRegistry Task TaskFamilyDescriptor)
(def (task-descriptor-in registry task)
  (task-family-for-kind-in registry (task-kind task)))

;; : (-> Task TaskFamilyDescriptor)
(def (task-descriptor task)
  (task-descriptor-in default-task-family-registry task))

;; : (-> TaskFamilyRegistry Task Symbol)
(def (task-capability-in registry task)
  (task-family-capability (task-descriptor-in registry task)))

;; : (-> Task Symbol)
(def (task-capability task)
  (task-capability-in default-task-family-registry task))

;; : (-> TaskFamilyRegistry Task Symbol)
(def (task-route-in registry task)
  (task-family-route (task-descriptor-in registry task)))

;; : (-> Task Symbol)
(def (task-route task)
  (task-route-in default-task-family-registry task))

;; : (-> TaskFamilyRegistry Task Symbol)
(def (task-runtime-owner-in registry task)
  (task-family-runtime-owner (task-descriptor-in registry task)))

;; : (-> Task Symbol)
(def (task-runtime-owner task)
  (task-runtime-owner-in default-task-family-registry task))

;;; Adapter operations translate descriptor-level dispatch into runtime adapter
;;; slots. Extensions may install a procedure dispatch hook when an operation
;;; must be derived from extension-owned task request data.
;; : (-> TaskFamilyRegistry Task AdapterOperation)
(def (task-adapter-operation-in registry task)
  (let ((dispatch (task-family-adapter-dispatch (task-descriptor-in registry task))))
    (if (procedure? dispatch)
      (dispatch task)
      dispatch)))

;; : (-> Task AdapterOperation)
(def (task-adapter-operation task)
  (task-adapter-operation-in default-task-family-registry task))

;;; Normalized requests are the adapter boundary format shared by store and
;;; external tasks.
;;; Plan, node, frontier, and strategy fields are optional control-plane
;;; evidence so Rust adapters can correlate requests with Scheme planning.
;;; Policy carries the stable alist snapshot that adapters should persist.
;; : (-> Symbol Symbol Request Value Contract Contract PlanId NodeId [Id] Strategy Policy ExecutionRequest)
(defstruct execution-request
  (name
   kind
   request
   input
   input-contract
   output-contract
   plan-id
   node-id
   frontier
   strategy
   policy)
  id: tao3k/agentic-ai-lab/modules/funflow/control-plane/task#execution-request::t
  transparent: #t
  final: #t)

(def ExecutionRequestContract
  (.cc Type. sexp: 'ExecutionRequest '.element? execution-request?))

;; : (-> Symbol Function Procedure Task)
(def (make-pure-task name signature proc)
  (make-task name 'pure (list 'pure name) signature proc))

;; : (-> Symbol Function Procedure Task)
(def (make-scheme-task name signature proc)
  (make-task name 'scheme (list 'scheme name) signature proc))

;;; Request operation and payload are generic helpers for extension-owned task
;;; families that use the conventional =(family operation payload)= shape.
;; : (-> Task (U Symbol #f))
(def (task-request-operation task)
  (if (and (pair? (task-request task))
           (pair? (cdr (task-request task))))
    (cadr (task-request task))
    #f))

;;; Boundary: task request payload is the policy-visible edge for core
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> Task (U Payload #f))
(def (task-request-payload task)
  (if (and (pair? (task-request task))
           (pair? (cdr (task-request task)))
           (pair? (cddr (task-request task))))
    (caddr (task-request task))
    #f))

;; : (-> Symbol Symbol Payload Function Task)
(def (make-external-task name operation payload signature)
  (make-task name 'external (list 'external operation payload) signature #f))

;; : (-> TaskFamilyRegistry Task Boolean)
(def (task-local?-in registry task)
  (eq? (task-route-in registry task) 'local))

;; : (-> Task Boolean)
(def (task-local? task)
  (task-local?-in default-task-family-registry task))

;; : (-> TaskFamilyRegistry Task Boolean)
(def (task-adapter-routed?-in registry task)
  (eq? (task-route-in registry task) 'adapter))

;; : (-> Task Boolean)
(def (task-adapter-routed? task)
  (task-adapter-routed?-in default-task-family-registry task))

;; : (-> Task Value ExecutionRequest)
(def (task-normalized-request task input)
  (task-adapter-request task input #f #f '() #f #f))

;;; Runner-owned request enrichment keeps task constructors pure while still
;;; giving runtime adapters the graph and strategy evidence they need.
;; : (-> Task Value PlanId NodeId [Id] Strategy Policy ExecutionRequest)
(def (task-adapter-request task input plan-id node-id frontier strategy policy)
  (make-execution-request (task-name task)
                          (task-kind task)
                          (task-request task)
                          input
                          (task-input-contract task)
                          (task-output-contract task)
                          plan-id
                          node-id
                          frontier
                          strategy
                          policy))
