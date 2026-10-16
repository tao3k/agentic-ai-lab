;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: flow declaration descriptors and registry metadata.
;;; Invariant: this owner does not define flow record classes or execute tasks.

(import :core/composition/roles
        (only-in :clan/poo/object .@ object?)
        :poo-flow/modules/workflow/control-plane/projection-syntax
        :poo-flow/modules/workflow/control-plane/roles
        :poo-flow/modules/workflow/control-plane/failure
        :poo-flow/modules/workflow/control-plane/task
        :core/object-family/role-syntax)

(export make-flow-declaration-descriptor
        flow-declaration-descriptor?
        flow-declaration-descriptor-prototype
        make-flow-declaration-registry
        flow-declaration-registry?
        flow-declaration-registry-prototype
        default-flow-declaration-registry
        flow-declaration-registry-name
        flow-declaration-registry-descriptors
        flow-declaration-registry-extend
        task-flow-descriptor
        sequential-flow-descriptor
        branch-flow-descriptor
        empty-flow-descriptor
        flow-declaration-descriptors
        flow-declaration-name
        flow-declaration-kind
        flow-declaration-planner
        flow-extension-policy
        flow-declaration-capability
        flow-declaration-for-kind-in)

;;; Flow descriptors are POO declaration metadata: they select planning policy
;;; without changing the stable flow record or running any task.
;; : (-> Unit FlowDeclarationDescriptorPrototype)
(def flow-declaration-descriptor-prototype
  (poo-core-role-object
   (slots ((kind 'flow-declaration)
           (planner 'linear-dag)
           (extension-policy 'descriptor-prototype)))
   (supers flow-role)))

;;; Descriptor supers are a pair-tree on purpose: gerbil-poo flattens supers
;;; before C4 linearization, so extension descriptors can add role parents
;;; without this module reimplementing inheritance order.
;; : (-> [Role] [Role])
(def (flow-declaration-descriptor-supers role-supers)
  (cons flow-declaration-descriptor-prototype role-supers))

;;; Boundary: make flow declaration descriptor is the policy-visible edge for
;;; core behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> Symbol Symbol PlannerPolicy ExtensionPolicy [Role] FlowDeclarationDescriptor)
(def (make-flow-declaration-descriptor descriptor-name descriptor-kind descriptor-planner descriptor-extension-policy . maybe-role-supers)
  (let (role-supers (if (null? maybe-role-supers) '() (car maybe-role-supers)))
    (poo-core-role-object
     (slots ((name descriptor-name)
             (declaration-kind descriptor-kind)
             (planner descriptor-planner)
             (extension-policy descriptor-extension-policy)
             (responsibility
              (list 'flow-declaration descriptor-kind descriptor-planner))))
     (supers (flow-declaration-descriptor-supers role-supers)))))

;; : (-> FlowDeclarationDescriptorCandidate Boolean)
(def (flow-declaration-descriptor? descriptor)
  (and (object? descriptor)
       (eq? (.@ descriptor kind) 'flow-declaration)))

;;; Flow declaration registries are immutable extension bundles. Strategy code
;;; can consume a registry without knowing which module contributed descriptors.
;; : (-> Unit FlowDeclarationRegistryPrototype)
(def flow-declaration-registry-prototype
  (poo-core-role-object
   (slots ((kind 'flow-declaration-registry)
           (descriptors '())
           (extension-policy 'immutable-registry)))
   (supers flow-role)))

;; : (-> Symbol [FlowDeclarationDescriptor] FlowDeclarationRegistry)
(def (make-flow-declaration-registry registry-name registry-descriptors)
  (poo-core-role-object
   (slots ((name registry-name)
           (descriptors registry-descriptors)
           (responsibility
            (list 'flow-declaration-registry registry-name))))
   (supers flow-declaration-registry-prototype)))

;; : (-> FlowDeclarationRegistryCandidate Boolean)
(def (flow-declaration-registry? registry)
  (and (object? registry)
       (eq? (.@ registry kind) 'flow-declaration-registry)))

;; : (-> FlowDeclarationRegistry Symbol)
(def (flow-declaration-registry-name registry)
  (.@ registry name))

;; : (-> FlowDeclarationRegistry [FlowDeclarationDescriptor])
(def (flow-declaration-registry-descriptors registry)
  (.@ registry descriptors))

;; : (-> FlowDeclarationRegistry FlowDeclarationDescriptor FlowDeclarationRegistry)
(def (flow-declaration-registry-extend registry descriptor)
  (make-flow-declaration-registry
   (flow-declaration-registry-name registry)
   (append (flow-declaration-registry-descriptors registry)
           (list descriptor))))

;; : (-> Unit FlowDeclarationDescriptor)
(def task-flow-descriptor
  (make-flow-declaration-descriptor 'task-flow 'task 'linear-dag 'closed
                                    (list task-role)))

;; : (-> Unit FlowDeclarationDescriptor)
(def sequential-flow-descriptor
  (make-flow-declaration-descriptor 'sequential-flow 'sequential 'linear-dag 'composable))

;; : (-> Unit FlowDeclarationDescriptor)
(def branch-flow-descriptor
  (make-flow-declaration-descriptor 'branch-flow 'branch 'linear-dag 'parallelizable
                                    (list branch-role)))

;; : (-> Unit FlowDeclarationDescriptor)
(def empty-flow-descriptor
  (make-flow-declaration-descriptor 'empty-flow 'empty 'linear-dag 'identity))

;; : (-> Unit FlowDeclarationRegistry)
(def default-flow-declaration-registry
  (make-flow-declaration-registry
   'default-flow-declarations
   (list task-flow-descriptor
         sequential-flow-descriptor
         branch-flow-descriptor
         empty-flow-descriptor)))

;; : (-> Unit [FlowDeclarationDescriptor])
(def flow-declaration-descriptors
  (flow-declaration-registry-descriptors default-flow-declaration-registry))

;; : (-> FlowDeclarationDescriptor Symbol)
(def (flow-declaration-name descriptor)
  (.@ descriptor name))

;; : (-> FlowDeclarationDescriptor Symbol)
(def (flow-declaration-kind descriptor)
  (.@ descriptor declaration-kind))

;; : (-> FlowDeclarationDescriptor PlannerPolicy)
(def (flow-declaration-planner descriptor)
  (.@ descriptor planner))

;; : (-> FlowDeclarationDescriptor ExtensionPolicy)
(def (flow-extension-policy descriptor)
  (.@ descriptor extension-policy))

;; : (-> FlowDeclarationDescriptor Symbol Value Value)
(def (flow-declaration-capability descriptor slot default)
  (role-slot/default descriptor slot default))

;;; Boundary: find flow declaration is the policy-visible edge for core
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> Symbol [FlowDeclarationDescriptor] MaybeFlowDeclarationDescriptor)
(def (find-flow-declaration kind descriptors)
  (cond
   ((null? descriptors) #f)
   ((eq? kind (flow-declaration-kind (car descriptors))) (car descriptors))
   (else (find-flow-declaration kind (cdr descriptors)))))

;;; Boundary: flow declaration for kind in is the policy-visible edge for core
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> FlowDeclarationRegistry Symbol Alist)
(defpoo-core-receipt-projection
  unknown-flow-declaration-detail (registry kind)
  (bindings ())
  (fields ((registry (flow-declaration-registry-name registry))
           (kind kind))))

;; : (-> FlowDeclarationRegistry Symbol FlowDeclarationDescriptor)
(def (flow-declaration-for-kind-in registry kind)
  (let ((descriptor (find-flow-declaration
                     kind
                     (flow-declaration-registry-descriptors registry))))
    (if descriptor
      descriptor
      (raise-control-plane-failure
       'flow-registry
       'unknown-flow-declaration
       "unknown flow declaration kind"
       (unknown-flow-declaration-detail registry kind)))))
