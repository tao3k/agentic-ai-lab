;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: reader-native source observations for lexical core-call shadows.
;;; Invariant: inspection reads datums only and never expands or evaluates code.

(import
        (only-in :std/list/list any)
        (only-in :core/utilities/algorithms
                 poo-flow-read-datums/append-map)
        (only-in :poo-flow/modules/user-interface/module-presentation
                 poo-flow-poo-slot-authoring-datum-bindings))

(export poo-flow-scheme-lexical-call-shadow-observation-kind
        poo-flow-scheme-lexical-call-shadow-datum-observations
        poo-flow-scheme-lexical-call-shadow-port-observations
        poo-flow-scheme-lexical-call-shadow-file-observations
        poo-flow-scheme-inline-prototype-observation-kind
        poo-flow-scheme-inline-prototype-datum-observations
        poo-flow-scheme-inline-prototype-port-observations
        poo-flow-scheme-inline-prototype-file-observations)

;;; Ordinary Scheme lexical bindings can shadow core procedures independently
;;; of POO slot authoring.  This reader-native gate records only the dangerous
;;; combination: a function formal named `values` whose body calls `values` as
;;; an operator.  It does not flag data parameters that are never invoked.
;; : (-> Unit PooFlowSchemeLexicalCallShadowObservationKind)
(def poo-flow-scheme-lexical-call-shadow-observation-kind
  "poo-flow.scheme-lexical-call-shadow-observation.v1")

;; : [Symbol]
(def +poo-flow-scheme-lexical-call-shadow-procedures+ '(values))

;;; Formal projection handles fixed, optional, keyword-backed, and dotted-rest
;;; formals without evaluating their default expressions.
;; : (forall (a) (-> a [Symbol]))
;; : (-> Value [Symbol])
(def (poo-flow-scheme-lexical-call-shadow-formal-names formals)
  (cond
   ((null? formals) '())
   ((symbol? formals) (list formals))
   ((pair? formals)
    (let* ((formal (car formals))
           (name (cond ((symbol? formal) formal)
                       ((and (pair? formal) (symbol? (car formal)))
                        (car formal))
                       (else #f)))
           (tail
            (poo-flow-scheme-lexical-call-shadow-formal-names
             (cdr formals))))
      (if name (cons name tail) tail)))
   (else '())))

;;; Call-head inspection deliberately ignores quoted and syntax data.  Other
;;; nested forms remain visible so a shadowed call cannot hide in a branch or
;;; a local sequencing form.
;; : (forall (a) (-> Symbol [a] Boolean))
;; : (-> Symbol List Boolean)
(def (poo-flow-scheme-lexical-call-shadow-called-in-elements? identifier elements)
  (cond
   ((null? elements) #f)
   ((pair? elements)
    (or (poo-flow-scheme-lexical-call-shadow-identifier-called?
         identifier (car elements))
        (poo-flow-scheme-lexical-call-shadow-called-in-elements?
         identifier (cdr elements))))
   (else
    (poo-flow-scheme-lexical-call-shadow-identifier-called?
     identifier elements))))

;; : (-> Symbol [Pair] Boolean)
(def (poo-flow-scheme-lexical-call-shadow-called-in-bindings? identifier bindings)
  (cond
   ((null? bindings) #f)
   ((not (pair? bindings)) #f)
   (else
    (let (binding (car bindings))
      (or (and (pair? binding)
               (poo-flow-scheme-lexical-call-shadow-called-in-elements?
                identifier (cdr binding)))
          (poo-flow-scheme-lexical-call-shadow-called-in-bindings?
           identifier (cdr bindings)))))))

;; : (-> Symbol Value Boolean)
(def (poo-flow-scheme-lexical-call-shadow-called-in-let? identifier datum)
  (let* ((tail (cdr datum))
         (named? (and (pair? tail) (symbol? (car tail))))
         (binding-tail (if named? (cdr tail) tail))
         (bindings (if (pair? binding-tail) (car binding-tail) '()))
         (body (if (pair? binding-tail) (cdr binding-tail) '())))
    (or (poo-flow-scheme-lexical-call-shadow-called-in-bindings?
         identifier bindings)
        (poo-flow-scheme-lexical-call-shadow-called-in-elements?
         identifier body))))

;; : (-> Symbol Value Boolean)
(def (poo-flow-scheme-lexical-call-shadow-called-in-poo? identifier datum)
  (any (lambda (binding)
         (poo-flow-scheme-lexical-call-shadow-identifier-called?
          identifier (cdr binding)))
       (poo-flow-poo-slot-authoring-datum-bindings datum)))

;; : (forall (a) (-> Symbol a Boolean))
;; : (-> Symbol Value Boolean)
(def (poo-flow-scheme-lexical-call-shadow-identifier-called? identifier datum)
  (cond
   ((not (pair? datum)) #f)
   ((memq (car datum) '(quote quasiquote syntax quasisyntax)) #f)
   ((eq? (car datum) identifier) #t)
   ((memq (car datum) '(let let* letrec letrec*))
    (poo-flow-scheme-lexical-call-shadow-called-in-let? identifier datum))
   ((memq (car datum) '(.o .def))
    (poo-flow-scheme-lexical-call-shadow-called-in-poo? identifier datum))
   (else
    (or (and (pair? (car datum))
             (poo-flow-scheme-lexical-call-shadow-identifier-called?
              identifier (car datum)))
        (poo-flow-scheme-lexical-call-shadow-called-in-elements?
         identifier (cdr datum))))))

;; : (-> Symbol Symbol Symbol Alist)
(def (poo-flow-scheme-lexical-call-shadow-observation scope definition identifier)
  (list
   (cons 'kind poo-flow-scheme-lexical-call-shadow-observation-kind)
   (cons 'scope scope)
   (cons 'definition definition)
   (cons 'identifier identifier)
   (cons 'status 'lexical-procedure-shadow)
   (cons 'detail
         (list
          (cons 'code 'scheme-lexical-binding-shadows-procedure)
          (cons 'rule 'scheme-procedure-formal-must-not-be-called-as-operator)
          (cons 'definition definition)
          (cons 'identifier identifier)
          (cons 'recommendation 'rename-lexical-binding)))
   (cons 'runtime-executed #f)))

;; : (-> Symbol Symbol [Symbol] [Value] [Alist])
(def (poo-flow-scheme-lexical-call-shadow-local-observations
      scope definition formals body)
  (filter-map
   (lambda (identifier)
     (and (memq identifier formals)
          (poo-flow-scheme-lexical-call-shadow-identifier-called?
           identifier body)
          (poo-flow-scheme-lexical-call-shadow-observation
           scope definition identifier)))
   +poo-flow-scheme-lexical-call-shadow-procedures+))

;;; Tail-passing discovery keeps nested source traversal linear: each pair is
;;; visited once and no recursive result list is copied by `append`.
(def (poo-flow-scheme-lexical-call-shadow-datum-observations/into
      scope datum tail)
  (cond
   ((not (pair? datum)) tail)
   ((memq (car datum) '(quote quasiquote syntax quasisyntax)) tail)
   ((and (memq (car datum) '(def define))
         (pair? (cdr datum))
         (pair? (cadr datum))
         (symbol? (caadr datum)))
    (let* ((header (cadr datum))
           (definition (car header))
           (body (cddr datum))
           (formals
            (poo-flow-scheme-lexical-call-shadow-formal-names (cdr header))))
      (foldr
       cons
       (poo-flow-scheme-lexical-call-shadow-datum-observations/into
        scope body tail)
       (poo-flow-scheme-lexical-call-shadow-local-observations
        scope definition formals body))))
   (else
    (poo-flow-scheme-lexical-call-shadow-datum-observations/into
     scope
     (car datum)
     (poo-flow-scheme-lexical-call-shadow-datum-observations/into
      scope (cdr datum) tail)))))

;;; Definition discovery stays on reader data and recognizes only ordinary
;;; function headers.  Quoted examples and syntax templates are not code.
;; : (forall (a) (-> Symbol a [Alist]))
;; : (-> Symbol Value [Alist])
(def (poo-flow-scheme-lexical-call-shadow-datum-observations scope datum)
  (poo-flow-scheme-lexical-call-shadow-datum-observations/into
   scope datum '()))

;; : (-> Symbol InputPort [Alist])
;; poo-flow-scheme-lexical-call-shadow-port-observations
;;   : (-> Symbol InputPort [Alist])
;;   | doc m%
;;       Read Scheme datums in source order and report function formals that
;;       shadow `values` exactly where the corresponding body invokes it.
;;       Quoted and syntax data remain inert, and no source form is expanded or
;;       evaluated by the observation pass.
;;
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-scheme-lexical-call-shadow-port-observations
;;        'source (open-input-string "(def (bad values) (values values))"))
;;       ;; => one lexical-procedure-shadow observation
;;       ```
;;     %
(def (poo-flow-scheme-lexical-call-shadow-port-observations scope port)
  (poo-flow-read-datums/append-map
   (cut poo-flow-scheme-lexical-call-shadow-datum-observations scope <>)
   port))

;; : (forall (k v) (-> Symbol PathString [(Pair k v)]))
;; : (-> Symbol PathString [Alist])
(def (poo-flow-scheme-lexical-call-shadow-file-observations scope path)
  (call-with-input-file
   path
   (lambda (port)
     (poo-flow-scheme-lexical-call-shadow-port-observations scope port))))

;;; Repeated `(.o (:: @ (.ref Contract 'proto)) ...)` couples prototype lookup
;;; to object construction.  It is semantically valid but obscures the cold
;;; lookup boundary and repeats a stable dependency in every constructor body.
;; : (-> Unit PooFlowSchemeInlinePrototypeObservationKind)
(def poo-flow-scheme-inline-prototype-observation-kind
  "poo-flow.scheme-inline-prototype-observation.v1")

;; : (-> SchemeDatum Boolean)
(def (poo-flow-scheme-inline-prototype-ref? datum)
  (and (pair? datum)
       (eq? (car datum) '.ref)
       (pair? (cdr datum))
       (pair? (cddr datum))
       (null? (cdddr datum))
       (equal? (caddr datum) '(quote proto))))

;; : (-> Value Symbol)
(def (poo-flow-scheme-inline-prototype-owner datum)
  (let (owner (cadr datum))
    (if (symbol? owner) owner 'dynamic-prototype-owner)))

;; : (-> Symbol Value Alist)
(def (poo-flow-scheme-inline-prototype-observation scope prototype-ref)
  (let (owner (poo-flow-scheme-inline-prototype-owner prototype-ref))
    (list
     (cons 'kind poo-flow-scheme-inline-prototype-observation-kind)
     (cons 'scope scope)
     (cons 'owner owner)
     (cons 'form '.o)
     (cons 'phase 'object-construction)
     (cons 'status 'inline-prototype-lookup)
     (cons 'detail
           (list
            (cons 'code 'poo-prototype-lookup-inside-composition)
            (cons 'rule 'poo-prototype-lookup-must-be-hoisted)
            (cons 'owner owner)
            (cons 'recommendation
                  'bind-prototype-once-before-repeated-construction)))
     (cons 'runtime-executed #f))))

;; : (-> Symbol Value [Alist] [Alist])
(def (poo-flow-scheme-inline-prototype-refs-observations/into scope refs tail)
  (if (pair? refs)
    (let* ((prototype-ref (car refs))
           (next
            (poo-flow-scheme-inline-prototype-refs-observations/into
             scope (cdr refs) tail)))
      (if (poo-flow-scheme-inline-prototype-ref? prototype-ref)
        (cons (poo-flow-scheme-inline-prototype-observation
               scope prototype-ref)
              next)
        next))
    tail))

;;; Source datums may use dotted `.o` forms.  Walk the pair spine instead of
;;; requiring every constructor clause list to be proper.
;; : (-> Symbol Value [Alist] [Alist])
(def (poo-flow-scheme-inline-prototype-super-observations/into
      scope clauses tail)
  (if (pair? clauses)
    (let* ((clause (car clauses))
           (next
            (poo-flow-scheme-inline-prototype-super-observations/into
             scope (cdr clauses) tail)))
      (if (and (pair? clause)
               (eq? (car clause) '::)
               (pair? (cdr clause)))
        (poo-flow-scheme-inline-prototype-refs-observations/into
         scope (cddr clause) next)
        next))
    tail))

;;; The walker observes only direct super expressions.  A `.ref` in an
;;; ordinary slot initializer may be runtime-dependent and is not this rule.
;;; Quoted examples and syntax templates remain inert.
(def (poo-flow-scheme-inline-prototype-datum-observations/into
      scope datum tail)
  (cond
   ((not (pair? datum)) tail)
   ((memq (car datum) '(quote quasiquote syntax quasisyntax)) tail)
   ((eq? (car datum) '.o)
    (poo-flow-scheme-inline-prototype-super-observations/into
     scope
     (cdr datum)
     (poo-flow-scheme-inline-prototype-datum-observations/into
      scope (cdr datum) tail)))
   (else
    (poo-flow-scheme-inline-prototype-datum-observations/into
     scope
     (car datum)
     (poo-flow-scheme-inline-prototype-datum-observations/into
      scope (cdr datum) tail)))))

;; : (forall (a) (-> Symbol a [Alist]))
;; : (-> Symbol Value [Alist])
(def (poo-flow-scheme-inline-prototype-datum-observations scope datum)
  (poo-flow-scheme-inline-prototype-datum-observations/into
   scope datum '()))

;; : (-> Symbol InputPort [Alist])
;; poo-flow-scheme-inline-prototype-port-observations
;;   : (-> Symbol InputPort [Alist])
;;   | doc m%
;;       Read Scheme datums in source order and report direct contract
;;       prototype lookups nested in `.o` super clauses. Quoted data and
;;       already-hoisted prototype bindings remain inert.
;;
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-scheme-inline-prototype-port-observations
;;        'source (open-input-string "(.o (:: @ (.ref Contract 'proto)))"))
;;       ;; => one inline-prototype-lookup observation
;;       ```
;;     %
(def (poo-flow-scheme-inline-prototype-port-observations scope port)
  (poo-flow-read-datums/append-map
   (cut poo-flow-scheme-inline-prototype-datum-observations scope <>)
   port))

;; : (forall (k v) (-> Symbol PathString [(Pair k v)]))
;; : (-> Symbol PathString [Alist])
(def (poo-flow-scheme-inline-prototype-file-observations scope path)
  (call-with-input-file
   path
   (lambda (port)
     (poo-flow-scheme-inline-prototype-port-observations scope port))))
