;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: flow strands describe Funflow-style interpreter families.
;;; Invariant: strand objects are declaration policy, not executable runners.

(import :core/composition/roles
        (only-in :clan/poo/object .@ object?)
        :poo-flow/modules/workflow/control-plane/roles
        :poo-flow/modules/workflow/control-plane/failure
        :poo-flow/modules/workflow/control-plane/projection-syntax
        :core/object-family/role-syntax)

(export flow-strand-descriptor-prototype
        make-flow-strand-descriptor
        flow-strand-descriptor?
        flow-strand-registry-prototype
        make-flow-strand-registry
        flow-strand-registry?
        default-flow-core-requirements
        simple-flow-strand-descriptor
        store-flow-strand-descriptor
        docker-flow-strand-descriptor
        default-flow-strand-registry
        flow-strand-registry-name
        flow-strand-registry-descriptors
        flow-strand-registry-core-requirements
        flow-strand-registry-extend
        flow-strand-registry-merge
        flow-strand-descriptors
        flow-strand-name
        flow-strand-task-families
        flow-strand-capabilities
        flow-strand-route
        flow-strand-interpreter-owner
        flow-strand-required?
        flow-strand-extension-policy
        flow-strand-capability
        find-flow-strand
        flow-strand-for-kind-in
        flow-strand-for-kind
        flow-strand-names
        flow-strand-descriptor->alist
        flow-strand-registry->alist)

;;; Flow strands mirror Funflow's RequiredStrands at the Scheme declaration
;;; layer: a strand names an interpreter family, while task descriptors keep
;;; owning route/runtime behavior.
;; : (-> Unit FlowStrandDescriptorPrototype)
(def flow-strand-descriptor-prototype
  (poo-core-role-object
   (slots ((kind 'flow-strand)
           (extension-policy 'strand-prototype)
           (required? #t)))
   (supers flow-role)))

;;; Strand supers follow the same pair-tree convention as flow descriptors so
;;; extension-owned strand descriptors can use gerbil-poo C4 composition.
;; : (-> [Role] [Role])
(def (flow-strand-descriptor-supers role-supers)
  (cons flow-strand-descriptor-prototype role-supers))

;;; Constructor arguments stay symbolic because this layer is a policy catalog:
;;; task families and capabilities are matched later by modules and adapters.
;; : (-> Symbol [Symbol] [Symbol] Symbol Symbol Boolean [Role] FlowStrandDescriptor)
(def (make-flow-strand-descriptor
      strand-name
      strand-task-families
      strand-capabilities
      strand-route
      strand-interpreter-owner
      strand-required?
      . maybe-role-supers)
  (let (role-supers (if (null? maybe-role-supers) '() (car maybe-role-supers)))
    (poo-core-role-object
     (slots ((name strand-name)
             (task-families strand-task-families)
             (capabilities strand-capabilities)
             (route strand-route)
             (interpreter-owner strand-interpreter-owner)
             (required? strand-required?)
             (extension-policy 'strand-descriptor)
             (responsibility
              (list 'flow-strand
                    strand-name
                    strand-route
                    strand-interpreter-owner))))
     (supers (flow-strand-descriptor-supers role-supers)))))

;; : (-> FlowStrandDescriptorCandidate Boolean)
(def (flow-strand-descriptor? descriptor)
  (and (object? descriptor)
       (eq? (.@ descriptor kind) 'flow-strand)))

;;; Strand registries are immutable POO policy bundles. Extending a registry
;;; replaces a same-named strand descriptor, which gives POO extensions a clean
;;; override path without mutating the default Funflow-like strand set.
;; : (-> Unit FlowStrandRegistryPrototype)
(def flow-strand-registry-prototype
  (poo-core-role-object
   (slots ((kind 'flow-strand-registry)
           (descriptors '())
           (core-requirements '())
           (extension-policy 'immutable-strand-registry)))
   (supers flow-role)))

;;; Core requirements are registry-level facts, mirroring Funflow's RequiredCore
;;; without tying every descriptor to the same backend interpretation contract.
;; : (-> Symbol [FlowStrandDescriptor] [Symbol] FlowStrandRegistry)
(def (make-flow-strand-registry
      registry-name
      registry-descriptors
      registry-core-requirements)
  (poo-core-role-object
   (slots ((name registry-name)
           (descriptors registry-descriptors)
           (core-requirements registry-core-requirements)
           (responsibility
            (list 'flow-strand-registry registry-name))))
   (supers flow-strand-registry-prototype)))

;; : (-> FlowStrandRegistryCandidate Boolean)
(def (flow-strand-registry? registry)
  (and (object? registry)
       (eq? (.@ registry kind) 'flow-strand-registry)))

;;; These symbols are the Scheme-side projection of Funflow's RequiredCore:
;;; composition/error/caching facts are visible, but execution remains outside.
;; : (-> Unit [Symbol])
(def default-flow-core-requirements
  '(arrow
    arrow-choice
    error-throw
    error-try
    io-lift
    caching
    runtime-handoff))

;;; The simple strand is the Scheme analogue of Funflow's PureTask/IOTask
;;; family: it is locally interpretable and never crosses the runtime adapter.
;; : (-> Unit FlowStrandDescriptor)
(def simple-flow-strand-descriptor
  (make-flow-strand-descriptor
   'simple
   '(pure scheme)
   '(pure-function io-continuation local-kleisli)
   'local
   'gerbil
   #t))

;;; Store remains a required strand because Funflow treats CAS as core, but the
;;; implementation owner is explicitly outside Scheme.
;; : (-> Unit FlowStrandDescriptor)
(def store-flow-strand-descriptor
  (make-flow-strand-descriptor
   'store
   '(store external)
   '(content-address-store put-dir get-dir artifact-manifest)
   'adapter
   'rust-or-external-runtime
   #t))

;;; Docker is part of the Funflow-compatible strand set only as declaration
;;; metadata; image pulls, volumes, and processes stay adapter-owned.
;; : (-> Unit FlowStrandDescriptor)
(def docker-flow-strand-descriptor
  (make-flow-strand-descriptor
   'docker
   '(docker external)
   '(container external-config volume-binding artifact-output)
   'adapter
   'rust-or-external-runtime
   #t))

;;; The default registry is the Scheme projection of Funflow's RequiredStrands,
;;; while extension-owned registries model ExtendedFlow additionalStrands.
;; : (-> Unit FlowStrandRegistry)
(def default-flow-strand-registry
  (make-flow-strand-registry
   'default-flow-strands
   (list simple-flow-strand-descriptor
         store-flow-strand-descriptor
         docker-flow-strand-descriptor)
   default-flow-core-requirements))

;;; Registry accessors are intentionally shallow: callers inspect the selected
;;; strand universe without depending on gerbil-poo slot internals.
;; : (-> FlowStrandRegistry Symbol)
(def (flow-strand-registry-name registry)
  (.@ registry name))

;; : (-> FlowStrandRegistry [FlowStrandDescriptor])
(def (flow-strand-registry-descriptors registry)
  (.@ registry descriptors))

;; : (-> FlowStrandRegistry [Symbol])
(def (flow-strand-registry-core-requirements registry)
  (.@ registry core-requirements))

;;; Descriptor accessors keep strategy and diagnostics code data-driven; they
;;; should not infer route or runtime ownership from the strand name.
;; : (-> FlowStrandDescriptor Symbol)
(def (flow-strand-name descriptor)
  (.@ descriptor name))

;; : (-> FlowStrandDescriptor [Symbol])
(def (flow-strand-task-families descriptor)
  (.@ descriptor task-families))

;; : (-> FlowStrandDescriptor [Symbol])
(def (flow-strand-capabilities descriptor)
  (.@ descriptor capabilities))

;; : (-> FlowStrandDescriptor Symbol)
(def (flow-strand-route descriptor)
  (.@ descriptor route))

;; : (-> FlowStrandDescriptor Symbol)
(def (flow-strand-interpreter-owner descriptor)
  (.@ descriptor interpreter-owner))

;; : (-> FlowStrandDescriptor Boolean)
(def (flow-strand-required? descriptor)
  (.@ descriptor required?))

;; : (-> FlowStrandDescriptor Symbol)
(def (flow-strand-extension-policy descriptor)
  (.@ descriptor extension-policy))

;; : (-> FlowStrandDescriptor Symbol Value Value)
(def (flow-strand-capability descriptor slot default)
  (role-slot/default descriptor slot default))

;;; Lookup stays over descriptor values so extension registries can be tested
;;; and inspected before any flow planner consumes them.
;; : (-> Symbol [FlowStrandDescriptor] MaybeFlowStrandDescriptor)
(def (find-flow-strand kind descriptors)
  (let (matches
        (filter (lambda (descriptor)
                  (eq? kind (flow-strand-name descriptor)))
                descriptors))
    (and (pair? matches) (car matches))))

;;; Same-name replacement is the POO extension point: downstream profiles can
;;; refine a strand object without producing duplicate interpreter families.
;; : (-> [FlowStrandDescriptor] FlowStrandDescriptor [FlowStrandDescriptor])
(def (flow-strand-descriptors-replace descriptors replacement)
  (cond
   ((null? descriptors) (list replacement))
   ((eq? (flow-strand-name replacement)
         (flow-strand-name (car descriptors)))
    (cons replacement (cdr descriptors)))
   (else
    (cons (car descriptors)
          (flow-strand-descriptors-replace (cdr descriptors) replacement)))))

;;; Registry extension is value-producing and deterministic; callers decide
;;; which registry to pass into category/strategy code.
;; : (-> FlowStrandRegistry FlowStrandDescriptor FlowStrandRegistry)
(def (flow-strand-registry-extend registry descriptor)
  (make-flow-strand-registry
   (flow-strand-registry-name registry)
   (flow-strand-descriptors-replace
    (flow-strand-registry-descriptors registry)
    descriptor)
   (flow-strand-registry-core-requirements registry)))

;; flow-strand-registry-merge
;;   : (-> FlowStrandRegistry (List FlowStrandDescriptor) FlowStrandRegistry)
;;   | doc m%
;;       `flow-strand-registry-merge` applies module profile descriptors in
;;       order, preserving existing descriptor order while letting later
;;       same-name descriptors replace the first visible registry entry.
;;
;;       # Examples
;;       ```scheme
;;       (flow-strand-registry-merge registry extension-descriptors)
;;       ;; => registry with deterministic descriptor override order
;;       ```
;;     %
(def (flow-strand-registry-merge registry descriptors)
  (if (null? descriptors)
    registry
    (let ((base-seen (make-hash-table))
          (base-first (make-hash-table))
          (override-seen (make-hash-table))
          (overrides (make-hash-table))
          (new-seen (make-hash-table))
          (replacement-used (make-hash-table)))
      (for-each
       (lambda (descriptor)
         (let (key (flow-strand-name descriptor))
           (if (not (hash-get base-seen key))
             (begin
               (hash-put! base-seen key #t)
               (hash-put! base-first key descriptor))
             #f)))
       (flow-strand-registry-descriptors registry))
      (def (finish-existing/rev remaining result-rev)
        (if (null? remaining)
          result-rev
          (let* ((descriptor (car remaining))
                 (key (flow-strand-name descriptor))
                 (next-descriptor
                  (if (and (hash-get override-seen key)
                           (not (hash-get replacement-used key)))
                    (begin
                      (hash-put! replacement-used key #t)
                      (hash-get overrides key))
                    descriptor)))
            (finish-existing/rev
             (cdr remaining)
             (cons next-descriptor result-rev)))))
      (def (finish-new/rev remaining-new-keys result-rev)
        (if (null? remaining-new-keys)
          result-rev
          (finish-new/rev
           (cdr remaining-new-keys)
           (cons (hash-get overrides (car remaining-new-keys))
                 result-rev))))
      (def (finish new-keys)
        (make-flow-strand-registry
         (flow-strand-registry-name registry)
         (reverse
          (finish-new/rev
           (reverse new-keys)
           (finish-existing/rev
            (flow-strand-registry-descriptors registry)
            '())))
         (flow-strand-registry-core-requirements registry)))
      (let loop-extra ((remaining descriptors)
                       (new-keys '()))
        (if (null? remaining)
          (finish new-keys)
          (let* ((descriptor (car remaining))
                 (key (flow-strand-name descriptor))
                 (next-new-keys
                  (if (or (hash-get base-seen key)
                          (hash-get new-seen key))
                    new-keys
                    (begin
                      (hash-put! new-seen key #t)
                      (cons key new-keys)))))
            (hash-put! override-seen key #t)
            (hash-put! overrides key descriptor)
            (loop-extra (cdr remaining) next-new-keys)))))))

;;; Default descriptors stay available as a value list for tests and docs that
;;; do not need the full registry envelope.
;; : (-> Unit [FlowStrandDescriptor])
(def flow-strand-descriptors
  (flow-strand-registry-descriptors default-flow-strand-registry))

;;; Missing strand failures are structural contract errors. They must surface
;;; before runtime adapters receive an underspecified flow universe.
;; : (-> FlowStrandRegistry Symbol Alist)
(defpoo-core-receipt-projection
  unknown-flow-strand-detail (registry kind)
  (bindings ())
  (fields ((registry (flow-strand-registry-name registry))
           (kind kind))))

;; : (-> FlowStrandRegistry Symbol FlowStrandDescriptor)
(def (flow-strand-for-kind-in registry kind)
  (let ((descriptor (find-flow-strand
                     kind
                     (flow-strand-registry-descriptors registry))))
    (if descriptor
      descriptor
      (raise-control-plane-failure
       'flow-strand-registry
       'unknown-flow-strand
       "unknown flow strand"
       (unknown-flow-strand-detail registry kind)))))

;;; The default lookup is a convenience for core Funflow-compatible strands;
;;; extension code should use the explicit registry variant.
;; : (-> Symbol FlowStrandDescriptor)
(def (flow-strand-for-kind kind)
  (flow-strand-for-kind-in default-flow-strand-registry kind))

;; : (-> FlowStrandRegistry [Symbol])
(def (flow-strand-names registry)
  (map flow-strand-name
       (flow-strand-registry-descriptors registry)))

;;; Descriptor snapshots are intentionally lossless for public slots so docs
;;; and manifests can compare POO extension results without object identity.
;; : (-> FlowStrandDescriptor Alist)
(defpoo-core-receipt-projection
  flow-strand-descriptor->alist (descriptor)
  (bindings ())
  (fields ((name (flow-strand-name descriptor))
           (task-families (flow-strand-task-families descriptor))
           (capabilities (flow-strand-capabilities descriptor))
           (route (flow-strand-route descriptor))
           (interpreter-owner (flow-strand-interpreter-owner descriptor))
           (required? (flow-strand-required? descriptor))
           (extension-policy (flow-strand-extension-policy descriptor)))))

;; : (-> [FlowStrandDescriptor] [Alist])
(def (flow-strand-descriptors->alists descriptors)
  (map flow-strand-descriptor->alist descriptors))

;;; The snapshot is for docs, tests, and runtime-manifest discovery. It exposes
;;; the strand universe without handing callers executable interpreters.
;; : (-> FlowStrandRegistry Alist)
(defpoo-core-receipt-projection
  flow-strand-registry->alist (registry)
  (bindings ((descriptors
              (flow-strand-descriptors->alists
               (flow-strand-registry-descriptors registry)))))
  (fields ((name (flow-strand-registry-name registry))
           (kind 'flow-strand-registry)
           (strand-names (flow-strand-names registry))
           (core-requirements
            (flow-strand-registry-core-requirements registry))
           (descriptors descriptors)
           (runtime-executed #f))))
