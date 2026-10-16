;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: flows describe workflow composition and contract shape.
;;; Invariant: task execution is deferred to runner/runtime-adapter code.

(import (only-in :clan/poo/object .@ object?)
        :poo-flow/modules/workflow/control-plane/roles
        :poo-flow/modules/workflow/control-plane/failure
        :poo-flow/modules/workflow/control-plane/task
        :poo-flow/modules/workflow/control-plane/flow-strand
        :poo-flow/modules/workflow/control-plane/flow-declarations
        :core/object-family/role-syntax
        :core/utilities/algorithms)

(export make-flow
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
;; : (-> Symbol [Step] Contract Contract Flow)
(defstruct flow
  (name
   steps
   input-contract
   output-contract)
  transparent: #t)


;;; Branch steps keep the left and right flows as declarations so planning can
;;; expose a DAG before runner or adapter code chooses an execution strategy.
;; : (-> Symbol Flow Flow Contract Contract BranchStep)
(defstruct branch-step
  (name
   left
   right
   input-contract
   output-contract)
  transparent: #t)

;;; Try steps keep Funflow-style =tryE= as a composable flow declaration. The
;;; runner owns interpretation; this record only names the protected source.
;; : (-> Symbol Flow Contract Contract TryStep)
(defstruct try-step
  (name
   source
   input-contract
   output-contract)
  transparent: #t)

;;; Kleisli steps keep dynamic flow selection in the flow kernel: the source
;;; runs first, then the binder receives the source value and returns the next
;;; flow. Runner owns execution because the next flow is value-dependent.
;; : (-> Symbol Flow Procedure Contract Contract KleisliStep)
(defstruct kleisli-step
  (name
   source
   binder
   input-contract
   output-contract)
  transparent: #t)

;; flow-compose
;;   : (forall (step) (-> Symbol [step] Contract Contract Flow))
;;   : (-> Symbol List Contract Contract Flow)
;;   : (-> Symbol [Step] Contract Contract Flow)
;;   | doc m%
;;       Compose a named flow from ordered step objects and boundary contracts.
;;
;;       # Examples
;;       ```scheme
;;       (flow-name (flow-compose 'empty '() #f #f))
;;       ;; => empty
;;       ```
;;     %
(def (flow-compose name steps input-contract output-contract)
  (make-flow name steps input-contract output-contract))

;; : (-> Symbol Task Flow)
(def (task-flow name task)
  (flow-compose name
                (list task)
                (task-input-contract task)
                (task-output-contract task)))

;; : (-> Symbol Procedure Contract Contract Flow)
(def (pure-flow name proc input-contract output-contract)
  (task-flow name (make-pure-task name proc input-contract output-contract)))

;;; Arrow lifting keeps Funflow's =arr=/=pureFlow= idea in the core Scheme
;;; composition API while still lowering to an ordinary pure task.
;; : (-> Symbol Procedure Contract Contract Flow)
(def (flow-arr name proc input-contract output-contract)
  (pure-flow name proc input-contract output-contract))

;; : (-> Symbol Procedure Contract Contract Flow)
(def (scheme-flow name proc input-contract output-contract)
  (task-flow name (make-scheme-task name proc input-contract output-contract)))

;;; Boundary:
;;; - This flow is the local ErrorHandling throw source.
;;; - Recovery policy stays in runner/failure helpers.
;; : (-> Symbol String Contract Contract Flow)
(def (throw-string-flow name message input-contract output-contract)
  (scheme-flow name
               (lambda (_input)
                 (throw-string-control-plane-failure message))
               input-contract
               output-contract))

;;; The try flow returns a typed =try-result= value through ordinary
;;; =runner-run=, matching Funflow's recoverable =tryE= surface.
;; : (-> Symbol Flow Flow)
(def (try-flow name source)
  (flow-compose name
                (list (make-try-step name
                                     source
                                     (flow-input-contract source)
                                     (list 'try (flow-output-contract source))))
                (flow-input-contract source)
                (list 'try (flow-output-contract source))))

;; : (-> Symbol Flow Flow)
(def (flow-try name source)
  (try-flow name source))

;; : (-> Symbol Symbol Payload Contract Contract Flow)
(def (external-flow name operation payload input-contract output-contract)
  (task-flow name (make-external-task name operation payload input-contract output-contract)))

;;; The identity lambda is the unit flow: it preserves value and contract while
;;; still presenting the same task-backed flow shape as non-trivial steps.
;; : (-> Symbol Contract Flow)
(def (return-flow name contract)
  (pure-flow name (lambda (value) value) contract contract))

;; : (-> Symbol Contract Flow)
(def (flow-identity name contract)
  (return-flow name contract))

;;; Boundary:
;;; - This helper owns local value selection for QuickReference.
;;; - Graph fan-out remains =flow-branch= and scheduler-owned planning.
;; : (forall (input output) (-> Symbol Predicate (-> input output) (-> input output) Contract Contract Flow))
;; : (-> Symbol Predicate Procedure Procedure Contract Contract Flow)
;; : (-> Symbol Predicate Procedure Procedure Contract Contract Flow)
(def (conditional-flow name predicate then-proc else-proc input-contract output-contract)
  (scheme-flow name
               (lambda (input)
                 (if (predicate input)
                   (then-proc input)
                   (else-proc input)))
               input-contract
               output-contract))

;;; Boundary:
;;; - This wrapper owns only local tutorial cache reuse.
;;; - Store and CAS extensions own persistent cache materialization.
;; : (-> Symbol KeyProcedure Procedure Contract Contract Flow)
(def (cached-pure-flow name key-proc proc input-contract output-contract)
  (pure-flow name (poo-flow-memoize key-proc proc)
             input-contract output-contract))

;;; Invariant:
;;; - Cache lookup must happen before executor invocation.
;;; - This preserves QuickReference's single visible =Increment!= observation.
;; : (-> Symbol KeyProcedure Procedure Contract Contract Flow)
(def (cached-scheme-flow name key-proc proc input-contract output-contract)
  (scheme-flow name (poo-flow-memoize key-proc proc)
               input-contract output-contract))

;;; Composition concatenates logical steps and keeps the left input/right output
;;; edge, matching pipeline composition without running either side.
;; : (-> Symbol Flow Flow Flow)
(def (flow-then name left right)
  (flow-compose name
                (append (flow-steps left) (flow-steps right))
                (flow-input-contract left)
                (flow-output-contract right)))

;;; Branch composition applies two flows to the same input and joins their
;;; outputs as a pair-shaped value, leaving heavy parallelism to adapters.
;; : (-> Symbol Flow Flow Flow)
(def (flow-branch name left right)
  (flow-compose name
                (list (make-branch-step name
                                        left
                                        right
                                        (flow-input-contract left)
                                        (list 'pair
                                              (flow-output-contract left)
                                              (flow-output-contract right))))
                (flow-input-contract left)
                (list 'pair
                      (flow-output-contract left)
                      (flow-output-contract right))))

;; : (-> Symbol Flow Flow Flow)
(def (flow-fanout name left right)
  (flow-branch name left right))

;;; Functional output mapping is ordinary sequential composition: the source
;;; flow runs first, then a pure arrow transforms its result.
;; : (-> Symbol Flow Procedure Contract Flow)
(def (flow-map name source proc output-contract)
  (flow-then name
             source
             (flow-arr (flow-derived-name name 'map)
                       proc
                       (flow-output-contract source)
                       output-contract)))

;;; Kleisli bind is intentionally a dynamic node instead of static
;;; =flow-then=: the next flow is selected from the previous value.
;; : (-> Symbol Flow Procedure Contract Flow)
(def (flow-bind name source binder output-contract)
  (flow-compose name
                (list (make-kleisli-step name
                                         source
                                         binder
                                         (flow-input-contract source)
                                         output-contract))
                (flow-input-contract source)
                output-contract))

;; : (-> Symbol Flow Procedure Contract Flow)
(def (flow-kleisli name source binder output-contract)
  (flow-bind name source binder output-contract))

;;; Arrow =first= applies a flow to the first element of a pair-shaped list and
;;; carries the second element through unchanged.
;; : (-> Symbol Flow Contract Flow)
(def (flow-first name source second-contract)
  (let* ((input-contract (list 'pair
                               (flow-input-contract source)
                               second-contract))
         (left-input (flow-arr (flow-derived-name name 'first-input)
                               car
                               input-contract
                               (flow-input-contract source)))
         (left (flow-then (flow-derived-name name 'first-left)
                          left-input
                          source))
         (right (flow-arr (flow-derived-name name 'first-right)
                          cadr
                          input-contract
                          second-contract)))
    (flow-fanout name left right)))

;;; Arrow =second= mirrors =flow-first= and applies the source flow to the
;;; second element of a pair-shaped list.
;; : (-> Symbol Flow Contract Flow)
(def (flow-second name source first-contract)
  (let* ((input-contract (list 'pair
                               first-contract
                               (flow-input-contract source)))
         (left (flow-arr (flow-derived-name name 'second-left)
                         car
                         input-contract
                         first-contract))
         (right-input (flow-arr (flow-derived-name name 'second-input)
                                cadr
                                input-contract
                                (flow-input-contract source)))
         (right (flow-then (flow-derived-name name 'second-right)
                           right-input
                           source)))
    (flow-fanout name left right)))

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



;;; The category object is POO metadata for the functional flow kernel. It does
;;; not replace the stable =flow= struct; it names the Category/Arrow operations
;;; that strategy and extension code can reuse without hard-coding helpers.
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

;; : (-> Symbol FlowCategory)
(def (make-flow-category category-name)
  (poo-core-role-object
   (slots ((name category-name)
           (responsibility
            (list 'functional-flow-kernel category-name))))
   (supers flow-category-prototype)))

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
(def (flow-category-arrow category)
  (.@ category arrow))

;; : (-> FlowCategory Flow Contract)
(def (flow-category-domain category flow)
  ((.@ category domain) flow))

;; : (-> FlowCategory Flow Contract)
(def (flow-category-codomain category flow)
  ((.@ category codomain) flow))

;; : (-> FlowCategory FlowStrandRegistry)
(def (flow-category-strand-registry category)
  (.@ category strand-registry))

;; : (-> FlowCategory Symbol Flow Flow Flow)
(def (flow-category-compose category name left right)
  ((.@ category compose) name left right))

;; : (-> FlowCategory Symbol Contract Flow)
(def (flow-category-identity category name contract)
  ((.@ category identity) name contract))

;; : (-> FlowCategory Symbol Procedure Contract Contract Flow)
(def (flow-category-arr category name proc input-contract output-contract)
  ((.@ category arr) name proc input-contract output-contract))

;; : (-> FlowCategory Symbol Flow Procedure Contract Flow)
(def (flow-category-map category name source proc output-contract)
  ((.@ category map) name source proc output-contract))

;; : (-> FlowCategory Symbol Flow Procedure Contract Flow)
(def (flow-category-bind category name source binder output-contract)
  ((.@ category bind) name source binder output-contract))

;; : (-> FlowCategory Symbol Flow Flow Flow)
(def (flow-category-fanout category name left right)
  ((.@ category fanout) name left right))

;;; Category-owned Arrow projections keep pair-routing visible as functional
;;; kernel metadata instead of requiring callers to hard-code helper names.
;; : (-> FlowCategory Symbol Flow Contract Flow)
(def (flow-category-first category name source second-contract)
  ((.@ category first) name source second-contract))

;; : (-> FlowCategory Symbol Flow Contract Flow)
(def (flow-category-second category name source first-contract)
  ((.@ category second) name source first-contract))
