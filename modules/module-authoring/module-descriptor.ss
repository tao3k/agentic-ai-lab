;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO Flow module descriptors and import closure validation.
;;; Invariant: descriptors are POO values and never load module sources.

(import :core/composition/roles
        (only-in :clan/poo/object .o .@ .ref object?)
        :poo-flow/modules/workflow/control-plane/roles
        :poo-flow/modules/workflow/control-plane/failure
        :core/object-family/role-syntax
        :poo-flow/modules/workflow/control-plane/task
        :poo-flow/modules/workflow/control-plane/flow
        :poo-flow/modules/module-authoring/module-interface
        (only-in :core/module-system/graph/funs
                 module-closure module-missing-imports)
        (only-in :core/module-system/funs
                 poo-flow-module-flags-enabled?)
        (only-in :core/object-family/syntax
                 defpoo-object-family)
        :core/module-system/source/imports
        :core/module-system/source/objects)

(export poo-flow-module-role
        poo-flow-module-descriptor-prototype
        make-poo-flow-module-descriptor/full
        make-poo-flow-module-descriptor/extended
        make-poo-flow-module-descriptor
        make-empty-poo-flow-module-descriptor
        poo-flow-module
        poo-flow-module-descriptor?
        poo-flow-module-config?
        poo-flow-modules
        pooFlowModules
        defpoo-flow-module
        poo-flow-module-name
        poo-flow-module-imports
        poo-flow-module-task-registry
        poo-flow-module-flow-registry
        poo-flow-module-options
        poo-flow-module-interface-object
        poo-flow-module-schemas
        poo-flow-module-config
        poo-flow-module-extensions
        poo-flow-module-scripts
        poo-flow-module-metadata
        poo-flow-module-descriptor-source-ref
        poo-flow-module-group
        poo-flow-module-flags
        poo-flow-module-features
        poo-flow-module-depth
        poo-flow-module-phase-files
        poo-flow-module-hooks
        poo-flow-module-active?
        poo-flow-module-task-descriptors
        poo-flow-module-flow-descriptors
        poo-flow-module-names
        poo-flow-module-import-profile
        poo-flow-module-import-config
        poo-flow-module-import-configs
        poo-flow-module-closure
        poo-flow-module-all-task-descriptors
        poo-flow-module-all-flow-descriptors
        poo-flow-module-all-options
        poo-flow-module-missing-imports
        validate-poo-flow-module-imports)

;;; Boundary: role data anchors module descriptors in the control-plane C4 set.
;; : (-> Unit Role)
(def poo-flow-module-role
  (.o (:: @ control-plane-role)
      (name 'poo-flow-module)
      (kind 'module)
      (brand-name poo-flow-brand-name)
      (responsibility 'descriptor-bundle)
      (scheme-owner 'gerbil)
      (runtime-owner 'marlin-agent-core)
      (module-capability 'poo-flow-descriptor-activation)))

;;; Product admission is distinct from Core's pure flag query.
(def (poo-flow-module-active? descriptor . required-flags)
  (and (poo-flow-module-descriptor? descriptor)
       (poo-flow-module-flags-enabled? descriptor required-flags)))

;;; Boundary: descriptor defaults define the product module slot layout.
;;; Intent: every module surface lowers into this slot layout.
;; : (-> Unit PooModuleDescriptorPrototype)
(def poo-flow-module-descriptor-prototype
  (poo-core-role-object
   (slots ((kind 'poo-flow-module)
           (module-kind poo-flow-modules-kind)
           (brand-name poo-flow-brand-name)
           (group poo-flow-brand-group)
           (interface #f)
           (imports '())
           (extensions '())
           (scripts '())
           (flags '())
           (features '())
           (depth (cons 0 0))
           (phase-files '())
           (hooks '())
           (task-registry
            (make-task-family-registry 'empty-module-task-families '()))
           (flow-registry
            (make-flow-declaration-registry 'empty-module-flow-declarations '()))
           (options '())
           (config (.o))
           (schemas (.o))
           (metadata '())
           (source-ref #f)
           (extension-policy 'poo-flow-module-descriptor)))
   (supers poo-flow-module-role)))

;;; Boundary: full constructor is the single descriptor slot authority.
;;; Intent: all public constructors must pass through one slot assembly point.
;;; Doom influence stays explicit in slots instead of hidden loader context.
;; : (-> ModuleName ModuleImportList TaskFamilyRegistry FlowDeclarationRegistry ModuleOptionAlist MaybeInterface ModuleSchemas ModuleConfig [ModuleExtension] [ModuleScript] ModuleMetadata MaybeSourceRef ModuleGroup [ModuleFlag] [ModuleFeature] ModuleDepth ModulePhaseFiles ModuleHooks PooModuleDescriptor)
(def (make-poo-flow-module-descriptor/full
      module-name
      module-imports
      task-registry
      flow-registry
      options
      interface
      schemas
      config
      extensions
      scripts
      metadata
      source-ref
      group
      flags
      features
      depth
      phase-files
      hooks)
  (poo-core-role-object
   (slots ((name module-name)
           (module-kind poo-flow-modules-kind)
           (group group)
           (interface interface)
           (imports module-imports)
           (extensions extensions)
           (scripts scripts)
           (flags flags)
           (features features)
           (depth depth)
           (phase-files phase-files)
           (hooks hooks)
           (task-registry task-registry)
           (flow-registry flow-registry)
           (options options)
           (config config)
           (schemas schemas)
           (metadata metadata)
           (source-ref source-ref)
           (responsibility
            (list 'poo-flow-module module-name))))
   (supers poo-flow-module-descriptor-prototype)))

;;; Boundary: extended constructor keeps Marlin migration call sites stable.
;; : (-> ModuleName ModuleImportList TaskFamilyRegistry FlowDeclarationRegistry ModuleOptionAlist MaybeInterface ModuleSchemas ModuleConfig [ModuleExtension] [ModuleScript] ModuleMetadata MaybeSourceRef PooModuleDescriptor)
(def (make-poo-flow-module-descriptor/extended
      module-name
      module-imports
      task-registry
      flow-registry
      options
      interface
      schemas
      config
      extensions
      scripts
      metadata
      source-ref)
  (make-poo-flow-module-descriptor/full
   module-name
   module-imports
   task-registry
   flow-registry
   options
   interface
   schemas
   config
   extensions
   scripts
   metadata
   source-ref
   poo-flow-brand-group
   '()
   '()
   (cons 0 0)
   '()
   '()))

;;; Sparse constructors keep older tests and module rows from repeating the
;;; empty interface/schema/script defaults owned by the extended constructor.
;; : (-> ModuleName ModuleImportList TaskFamilyRegistry FlowDeclarationRegistry ModuleOptionAlist PooModuleDescriptor)
(def (make-poo-flow-module-descriptor module-name module-imports task-registry flow-registry options)
  (make-poo-flow-module-descriptor/extended
   module-name
   module-imports
   task-registry
   flow-registry
   options
   #f
   (.o)
   (.o)
   '()
   '()
   '()
   #f))

;; : (-> ModuleName ModuleImportList ModuleOptionAlist PooModuleDescriptor)
(def (make-empty-poo-flow-module-descriptor module-name module-imports options)
  (make-poo-flow-module-descriptor
   module-name
   module-imports
   (make-task-family-registry module-name '())
   (make-flow-declaration-registry module-name '())
   options))

;;; Boundary: Marlin-style facade lowers sparse user config into a POO descriptor.
;;; Intent: preserve Marlin's interface/config split without importing its runtime.
;; : (-> PooModuleInterface POOObject PooModuleDescriptor)
(def (poo-flow-modules interface module-config)
  (let* ((config-values
          ;; Config may be supplied under Marlin's `config` slot or as option data.
          (poo-flow-module-object-ref/default
           module-config
           'config
           (poo-flow-module-object-ref/default module-config 'options (.o))))
         (module-id-value
          ;; Missing ids inherit the interface id so sparse configs stay valid.
          (poo-flow-module-object-ref/default
           module-config
           'id
           (poo-flow-module-interface-id interface)))
         (module-imports
          (poo-flow-module-object-ref/default module-config 'imports '()))
         (module-extensions
          (poo-flow-module-object-ref/default module-config 'extensions '()))
         (module-scripts
          (poo-flow-module-object-ref/default module-config 'scripts '()))
         (module-metadata
          (poo-flow-module-object-ref/default
           module-config
           'metadata
           (poo-flow-module-interface-metadata interface)))
         (module-source-ref
          (poo-flow-module-object-ref/default module-config 'source-ref #f))
         (module-group
          (poo-flow-module-object-ref/default
           module-config
           'group
           poo-flow-brand-group))
         (module-flags
          (poo-flow-module-object-ref/default module-config 'flags '()))
         (module-features
          (poo-flow-module-object-ref/default module-config 'features '()))
         (module-depth
          (poo-flow-module-object-ref/default module-config 'depth (cons 0 0)))
         (module-phase-files
          (poo-flow-module-object->alist
           (poo-flow-module-object-ref/default module-config 'phase-files '())))
         (module-hooks
          (poo-flow-module-object->alist
           (poo-flow-module-object-ref/default module-config 'hooks '()))))
    (make-poo-flow-module-descriptor/full
     module-id-value
     module-imports
     (make-task-family-registry module-id-value '())
     (make-flow-declaration-registry module-id-value '())
     (poo-flow-module-object->alist config-values)
     interface
     (poo-flow-module-interface-schemas interface)
     config-values
     module-extensions
     module-scripts
     module-metadata
     module-source-ref
     module-group
     module-flags
     module-features
     module-depth
     module-phase-files
     module-hooks)))

;; : (-> PooModuleInterface POOObject PooModuleDescriptor)
(def (pooFlowModules interface module-config)
  (poo-flow-modules interface module-config))

;; : (-> ModuleDescriptorCandidate Boolean)
(def (poo-flow-module-config? value)
  (poo-flow-module-descriptor? value))

;;; Boundary:
;;; - defpoo-flow-module is constructor sugar around POO descriptor values.
;;; - Expansion must not load files, query registries, or capture phase state.
;;; - The generated descriptor slots remain the facade-test source witnesses.
;; | type DefPooModuleBinding = Symbol
;; | type DefPooModuleClause = MacroClause
;; defpoo-flow-module
;;   : (-> DefPooModuleBinding PooModuleInterface DefPooModuleClause... PooModuleDescriptor)
;;   | contract: expands a named interface/config declaration to a POO descriptor
;;   | warning: expansion forwards syntax into constructors and stays activation-free
;;   | doc m%
;;       `defpoo-flow-module` defines `binding` as the descriptor built from an
;;       interface and a literal module configuration shape.
;;       # Examples
;;       ```scheme
;;       (defpoo-flow-module demo iface (id 'demo) (imports) (config (.o)) (extensions) (scripts))
;;       ;; => demo
;;       ```
;;     %
(defrules defpoo-flow-module ()
  ((_ binding
      interface
      (id module-id)
      (imports import-value ...)
      (config config-object)
      (extensions extension-value ...)
      (scripts script-value ...)
      (metadata metadata-value))
   (def binding
     (pooFlowModules
      interface
      (.o id: module-id
          imports: (poo-flow-imports import-value ...)
          config: config-object
          extensions: (poo-flow-extensions extension-value ...)
          scripts: (list script-value ...)
          metadata: metadata-value))))
  ((_ binding
      interface
      (id module-id)
      (imports import-value ...)
      (config config-object)
      (extensions extension-value ...)
      (scripts script-value ...))
   (def binding
     (pooFlowModules
      interface
      (.o id: module-id
          imports: (poo-flow-imports import-value ...)
          config: config-object
          extensions: (poo-flow-extensions extension-value ...)
          scripts: (list script-value ...)
          metadata: (poo-flow-module-interface-metadata interface))))))

;;; Boundary:
;;; - poo-flow-module preserves the registry-oriented descriptor constructor surface.
;;; - The macro lowers clauses to one descriptor and never activates a module.
;;; - Registry inputs stay data so the loader/resolver boundary remains outside.
;; | type PooModuleImportClause = (Tuple 'imports ModuleImportValue...)
;; | type PooModuleTaskClause = (Tuple 'tasks TaskFamilyDescriptor...)
;; | type PooModuleFlowClause = (Tuple 'flows FlowDeclarationDescriptor...)
;; | type PooModuleOptionClause = (Tuple 'options ModuleOption...)
;; poo-flow-module
;;   : (-> ModuleName PooModuleImportClause PooModuleTaskClause PooModuleFlowClause PooModuleOptionClause PooModuleDescriptor)
;;   | contract: expands task and flow registry clauses to one descriptor value
;;   | warning: expansion is constructor sugar only and must stay activation-free
;;   | doc m%
;;       `poo-flow-module` returns a descriptor for `module-name` from explicit
;;       import, task, flow, and option clauses.
;;       # Examples
;;       ```scheme
;;       (poo-flow-module demo (imports) (tasks task-descriptor) (flows flow-descriptor) (options))
;;       ;; => PooModuleDescriptor
;;       ```
;;     %
(defrules poo-flow-module (imports tasks flows options)
  ((_ module-name
      (imports import ...)
      (tasks task-descriptor ...)
      (flows flow-descriptor ...)
      (options option ...))
   (make-poo-flow-module-descriptor
    'module-name
    '(import ...)
    (make-task-family-registry 'module-name (list task-descriptor ...))
    (make-flow-declaration-registry 'module-name (list flow-descriptor ...))
    (list option ...))))

;;; Boundary: descriptor predicate is slot-based to allow future C4 variants.
;; : (-> PooModuleDescriptorCandidate Boolean)
(def (poo-flow-module-descriptor? descriptor)
  (and (object? descriptor)
       (eq? (.@ descriptor kind) 'poo-flow-module)))

;;; Boundary: accessors expose descriptor slots without reinterpreting values.
(defpoo-object-family
  (reader .@)
  (accessors
   (poo-flow-module-name name)
   (poo-flow-module-imports imports)
   (poo-flow-module-task-registry task-registry)
   (poo-flow-module-flow-registry flow-registry)
   (poo-flow-module-options options)
   (poo-flow-module-interface-object interface)
   (poo-flow-module-schemas schemas)
   (poo-flow-module-config config)
   (poo-flow-module-extensions extensions)
   (poo-flow-module-scripts scripts)
   (poo-flow-module-metadata metadata)
   (poo-flow-module-descriptor-source-ref source-ref)
   (poo-flow-module-group group)
   (poo-flow-module-flags flags)
   (poo-flow-module-features features)
   (poo-flow-module-depth depth)
   (poo-flow-module-phase-files phase-files)
   (poo-flow-module-hooks hooks)))

;;; Boundary: task descriptors are already normalized inside registries.
;; : (-> PooModuleDescriptor [TaskFamilyDescriptor])
(def (poo-flow-module-task-descriptors descriptor)
  (task-family-registry-descriptors (poo-flow-module-task-registry descriptor)))

;;; Boundary: flow descriptors are already normalized inside registries.
;; : (-> PooModuleDescriptor [FlowDeclarationDescriptor])
(def (poo-flow-module-flow-descriptors descriptor)
  (flow-declaration-registry-descriptors (poo-flow-module-flow-registry descriptor)))

;;; Boundary: module name projection preserves activation order.
;; : (-> [PooModuleDescriptor] [Symbol])
(def (poo-flow-module-names modules)
  (map poo-flow-module-name modules))

;;; Boundary: import profiles can be descriptor values or closed-world names.
;; : (-> ModuleImportValue ModuleImportProfile)
(def (poo-flow-module-import-profile import-value)
  (if (poo-flow-import? import-value)
    (.ref import-value 'profile)
    import-value))

;;; Boundary: module import config is the policy-visible edge for module-system
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> ModuleImportValue MaybePooModuleDescriptor)
(def (poo-flow-module-import-config import-value)
  (let (profile (poo-flow-module-import-profile import-value))
    (if (poo-flow-module-config? profile)
      profile
      #f)))

;; : (-> ModuleImportValue Boolean)
(def (poo-flow-module-named-import? import-value)
  (let (profile (poo-flow-module-import-profile import-value))
    (or (symbol? profile)
        (string? profile))))

;;; Boundary: module import name is the policy-visible edge for module-system
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> ModuleImportValue ModuleName)
(def (poo-flow-module-import-name import-value)
  (let (profile (poo-flow-module-import-profile import-value))
    (if (poo-flow-module-config? profile)
      (poo-flow-module-name profile)
      profile)))

;;; Boundary: import-configs keeps only descriptor profiles from import rows.
;;; Invariant: only descriptor profiles enter the closure list.
;;; Runtime imports remain payloads for the later resolver stage.
;;; Names, paths, and runtime payloads are intentionally dropped from the closure list.
;; : (-> [Value] [PooModuleDescriptor] [PooModuleDescriptor])
(def (poo-flow-module-import-configs/rev imports configs-rev)
  (cond
   ((null? imports) configs-rev)
   ((poo-flow-module-import-config (car imports))
    => (lambda (module)
         (poo-flow-module-import-configs/rev
          (cdr imports)
          (cons module configs-rev))))
   (else
    (poo-flow-module-import-configs/rev (cdr imports) configs-rev))))

;; : (-> [Value] [PooModuleDescriptor])
(def (poo-flow-module-import-configs imports)
  (reverse (poo-flow-module-import-configs/rev imports '())))

;;; Core owns the ordered DFS and closed-world lookup. POO Flow supplies only
;;; descriptor projections and source import interpretation.
(def (poo-flow-module-closure modules)
  (module-closure
   modules
   poo-flow-module-name
   (lambda (module)
     (poo-flow-module-import-configs (poo-flow-module-imports module)))))

(def (poo-flow-module-missing-imports modules)
  (module-missing-imports
   (poo-flow-module-closure modules)
   poo-flow-module-name
   poo-flow-module-imports
   poo-flow-module-named-import?
   poo-flow-module-import-name))

;;; Boundary: activation may only proceed after closed-world imports validate.
;; : (-> [PooModuleDescriptor] Boolean)
(def (validate-poo-flow-module-imports modules)
  (let ((missing (poo-flow-module-missing-imports modules)))
    (if (null? missing)
      #t
      (raise-control-plane-failure
       'module-system
       'missing-module-imports
       "poo-flow module activation has missing imports"
       (list (cons 'missing missing))))))

;;; Boundary: aggregation is append-only; conflict policy belongs to diagnostics.
;;; Boundary: module all task descriptors is the policy-visible edge for
;;; module-system behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> [PooModuleDescriptor] [TaskFamilyDescriptor])
(def (poo-flow-module-all-task-descriptors modules)
  (foldr append '() (map poo-flow-module-task-descriptors modules)))

;;; Boundary: flow aggregation mirrors task aggregation order.
;; : (-> [PooModuleDescriptor] [FlowDeclarationDescriptor])
(def (poo-flow-module-all-flow-descriptors modules)
  (foldr append '() (map poo-flow-module-flow-descriptors modules)))

;;; Boundary: option projections stay at the config/run-config edge.
;; : (-> [PooModuleDescriptor] ModuleOptionAlist)
(def (poo-flow-module-all-options modules)
  (foldr append '() (map poo-flow-module-options modules)))
