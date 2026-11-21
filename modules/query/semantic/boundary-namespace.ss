;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Semantic: P0 boundary names and namespace descriptors.
;;; Invariant: these names define ownership; projections and runtime handoff
;;; must not become semantic owners.

(import (only-in :clan/poo/object .def .ref object?)
        )

(export agentic-ai-lab-intent-boundary-prototype
        agentic-ai-lab-author-boundary-prototype
        agentic-ai-lab-graph-boundary-prototype
        agentic-ai-lab-semantic-boundary-prototype
        agentic-ai-lab-contract-boundary-prototype
        agentic-ai-lab-observability-boundary-prototype
        agentic-ai-lab-projection-boundary-prototype
        agentic-ai-lab-runtime-boundary-prototype
        +agentic-ai-lab-boundary-layers+
        +agentic-ai-lab-agent-repair-boundary-layers+
        +agentic-ai-lab-disallowed-public-categories+
        +agentic-ai-lab-boundary-namespace-prefix+
        agentic-ai-lab-boundary-layer?
        agentic-ai-lab-agent-repair-boundary-layer?
        agentic-ai-lab-public-category-allowed?
        agentic-ai-lab-boundary-prototype?
        agentic-ai-lab-boundary-prototype-id
        agentic-ai-lab-boundary-prototype->alist
        make-agentic-ai-lab-namespace-descriptor
        agentic-ai-lab-namespace-descriptor?
        agentic-ai-lab-namespace-descriptor-kind
        agentic-ai-lab-namespace-descriptor-boundary
        agentic-ai-lab-namespace-descriptor-category
        agentic-ai-lab-namespace-descriptor-module
        agentic-ai-lab-namespace-descriptor-segments
        agentic-ai-lab-namespace-descriptor-public?
        agentic-ai-lab-namespace-descriptor-repair-layer
        agentic-ai-lab-namespace-descriptor->symbol
        agentic-ai-lab-namespace-descriptor->alist
        agentic-ai-lab-boundary-namespace
        agentic-ai-lab-category-module-namespace)

;; +agentic-ai-lab-boundary-layers+
;;   : [Symbol]
;;   | doc m%
;;       Canonical P0 owner layers for the Scheme control plane.
;;     %
(def +agentic-ai-lab-boundary-layers+
  '(intent author graph semantic contract observability projection runtime))

;; +agentic-ai-lab-agent-repair-boundary-layers+
;;   : [Symbol]
;;   | doc m%
;;       Boundary layers that an agent may repair without entering runtime
;;       execution ownership.
;;     %
(def +agentic-ai-lab-agent-repair-boundary-layers+
  '(intent author graph semantic contract observability))

;; +agentic-ai-lab-disallowed-public-categories+
;;   : [Symbol]
;;   | doc m%
;;       Stale or ambiguous category namespace roots rejected at the public
;;       module boundary.
;;     %
(def +agentic-ai-lab-disallowed-public-categories+
  '(modules funflow popflow core config merge))

;; +agentic-ai-lab-boundary-namespace-prefix+
;;   : String
;;   | doc m%
;;       Stable public namespace prefix for all user-visible Agentic AI Lab modules.
;;     %
(def +agentic-ai-lab-boundary-namespace-prefix+ "agentic-ai-lab")

;; : (POOObject Symbol AgenticAILabBoundaryOwnership [Symbol] Boolean)
(.def agentic-ai-lab-intent-boundary-prototype
  id: 'intent
  owns: 'user-graph-request
  denies: '(scheme-expansion validation runtime-execution)
  repairable-by-agent?: #t)

;; : (POOObject Symbol AgenticAILabBoundaryOwnership [Symbol] Boolean)
(.def agentic-ai-lab-author-boundary-prototype
  id: 'author
  owns: '(init use-module profiles feature-config)
  denies: '(generated-manifest lean-facts runtime-execution)
  repairable-by-agent?: #t)

;; : (POOObject Symbol AgenticAILabBoundaryOwnership [Symbol] Boolean)
(.def agentic-ai-lab-graph-boundary-prototype
  id: 'graph
  owns: '(workflow-graph loop step model module gate result-path)
  denies: '(poo-method-order final-abi-rows)
  repairable-by-agent?: #t)

;; : (POOObject Symbol AgenticAILabBoundaryOwnership [Symbol] Boolean)
(.def agentic-ai-lab-semantic-boundary-prototype
  id: 'semantic
  owns: '(poo-object-graph prototypes c4 functional-builders)
  denies: '(external-execution)
  repairable-by-agent?: #t)

;; : (POOObject Symbol AgenticAILabBoundaryOwnership [Symbol] Boolean)
(.def agentic-ai-lab-contract-boundary-prototype
  id: 'contract
  owns: '(typed-slots structural-validation safety-invariants hard-gates)
  denies: '(graph-rendering runtime-work)
  repairable-by-agent?: #t)

;; : (POOObject Symbol AgenticAILabBoundaryOwnership [Symbol] Boolean)
(.def agentic-ai-lab-observability-boundary-prototype
  id: 'observability
  owns: '(events spans diagnostics receipts evidence-provenance)
  denies: '(semantic-ownership runtime-execution)
  repairable-by-agent?: #t)

;; : (POOObject Symbol AgenticAILabBoundaryOwnership [Symbol] Boolean)
(.def agentic-ai-lab-projection-boundary-prototype
  id: 'projection
  owns: '(manifest-rows graph-previews proof-facts doctor-reports handoff-payloads)
  denies: '(source-semantics)
  repairable-by-agent?: #f)

;; : (POOObject Symbol AgenticAILabBoundaryOwnership [Symbol] Boolean)
(.def agentic-ai-lab-runtime-boundary-prototype
  id: 'runtime
  owns: '(external-execution handoff-contract)
  denies: '(scheme-policy-authorship)
  repairable-by-agent?: #f)

;; : (-> AgenticAILabBoundaryLayerCandidate Boolean)
(def (agentic-ai-lab-boundary-layer? layer)
  (and (symbol? layer)
       (member layer +agentic-ai-lab-boundary-layers+)
       #t))

;; : (-> AgenticAILabBoundaryLayerCandidate Boolean)
(def (agentic-ai-lab-agent-repair-boundary-layer? layer)
  (and (symbol? layer)
       (member layer +agentic-ai-lab-agent-repair-boundary-layers+)
       #t))

;; : (-> AgenticAILabBoundaryPrototypeCandidate Boolean)
(def (agentic-ai-lab-boundary-prototype? value)
  (and (object? value)
       (with-catch
        (lambda (_failure) #f)
        (lambda ()
          (agentic-ai-lab-boundary-layer? (.ref value 'id))))))

;; : (-> AgenticAILabBoundaryPrototype Symbol)
(def (agentic-ai-lab-boundary-prototype-id prototype)
  (.ref prototype 'id))

;; : (-> AgenticAILabBoundaryPrototype Alist)
(def (agentic-ai-lab-boundary-prototype->alist prototype)
  (list
   (cons 'id (.ref prototype 'id))
   (cons 'owns (.ref prototype 'owns))
   (cons 'denies (.ref prototype 'denies))
   (cons 'repairable-by-agent? (.ref prototype 'repairable-by-agent?))))

;; : (-> Symbol [Symbol])
(def (agentic-ai-lab-namespace-boundary-segments boundary)
  (list
   (string->symbol +agentic-ai-lab-boundary-namespace-prefix+)
   boundary))

;; : (-> Symbol (Or Symbol False))
(def (agentic-ai-lab-boundary-default-repair-layer boundary)
  (if (agentic-ai-lab-agent-repair-boundary-layer? boundary)
    boundary
    #f))

;; : (-> [Symbol] Symbol)
(def (agentic-ai-lab-namespace-segments->symbol segments)
  (string->symbol
   (string-join
    (map symbol->string
         (if (null? segments)
           (list (string->symbol +agentic-ai-lab-boundary-namespace-prefix+))
           segments))
    ".")))

;; agentic-ai-lab-namespace-descriptor
;;   : (-> Symbol (Or Symbol False) (Or Symbol False) (Or Symbol False) [Symbol] Boolean (Or Symbol False) AgenticAILabNamespaceDescriptor)
;;   | doc m%
;;       Fixed semantic namespace descriptor. It records ownership boundary,
;;       optional public category/module names, symbolic segments, and the agent
;;       repair layer before any manifest or runtime projection occurs.
;;     %
(defstruct agentic-ai-lab-namespace-descriptor
  (kind
   boundary
   category
   module
   segments
   public?
   repair-layer)
  transparent: #t)

;; : (-> AgenticAILabNamespaceDescriptor Symbol)
(def (agentic-ai-lab-namespace-descriptor->symbol descriptor)
  (agentic-ai-lab-namespace-segments->symbol
   (agentic-ai-lab-namespace-descriptor-segments descriptor)))

;; : (-> AgenticAILabNamespaceDescriptor Alist)
(def (agentic-ai-lab-namespace-descriptor->alist descriptor)
  (list
   (cons 'kind (agentic-ai-lab-namespace-descriptor-kind descriptor))
   (cons 'boundary (agentic-ai-lab-namespace-descriptor-boundary descriptor))
   (cons 'category (agentic-ai-lab-namespace-descriptor-category descriptor))
   (cons 'module (agentic-ai-lab-namespace-descriptor-module descriptor))
   (cons 'segments (agentic-ai-lab-namespace-descriptor-segments descriptor))
   (cons 'namespace (agentic-ai-lab-namespace-descriptor->symbol descriptor))
   (cons 'public? (agentic-ai-lab-namespace-descriptor-public? descriptor))
   (cons 'repair-layer
         (agentic-ai-lab-namespace-descriptor-repair-layer descriptor))))

;; : (-> Symbol Boolean)
(def (agentic-ai-lab-public-category-allowed? category)
  (and (symbol? category)
       (not (member category +agentic-ai-lab-disallowed-public-categories+))))

;; : (-> Symbol [Symbol] AgenticAILabNamespaceDescriptor)
(def (agentic-ai-lab-boundary-namespace boundary . maybe-tail)
  (let (tail (if (null? maybe-tail) '() (car maybe-tail)))
    (make-agentic-ai-lab-namespace-descriptor
     'boundary
     boundary
     #f
     #f
     (append (agentic-ai-lab-namespace-boundary-segments boundary) tail)
     #t
     (agentic-ai-lab-boundary-default-repair-layer boundary))))

;; : (-> Symbol Symbol AgenticAILabNamespaceDescriptor)
(def (agentic-ai-lab-category-module-namespace category module)
  (make-agentic-ai-lab-namespace-descriptor
   'category-module
   #f
   category
   module
   (list (string->symbol +agentic-ai-lab-boundary-namespace-prefix+)
         category
         module)
   #t
   'author))
