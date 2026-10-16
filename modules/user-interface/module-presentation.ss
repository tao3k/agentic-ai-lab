;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: strict observability data for module-system debugging.
;;; Invariant: observations are strict POO values without lazy slots or runtime adapters.
;;; Intent: make recursive presentation paths visible without participating in them.

(import
        (only-in :core/utilities/algorithms
                 poo-flow-read-datums/append-map
                 poo-flow-scheme-datum-find)
        (only-in :core/object-family/syntax
                 defpoo-object-family)
        :core/utilities/final-projection-syntax)

(export poo-flow-module-observation-kind
        poo-flow-module-observation-prototype
        make-poo-flow-module-observation
        poo-flow-module-observation?
        poo-flow-module-observation-scope
        poo-flow-module-observation-stage
        poo-flow-module-observation-status
        poo-flow-module-observation-count
        poo-flow-module-observation-depth
        poo-flow-module-observation-path
        poo-flow-module-observation-detail
        poo-flow-module-observation-descriptor-realized?
        poo-flow-module-observation-runtime-executed?
        poo-flow-module-observation-recursive-stage?
        poo-flow-module-observation-stage-status
        poo-flow-module-observation-stage/detail
        poo-flow-module-observation-stage/alist
        poo-flow-module-observation->alist
        poo-flow-module-presentation-trace
        poo-flow-module-presentation-trace/add
        poo-flow-poo-slot-authoring-observation-kind
        poo-flow-poo-slot-authoring-observation-prototype
        make-poo-flow-poo-slot-authoring-observation
        poo-flow-poo-slot-authoring-observation?
        poo-flow-poo-slot-authoring-observation-scope
        poo-flow-poo-slot-authoring-observation-slot
        poo-flow-poo-slot-authoring-observation-initializer
        poo-flow-poo-slot-authoring-observation-status
        poo-flow-poo-slot-authoring-observation-detail
        poo-flow-poo-slot-authoring-observation-descriptor-realized?
        poo-flow-poo-slot-authoring-observation-runtime-executed?
        poo-flow-poo-slot-authoring-self-reference?
        poo-flow-scheme-datum-find
        poo-flow-poo-slot-authoring-primitive-slot?
        poo-flow-poo-slot-authoring-status
        poo-flow-poo-slot-authoring-observation/alist
        poo-flow-poo-slot-authoring-observations
        poo-flow-poo-slot-authoring-datum-bindings
        poo-flow-poo-slot-authoring-datum-observations
        poo-flow-poo-slot-authoring-port-observations
        poo-flow-poo-slot-authoring-file-observations
        poo-flow-poo-slot-authoring-summary-kind
        poo-flow-poo-slot-authoring-observation-ok?
        poo-flow-poo-slot-authoring-statuses
        poo-flow-poo-slot-authoring-diagnostics
        poo-flow-poo-slot-authoring-summary)

;;; Observation kind ids are shared by doctor, user-config, and future CLI
;;; surfaces so tooling can recognize one trace vocabulary across projections.
;; : (-> Unit PooFlowModuleObservationKind)
(def poo-flow-module-observation-kind
  "poo-flow.modules.observation.v1")

;;; Observation values are strict native POO objects. They contain only eager
;;; slots, so debugging a lazy `.ref` recursion never creates another lazy path.
;; : (-> Symbol Symbol Symbol Integer Integer [Symbol] Alist Boolean Boolean PooFlowModuleObservation)
(defpoo-object-family
  (prototype poo-flow-module-observation-prototype
             module-observation?
             poo-flow-module-observation?)
  (constructor make-poo-flow-module-observation
               (scope-value scope)
               (stage-value stage)
               (status-value status)
               (count-value count)
               (depth-value depth)
               (path-value path)
               (detail-value detail)
               (descriptor-realized-value descriptor-realized?)
               (runtime-executed-value runtime-executed?))
  (accessors
   (poo-flow-module-observation-scope scope)
   (poo-flow-module-observation-stage stage)
   (poo-flow-module-observation-status status)
   (poo-flow-module-observation-count count)
   (poo-flow-module-observation-depth depth)
   (poo-flow-module-observation-path path)
   (poo-flow-module-observation-detail detail)
   (poo-flow-module-observation-descriptor-realized? descriptor-realized?)
   (poo-flow-module-observation-runtime-executed? runtime-executed?))
  (projections))

;;; Recursive-stage detection is intentionally just path membership. The
;;; framework should flag suspicious projection shape without interpreting
;;; descriptor semantics or executing module loaders.
;; : (-> Symbol [Symbol] Boolean)
(def (poo-flow-module-observation-recursive-stage? stage active-path)
  (and (member stage active-path) #t))

;;; Stage status stays finite and symbolic so test fixtures can assert on it
;;; without parsing messages or stack traces.
;; : (-> Symbol [Symbol] Symbol)
(def (poo-flow-module-observation-stage-status stage active-path)
  (if (poo-flow-module-observation-recursive-stage? stage active-path)
    'recursive-stage
    'ok))

;;; Stage observations record the path after the stage is entered. A repeated
;;; stage therefore carries both a `recursive-stage` status and the full path
;;; needed to reproduce the problematic projection walk.
;; : (forall (a) (-> [a] [a] [a]))
;; : (-> List List List)
(def (poo-flow-module-observation-values/tail values tail)
  (append values tail))

;; : (-> Symbol Symbol Integer [Symbol] Alist PooFlowModuleObservation)
(def (poo-flow-module-observation-stage/detail
      scope
      stage
      count
      active-path
      detail)
  (make-poo-flow-module-observation
   scope
   stage
   (poo-flow-module-observation-stage-status stage active-path)
   count
   (length active-path)
   (poo-flow-module-observation-values/tail active-path (list stage))
   detail
   #f
   #f))

;;; Alist projection is the safe edge for user-interface and doctor outputs.
;; : (-> PooFlowModuleObservation Alist)
(defpoo-final-projection
  poo-flow-module-observation->alist (observation)
  (bindings ())
  (fields ((kind poo-flow-module-observation-kind)
           (scope (poo-flow-module-observation-scope observation))
           (stage (poo-flow-module-observation-stage observation))
           (status (poo-flow-module-observation-status observation))
           (count (poo-flow-module-observation-count observation))
           (depth (poo-flow-module-observation-depth observation))
           (path (poo-flow-module-observation-path observation))
           (detail (poo-flow-module-observation-detail observation))
           (descriptor-realized?
            (poo-flow-module-observation-descriptor-realized? observation))
           (runtime-executed
            (poo-flow-module-observation-runtime-executed? observation)))))

;;; Stage/alist keeps the common presentation path concise while still routing
;;; every trace row through the strict observation record.
;; : (-> Symbol Symbol Integer [Symbol] Alist)
(def (poo-flow-module-observation-stage/alist scope stage count active-path)
  (poo-flow-module-observation->alist
   (poo-flow-module-observation-stage/detail
    scope
    stage
    count
    active-path
    '())))

;;; Trace construction is a simple left-to-right walk over `(stage . count)`
;;; pairs. Repeated stages stay in the output with `recursive-stage` status
;;; instead of raising while the caller is trying to inspect a broken projection.
;; : (-> Symbol [Pair] [Symbol] [Alist])
(def (poo-flow-module-presentation-trace/add scope stage-counts active-path)
  (cond
   ((null? stage-counts) '())
   (else
    (let ((entry (car stage-counts)))
      (cons (poo-flow-module-observation-stage/alist
             scope
             (car entry)
             (cdr entry)
             active-path)
            (poo-flow-module-presentation-trace/add
             scope
             (cdr stage-counts)
             (poo-flow-module-observation-values/tail
              active-path
              (list (car entry)))))))))

;;; Presentation traces are report-only data. They are safe to read before
;;; heavier slots because they do not dereference POO objects or realize modules.
;; : (-> Symbol [Pair] [Alist])
(def (poo-flow-module-presentation-trace scope stage-counts)
  (poo-flow-module-presentation-trace/add scope stage-counts '()))

;;; POO authoring observations inspect source-shaped slot bindings, not POO
;;; objects. This catches `.o slot: slot` style self references before a `.ref`
;;; path can recurse or allocate during debugging.
;; : (-> Unit PooFlowPooSlotAuthoringObservationKind)
(def poo-flow-poo-slot-authoring-observation-kind
  "poo-flow.poo-slot-authoring-observation.v1")

;; : (-> Symbol Symbol Value Symbol Alist Boolean Boolean PooFlowPooSlotAuthoringObservation)
(defpoo-object-family
  (prototype poo-flow-poo-slot-authoring-observation-prototype
             poo-slot-authoring-observation?
             poo-flow-poo-slot-authoring-observation?)
  (constructor make-poo-flow-poo-slot-authoring-observation
               (scope-value scope)
               (slot-value slot)
               (initializer-value initializer)
               (status-value status)
               (detail-value detail)
               (descriptor-realized-value descriptor-realized?)
               (runtime-executed-value runtime-executed?))
  (accessors
   (poo-flow-poo-slot-authoring-observation-scope scope)
   (poo-flow-poo-slot-authoring-observation-slot slot)
   (poo-flow-poo-slot-authoring-observation-initializer initializer)
   (poo-flow-poo-slot-authoring-observation-status status)
   (poo-flow-poo-slot-authoring-observation-detail detail)
   (poo-flow-poo-slot-authoring-observation-descriptor-realized?
    descriptor-realized?)
   (poo-flow-poo-slot-authoring-observation-runtime-executed?
    runtime-executed?))
  (projections))

;; : (forall (a) (-> Symbol a Boolean))
;; : (-> Symbol Value Boolean)
(def (poo-flow-poo-slot-authoring-identifier-reference? identifier datum)
  (if (poo-flow-scheme-datum-find
       (lambda (candidate)
         (and (symbol? candidate) (eq? identifier candidate)))
       datum)
    #t
    #f))

;; : (-> Symbol Value Boolean)
(def (poo-flow-poo-slot-authoring-self-reference? slot initializer)
  (and (symbol? slot)
       (poo-flow-poo-slot-authoring-identifier-reference?
        slot initializer)))

;; : [Symbol]
(def +poo-flow-poo-slot-authoring-primitive-slots+
  '(.o .def .ref .slot? object?))

;;; Boundary: poo slot authoring primitive slot predicate is the policy-visible
;;; edge for module-system behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> Symbol Boolean)
(def (poo-flow-poo-slot-authoring-primitive-slot? slot)
  (and (symbol? slot)
       (member slot +poo-flow-poo-slot-authoring-primitive-slots+)
       #t))

;;; Boundary: poo slot authoring status is the policy-visible edge for module-
;;; system behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> Symbol Value Symbol)
(def (poo-flow-poo-slot-authoring-status slot initializer)
  (cond
   ((poo-flow-poo-slot-authoring-self-reference? slot initializer)
    'self-referential-slot-initializer)
   ((poo-flow-poo-slot-authoring-primitive-slot? slot)
    'primitive-shadow-slot)
   (else 'ok)))

;;; Boundary: poo slot authoring detail is the policy-visible edge for module-
;;; system behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> Symbol Value Alist)
(def (poo-flow-poo-slot-authoring-detail slot initializer)
  (cond
   ((poo-flow-poo-slot-authoring-self-reference? slot initializer)
    (list (cons 'code 'poo-slot-initializer-shadows-slot)
          (cons 'rule 'poo-slot-initializer-must-not-shadow-slot-name)
          (cons 'slot slot)
          (cons 'initializer initializer)
          (cons 'recommendation 'rename-local-or-wrap-in-helper)))
   ((poo-flow-poo-slot-authoring-primitive-slot? slot)
    (list (cons 'code 'poo-slot-shadows-poo-primitive)
          (cons 'rule 'poo-slot-must-not-shadow-poo-primitive)
          (cons 'slot slot)
          (cons 'initializer initializer)
          (cons 'recommendation 'rename-slot-or-use-result-prefix)))
   (else '())))

;; : (-> Symbol Symbol Value PooFlowPooSlotAuthoringObservation)
(def (poo-flow-poo-slot-authoring-observation/make scope slot initializer)
  (make-poo-flow-poo-slot-authoring-observation
   scope
   slot
   initializer
   (poo-flow-poo-slot-authoring-status slot initializer)
   (poo-flow-poo-slot-authoring-detail slot initializer)
   #f
   #f))

;; : (-> PooFlowPooSlotAuthoringObservation Alist)
(defpoo-final-projection
  poo-flow-poo-slot-authoring-observation->alist (observation)
  (bindings ())
  (fields ((kind poo-flow-poo-slot-authoring-observation-kind)
           (scope
            (poo-flow-poo-slot-authoring-observation-scope observation))
           (slot
            (poo-flow-poo-slot-authoring-observation-slot observation))
           (initializer
            (poo-flow-poo-slot-authoring-observation-initializer observation))
           (status
            (poo-flow-poo-slot-authoring-observation-status observation))
           (detail
            (poo-flow-poo-slot-authoring-observation-detail observation))
           (descriptor-realized?
            (poo-flow-poo-slot-authoring-observation-descriptor-realized?
             observation))
           (runtime-executed
            (poo-flow-poo-slot-authoring-observation-runtime-executed?
             observation)))))

;; : (-> Symbol Pair Alist)
(def (poo-flow-poo-slot-authoring-observation/alist scope slot-initializer)
   (poo-flow-poo-slot-authoring-observation->alist
   (poo-flow-poo-slot-authoring-observation/make
    scope
    (car slot-initializer)
    (cdr slot-initializer))))

;; : (forall (k v) (-> Symbol [(Pair k v)] [Alist]))
;; : (-> Symbol [Pair] [Alist])
(def (poo-flow-poo-slot-authoring-observations scope slot-initializers)
  (map (lambda (slot-initializer)
         (poo-flow-poo-slot-authoring-observation/alist
          scope
          slot-initializer))
       slot-initializers))

;;; Read-only source inspection recognizes both POO-native slot spellings:
;;; `slot: initializer` and `(slot initializer)`.  It operates on reader data,
;;; never expands `.o`/`.def`, constructs a POO object, or evaluates an
;;; initializer.  In particular, a lexical spelling such as `values: values`
;;; is observable before POO can reinterpret the right hand identifier as a
;;; lazy self-slot lookup. `.cc` is a procedure: override values are evaluated
;;; before constant slots are installed, so that spelling is not a lazy
;;; self-reference and must not be rejected here.
;; : (forall (a) (-> [a] [(Pair Symbol a)]))
;; : (-> List [Pair])
(def (poo-flow-poo-slot-authoring-form-bindings elements)
  (cond
   ((null? elements) '())
   ((not (pair? elements)) '())
   ((and (keyword? (car elements))
         (pair? (cdr elements)))
    (cons (cons (string->symbol (keyword->string (car elements)))
                (cadr elements))
          (poo-flow-poo-slot-authoring-form-bindings (cddr elements))))
   ((and (pair? (car elements))
         (symbol? (caar elements))
         (pair? (cdar elements))
         (null? (cddar elements)))
    (cons (cons (caar elements) (cadar elements))
          (poo-flow-poo-slot-authoring-form-bindings (cdr elements))))
   (else
    (poo-flow-poo-slot-authoring-form-bindings (cdr elements)))))

;; : (forall (a) (-> a [(Pair Symbol a)]))
;; poo-flow-poo-slot-authoring-datum-bindings
;;   : (-> Value [Pair])
;;   | doc m%
;;       Read the POO slot/initializer bindings nested in one Scheme datum
;;       without expanding the form, realizing an object, or evaluating code.
;;       The specialized keyword and parenthesized branches preserve source
;;       order and return only source-shaped pairs for the observation owner.
;;
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-poo-slot-authoring-datum-bindings
;;        '(.o values: values (safe safe-value)))
;;       ;; => ((values . values) (safe . safe-value))
;;       ```
;;     %
(def (poo-flow-poo-slot-authoring-datum-bindings/into datum tail)
  (cond
   ((not (pair? datum)) tail)
   ((and (memq (car datum) '(quote quasiquote syntax quasisyntax))
         (pair? (cdr datum)))
    tail)
   (else
    (let* ((head (car datum))
           (object-elements
            (cond
             ((eq? head '.o) (cdr datum))
             ((and (eq? head '.def) (pair? (cdr datum))) (cddr datum))
             (else '())))
           (local-bindings
            (poo-flow-poo-slot-authoring-form-bindings object-elements))
           (cdr-bindings
            (poo-flow-poo-slot-authoring-datum-bindings/into
             (cdr datum)
             tail))
           (child-bindings
            (poo-flow-poo-slot-authoring-datum-bindings/into
             (car datum)
             cdr-bindings)))
      (foldr cons child-bindings local-bindings)))))

(def (poo-flow-poo-slot-authoring-datum-bindings datum)
  (poo-flow-poo-slot-authoring-datum-bindings/into datum '()))

;; : (forall (a) (-> Symbol a [Alist]))
;; poo-flow-poo-slot-authoring-datum-observations
;;   : (-> Symbol Value [Alist])
;;   | doc m%
;;       Project one source datum's POO slot bindings into strict authoring
;;       observations without expanding or evaluating the source.
;;
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-poo-slot-authoring-datum-observations
;;        'source '(.o value: value))
;;       ;; => one self-referential-slot-initializer observation
;;       ```
;;     %
(def (poo-flow-poo-slot-authoring-datum-observations scope datum)
  (poo-flow-poo-slot-authoring-observations
   scope
   (poo-flow-poo-slot-authoring-datum-bindings datum)))

;; : (-> Symbol InputPort [Alist])
;; poo-flow-poo-slot-authoring-port-observations
;;   : (-> Symbol InputPort [Alist])
;;   | doc m%
;;       Read every datum from a Scheme port and preserve source order while
;;       projecting POO slot authoring observations.
;;
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-poo-slot-authoring-port-observations
;;        'source (open-input-string "(.o value: value)"))
;;       ;; => one self-referential-slot-initializer observation
;;       ```
;;     %
(def (poo-flow-poo-slot-authoring-port-observations scope port)
  (poo-flow-read-datums/append-map
   (cut poo-flow-poo-slot-authoring-datum-observations scope <>)
   port))

;; : (forall (k v) (-> Symbol PathString [(Pair k v)]))
;; : (-> Symbol PathString [Alist])
;; poo-flow-poo-slot-authoring-file-observations
;;   : (-> Symbol PathString [Alist])
;;   | doc m%
;;       Open one Scheme source file and return its reader-native POO authoring
;;       observations without loading the module or realizing an object.
;;
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-poo-slot-authoring-file-observations
;;        'module "modules/module-authoring/module-descriptor.ss")
;;       ;; => ordered authoring observations
;;       ```
;;     %
(def (poo-flow-poo-slot-authoring-file-observations scope path)
  (call-with-input-file
   path
   (lambda (port)
     (poo-flow-poo-slot-authoring-port-observations scope port))))

;; : (-> Unit PooFlowPooSlotAuthoringSummaryKind)
(def poo-flow-poo-slot-authoring-summary-kind
  "poo-flow.poo-slot-authoring-summary.v1")

;; : (-> Alist Boolean)
(def (poo-flow-poo-slot-authoring-observation-ok? observation)
  (eq? (cdr (assoc 'status observation)) 'ok))

;; : (forall (k v) (-> [(Pair k v)] [Symbol]))
;; : (-> [Alist] [Symbol])
(def (poo-flow-poo-slot-authoring-statuses observations)
  (map (lambda (observation)
         (cdr (assoc 'status observation)))
       observations))

;;; Boundary: poo slot authoring diagnostics is the policy-visible edge for
;;; module-system behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (forall (k v) (-> [(Pair k v)] [(Pair k v)]))
;; : (-> [Alist] [Alist])
(def (poo-flow-poo-slot-authoring-diagnostics observations)
  (map (lambda (observation)
         (cdr (assoc 'detail observation)))
       (filter (lambda (observation)
                 (not (poo-flow-poo-slot-authoring-observation-ok?
                       observation)))
               observations)))

;; : (-> Symbol [Alist] Alist)
(defpoo-final-projection
  poo-flow-poo-slot-authoring-summary (scope observations)
  (bindings ((diagnostics
              (poo-flow-poo-slot-authoring-diagnostics observations))))
  (fields ((kind poo-flow-poo-slot-authoring-summary-kind)
           (scope scope)
           (observation-count (length observations))
           (statuses
            (poo-flow-poo-slot-authoring-statuses observations))
           (diagnostic-count (length diagnostics))
           (diagnostics diagnostics)
           (descriptor-realized? #f)
           (runtime-executed #f))))
