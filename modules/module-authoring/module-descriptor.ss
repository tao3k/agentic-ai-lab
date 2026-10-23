;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Agentic AI Lab module descriptors and import closure validation.
;;; Invariant: descriptors are POO values and never load module sources.

(import :yuanxu/composition/roles
        (only-in :clan/poo/object .o .@ .ref object?)
        :yuanxu/modules/funflow/control-plane/roles
        :yuanxu/modules/funflow/control-plane/failure
        :yuanxu/object-family/role-syntax
        :yuanxu/modules/funflow/control-plane/task
        :yuanxu/modules/funflow/control-plane/flow
        :agentic-ai-lab/modules/module-authoring/module-interface
        (only-in :yuanxu/module-system/graph/funs
                 module-closure module-missing-imports)
        (only-in :yuanxu/module-system/funs
                 yuanxu-module-flags-enabled?)
        (only-in :yuanxu/object-family/syntax
                 defpoo-object-family)
        :yuanxu/module-system/source/imports
        :yuanxu/module-system/source/objects)

(export agentic-ai-lab-module-role
        agentic-ai-lab-module-descriptor-prototype
        make-agentic-ai-lab-module-descriptor/full
        make-agentic-ai-lab-module-descriptor/extended
        make-agentic-ai-lab-module-descriptor
        make-empty-agentic-ai-lab-module-descriptor
        agentic-ai-lab-module
        agentic-ai-lab-module-descriptor?
        agentic-ai-lab-module-config?
        agentic-ai-lab-modules
        agenticAiLabModules
        defagentic-ai-lab-module
        agentic-ai-lab-module-name
        yuanxu-module-imports
        agentic-ai-lab-module-task-registry
        agentic-ai-lab-module-flow-registry
        agentic-ai-lab-module-options
        agentic-ai-lab-module-interface-object
        agentic-ai-lab-module-schemas
        agentic-ai-lab-module-config
        agentic-ai-lab-module-extensions
        agentic-ai-lab-module-scripts
        agentic-ai-lab-module-metadata
        agentic-ai-lab-module-descriptor-source-ref
        agentic-ai-lab-module-group
        agentic-ai-lab-module-flags
        agentic-ai-lab-module-features
        agentic-ai-lab-module-depth
        agentic-ai-lab-module-phase-files
        agentic-ai-lab-module-hooks
        agentic-ai-lab-module-active?
        agentic-ai-lab-module-task-descriptors
        agentic-ai-lab-module-flow-descriptors
        agentic-ai-lab-module-names
        agentic-ai-lab-module-import-profile
        agentic-ai-lab-module-import-config
        agentic-ai-lab-module-import-configs
        agentic-ai-lab-module-closure
        agentic-ai-lab-module-all-task-descriptors
        agentic-ai-lab-module-all-flow-descriptors
        agentic-ai-lab-module-all-options
        agentic-ai-lab-module-missing-imports
        validate-yuanxu-module-imports)

;;; Boundary: role data anchors module descriptors in the control-plane C4 set.
;; : (-> Unit Role)
(def agentic-ai-lab-module-role
  (.o (:: @ control-plane-role)
      (name 'agentic-ai-lab-module)
      (kind 'module)
      (brand-name agentic-ai-lab-brand-name)
      (responsibility 'descriptor-bundle)
      (scheme-owner 'gerbil)
      (runtime-owner 'marlin-agent-core)
      (module-capability 'agentic-ai-lab-descriptor-activation)))

;;; Product admission is distinct from Core's pure flag query.
(def (agentic-ai-lab-module-active? descriptor . required-flags)
  (and (agentic-ai-lab-module-descriptor? descriptor)
       (yuanxu-module-flags-enabled? descriptor required-flags)))

;;; Boundary: descriptor defaults define the product module slot layout.
;;; Intent: every module surface lowers into this slot layout.
;; : (-> Unit PooModuleDescriptorPrototype)
(def agentic-ai-lab-module-descriptor-prototype
  (poo-core-role-object
   (slots ((kind 'agentic-ai-lab-module)
           (module-kind agentic-ai-lab-modules-kind)
           (brand-name agentic-ai-lab-brand-name)
           (group agentic-ai-lab-brand-group)
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
           (extension-policy 'agentic-ai-lab-module-descriptor)))
   (supers agentic-ai-lab-module-role)))

;;; Boundary: full constructor is the single descriptor slot authority.
;;; Intent: all public constructors must pass through one slot assembly point.
;;; Doom influence stays explicit in slots instead of hidden loader context.
;; : (-> ModuleName ModuleImportList TaskFamilyRegistry FlowDeclarationRegistry ModuleOptionAlist MaybeInterface ModuleSchemas ModuleConfig [ModuleExtension] [ModuleScript] ModuleMetadata MaybeSourceRef ModuleGroup [ModuleFlag] [ModuleFeature] ModuleDepth ModulePhaseFiles ModuleHooks PooModuleDescriptor)
(def (make-agentic-ai-lab-module-descriptor/full
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
           (module-kind agentic-ai-lab-modules-kind)
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
            (list 'agentic-ai-lab-module module-name))))
   (supers agentic-ai-lab-module-descriptor-prototype)))

;;; Boundary: extended constructor keeps Marlin migration call sites stable.
;; : (-> ModuleName ModuleImportList TaskFamilyRegistry FlowDeclarationRegistry ModuleOptionAlist MaybeInterface ModuleSchemas ModuleConfig [ModuleExtension] [ModuleScript] ModuleMetadata MaybeSourceRef PooModuleDescriptor)
(def (make-agentic-ai-lab-module-descriptor/extended
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
  (make-agentic-ai-lab-module-descriptor/full
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
   agentic-ai-lab-brand-group
   '()
   '()
   (cons 0 0)
   '()
   '()))

;;; Sparse constructors keep older tests and module rows from repeating the
;;; empty interface/schema/script defaults owned by the extended constructor.
;; : (-> ModuleName ModuleImportList TaskFamilyRegistry FlowDeclarationRegistry ModuleOptionAlist PooModuleDescriptor)
(def (make-agentic-ai-lab-module-descriptor module-name module-imports task-registry flow-registry options)
  (make-agentic-ai-lab-module-descriptor/extended
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
(def (make-empty-agentic-ai-lab-module-descriptor module-name module-imports options)
  (make-agentic-ai-lab-module-descriptor
   module-name
   module-imports
   (make-task-family-registry module-name '())
   (make-flow-declaration-registry module-name '())
   options))

;;; Boundary: Marlin-style facade lowers sparse user config into a POO descriptor.
;;; Intent: preserve Marlin's interface/config split without importing its runtime.
;; : (-> PooModuleInterface POOObject PooModuleDescriptor)
(def (agentic-ai-lab-modules interface module-config)
  (let* ((config-values
          ;; Config may be supplied under Marlin's `config` slot or as option data.
          (yuanxu-module-object-ref/default
           module-config
           'config
           (yuanxu-module-object-ref/default module-config 'options (.o))))
         (module-id-value
          ;; Missing ids inherit the interface id so sparse configs stay valid.
          (yuanxu-module-object-ref/default
           module-config
           'id
           (yuanxu-module-interface-id interface)))
         (module-imports
          (yuanxu-module-object-ref/default module-config 'imports '()))
         (module-extensions
          (yuanxu-module-object-ref/default module-config 'extensions '()))
         (module-scripts
          (yuanxu-module-object-ref/default module-config 'scripts '()))
         (module-metadata
          (yuanxu-module-object-ref/default
           module-config
           'metadata
           (yuanxu-module-interface-metadata interface)))
         (module-source-ref
          (yuanxu-module-object-ref/default module-config 'source-ref #f))
         (module-group
          (yuanxu-module-object-ref/default
           module-config
           'group
           agentic-ai-lab-brand-group))
         (module-flags
          (yuanxu-module-object-ref/default module-config 'flags '()))
         (module-features
          (yuanxu-module-object-ref/default module-config 'features '()))
         (module-depth
          (yuanxu-module-object-ref/default module-config 'depth (cons 0 0)))
         (module-phase-files
          (yuanxu-module-object->alist
           (yuanxu-module-object-ref/default module-config 'phase-files '())))
         (module-hooks
          (yuanxu-module-object->alist
           (yuanxu-module-object-ref/default module-config 'hooks '()))))
    (make-agentic-ai-lab-module-descriptor/full
     module-id-value
     module-imports
     (make-task-family-registry module-id-value '())
     (make-flow-declaration-registry module-id-value '())
     (yuanxu-module-object->alist config-values)
     interface
     (yuanxu-module-interface-schemas interface)
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
(def (agenticAiLabModules interface module-config)
  (agentic-ai-lab-modules interface module-config))

;; : (-> ModuleDescriptorCandidate Boolean)
(def (agentic-ai-lab-module-config? value)
  (agentic-ai-lab-module-descriptor? value))

;;; Boundary:
;;; - defagentic-ai-lab-module is constructor sugar around POO descriptor values.
;;; - Expansion must not load files, query registries, or capture phase state.
;;; - The generated descriptor slots remain the facade-test source witnesses.
;; | type DefPooModuleBinding = Symbol
;; | type DefPooModuleClause = MacroClause
;; defagentic-ai-lab-module
;;   : (-> DefPooModuleBinding PooModuleInterface DefPooModuleClause... PooModuleDescriptor)
;;   | contract: expands a named interface/config declaration to a POO descriptor
;;   | warning: expansion forwards syntax into constructors and stays activation-free
;;   | doc m%
;;       `defagentic-ai-lab-module` defines `binding` as the descriptor built from an
;;       interface and a literal module configuration shape.
;;       # Examples
;;       ```scheme
;;       (defagentic-ai-lab-module demo iface (id 'demo) (imports) (config (.o)) (extensions) (scripts))
;;       ;; => demo
;;       ```
;;     %
(defrules defagentic-ai-lab-module ()
  ((_ binding
      interface
      (id module-id)
      (imports import-value ...)
      (config config-object)
      (extensions extension-value ...)
      (scripts script-value ...)
      (metadata metadata-value))
   (def binding
     (agenticAiLabModules
      interface
      (.o id: module-id
          imports: (yuanxu-imports import-value ...)
          config: config-object
          extensions: (yuanxu-extensions extension-value ...)
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
     (agenticAiLabModules
      interface
      (.o id: module-id
          imports: (yuanxu-imports import-value ...)
          config: config-object
          extensions: (yuanxu-extensions extension-value ...)
          scripts: (list script-value ...)
          metadata: (yuanxu-module-interface-metadata interface))))))

;;; Boundary:
;;; - agentic-ai-lab-module preserves the registry-oriented descriptor constructor surface.
;;; - The macro lowers clauses to one descriptor and never activates a module.
;;; - Registry inputs stay data so the loader/resolver boundary remains outside.
;; | type PooModuleImportClause = (Tuple 'imports ModuleImportValue...)
;; | type PooModuleTaskClause = (Tuple 'tasks TaskFamilyDescriptor...)
;; | type PooModuleFlowClause = (Tuple 'flows FlowDeclarationDescriptor...)
;; | type PooModuleOptionClause = (Tuple 'options ModuleOption...)
;; agentic-ai-lab-module
;;   : (-> ModuleName PooModuleImportClause PooModuleTaskClause PooModuleFlowClause PooModuleOptionClause PooModuleDescriptor)
;;   | contract: expands task and flow registry clauses to one descriptor value
;;   | warning: expansion is constructor sugar only and must stay activation-free
;;   | doc m%
;;       `agentic-ai-lab-module` returns a descriptor for `module-name` from explicit
;;       import, task, flow, and option clauses.
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-module demo (imports) (tasks task-descriptor) (flows flow-descriptor) (options))
;;       ;; => PooModuleDescriptor
;;       ```
;;     %
(defrules agentic-ai-lab-module (imports tasks flows options)
  ((_ module-name
      (imports import ...)
      (tasks task-descriptor ...)
      (flows flow-descriptor ...)
      (options option ...))
   (make-agentic-ai-lab-module-descriptor
    'module-name
    '(import ...)
    (make-task-family-registry 'module-name (list task-descriptor ...))
    (make-flow-declaration-registry 'module-name (list flow-descriptor ...))
    (list option ...))))

;;; Boundary: descriptor predicate is slot-based to allow future C4 variants.
;; : (-> PooModuleDescriptorCandidate Boolean)
(def (agentic-ai-lab-module-descriptor? descriptor)
  (and (object? descriptor)
       (eq? (.@ descriptor kind) 'agentic-ai-lab-module)))

;;; Boundary: accessors expose descriptor slots without reinterpreting values.
(defpoo-object-family
  (reader .@)
  (accessors
   (agentic-ai-lab-module-name name)
   (yuanxu-module-imports imports)
   (agentic-ai-lab-module-task-registry task-registry)
   (agentic-ai-lab-module-flow-registry flow-registry)
   (agentic-ai-lab-module-options options)
   (agentic-ai-lab-module-interface-object interface)
   (agentic-ai-lab-module-schemas schemas)
   (agentic-ai-lab-module-config config)
   (agentic-ai-lab-module-extensions extensions)
   (agentic-ai-lab-module-scripts scripts)
   (agentic-ai-lab-module-metadata metadata)
   (agentic-ai-lab-module-descriptor-source-ref source-ref)
   (agentic-ai-lab-module-group group)
   (agentic-ai-lab-module-flags flags)
   (agentic-ai-lab-module-features features)
   (agentic-ai-lab-module-depth depth)
   (agentic-ai-lab-module-phase-files phase-files)
   (agentic-ai-lab-module-hooks hooks)))

;;; Boundary: task descriptors are already normalized inside registries.
;; : (-> PooModuleDescriptor [TaskFamilyDescriptor])
(def (agentic-ai-lab-module-task-descriptors descriptor)
  (task-family-registry-descriptors (agentic-ai-lab-module-task-registry descriptor)))

;;; Boundary: flow descriptors are already normalized inside registries.
;; : (-> PooModuleDescriptor [FlowDeclarationDescriptor])
(def (agentic-ai-lab-module-flow-descriptors descriptor)
  (flow-declaration-registry-descriptors (agentic-ai-lab-module-flow-registry descriptor)))

;;; Boundary: module name projection preserves activation order.
;; : (-> [PooModuleDescriptor] [Symbol])
(def (agentic-ai-lab-module-names modules)
  (map agentic-ai-lab-module-name modules))

;;; Boundary: import profiles can be descriptor values or closed-world names.
;; : (-> ModuleImportValue ModuleImportProfile)
(def (agentic-ai-lab-module-import-profile import-value)
  (if (yuanxu-import? import-value)
    (.ref import-value 'profile)
    import-value))

;;; Boundary: module import config is the policy-visible edge for module-system
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> ModuleImportValue MaybePooModuleDescriptor)
(def (agentic-ai-lab-module-import-config import-value)
  (let (profile (agentic-ai-lab-module-import-profile import-value))
    (if (agentic-ai-lab-module-config? profile)
      profile
      #f)))

;; : (-> ModuleImportValue Boolean)
(def (agentic-ai-lab-module-named-import? import-value)
  (let (profile (agentic-ai-lab-module-import-profile import-value))
    (or (symbol? profile)
        (string? profile))))

;;; Boundary: module import name is the policy-visible edge for module-system
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> ModuleImportValue ModuleName)
(def (agentic-ai-lab-module-import-name import-value)
  (let (profile (agentic-ai-lab-module-import-profile import-value))
    (if (agentic-ai-lab-module-config? profile)
      (agentic-ai-lab-module-name profile)
      profile)))

;;; Boundary: import-configs keeps only descriptor profiles from import rows.
;;; Invariant: only descriptor profiles enter the closure list.
;;; Runtime imports remain payloads for the later resolver stage.
;;; Names, paths, and runtime payloads are intentionally dropped from the closure list.
;; : (-> [Value] [PooModuleDescriptor] [PooModuleDescriptor])
(def (agentic-ai-lab-module-import-configs/rev imports configs-rev)
  (cond
   ((null? imports) configs-rev)
   ((agentic-ai-lab-module-import-config (car imports))
    => (lambda (module)
         (agentic-ai-lab-module-import-configs/rev
          (cdr imports)
          (cons module configs-rev))))
   (else
    (agentic-ai-lab-module-import-configs/rev (cdr imports) configs-rev))))

;; : (-> [Value] [PooModuleDescriptor])
(def (agentic-ai-lab-module-import-configs imports)
  (reverse (agentic-ai-lab-module-import-configs/rev imports '())))

;;; Core owns the ordered DFS and closed-world lookup. Agentic AI Lab supplies only
;;; descriptor projections and source import interpretation.
(def (agentic-ai-lab-module-closure modules)
  (module-closure
   modules
   agentic-ai-lab-module-name
   (lambda (module)
     (agentic-ai-lab-module-import-configs (yuanxu-module-imports module)))))

(def (agentic-ai-lab-module-missing-imports modules)
  (module-missing-imports
   (agentic-ai-lab-module-closure modules)
   agentic-ai-lab-module-name
   yuanxu-module-imports
   agentic-ai-lab-module-named-import?
   agentic-ai-lab-module-import-name))

;;; Boundary: activation may only proceed after closed-world imports validate.
;; : (-> [PooModuleDescriptor] Boolean)
(def (validate-yuanxu-module-imports modules)
  (let ((missing (agentic-ai-lab-module-missing-imports modules)))
    (if (null? missing)
      #t
      (raise-control-plane-failure
       'module-system
       'missing-module-imports
       "agentic-ai-lab module activation has missing imports"
       (list (cons 'missing missing))))))

;;; Boundary: aggregation is append-only; conflict policy belongs to diagnostics.
;;; Boundary: module all task descriptors is the policy-visible edge for
;;; module-system behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> [PooModuleDescriptor] [TaskFamilyDescriptor])
(def (agentic-ai-lab-module-all-task-descriptors modules)
  (foldr append '() (map agentic-ai-lab-module-task-descriptors modules)))

;;; Boundary: flow aggregation mirrors task aggregation order.
;; : (-> [PooModuleDescriptor] [FlowDeclarationDescriptor])
(def (agentic-ai-lab-module-all-flow-descriptors modules)
  (foldr append '() (map agentic-ai-lab-module-flow-descriptors modules)))

;;; Boundary: option projections stay at the config/run-config edge.
;; : (-> [PooModuleDescriptor] ModuleOptionAlist)
(def (agentic-ai-lab-module-all-options modules)
  (foldr append '() (map agentic-ai-lab-module-options modules)))
