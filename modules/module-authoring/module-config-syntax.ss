;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: product module config authoring and POO prototype declarations.
;;; Invariant: generated forms are ordinary POO objects and predicates; public
;;; config authoring remains prototype composition plus named conversion helpers.

(import (only-in :clan/poo/object .o .ref .slot? object? object<-alist)
        (only-in :poo-flow/modules/workflow/scenario/configuration/selection-policy
                 poo-flow-product-use-module))

(export defpoo-module-config-prototype
        defpoo-module-config-kind-predicate
        defpoo-module-config-converter
        poo-flow-module-configs
        poo-flow-module-inherited-config)

;;; One runtime lowering owns inherited external execution declarations.
;;; Values remain inert module-selection facts; no sandbox or command runs here.
(def (poo-flow-module-inherited-config module-key
                                       inherited-profile
                                       isolation
                                       environment
                                       command
                                       backend)
  (poo-flow-product-use-module
   module-key
   (list (cons ':inherits inherited-profile)
         (cons ':isolation isolation)
         (cons ':environment environment)
         (cons ':command command)
         (cons ':nono backend))))

(begin-syntax
  (def (poo-flow-config-syntax-keyword-slots/elements ctx elements)
    (match elements
      ([] '())
      ([slot-key slot-value . more]
       (let (key (syntax->datum slot-key))
         (and (keyword? key)
              (let (rest
                    (poo-flow-config-syntax-keyword-slots/elements ctx more))
                (and rest
                     (cons (list (datum->syntax
                                  ctx
                                  (string->symbol (keyword->string key)))
                                 slot-value)
                           rest))))))
      (else #f)))

  (def (poo-flow-config-syntax-keyword-slots ctx slot-specs)
    (let (elements (syntax->list slot-specs))
      (and elements
           (poo-flow-config-syntax-keyword-slots/elements ctx elements))))

  (def (poo-flow-config-syntax-keyword-slot-groups ctx slot-def-groups)
    (map (lambda (slot-specs)
           (poo-flow-config-syntax-keyword-slots ctx slot-specs))
         (syntax->list slot-def-groups)))

  (def (poo-flow-config-syntax-all? values)
    (not (member #f values)))

  (def (poo-flow-config-syntax-definition-heads? heads)
    (andmap (lambda (head)
              (eq? (syntax->datum head) '.def))
            (syntax->list heads))))

;;; One lowering owns POO prototype config declarations for every module.
;;; Module-specific syntax supplies only its module key and config projector.
(defsyntax (poo-flow-module-configs stx)
  (syntax-case stx (quoted)
    ((ctx module-key config-flags
          (quoted quoted-form ...)
          (definition-head
           (prototype-name prototype-self prototype-super prototype-slot ...)
           slot-def ...)
          ...)
     (let* ((definition-heads?
             (poo-flow-config-syntax-definition-heads?
              (syntax (definition-head ...))))
            (slot-groups
             (poo-flow-config-syntax-keyword-slot-groups
              (syntax ctx)
              (syntax ((slot-def ...) ...)))))
       (unless definition-heads?
         (error "poo-flow module config expects native .def forms"))
       (if (poo-flow-config-syntax-all? slot-groups)
         (with-syntax (((((slot-name slot-value) ...) ...) slot-groups))
           (syntax
            (let* ((prototype-name
                    (object<-alist
                     (list (cons 'slot-name slot-value) ...)
                     supers: prototype-super))
                   ...)
              (poo-flow-product-use-module
               'module-key
               (config-flags
                (list prototype-name ...)
                '(quoted-form ...))))))
         (syntax
          (let* ((prototype-name
                  (.o (:: prototype-self prototype-super prototype-slot ...)
                      slot-def ...))
                 ...)
            (poo-flow-product-use-module
             'module-key
             (config-flags
              (list prototype-name ...)
              '(quoted-form ...))))))))))

;;; Prototype macros define named POO config objects from bounded slot rows.
;; defpoo-module-config-prototype
;; : (-> Syntax Syntax Syntax)
;; | type ConfigBindingSyntax = Syntax
;; | type ConfigSlotRowsSyntax = Syntax
;; | type ConfigPrototypeSyntax = Syntax
;; | contract: expands bounded literal slots through clan/poo's native object constructor
;; | warning: keep object inheritance and merge policy outside this syntax helper
;; | doc m%
;;   Defines a module config prototype object.
;;   # Examples
;;   ```scheme
;;   (defpoo-module-config-prototype workflow-prototype (slots ((kind 'workflow))))
;;   ;; => workflow-prototype is bound to a POO object with kind
;;   ```
(defrules defpoo-module-config-prototype
  (slots)
  ((_ binding
      (slots ((slot-key slot-value) ...)))
   (def binding
     (object<-alist
      (list (cons 'slot-key slot-value) ...)))))

;;; Predicate macros generate kind guards over POO config prototypes.
;; defpoo-module-config-kind-predicate
;; : (-> Syntax Syntax)
;; | type PredicateBindingSyntax = Syntax
;; | type ConfigKindSyntax = Syntax
;; | type KindPredicateSyntax = Syntax
;; | contract: expands a predicate binding and expected kind into an object guard
;; | warning: this helper checks only the `kind` slot, not full object validation
;; | doc m%
;;   Defines a predicate for module config object kinds.
;;   # Examples
;;   ```scheme
;;   (defpoo-module-config-kind-predicate workflow-config? 'workflow)
;;   ;; => workflow-config? accepts objects whose kind is workflow
;;   ```
(defrule (defpoo-module-config-kind-predicate predicate kind-expr)
  (def (predicate value)
    (and (object? value)
         (.slot? value 'kind)
         (eq? (.ref value 'kind) kind-expr))))

;;; Converter macros project prototype slots and literals into constructors.
;; defpoo-module-config-converter
;; : (-> Syntax Syntax Syntax Syntax Syntax Syntax)
;; | type ConverterBindingSyntax = Syntax
;; | type ConverterPrototypeArgumentsSyntax = Syntax
;; | type ConstructorSyntax = Syntax
;; | type ConverterArgumentRowsSyntax = Syntax
;; | type ConverterSyntax = Syntax
;; | contract: expands a converter that passes declared arguments to a constructor
;; | warning: constructor contract enforcement belongs to the generated constructor
;; | doc m%
;;   Defines a converter from a POO prototype plus arguments.
;;   # Examples
;;   ```scheme
;;   (defpoo-module-config-converter make-workflow (prototype name) (constructor list) (arguments (slot kind) (value name)))
;;   ;; => make-workflow pulls kind from the prototype and forwards name
;;   ```
(defrules defpoo-module-config-converter
  (constructor arguments slot value)
  ((_ converter (prototype argument ...)
      (constructor constructor-expr)
      (arguments argument-row ...))
   (def (converter prototype argument ...)
     (constructor-expr
      (defpoo-module-config-converter-argument prototype argument-row)
      ...))))

;;; Converter arguments keep slot projection separate from literal values.
;; defpoo-module-config-converter-argument
;; : (-> Syntax Syntax Syntax Syntax)
;; | type ConverterPrototypeSyntax = Syntax
;; | type ConverterArgumentRowSyntax = Syntax
;; | type ConverterArgumentSyntax = Syntax
;; | contract: expands `(slot key)` to `.ref` and `(value expr)` to the expression
;; | warning: missing slot diagnostics are owned by object validation, not this macro
;; | doc m%
;;   Expands one converter argument row.
;;   # Examples
;;   ```scheme
;;   (defpoo-module-config-converter-argument prototype (slot kind))
;;   ;; => reads kind from prototype
;;   ```
(defrules defpoo-module-config-converter-argument
  (slot value)
  ((_ prototype (slot slot-key))
   (.ref prototype 'slot-key))
  ((_ _prototype (value value-expr))
   value-expr))
