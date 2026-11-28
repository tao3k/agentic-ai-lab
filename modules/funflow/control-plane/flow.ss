;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: flows describe workflow composition and contract shape.
;;; Invariant: task execution is deferred to runner/runtime-adapter code.

(import (only-in :clan/poo/object .@ .o .cc .ref .get .call .slot? object?
                 compute-precedence-list!)
        (only-in :clan/poo/types/object-contract ObjectContract. refine)
        (only-in :clan/poo/type Pair.)
        (only-in :clan/poo/fun Observation.)
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/signatures
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/roles
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/failure
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/task
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/flow-strand
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/flow-declarations
        :tao3k/yuanxu/object/role-syntax
        :tao3k/yuanxu/utilities/algorithms)

(export FlowCategoryContract FlowContract FlowOf FlowOperationTypes FlowOperationsContract flow-signature admit-flow
        (import: :tao3k/agentic-ai-lab/modules/funflow/control-plane/signatures)
        make-flow
        flow?
        flow-name
        flow-steps
        flow-input-contract
        flow-output-contract
        make-flow-declaration-descriptor
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
        flow-declaration-for-kind-in
        flow-declaration-descriptor-in
        flow-declaration-descriptor
        flow-branch-declaration?
        flow-task-declaration?
        flow-sequential-declaration?
        make-branch-step
        branch-step?
        branch-step-name
        branch-step-left
        branch-step-right
        branch-step-input-contract
        branch-step-output-contract
        make-try-step
        try-step?
        try-step-name
        try-step-source
        try-step-input-contract
        try-step-output-contract
        make-kleisli-step
        kleisli-step?
        kleisli-step-name
        kleisli-step-source
        kleisli-step-binder
        kleisli-step-input-contract
        kleisli-step-output-contract
        flow-compose
        task-flow
        pure-flow
        flow-arr
        scheme-flow
        throw-string-flow
        try-flow
        flow-try
        external-flow
        return-flow
        flow-identity
        conditional-flow
        cached-pure-flow
        cached-scheme-flow
        flow-then
        flow-branch
        flow-fanout
        flow-map
        flow-bind
        flow-kleisli
        flow-first
        flow-second
        flow-empty?
        flow-step-count
        flow-category-prototype
        make-flow-category
        flow-category?
        default-flow-category
        flow-category-name
        flow-category-arrow
        flow-category-domain
        flow-category-codomain
        flow-category-strand-registry
        flow-category-compose
        flow-category-identity
        flow-category-arr
        flow-category-map
        flow-category-bind
        flow-category-fanout
        flow-category-first
        flow-category-second)



;;; Boundary: a flow stores ordered steps plus its input/output contract edge.
;;; Invariant: nested flows remain steps until a planner chooses lowering.
;; : (-> Symbol [Step] Function Flow)
(def (flow? value)
  (and (object? value) (.slot? value 'funflow-flow?) (.ref value 'funflow-flow?)))
(def (branch-step? value)
  (and (object? value) (.slot? value 'funflow-branch-step?) (.ref value 'funflow-branch-step?)))
(def (try-step? value)
  (and (object? value) (.slot? value 'funflow-try-step?) (.ref value 'funflow-try-step?)))
(def (kleisli-step? value)
  (and (object? value) (.slot? value 'funflow-kleisli-step?) (.ref value 'funflow-kleisli-step?)))

;; Forward through Types so nested steps use the same recursive Class
;; normalization as callbacks returned by a binder. There is no field walker.
(def Step
  (.cc Type. sexp: 'FunflowStep
    '.element? (lambda (value) (element? StepFields value))
    '.validate (lambda (value) (validate StepFields value))))
(def FlowContract
  (refine
    (.cc ObjectContract. identity: 'funflow/flow sexp: 'FunflowFlow
      extra-fields: 'delegate constraints: (list (Record))
      responsibilities:
      (.o funflow-flow?: (Exactly #t) name: Symbol
          signature: OperationSignature steps: (List Step)))
    (lambda (flow location)
      (if (flow-edges-match? flow) '()
        (list (.o kind: 'incompatible-flow-route path: location))))))
;; The signature describes the actual ordered route, including empty identity
;; flows. These relations inspect Types; runtime Function owns value validation.
(def (step-signature step) (.get step signature))
(def (flow-edges-match? flow)
  (let walk ((previous (flow-input-contract flow)) (steps (flow-steps flow)))
    (if (null? steps)
      (type-flows? previous (flow-output-contract flow))
      (let (signature (step-signature (car steps)))
        (and (type-flows? previous (operation-input signature))
             (walk (operation-output signature) (cdr steps)))))))
;; Inspect the runtime carrier parameters instead of reconstructing a Type
;; and asking the finite expression checker to infer opaque predicate inclusion.
(def (pair-output-matches? output left right)
  (and (memq Pair. (compute-precedence-list! output))
       (memq Pair. (compute-precedence-list! (.get output right)))
       (eq? (.get output right right) Null)
       (type-flows? left (.get output left))
       (type-flows? right (.get output right left))))
(def (try-output-matches? output result-type)
  (and (.slot? output 'variants)
       (.slot? (.get output variants) 'left) (.slot? (.get output variants) 'right)
       (eq? (.get output variants left) ExecutionFailureType)
       (type-flows? result-type (.get output variants right))))
(def BranchContract
  (refine
    (.cc ObjectContract. identity: 'funflow/branch
      extra-fields: 'delegate constraints: (list (Record))
      responsibilities:
      (.o funflow-branch-step?: (Exactly #t) name: Symbol signature: OperationSignature
          left: FlowContract right: FlowContract))
    (lambda (step location)
      (def signature (.get step signature))
      (def left (.get step left))
      (def right (.get step right))
      (if (and (type-flows? (operation-input signature) (flow-input-contract left))
               (type-flows? (operation-input signature) (flow-input-contract right))
               (pair-output-matches? (operation-output signature)
                                     (flow-output-contract left) (flow-output-contract right)))
        '() (list (.o kind: 'incompatible-branch-route path: location))))))
(def TryContract
  (refine
    (.cc ObjectContract. identity: 'funflow/try
      extra-fields: 'delegate constraints: (list (Record))
      responsibilities:
      (.o funflow-try-step?: (Exactly #t) name: Symbol
          signature: OperationSignature source: FlowContract))
    (lambda (step location)
      (def signature (.get step signature))
      (def source (.get step source))
      (if (and (type-flows? (operation-input signature) (flow-input-contract source))
               (try-output-matches? (operation-output signature) (flow-output-contract source)))
        '() (list (.o kind: 'incompatible-try-route path: location))))))
(def (kleisli-fields value)
  (Record funflow-kleisli-step?: (list (Exactly #t)) name: (list Symbol)
          signature: (list OperationSignature) source: (list FlowContract)
          binder: (list (Fun (FlowOf (operation-input (.get value signature))
                                    (operation-output (.get value signature)))
                            <- (flow-output-contract (.get value source))))))
(def KleisliContract
  (.cc Type. sexp: 'FunflowKleisli
    '.element? (lambda (value) (and (kleisli-step? value) (element? (kleisli-fields value) value)))
    '.validate (lambda (value)
                 (unless (kleisli-step? value) (raise-type-error KleisliContract value))
                 (validate (kleisli-fields value) value))))
(def StepFields (Union TaskContract FlowContract BranchContract TryContract KleisliContract))
(def (admit-flow value) (validate FlowContract value))
(def (FlowOf input output)
  (.cc Type. sexp: (list 'FunflowFlow (.get input sexp) (.get output sexp))
    '.element? (lambda (value)
                 (and (element? FlowContract value)
                      (type-flows? input (flow-input-contract value))
                      (type-flows? (flow-output-contract value) output)))
    '.validate
    (lambda (value)
      (def checked (admit-flow value))
      (require-type-flow! input (flow-input-contract checked))
      (require-type-flow! (flow-output-contract checked) output)
      checked)))
(def (make-flow name steps signature)
  (admit-flow (.o bind-these: #f funflow-flow?: #t name: name steps: steps signature: signature)))
(def (flow-name value) (.ref value 'name))
(def (flow-steps value) (.ref value 'steps))
(def (flow-signature value) (.ref value 'signature))
(def (flow-input-contract value) (operation-input (flow-signature value)))
(def (flow-output-contract value) (operation-output (flow-signature value)))

(def (make-branch-step name left right signature)
  (validate BranchContract (.o bind-these: #f funflow-branch-step?: #t name: name left: left right: right signature: signature)))
(def (branch-step-name value) (.ref value 'name))
(def (branch-step-left value) (.ref value 'left))
(def (branch-step-right value) (.ref value 'right))
(def (branch-step-input-contract value) (operation-input (.get value signature)))
(def (branch-step-output-contract value) (operation-output (.get value signature)))
(def (make-try-step name source signature)
  (validate TryContract (.o bind-these: #f funflow-try-step?: #t name: name source: source signature: signature)))
(def (try-step-name value) (.ref value 'name))
(def (try-step-source value) (.ref value 'source))
(def (try-step-input-contract value) (operation-input (.get value signature)))
(def (try-step-output-contract value) (operation-output (.get value signature)))
(def (make-kleisli-step name source binder signature)
  (validate KleisliContract
    (.o bind-these: #f funflow-kleisli-step?: #t name: name source: source binder: binder signature: signature)))
(def (kleisli-step-name value) (.ref value 'name))
(def (kleisli-step-source value) (.ref value 'source))
(def (kleisli-step-binder value) (.ref value 'binder))
(def (kleisli-step-input-contract value) (operation-input (.get value signature)))
(def (kleisli-step-output-contract value) (operation-output (.get value signature)))

(def (flow-compose name steps signature) (make-flow name steps signature))
(def (task-flow name task) (flow-compose name (list task) (task-signature task)))
(def (pure-flow name signature proc) (task-flow name (make-pure-task name signature proc)))
(def (flow-arr name signature proc) (pure-flow name signature proc))
(def (scheme-flow name signature proc) (task-flow name (make-scheme-task name signature proc)))
(def (throw-string-flow name message signature)
  (scheme-flow name signature (lambda (_input) (throw-string-control-plane-failure message))))
(def (try-flow name source)
  (def signature (Fun (TryValue (flow-output-contract source)) <- (flow-input-contract source)))
  (flow-compose name (list (make-try-step name source signature)) signature))
(def (flow-try name source) (try-flow name source))
(def (external-flow name operation payload signature)
  (task-flow name (make-external-task name operation payload signature)))
(def (return-flow name type) (pure-flow name (Fun type <- type) identity))
(def (flow-identity name type) (return-flow name type))

(def (conditional-flow name signature predicate then-proc else-proc)
  (def test (validate (Fun Bool <- (operation-input signature)) predicate))
  (def yes (validate signature then-proc))
  (def no (validate signature else-proc))
  (scheme-flow name signature
    (.call Observation. .bind test (lambda (accepted?) (if accepted? yes no)))))
(def (cached-pure-flow name signature key-type key-proc proc)
  (def key (validate (Fun key-type <- (operation-input signature)) key-proc))
  (def operation (validate signature proc))
  (pure-flow name signature (yuanxu-memoize key operation)))
(def (cached-scheme-flow name signature key-type key-proc proc)
  (def key (validate (Fun key-type <- (operation-input signature)) key-proc))
  (def operation (validate signature proc))
  (scheme-flow name signature (yuanxu-memoize key operation)))

(def (flow-then name left right)
  (require-type-flow! (flow-output-contract left) (flow-input-contract right))
  (flow-compose name (append (flow-steps left) (flow-steps right))
                (Fun (flow-output-contract right) <- (flow-input-contract left))))
(def (flow-branch name left right)
  (require-type-flow! (flow-input-contract left) (flow-input-contract right))
  (def signature (Fun (PairValue (flow-output-contract left) (flow-output-contract right))
                     <- (flow-input-contract left)))
  (flow-compose name (list (make-branch-step name left right signature)) signature))
(def (flow-fanout name left right) (flow-branch name left right))
(def (flow-map name source signature proc)
  (flow-then name source (flow-arr (flow-derived-name name 'map) signature proc)))
(def (flow-bind name source output binder)
  (def signature (Fun output <- (flow-input-contract source)))
  (flow-compose name (list (make-kleisli-step name source binder signature)) signature))
(def (flow-kleisli name source output binder) (flow-bind name source output binder))
(def (flow-first name source other)
  (def input (PairValue (flow-input-contract source) other))
  (flow-fanout name
    (flow-then (flow-derived-name name 'first-left)
      (flow-arr (flow-derived-name name 'first-input) (Fun (flow-input-contract source) <- input) car) source)
    (flow-arr (flow-derived-name name 'first-right) (Fun other <- input) cadr)))
(def (flow-second name source other)
  (def input (PairValue other (flow-input-contract source)))
  (flow-fanout name
    (flow-arr (flow-derived-name name 'second-left) (Fun other <- input) car)
    (flow-then (flow-derived-name name 'second-right)
      (flow-arr (flow-derived-name name 'second-input) (Fun (flow-input-contract source) <- input) cadr) source)))

;; A submitted body is existentially paired with the explicit signature. The
;; constructor above immediately validates it against that signature; the Any
;; position here never substitutes for the operation's argument/result Types.
(def FlowOperationTypes
  (.o flow-arr: (Fun FlowContract <- Symbol OperationSignature Any)
      flow-then: (Fun FlowContract <- Symbol FlowContract FlowContract)
      flow-fanout: (Fun FlowContract <- Symbol FlowContract FlowContract)
      flow-map: (Fun FlowContract <- Symbol FlowContract OperationSignature Any)
      flow-bind: (Fun FlowContract <- Symbol FlowContract Type Any)
      flow-first: (Fun FlowContract <- Symbol FlowContract Type)
      flow-second: (Fun FlowContract <- Symbol FlowContract Type)
      conditional-flow: (Fun FlowContract <- Symbol OperationSignature Any Any Any)
      try-flow: (Fun FlowContract <- Symbol FlowContract)
      return-flow: (Fun FlowContract <- Symbol Type)
      cached-pure-flow: (Fun FlowContract <- Symbol OperationSignature Type Any Any)))
(def FlowOperationsContract
  (.cc ObjectContract. identity: 'funflow/operations responsibilities: FlowOperationTypes))

;; : (-> Symbol Symbol Symbol)
(def (flow-derived-name base suffix)
  (string->symbol
   (string-append (symbol->string base)
                  "-"
                  (symbol->string suffix))))

;; : (-> Flow Boolean)
(def (flow-empty? flow)
  (null? (flow-steps flow)))

;;; Boundary: steps contain branch predicate is the policy-visible edge for
;;; core behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> Flow Boolean)
(def (flow-branch-declaration? flow)
  (steps-contain-branch? (flow-steps flow)))

;; : (-> Flow Boolean)
(def (flow-task-declaration? flow)
  (let ((steps (flow-steps flow)))
    (and (not (null? steps))
         (null? (cdr steps))
         (task? (car steps)))))

;; : (-> Flow Boolean)
(def (flow-sequential-declaration? flow)
  (and (not (flow-empty? flow))
       (not (flow-branch-declaration? flow))
       (not (flow-task-declaration? flow))))

;;; Boundary: steps contain branch predicate is the policy-visible edge for
;;; core behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> [Step] Boolean)
(def (steps-contain-branch? steps)
  (cond
   ((null? steps) #f)
   ((branch-step? (car steps)) #t)
   (else (steps-contain-branch? (cdr steps)))))

;;; Boundary:
;;; - Descriptor selection is a declaration classifier, not an executor.
;;; - Runner behavior stays behind the selected descriptor's planner policy.
;;; Extension contract:
;;; - New flow kinds register descriptors instead of changing this dispatch shape.
;;; - Structural predicates keep legacy task/branch/sequential flows stable.
;; : (-> FlowDeclarationRegistry Flow FlowDeclarationDescriptor)
(def (flow-declaration-descriptor-in registry flow)
  (cond
   ((flow-empty? flow) (flow-declaration-for-kind-in registry 'empty))
   ((flow-branch-declaration? flow) (flow-declaration-for-kind-in registry 'branch))
   ((flow-task-declaration? flow) (flow-declaration-for-kind-in registry 'task))
   (else (flow-declaration-for-kind-in registry 'sequential))))

;; : (-> Flow FlowDeclarationDescriptor)
(def (flow-declaration-descriptor flow)
  (flow-declaration-descriptor-in default-flow-declaration-registry flow))

;; : (-> Flow Nat)
(def (flow-step-count flow)
  (length (flow-steps flow)))



;;; The category is an extensible POO object. Every operation slot uses
;;; the same Function descriptor as the module export; derived callbacks acquire
;;; that boundary before dispatch.
;; : (-> Unit FlowCategoryPrototype)
(def flow-category-prototype
  (poo-core-role-object
   (slots ((kind 'flow-category)
           (arrow 'flow)
           (domain flow-input-contract)
           (codomain flow-output-contract)
           (compose flow-then)
           (identity flow-identity)
           (arr flow-arr)
           (map flow-map)
           (bind flow-bind)
           (fanout flow-fanout)
           (first flow-first)
           (second flow-second)
           (strand-registry default-flow-strand-registry)
           (extension-policy 'functional-kernel)))
   (supers flow-role)))

(def FlowCategoryContract
  (Record kind: (list (Exactly 'flow-category)) name: (list Symbol)
          domain: (list (Fun Type <- FlowContract))
          codomain: (list (Fun Type <- FlowContract))
          compose: (list (.get FlowOperationTypes flow-then))
          identity: (list (.get FlowOperationTypes return-flow))
          arr: (list (.get FlowOperationTypes flow-arr))
          map: (list (.get FlowOperationTypes flow-map))
          bind: (list (.get FlowOperationTypes flow-bind))
          fanout: (list (.get FlowOperationTypes flow-fanout))
          first: (list (.get FlowOperationTypes flow-first))
          second: (list (.get FlowOperationTypes flow-second))))

;; : (-> Symbol FlowCategory)
(def (make-flow-category category-name)
  (validate FlowCategoryContract
   (poo-core-role-object
   (slots ((name category-name)
           (responsibility
            (list 'functional-flow-kernel category-name))))
   (supers flow-category-prototype))))

;; : (-> Unit FlowCategory)
(def default-flow-category
  (make-flow-category 'flow))

;; : (-> FlowCategoryCandidate Boolean)
(def (flow-category? category)
  (and (object? category)
       (eq? (.@ category kind) 'flow-category)))

;; : (-> FlowCategory Symbol)
(def (flow-category-name category)
  (.@ category name))

;; : (-> FlowCategory Symbol)
(def (flow-category-arrow category) (.@ category arrow))

;; : (-> FlowCategory Flow Contract)
(def (flow-category-domain category flow)
  ((.ref (validate FlowCategoryContract category) 'domain) flow))

;; : (-> FlowCategory Flow Contract)
(def (flow-category-codomain category flow)
  ((.ref (validate FlowCategoryContract category) 'codomain) flow))

;; : (-> FlowCategory FlowStrandRegistry)
(def (flow-category-strand-registry category)
  (.@ category strand-registry))

;; : (-> FlowCategory Symbol Flow Flow Flow)
(def (flow-category-compose category name left right)
  ((.ref (validate FlowCategoryContract category) 'compose) name left right))

;; : (-> FlowCategory Symbol Contract Flow)
(def (flow-category-identity category name contract)
  ((.ref (validate FlowCategoryContract category) 'identity) name contract))

;; : (-> FlowCategory Symbol Function Procedure Flow)
(def (flow-category-arr category name signature proc)
  ((.ref (validate FlowCategoryContract category) 'arr) name signature proc))

;; : (-> FlowCategory Symbol Flow Procedure Contract Flow)
(def (flow-category-map category name source signature proc)
  ((.ref (validate FlowCategoryContract category) 'map) name source signature proc))

;; : (-> FlowCategory Symbol Flow Procedure Contract Flow)
(def (flow-category-bind category name source output binder)
  ((.ref (validate FlowCategoryContract category) 'bind) name source output binder))

;; : (-> FlowCategory Symbol Flow Flow Flow)
(def (flow-category-fanout category name left right)
  ((.ref (validate FlowCategoryContract category) 'fanout) name left right))

;;; Category-owned Arrow projections keep pair-routing visible as functional
;;; kernel metadata instead of requiring callers to hard-code helper names.
;; : (-> FlowCategory Symbol Flow Contract Flow)
(def (flow-category-first category name source second-contract)
  ((.ref (validate FlowCategoryContract category) 'first) name source second-contract))

;; : (-> FlowCategory Symbol Flow Contract Flow)
(def (flow-category-second category name source first-contract)
  ((.ref (validate FlowCategoryContract category) 'second) name source first-contract))
