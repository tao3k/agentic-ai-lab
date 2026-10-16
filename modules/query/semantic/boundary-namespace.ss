;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Semantic: P0 boundary names and namespace descriptors.
;;; Invariant: these names define ownership; projections and runtime handoff
;;; must not become semantic owners.

(import (only-in :clan/poo/object .def .ref object?)
        )

(export poo-flow-intent-boundary-prototype
        poo-flow-author-boundary-prototype
        poo-flow-graph-boundary-prototype
        poo-flow-semantic-boundary-prototype
        poo-flow-contract-boundary-prototype
        poo-flow-observability-boundary-prototype
        poo-flow-projection-boundary-prototype
        poo-flow-runtime-boundary-prototype
        +poo-flow-boundary-layers+
        +poo-flow-agent-repair-boundary-layers+
        +poo-flow-disallowed-public-categories+
        +poo-flow-boundary-namespace-prefix+
        poo-flow-boundary-layer?
        poo-flow-agent-repair-boundary-layer?
        poo-flow-public-category-allowed?
        poo-flow-boundary-prototype?
        poo-flow-boundary-prototype-id
        poo-flow-boundary-prototype->alist
        make-poo-flow-namespace-descriptor
        poo-flow-namespace-descriptor?
        poo-flow-namespace-descriptor-kind
        poo-flow-namespace-descriptor-boundary
        poo-flow-namespace-descriptor-category
        poo-flow-namespace-descriptor-module
        poo-flow-namespace-descriptor-segments
        poo-flow-namespace-descriptor-public?
        poo-flow-namespace-descriptor-repair-layer
        poo-flow-namespace-descriptor->symbol
        poo-flow-namespace-descriptor->alist
        poo-flow-boundary-namespace
        poo-flow-category-module-namespace)

;; +poo-flow-boundary-layers+
;;   : [Symbol]
;;   | doc m%
;;       Canonical P0 owner layers for the Scheme control plane.
;;     %
(def +poo-flow-boundary-layers+
  '(intent author graph semantic contract observability projection runtime))

;; +poo-flow-agent-repair-boundary-layers+
;;   : [Symbol]
;;   | doc m%
;;       Boundary layers that an agent may repair without entering runtime
;;       execution ownership.
;;     %
(def +poo-flow-agent-repair-boundary-layers+
  '(intent author graph semantic contract observability))

;; +poo-flow-disallowed-public-categories+
;;   : [Symbol]
;;   | doc m%
;;       Stale or ambiguous category namespace roots rejected at the public
;;       module boundary.
;;     %
(def +poo-flow-disallowed-public-categories+
  '(modules funflow popflow core config merge))

;; +poo-flow-boundary-namespace-prefix+
;;   : String
;;   | doc m%
;;       Stable public namespace prefix for all user-visible POO Flow modules.
;;     %
(def +poo-flow-boundary-namespace-prefix+ "poo-flow")

;; : (POOObject Symbol PooFlowBoundaryOwnership [Symbol] Boolean)
(.def poo-flow-intent-boundary-prototype
  id: 'intent
  owns: 'user-graph-request
  denies: '(scheme-expansion validation runtime-execution)
  repairable-by-agent?: #t)

;; : (POOObject Symbol PooFlowBoundaryOwnership [Symbol] Boolean)
(.def poo-flow-author-boundary-prototype
  id: 'author
  owns: '(init use-module profiles feature-config)
  denies: '(generated-manifest lean-facts runtime-execution)
  repairable-by-agent?: #t)

;; : (POOObject Symbol PooFlowBoundaryOwnership [Symbol] Boolean)
(.def poo-flow-graph-boundary-prototype
  id: 'graph
  owns: '(workflow-graph loop step model module gate result-path)
  denies: '(poo-method-order final-abi-rows)
  repairable-by-agent?: #t)

;; : (POOObject Symbol PooFlowBoundaryOwnership [Symbol] Boolean)
(.def poo-flow-semantic-boundary-prototype
  id: 'semantic
  owns: '(poo-object-graph prototypes c4 functional-builders)
  denies: '(external-execution)
  repairable-by-agent?: #t)

;; : (POOObject Symbol PooFlowBoundaryOwnership [Symbol] Boolean)
(.def poo-flow-contract-boundary-prototype
  id: 'contract
  owns: '(typed-slots structural-validation safety-invariants hard-gates)
  denies: '(graph-rendering runtime-work)
  repairable-by-agent?: #t)

;; : (POOObject Symbol PooFlowBoundaryOwnership [Symbol] Boolean)
(.def poo-flow-observability-boundary-prototype
  id: 'observability
  owns: '(events spans diagnostics receipts evidence-provenance)
  denies: '(semantic-ownership runtime-execution)
  repairable-by-agent?: #t)

;; : (POOObject Symbol PooFlowBoundaryOwnership [Symbol] Boolean)
(.def poo-flow-projection-boundary-prototype
  id: 'projection
  owns: '(manifest-rows graph-previews proof-facts doctor-reports handoff-payloads)
  denies: '(source-semantics)
  repairable-by-agent?: #f)

;; : (POOObject Symbol PooFlowBoundaryOwnership [Symbol] Boolean)
(.def poo-flow-runtime-boundary-prototype
  id: 'runtime
  owns: '(external-execution handoff-contract)
  denies: '(scheme-policy-authorship)
  repairable-by-agent?: #f)

;; : (-> PooFlowBoundaryLayerCandidate Boolean)
(def (poo-flow-boundary-layer? layer)
  (and (symbol? layer)
       (member layer +poo-flow-boundary-layers+)
       #t))

;; : (-> PooFlowBoundaryLayerCandidate Boolean)
(def (poo-flow-agent-repair-boundary-layer? layer)
  (and (symbol? layer)
       (member layer +poo-flow-agent-repair-boundary-layers+)
       #t))

;; : (-> PooFlowBoundaryPrototypeCandidate Boolean)
(def (poo-flow-boundary-prototype? value)
  (and (object? value)
       (with-catch
        (lambda (_failure) #f)
        (lambda ()
          (poo-flow-boundary-layer? (.ref value 'id))))))

;; : (-> PooFlowBoundaryPrototype Symbol)
(def (poo-flow-boundary-prototype-id prototype)
  (.ref prototype 'id))

;; : (-> PooFlowBoundaryPrototype Alist)
(def (poo-flow-boundary-prototype->alist prototype)
  (list
   (cons 'id (.ref prototype 'id))
   (cons 'owns (.ref prototype 'owns))
   (cons 'denies (.ref prototype 'denies))
   (cons 'repairable-by-agent? (.ref prototype 'repairable-by-agent?))))

;; : (-> Symbol [Symbol])
(def (poo-flow-namespace-boundary-segments boundary)
  (list
   (string->symbol +poo-flow-boundary-namespace-prefix+)
   boundary))

;; : (-> Symbol (Or Symbol False))
(def (poo-flow-boundary-default-repair-layer boundary)
  (if (poo-flow-agent-repair-boundary-layer? boundary)
    boundary
    #f))

;; : (-> [Symbol] Symbol)
(def (poo-flow-namespace-segments->symbol segments)
  (string->symbol
   (string-join
    (map symbol->string
         (if (null? segments)
           (list (string->symbol +poo-flow-boundary-namespace-prefix+))
           segments))
    ".")))

;; poo-flow-namespace-descriptor
;;   : (-> Symbol (Or Symbol False) (Or Symbol False) (Or Symbol False) [Symbol] Boolean (Or Symbol False) PooFlowNamespaceDescriptor)
;;   | doc m%
;;       Fixed semantic namespace descriptor. It records ownership boundary,
;;       optional public category/module names, symbolic segments, and the agent
;;       repair layer before any manifest or runtime projection occurs.
;;     %
(defstruct poo-flow-namespace-descriptor
  (kind
   boundary
   category
   module
   segments
   public?
   repair-layer)
  transparent: #t)

;; : (-> PooFlowNamespaceDescriptor Symbol)
(def (poo-flow-namespace-descriptor->symbol descriptor)
  (poo-flow-namespace-segments->symbol
   (poo-flow-namespace-descriptor-segments descriptor)))

;; : (-> PooFlowNamespaceDescriptor Alist)
(def (poo-flow-namespace-descriptor->alist descriptor)
  (list
   (cons 'kind (poo-flow-namespace-descriptor-kind descriptor))
   (cons 'boundary (poo-flow-namespace-descriptor-boundary descriptor))
   (cons 'category (poo-flow-namespace-descriptor-category descriptor))
   (cons 'module (poo-flow-namespace-descriptor-module descriptor))
   (cons 'segments (poo-flow-namespace-descriptor-segments descriptor))
   (cons 'namespace (poo-flow-namespace-descriptor->symbol descriptor))
   (cons 'public? (poo-flow-namespace-descriptor-public? descriptor))
   (cons 'repair-layer
         (poo-flow-namespace-descriptor-repair-layer descriptor))))

;; : (-> Symbol Boolean)
(def (poo-flow-public-category-allowed? category)
  (and (symbol? category)
       (not (member category +poo-flow-disallowed-public-categories+))))

;; : (-> Symbol [Symbol] PooFlowNamespaceDescriptor)
(def (poo-flow-boundary-namespace boundary . maybe-tail)
  (let (tail (if (null? maybe-tail) '() (car maybe-tail)))
    (make-poo-flow-namespace-descriptor
     'boundary
     boundary
     #f
     #f
     (append (poo-flow-namespace-boundary-segments boundary) tail)
     #t
     (poo-flow-boundary-default-repair-layer boundary))))

;; : (-> Symbol Symbol PooFlowNamespaceDescriptor)
(def (poo-flow-category-module-namespace category module)
  (make-poo-flow-namespace-descriptor
   'category-module
   #f
   category
   module
   (list (string->symbol +poo-flow-boundary-namespace-prefix+)
         category
         module)
   #t
   'author))
