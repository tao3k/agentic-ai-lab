;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO Flow role-aware source admission for one loaded Module Interface.
;;; Invariant: source is read as inert data; this owner never expands or runs it.

(import (only-in :clan/poo/object .def .o .ref .slot? object?)
        (only-in :clan/poo/mop Type. define-type element? validate)
        (only-in :std/list/list any filter-map find)
        (only-in :core/utilities/algorithms
                 poo-flow-read-datums/append-map
                 poo-flow-scheme-datum-find)
        (only-in :poo-flow/modules/module-authoring/module-interface
                 poo-flow-module-interface-prototype
                 poo-flow-module-interface?
                 poo-flow-module-interface-id
                 poo-flow-module-interface-authoring)
        (only-in :poo-flow/modules/user-interface/module-presentation
                 poo-flow-poo-slot-authoring-datum-bindings
                 poo-flow-poo-slot-authoring-self-reference?)
        :core/poo-clos/interface
        (only-in :poo-flow/modules/module-authoring/semantic-module
                 ModuleAuthoringExecutor. ModuleSourceRole.
                 ConfigSourceRole.))

(export ModuleAuthoringAdmissionProtocol
        ModuleAuthoringAdmissionGeneric
        ModuleAuthoringCoreMethods
        PooFlowModuleAuthoringDiagnostic
        PooFlowModuleAuthoringAdmission
        poo-flow-module-authoring-role
        poo-flow-module-authoring-admit-datum
        poo-flow-module-authoring-admit-port
        poo-flow-module-authoring-admission?
        poo-flow-module-authoring-admission-accepted?
        poo-flow-module-authoring-admission-diagnostics)

(.def ModuleAuthoringDiagnostic
  kind: 'poo-flow.module-authoring.diagnostic.v1
  module: #f
  role: #f
  code: #f
  subject: #f
  rule: #f
  recommendation: #f
  repair-operators: '()
  freedom: #f
  runtime-executed?: #f)

(.def ModuleAuthoringAdmission
  kind: 'poo-flow.module-authoring.admission.v1
  module: #f
  role: #f
  accepted?: #f
  diagnostics: '()
  runtime-executed?: #f)

(def (poo-flow-module-authoring-diagnostic-shape? value)
  (and (object? value)
       (andmap (cut .slot? value <>)
               '(kind module role code subject rule recommendation
                      repair-operators freedom runtime-executed?))
       (eq? (.ref value 'kind) 'poo-flow.module-authoring.diagnostic.v1)
       (string? (.ref value 'module))
       (symbol? (.ref value 'role))
       (symbol? (.ref value 'code))
       (symbol? (.ref value 'rule))
       (symbol? (.ref value 'recommendation))
       (list? (.ref value 'repair-operators))
       (andmap symbol? (.ref value 'repair-operators))
       (symbol? (.ref value 'freedom))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (PooFlowModuleAuthoringDiagnostic @ Type.)
  .element?: poo-flow-module-authoring-diagnostic-shape?)

(def (poo-flow-module-authoring-admission-shape? value)
  (and (object? value)
       (andmap (cut .slot? value <>)
               '(kind module role accepted? diagnostics runtime-executed?))
       (eq? (.ref value 'kind) 'poo-flow.module-authoring.admission.v1)
       (string? (.ref value 'module))
       (symbol? (.ref value 'role))
       (boolean? (.ref value 'accepted?))
       (list? (.ref value 'diagnostics))
       (andmap (cut element? PooFlowModuleAuthoringDiagnostic <>)
               (.ref value 'diagnostics))
       (eq? (.ref value 'accepted?)
            (null? (.ref value 'diagnostics)))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (PooFlowModuleAuthoringAdmission @ Type.)
  .element?: poo-flow-module-authoring-admission-shape?)

;; : (-> Symbol [Symbol] (Maybe Symbol))
(def (poo-flow-module-authoring-forbidden-slot-verb slot verbs)
  (and (symbol? slot)
       (let* ((name (symbol->string slot))
              (plain (if (string-prefix? "." name)
                       (substring name 1 (string-length name))
                       name)))
         (find (lambda (verb)
                 (string-prefix?
                  (string-append (symbol->string verb) "-")
                  plain))
               verbs))))

;; : (-> PooModuleInterface PooModuleSourceRole Symbol PooModuleAuthoringDiagnostic)
(def (poo-flow-module-authoring-slot-diagnostic interface source-role slot)
  (validate PooFlowModuleAuthoringDiagnostic
    (.o (:: @ ModuleAuthoringDiagnostic)
        module: (poo-flow-module-interface-id interface)
        role: (.ref source-role 'identity)
        code: 'poo-domain-slot-must-be-noun
        subject: slot
        rule: 'native-poo-slot-algebra-only
        recommendation: 'rename-as-domain-noun-and-refine-native-slot
        repair-operators: (.ref source-role 'repair-operators)
        freedom: (.ref source-role 'freedom))))

;; : (-> PooModuleInterface PooModuleSourceRole SchemeDatum [PooModuleAuthoringDiagnostic])
(def (poo-flow-module-authoring-slot-diagnostics interface role bindings)
  (filter-map
   (lambda (binding)
     (and (poo-flow-module-authoring-forbidden-slot-verb
           (car binding)
           (.ref role 'forbidden-slot-verbs))
          (poo-flow-module-authoring-slot-diagnostic
           interface role (car binding))))
   bindings))

;; A lazy POO slot can recurse before runtime observability has a chance to
;; report progress. Reuse the inert-source observation at the admission edge.
(def (poo-flow-module-authoring-self-reference-diagnostics interface role bindings)
  (filter-map
   (lambda (binding)
     (and (poo-flow-poo-slot-authoring-self-reference?
           (car binding) (cdr binding))
          (poo-flow-module-authoring-surface-diagnostic
           interface role
           'poo-slot-initializer-shadows-slot
           (car binding)
           'poo-slot-initializer-must-not-shadow-slot-name
           'rename-local-or-wrap-in-helper)))
   bindings))

;; : (-> SchemeDatum [Symbol] Boolean (Maybe Symbol))
;;; Walk executable child forms, but never reinterpret quoted values or import
;;; leaf symbols as calls.  This catches a hidden (.o ...) under a root
;;; composition without turning the Contract into a Scheme parser/evaluator.
(def (poo-flow-module-authoring-forbidden-root-form datum forbidden recursive?)
  (let (forbidden-form
        (lambda (candidate)
          (and (pair? candidate)
               (symbol? (car candidate))
               (memq (car candidate) forbidden)
               (car candidate))))
    (if recursive?
      (poo-flow-scheme-datum-find forbidden-form datum)
      (forbidden-form datum))))

;; : (-> PooModuleInterface PooModuleSourceRole SchemeDatum [PooModuleAuthoringDiagnostic])
(def (poo-flow-module-authoring-root-diagnostics interface source-role datum)
  (let (form
        (poo-flow-module-authoring-forbidden-root-form
         datum
         (.ref source-role 'forbidden-root-forms)
         (.ref source-role 'recursive-root-forms?)))
    (if form
      (list
       (validate PooFlowModuleAuthoringDiagnostic
         (.o (:: @ ModuleAuthoringDiagnostic)
             module: (poo-flow-module-interface-id interface)
             role: (.ref source-role 'identity)
             code: 'poo-config-must-compose-maintained-values
             subject: form
             rule: 'root-config-composition-only
             recommendation: 'move-responsibility-to-selected-profile-owner
             repair-operators: (.ref source-role 'repair-operators)
             freedom: (.ref source-role 'freedom))))
      '())))

;; : (-> SchemeDatum (Maybe Symbol))
;;; Import wrappers keep the imported module in their second position.  This
;;; reads only the native Scheme import datum; it does not expand or evaluate
;;; an alternate module language.
(def (poo-flow-module-authoring-import-module import-spec)
  (cond
   ((symbol? import-spec) import-spec)
   ((and (pair? import-spec)
         (memq (car import-spec)
               '(only-in except-in rename-in prefix-in)))
    (poo-flow-module-authoring-import-module (cadr import-spec)))
   (else #f)))

;; : (-> SchemeDatum [Symbol] (Maybe Symbol))
(def (poo-flow-module-authoring-forbidden-import datum forbidden)
  (and (pair? datum)
       (eq? (car datum) 'import)
       (any (lambda (import-spec)
              (let (module-name
                    (poo-flow-module-authoring-import-module import-spec))
                (and module-name
                     (memq module-name forbidden)
                     module-name)))
            (cdr datum))))

;; : (-> SchemeDatum [Symbol] (Maybe Symbol))
(def (poo-flow-module-authoring-forbidden-form datum forbidden)
  (poo-flow-scheme-datum-find
   (lambda (candidate)
     (and (pair? candidate)
          (symbol? (car candidate))
          (memq (car candidate) forbidden)
          (car candidate)))
   datum))

;; : (-> SchemeDatum Boolean)
(def (poo-flow-module-authoring-raw-behavior-hook? datum)
  (if (poo-flow-scheme-datum-find
       (lambda (candidate)
         (and (pair? candidate)
              (eq? (car candidate) 'lambda)
              (pair? (cdr candidate))
              (equal? (cadr candidate) '(self super))))
       datum)
    #t
    #f))

;;; Query slots are the public semantic boundary, not a place to hide a raw
;;; string/list language or an anonymous evaluator.  Provider-specific source
;;; text remains valid behind a named projection object such as `gql-source`;
;;; only slots that claim Query identity are governed here.
;; : (-> Symbol Boolean)
(def (poo-flow-module-authoring-query-slot? slot)
  (and (symbol? slot)
       (let (name (symbol->string slot))
         (or (member slot '(query queries query-predicate query-predicates))
             (string-suffix? "-query" name)
             (string-suffix? "-queries" name)))))

;; : (-> SchemeDatum Boolean)
(def (poo-flow-module-authoring-raw-query-initializer? initializer)
  (cond
   ((string? initializer) #t)
   ((not (pair? initializer)) #f)
   ((memq (car initializer) '(lambda list vector)) #t)
   ((and (memq (car initializer) '(quote quasiquote))
         (pair? (cdr initializer)))
    (let (quoted (cadr initializer))
      (or (string? quoted) (pair? quoted) (vector? quoted))))
   (else #f)))

;; : (-> PooModuleInterface PooModuleSourceRole SchemeDatum [PooModuleAuthoringDiagnostic])
(def (poo-flow-module-authoring-query-diagnostics interface role bindings)
  (if (.ref role 'forbid-raw-query-initializers?)
    (filter-map
     (lambda (binding)
       (and (poo-flow-module-authoring-query-slot? (car binding))
            (poo-flow-module-authoring-raw-query-initializer? (cdr binding))
            (poo-flow-module-authoring-surface-diagnostic
             interface role
             'poo-query-must-be-native-object
             (car binding)
             'single-poo-semantic-model
             'bind-named-poo-query-or-provider-projection)))
     bindings)
    '()))

(def (poo-flow-module-authoring-surface-diagnostic
      interface source-role code-value subject-value rule-value
      recommendation-value)
  (validate PooFlowModuleAuthoringDiagnostic
    (.o (:: @ ModuleAuthoringDiagnostic)
        module: (poo-flow-module-interface-id interface)
        role: (.ref source-role 'identity)
        code: code-value
        subject: subject-value
        rule: rule-value
        recommendation: recommendation-value
        repair-operators: (.ref source-role 'repair-operators)
        freedom: (.ref source-role 'freedom))))

;; : (-> PooModuleInterface PooModuleSourceRole SchemeDatum [PooModuleAuthoringDiagnostic])
(def (poo-flow-module-authoring-default-surface-diagnostics interface role datum)
  (let* ((forbidden-import
          (poo-flow-module-authoring-forbidden-import
           datum (.ref role 'forbidden-imports)))
         (forbidden-form
          (poo-flow-module-authoring-forbidden-form
           datum (.ref role 'forbidden-forms)))
         (raw-hook?
          (and (.ref role 'forbid-raw-behavior-hooks?)
               (poo-flow-module-authoring-raw-behavior-hook? datum))))
    (filter-map
     (lambda (rule-row)
       (and (car rule-row)
            (apply poo-flow-module-authoring-surface-diagnostic
                   interface role (cdr rule-row))))
     (list
      (list forbidden-import
            'poo-user-surface-forbids-meta-import forbidden-import
            'default-surface-meta-last
            'move-meta-extension-to-maintained-module-owner)
      (list forbidden-form
            'poo-user-surface-forbids-direct-clos forbidden-form
            'default-surface-value-first
            'select-maintained-profile-or-extension-owner)
      (list raw-hook?
            'poo-user-surface-forbids-raw-behavior-hook 'lambda
            'default-surface-behavior-on-demand
            'move-behavior-to-named-maintained-operation)))))

;; : (-> PooModuleInterface PooModuleSourceRole [PooModuleAuthoringDiagnostic] PooModuleAuthoringAdmission)
(def (poo-flow-module-authoring-admission interface source-role diagnostic-values)
  (validate PooFlowModuleAuthoringAdmission
    (.o (:: @ ModuleAuthoringAdmission)
        module: (poo-flow-module-interface-id interface)
        role: (.ref source-role 'identity)
        accepted?: (null? diagnostic-values)
        diagnostics: diagnostic-values)))

(def (poo-flow-module-authoring-admit/common interface role datum)
  (let (bindings (poo-flow-poo-slot-authoring-datum-bindings datum))
    (poo-flow-module-authoring-admission
     interface role
     (append
      (poo-flow-module-authoring-slot-diagnostics interface role bindings)
      (poo-flow-module-authoring-self-reference-diagnostics
       interface role bindings)
      (poo-flow-module-authoring-query-diagnostics interface role bindings)))))

(def (poo-flow-module-authoring-admit/config interface role datum)
  (let (bindings (poo-flow-poo-slot-authoring-datum-bindings datum))
    (poo-flow-module-authoring-admission
     interface role
     (append
      (poo-flow-module-authoring-slot-diagnostics interface role bindings)
      (poo-flow-module-authoring-self-reference-diagnostics
       interface role bindings)
      (poo-flow-module-authoring-query-diagnostics interface role bindings)
      (poo-flow-module-authoring-root-diagnostics interface role datum)
      (poo-flow-module-authoring-default-surface-diagnostics
       interface role datum)))))

;;; Executor strategy and SourceRole are independently extensible. Module
;;; packages can contribute a method bundle for a refined executor/role pair
;;; without extending a central role switch.
(def ModuleAuthoringAdmissionProtocol
  (poo-clos-generic-protocol 'module-system/authoring-admission))

(def ModuleAuthoringAdmissionGeneric
  (poo-clos-generic-function
   'module-authoring-admit 4
   protocol: ModuleAuthoringAdmissionProtocol))

(def ModuleAuthoringCommonMethod
  (poo-clos-method
   'module-authoring/common
   (list (poo-clos-prototype-specializer ModuleAuthoringExecutor.)
         (poo-clos-prototype-specializer ModuleSourceRole.)
         (poo-clos-prototype-specializer poo-flow-module-interface-prototype)
         (poo-clos-any-specializer))
   (lambda (_frame _executor role interface datum)
     (poo-flow-module-authoring-admit/common interface role datum))))

(def ModuleAuthoringConfigMethod
  (poo-clos-method
   'module-authoring/config
   (list (poo-clos-prototype-specializer ModuleAuthoringExecutor.)
         (poo-clos-prototype-specializer ConfigSourceRole.)
         (poo-clos-prototype-specializer poo-flow-module-interface-prototype)
         (poo-clos-any-specializer))
   (lambda (_frame _executor role interface datum)
     (poo-flow-module-authoring-admit/config interface role datum))))

(.defmethod-bundle ModuleAuthoringCoreMethods
  ModuleAuthoringAdmissionProtocol
  ModuleAuthoringCommonMethod
  ModuleAuthoringConfigMethod)

(poo-clos-compose-method-bundle
 ModuleAuthoringAdmissionGeneric
 ModuleAuthoringCoreMethods)

;; : (-> PooModuleInterface Symbol PooModuleSourceRole)
(def (poo-flow-module-authoring-role interface role-name)
  (unless (poo-flow-module-interface? interface)
    (error "module authoring admission requires a POO Module Interface"
           interface))
  (let (authoring (poo-flow-module-interface-authoring interface))
    (unless (.slot? authoring role-name)
      (error "module authoring Profile does not define the requested source role"
             role-name))
    (.ref authoring role-name)))

;; : (-> PooModuleInterface Symbol SchemeDatum PooModuleAuthoringAdmission)
(def (poo-flow-module-authoring-admit-datum interface role-name datum)
  (let* ((authoring (poo-flow-module-interface-authoring interface))
         (executor (.ref authoring 'executor))
         (role (poo-flow-module-authoring-role interface role-name)))
    (poo-clos-call ModuleAuthoringAdmissionGeneric
                   executor role interface datum)))

;; : (-> PooModuleInterface Symbol InputPort PooModuleAuthoringAdmission)
(def (poo-flow-module-authoring-admit-port interface role-name port)
  (poo-flow-module-authoring-admission
   interface
   (poo-flow-module-authoring-role interface role-name)
   (poo-flow-read-datums/append-map
    (lambda (datum)
      (.ref (poo-flow-module-authoring-admit-datum
             interface role-name datum)
            'diagnostics))
    port)))

(def (poo-flow-module-authoring-admission? value)
  (element? PooFlowModuleAuthoringAdmission value))

(def (poo-flow-module-authoring-admission-accepted? admission)
  (.ref admission 'accepted?))

(def (poo-flow-module-authoring-admission-diagnostics admission)
  (.ref admission 'diagnostics))
