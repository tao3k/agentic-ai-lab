(import (only-in :agentic-ai-lab/modules/workflow/funflow-config agentic-ai-lab-funflow-configs agentic-ai-lab-funflow-poo-config-flags))
;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: init/profile declaration syntax lives outside core profile data.
;;; Invariant: macros expand to profile-config data and never realize descriptors.

(import (only-in :clan/poo/object .o object<-alist)
        :agentic-ai-lab/modules/module-authoring/fragment-syntax
        :agentic-ai-lab/modules/module-authoring/module-config-syntax
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-user-module-selection-flag-entry
                 yuanxu-user-module-selection->alist)
        :yuanxu/module-system/observability/presentation
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/interface
        :agentic-ai-lab/modules/cubeSandbox/config
        :agentic-ai-lab/modules/cubeSandbox/profile-interface
        :agentic-ai-lab/modules/docker-sandbox/config
        :agentic-ai-lab/modules/docker-sandbox/profile-interface
        :yuanxu/modules/funflow/graph-projection
        :agentic-ai-lab/modules/session/config
        :agentic-ai-lab/modules/session/syntax
        :agentic-ai-lab/modules/tool-core/config
        :agentic-ai-lab/modules/nono-sandbox/config
        :agentic-ai-lab/modules/nono-sandbox/profile-interface
        :agentic-ai-lab/modules/loop-engine/control/spec-evolution
        (only-in :agentic-ai-lab/modules/loop-engine/config
                 agentic-ai-lab-loop-engine-configs
                 agentic-ai-lab-user-loop-engine-poo-config-flags)
        (only-in :agentic-ai-lab/modules/loop-engine/prototypes
                 loop-engine-use-case
                 loop-engine-governor
                 loop-engine-agent-judges
                 loop-engine-human-audit
                 loop-engine-schedule
                 loop-engine-state
                 loop-engine-sandbox
                 loop-engine-budget
                 loop-engine-result
                 loop-engine-observability
                 loop-engine-runtime
                 loop-engine-lineage-policy
                 loop-engine-selector-policy
                 loop-engine-resource-policy
                 loop-engine-capability-policy
                 loop-engine-memory-policy
                 loop-engine-compression-policy
                 loop-engine-profile)
        (only-in :agentic-ai-lab/modules/loop-engine/policy-extension
                 loop-engine-policy-extension
                 loop-engine-coordination-policy-extension
                 loop-engine-observability-policy-extension
                 loop-engine-safety-policy-extension)
        :agentic-ai-lab/modules/sandbox-core/profile
        :agentic-ai-lab/modules/sandbox-core/profile-interface
        :yuanxu/module-system/selection/init-syntax
        :agentic-ai-lab/modules/workflow/scenario/configuration/profile-config
        :yuanxu/module-system/selection/syntax
        :yuanxu/module-system/selection/contract
        :agentic-ai-lab/modules/ai-agentic-context/selection-adapter)

(export agentic-ai-lab-module-bundles
        (import: :yuanxu/module-system/selection/syntax)
        agentic-ai-lab-custom-module-bundles
        agentic-ai-lab-init-module-bundles
        use-module
        agentic-ai-lab-module-configs
        (import: :agentic-ai-lab/modules/module-authoring/fragment-syntax)
        (import: :yuanxu/module-system/selection/init-syntax)
        agentic-ai-lab-profile-set
        agentic-ai-lab-profile-extend
        agentic-ai-lab-profile
        yuanxu-user-module-selection-flag-entry
        yuanxu-user-module-selection->alist
        (import: :agentic-ai-lab/modules/cubeSandbox/profile-interface)
        (import: :agentic-ai-lab/modules/docker-sandbox/profile-interface)
        (import: :yuanxu/modules/funflow/graph-projection)
        (import: :agentic-ai-lab/modules/workflow/funflow-config)
        (import: :agentic-ai-lab/modules/ai-agentic-context/features/memory/interface)
        (import: :agentic-ai-lab/modules/session/config)
        (import: :agentic-ai-lab/modules/session/syntax)
        (import: :agentic-ai-lab/modules/tool-core/config)
        (import: :agentic-ai-lab/modules/loop-engine/control/spec-evolution)
        loop-engine-use-case
        loop-engine-governor
        loop-engine-agent-judges
        loop-engine-human-audit
        loop-engine-schedule
        loop-engine-state
        loop-engine-sandbox
        loop-engine-budget
        loop-engine-result
        loop-engine-observability
        loop-engine-runtime
        loop-engine-lineage-policy
        loop-engine-selector-policy
        loop-engine-resource-policy
        loop-engine-capability-policy
        loop-engine-memory-policy
        loop-engine-compression-policy
        loop-engine-profile
        loop-engine-policy-extension
        loop-engine-coordination-policy-extension
        loop-engine-observability-policy-extension
        loop-engine-safety-policy-extension
        (import: :agentic-ai-lab/modules/nono-sandbox/profile-interface)
        (import: :yuanxu/module-system/observability/presentation)
        (import: :agentic-ai-lab/modules/sandbox-core/profile-interface))

;;; Concrete module loading is the primary user-facing surface. The macro stays
;;; thin: it only quotes the module name and payload, while group routing lives
;;; in `yuanxu-modules-system-use-module` upstream data helpers.
(begin-syntax
  (def (agentic-ai-lab-syntax-list->list stx)
    (syntax->list stx))

  (def (agentic-ai-lab-simple-keyword-slot-specs/elements ctx elements)
    (match elements
      ([] '())
      ([slot-key slot-value . more]
       (let (key (syntax->datum slot-key))
         (and (keyword? key)
              (let (rest
                    (agentic-ai-lab-simple-keyword-slot-specs/elements ctx more))
                (and rest
                     (cons (list (datum->syntax
                                  ctx
                                  (string->symbol (keyword->string key)))
                                 slot-value)
                           rest))))))
      (else #f)))

  (def (agentic-ai-lab-simple-keyword-slot-specs ctx slot-specs)
    (let (elements (agentic-ai-lab-syntax-list->list slot-specs))
      (and elements
           (agentic-ai-lab-simple-keyword-slot-specs/elements ctx elements))))

  (def (agentic-ai-lab-simple-keyword-slot-groups/elements ctx elements)
    (match elements
      ([] '())
      ([slot-specs . more]
       (cons (agentic-ai-lab-simple-keyword-slot-specs ctx slot-specs)
             (agentic-ai-lab-simple-keyword-slot-groups/elements ctx more)))))

  (def (agentic-ai-lab-simple-keyword-slot-groups ctx slot-def-groups)
    (agentic-ai-lab-simple-keyword-slot-groups/elements
     ctx
     (agentic-ai-lab-syntax-list->list slot-def-groups)))

  (def (yuanxu-all? values)
    (not (member #f values))))

;; agentic-ai-lab-use-module-sandbox-profile-config
;;   : (-> Syntax Syntax)
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (use-module nono-sandbox :inherits ci/build)
;;       ;; => sandbox selection
;;       ```
;;     %
(defsyntax (agentic-ai-lab-use-module-sandbox-profile-config stx)
  (syntax-case stx (profile-arguments quoted .def)
    ((ctx module-key config-flags
          (profile-arguments config-arg ...)
          (quoted quoted-form ...)
          (.def (profile-name profile-self profile-super profile-slot ...)
                slot-def ...)
          ...)
     (let* ((slot-groups
             (agentic-ai-lab-simple-keyword-slot-groups
              (syntax ctx)
              (syntax ((slot-def ...) ...)))))
       (if (yuanxu-all? slot-groups)
         (with-syntax (((((slot-name slot-value) ...) ...) slot-groups))
           (syntax
            (let* ((profile-name
                    (object<-alist
                     (list (cons 'slot-name slot-value) ...)
                     supers: profile-super))
                   ...)
              (agentic-ai-lab-modules-system-use-module/ai
               'module-key
               (config-flags
                config-arg ...
                (agentic-ai-lab-sandbox-profile-prototypes
                 (profile-name profile-name) ...)
                '(quoted-form ...))))))
         (syntax
          (let* ((profile-name
                  (.o (:: profile-self profile-super profile-slot ...)
                      slot-def ...))
                 ...)
            (agentic-ai-lab-modules-system-use-module/ai
             'module-key
             (config-flags
              config-arg ...
              (agentic-ai-lab-sandbox-profile-prototypes
               (profile-name profile-name) ...)
              '(quoted-form ...))))))))))

;; use-module
;;   : (-> Symbol UserModuleFlagEntry... [PooUserModuleSelection])
;;   | contract: maps a concrete module row into one inspectable bundle
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (use-module nono-sandbox +nono +doctor)
;;       ;; => sandbox module selection bundle
;;       ```
;;     %
(defsyntax (use-module stx)
  (syntax-case stx (:config :rows :metadata profiles binding workflow funflow session tool-core ai-agentic-context :memory loop-engine nono-sandbox cubeSandbox docker-sandbox
                    session-case metadata objects rows row-groups
                    .def
                    :inherits :isolation :environment :command :nono)
    ((_ funflow
        (.def (prototype-name prototype-self prototype-super prototype-slot ...)
              slot-def ...)
        ...)
     (let* ((slot-groups
             (agentic-ai-lab-simple-keyword-slot-groups
              (syntax ctx)
              (syntax ((slot-def ...) ...)))))
       (if (yuanxu-all? slot-groups)
         (with-syntax (((((slot-name slot-value) ...) ...) slot-groups))
           (syntax
            (let* ((prototype-name
                    (object<-alist
                     (list (cons 'slot-name slot-value) ...)
                     supers: (agentic-ai-lab-ai-agentic-context-memory-prototype-super
                              'prototype-super)))
                   ...)
              (agentic-ai-lab-modules-system-use-module/ai
               'funflow
               (agentic-ai-lab-funflow-poo-config-flags
                (list prototype-name ...)
                '((.def (prototype-name prototype-self prototype-super prototype-slot ...)
                        slot-def ...)
                  ...))))))
         (syntax
          (let* ((prototype-name
                  (.o (:: prototype-self
                          (agentic-ai-lab-ai-agentic-context-memory-prototype-super
                           'prototype-super)
                          prototype-slot ...)
                      slot-def ...))
                 ...)
            (agentic-ai-lab-modules-system-use-module/ai
             'funflow
             (agentic-ai-lab-funflow-poo-config-flags
              (list prototype-name ...)
              '((.def (prototype-name prototype-self prototype-super prototype-slot ...)
                      slot-def ...)
                ...))))))))
    ((_ funflow
        :config
        (.def (prototype-name prototype-self prototype-super prototype-slot ...)
              slot-def ...)
        ...)
     (syntax
      (agentic-ai-lab-funflow-configs
       (.def (prototype-name prototype-self prototype-super prototype-slot ...)
             slot-def ...)
       ...)))
    ((_ workflow :config bad-clause ...)
     (syntax
      (agentic-ai-lab-modules-system-use-module/ai
       'workflow
       '())))
    ((_ session
        :config
        (session-case case-name
          (metadata metadata-entry ...)
          (objects (object-name object-expr) ...)
          (rows row-expr ...)
          (row-groups row-group-expr ...))
        ...)
     (syntax
      (agentic-ai-lab-session-cases
       (session-case case-name
         (metadata metadata-entry ...)
         (objects (object-name object-expr) ...)
         (rows row-expr ...)
         (row-groups row-group-expr ...))
       ...)))
    ((_ session
        :config
        (session-case case-name
          (metadata metadata-entry ...)
          (objects (object-name object-expr) ...)
          (rows row-expr ...))
        ...)
     (syntax
      (agentic-ai-lab-session-cases
       (session-case case-name
         (metadata metadata-entry ...)
         (objects (object-name object-expr) ...)
         (rows row-expr ...))
       ...)))
    ((_ session
        :config
        (.def (prototype-name prototype-self prototype-super prototype-slot ...)
              slot-def ...)
        ...)
     (error "session :config .def has been removed; use (use-module session :config (session-case ...))"))
    ((_ session
        :rows bad-clause ...)
     (error "session :rows has been removed; use (use-module session :config (session-case ...))"))
    ((_ tool-core
        :config
        (.def (prototype-name prototype-self prototype-super prototype-slot ...)
              slot-def ...)
        ...)
     (syntax
      (agentic-ai-lab-tool-configs
       (.def (prototype-name prototype-self prototype-super prototype-slot ...)
             slot-def ...)
       ...)))
    ((_ ai-agentic-context :memory
        :config
        (.def (prototype-name prototype-self prototype-super prototype-slot ...)
              slot-def ...)
        ...)
     (syntax
      (agentic-ai-lab-memory-configs
       (.def (prototype-name prototype-self prototype-super prototype-slot ...)
             slot-def ...)
       ...)))
    ((_ loop-engine
        :config
        (.def (prototype-name prototype-self prototype-super prototype-slot ...)
              slot-def ...)
        ...)
     (syntax
      (agentic-ai-lab-loop-engine-configs
       (.def (prototype-name prototype-self prototype-super prototype-slot ...)
             slot-def ...)
       ...)))
    ((_ loop-engine bad-clause ...)
     (error "loop-engine config DSL has been removed; use (use-module loop-engine :config (.def ...))"))
    ((_ nono-sandbox
        (binding binding-kind)
        (.def (profile-name profile-self profile-super profile-slot ...)
              slot-def ...)
        ...)
     (syntax
      (agentic-ai-lab-use-module-sandbox-profile-config
       nono-sandbox
       agentic-ai-lab-nono-sandbox-config-flags
       (profile-arguments 'binding-kind)
       (quoted (binding binding-kind)
               (.def (profile-name profile-self profile-super profile-slot ...)
                     slot-def ...)
               ...)
       (.def (profile-name profile-self profile-super profile-slot ...)
             slot-def ...)
       ...)))
    ((_ nono-sandbox
        (.def (profile-name profile-self profile-super profile-slot ...)
              slot-def ...)
        ...)
     (syntax
      (agentic-ai-lab-use-module-sandbox-profile-config
       nono-sandbox
       agentic-ai-lab-nono-sandbox-config-flags
       (profile-arguments +agentic-ai-lab-nono-sandbox-default-binding+)
       (quoted (.def (profile-name profile-self profile-super profile-slot ...)
                     slot-def ...)
               ...)
       (.def (profile-name profile-self profile-super profile-slot ...)
             slot-def ...)
       ...)))
    ((_ cubeSandbox
        (.def (profile-name profile-self profile-super profile-slot ...)
              slot-def ...)
        ...)
     (syntax
      (agentic-ai-lab-use-module-sandbox-profile-config
       cubeSandbox
       agentic-ai-lab-cubeSandbox-config-flags
       (profile-arguments)
       (quoted (.def (profile-name profile-self profile-super profile-slot ...)
                     slot-def ...)
               ...)
       (.def (profile-name profile-self profile-super profile-slot ...)
             slot-def ...)
       ...)))
    ((_ docker-sandbox
        (.def (profile-name profile-self profile-super profile-slot ...)
              slot-def ...)
        ...)
     (syntax
      (agentic-ai-lab-use-module-sandbox-profile-config
       docker-sandbox
       agentic-ai-lab-docker-sandbox-config-flags
       (profile-arguments)
       (quoted (.def (profile-name profile-self profile-super profile-slot ...)
                     slot-def ...)
               ...)
       (.def (profile-name profile-self profile-super profile-slot ...)
             slot-def ...)
       ...)))
    ((_ module
        :inherits inherited-profile
        :isolation isolation-clause
        :environment environment-clause
        :command command-clause
        :nono nono-clause)
     (syntax
      (agentic-ai-lab-module-inherited-config
       'module
       'inherited-profile
       'isolation-clause
       'environment-clause
       'command-clause
       'nono-clause)))
    ((_ module :config bad-clause ...)
     (error "use-module :config DSL has been removed; module configs use native POO .def forms"))
    ((_ module flag ...)
     (syntax
      (agentic-ai-lab-modules-system-use-module/ai 'module (list 'flag ...))))))

;;; Module bundle lists are the direct analogue of Doom's module rows: each row
;;; stays a separate bundle so diagnostics can preserve declaration order.
;; | AgenticAILabModuleRow = (Group Module Flag...)
;; agentic-ai-lab-module-bundles
;;   : (-> AgenticAILabModuleRow... [[PooUserModuleSelection]])
;;   | contract: expands module rows into inspectable bundle data only
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-module-bundles
;;         (flow funflow +functional)
;;         (loop governor +policy))
;;       ;; => bundles
;;       ```
;;     %
(defrules agentic-ai-lab-module-bundles ()
  ((_)
   '())
  ((_ module-clause module-clause-rest ...)
   (cons (yuanxu-user-module-bundle module-clause)
         (agentic-ai-lab-module-bundles module-clause-rest ...))))

;;; Private/custom module rows keep the init surface pure: users name the
;;; module and entrypoint root, while the macro supplies the custom group.
;; | AgenticAILabCustomModuleRow = (Module RootPath Flag...)
;; agentic-ai-lab-custom-module-bundles
;;   : (-> AgenticAILabCustomModuleRow... [[PooUserModuleSelection]])
;;   | contract: expands private rows into custom module selections only
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-custom-module-bundles
;;         (my-module "./custom/my-module" +private +doctor))
;;       ;; => bundles
;;       ```
;;     %
(defrules agentic-ai-lab-custom-module-bundles ()
  ((_)
   '())
  ((_ (module module-root-path flag ...) custom-clause ...)
   (cons (yuanxu-user-module-bundle
          (custom module module-root-path flag ...))
         (agentic-ai-lab-custom-module-bundles custom-clause ...))))

;;; Doom-style init rows use category markers. `+flags` remain feature
;;; modifiers, while `:workflow`, `:loop`, `:sandbox`, and `:custom` own grouping.
;;; `use-module` is intentionally not accepted here; it belongs to config/helper
;;; surfaces that already know they are constructing module selections directly.
;; | AgenticAILabInitRow = :Category ModuleRow...
;; agentic-ai-lab-init-module-bundles
;;   : (-> AgenticAILabInitRow... [[PooUserModuleSelection]])
;;   | contract: parses flat Doom-style category rows into POO module bundles
;;   | doc m%
;;       Category markers dispatch to their POO-native row walker while direct
;;       module and custom rows remain reusable composition values.
;;
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-init-module-bundles :workflow (funflow +functional) :sandbox (nono-sandbox +doctor))
;;       ;; => bundles
;;       ```
;;     %
(defrules agentic-ai-lab-init-module-bundles
  (modules custom :workflow :loop :sandbox :custom)
  ((_)
   '())
  ((_ (modules module-clause ...) init-clause ...)
   (append (agentic-ai-lab-module-bundles module-clause ...)
           (yuanxu-modules! init-clause ...)))
  ((_ (custom custom-clause ...) init-clause ...)
   (append (agentic-ai-lab-custom-module-bundles custom-clause ...)
           (yuanxu-modules! init-clause ...)))
  ((_ :workflow init-clause ...)
   (agentic-ai-lab-init-flow-bundles init-clause ...))
  ((_ :loop init-clause ...)
   (agentic-ai-lab-init-loop-bundles init-clause ...))
  ((_ :sandbox init-clause ...)
   (agentic-ai-lab-init-sandbox-bundles init-clause ...))
  ((_ :custom init-clause ...)
   (agentic-ai-lab-init-custom-bundles init-clause ...)))

;;; Plain category walkers share the same marker transfer and row wrapping
;;; frame. Flow and custom stay explicit because they carry special row shapes.
;; defpoo-init-category-bundles
;;   : (-> Identifier Identifier Syntax)
;;   | contract: generates a private init category walker for plain rows
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (defpoo-init-category-bundles agentic-ai-lab-init-loop-bundles loop)
;;       ;; => marker-aware walker over (module flag ...) rows
;;       ```
;;     %
(defsyntax (defpoo-init-category-bundles stx)
  (syntax-case stx ()
    ((_ walker category)
     (let ((walker-name (syntax->datum (syntax walker)))
           (category-name (syntax->datum (syntax category))))
       (datum->syntax
        (syntax walker)
        `(defrules ,walker-name (:workflow :loop :sandbox :custom)
           ((_)
            '())
           ((_ :workflow init-clause ...)
            (agentic-ai-lab-init-flow-bundles init-clause ...))
           ((_ :loop init-clause ...)
            (agentic-ai-lab-init-loop-bundles init-clause ...))
           ((_ :sandbox init-clause ...)
            (agentic-ai-lab-init-sandbox-bundles init-clause ...))
           ((_ :custom init-clause ...)
            (agentic-ai-lab-init-custom-bundles init-clause ...))
           ((_ (module flag ...) init-clause ...)
            (cons (yuanxu-user-module-bundle
                   (,category-name module flag ...))
                  (,walker-name init-clause ...)))))))))

;;; Workflow category walking is a macro-time cursor over init rows: it emits
;;; flow selections until another category marker transfers control.
;; agentic-ai-lab-init-flow-bundles
;;   : (-> AgenticAILabInitRow... [[PooUserModuleSelection]])
;;   | contract: parses rows after :workflow until the next category marker
;;   | doc m%
;;       Workflow rows stay in the functional-flow category until another
;;       marker transfers control to its own POO-native walker.
;;
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-init-flow-bundles (funflow +dag) :sandbox (cubeSandbox +doctor))
;;       ;; => bundles
;;       ```
;;     %
(defrules agentic-ai-lab-init-flow-bundles (:workflow :loop :sandbox :custom loop-engine)
  ((_)
   '())
  ((_ :workflow init-clause ...)
   (agentic-ai-lab-init-flow-bundles init-clause ...))
  ((_ :loop init-clause ...)
   (agentic-ai-lab-init-loop-bundles init-clause ...))
  ((_ :sandbox init-clause ...)
   (agentic-ai-lab-init-sandbox-bundles init-clause ...))
  ((_ :custom init-clause ...)
   (agentic-ai-lab-init-custom-bundles init-clause ...))
  ((_ (loop-engine flag flag-rest ...) init-clause ...)
   (error "loop-engine init row config DSL has been removed; use use-module loop-engine :config with native POO .def forms"))
  ((_ (loop-engine) init-clause ...)
   (cons (yuanxu-user-module-bundle
          (flow loop-engine))
         (agentic-ai-lab-init-flow-bundles init-clause ...)))
  ((_ (module flag ...) init-clause ...)
   (cons (yuanxu-user-module-bundle
          (flow module flag ...))
         (agentic-ai-lab-init-flow-bundles init-clause ...))))

;;; Loop category walking mirrors workflow parsing but tags plain rows as loop
;;; selections; marker clauses remain tail calls into sibling walkers.
;; agentic-ai-lab-init-loop-bundles
;;   : (-> AgenticAILabInitRow... [[PooUserModuleSelection]])
;;   | contract: parses rows after :loop until the next category marker
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-init-loop-bundles
;;         (governor +policy)
;;         :custom
;;         (my-module "./custom/my-module"))
;;       ;; => bundles
;;       ```
;;     %
(defpoo-init-category-bundles agentic-ai-lab-init-loop-bundles loop)

;;; Sandbox category walking keeps backend choices declarative: rows become
;;; user selections, not sandbox descriptors or runtime requests.
;; agentic-ai-lab-init-sandbox-bundles
;;   : (-> AgenticAILabInitRow... [[PooUserModuleSelection]])
;;   | contract: parses rows after :sandbox until the next category marker
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-init-sandbox-bundles
;;         (nono-sandbox +doctor)
;;         (cubeSandbox +doctor))
;;       ;; => bundles
;;       ```
;;     %
(defpoo-init-category-bundles agentic-ai-lab-init-sandbox-bundles sandbox)

;;; Custom category walking is the only init walker that accepts a module root
;;; path; it records source metadata while loaders decide execution later.
;; agentic-ai-lab-init-custom-bundles
;;   : (-> AgenticAILabInitRow... [[PooUserModuleSelection]])
;;   | contract: parses rows after :custom until the next category marker
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-init-custom-bundles
;;         (my-module "./custom/my-module" +private))
;;       ;; => bundles
;;       ```
;;     %
(defrules agentic-ai-lab-init-custom-bundles (:workflow :loop :sandbox :custom)
  ((_)
   '())
  ((_ :workflow init-clause ...)
   (agentic-ai-lab-init-flow-bundles init-clause ...))
  ((_ :loop init-clause ...)
   (agentic-ai-lab-init-loop-bundles init-clause ...))
  ((_ :sandbox init-clause ...)
   (agentic-ai-lab-init-sandbox-bundles init-clause ...))
  ((_ :custom init-clause ...)
   (agentic-ai-lab-init-custom-bundles init-clause ...))
  ((_ (module module-root-path flag ...) init-clause ...)
   (cons (yuanxu-user-module-bundle
          (custom module module-root-path flag ...))
         (agentic-ai-lab-init-custom-bundles init-clause ...))))

;;; Compact profile-set syntax borrows Doom's profiles.el shape but restricts
;;; the surface to profile registry data.
;; | AgenticAILabProfileSetName = Symbol
;; | AgenticAILabProfileName = Symbol
;; agentic-ai-lab-profile-set
;;   : (-> AgenticAILabProfileSetName AgenticAILabProfileName PooUserProfile... PooUserProfileSet)
;;   | contract: selects a default profile by name; no file loading or sync
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-profile-set user
;;         (default kernel)
;;         (profiles agentic-ai-lab-kernel-profile))
;;       ;; => profile-set
;;       ```
;;     %
(defrules agentic-ai-lab-profile-set ()
  ((_ binding-name
      set-name
      (_ default-profile-name)
      (_ profile ...))
   (def binding-name
     (yuanxuUserProfileSet 'set-name
                            'default-profile-name
                            (list profile ...))))
  ((_ set-name
      (_ default-profile-name)
      (_ profile ...))
   (yuanxuUserProfileSet 'set-name
                          'default-profile-name
                          (list profile ...))))

;;; Profile extension declaration keeps root init files close to Doom's init.el:
;;; one user-visible form appends custom modules to a base POO profile object.
;; | AgenticAILabProfileBinding = Identifier
;; | AgenticAILabProfileName = Symbol
;; | AgenticAILabBaseProfile = PooUserProfile
;; | AgenticAILabProfileModuleBundle = [PooUserModuleSelection]
;; agentic-ai-lab-profile-extend
;;   : (-> AgenticAILabProfileBinding AgenticAILabProfileName AgenticAILabBaseProfile AgenticAILabProfileModuleBundle... PooUserProfile)
;;   | contract: defines an extended profile object; no descriptor realization
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-profile-extend user-profile developer base-profile
;;         (modules custom-bundle))
;;       ;; => user-profile
;;       ```
;;     %
(defrules agentic-ai-lab-profile-extend (modules bundles)
  ((_ binding-name
      profile-name
      base-profile
      (bundles module-bundles ...))
   (def binding-name
     (yuanxuUserProfileExtend 'profile-name
                               base-profile
                               (append module-bundles ...))))
  ((_ binding-name
      profile-name
      base-profile
      (modules module-bundle ...))
   (def binding-name
     (yuanxuUserProfileExtend 'profile-name
                               base-profile
                               (list module-bundle ...)))))

;;; Canonical profile syntax keeps user-facing declarations aligned with the
;;; product name without changing the underlying profile object contract.
;; | AgenticAILabUserProfileName = Symbol
;; | AgenticAILabUserProfileModuleBundle = [PooUserModuleSelection]
;; agentic-ai-lab-profile
;;   : (-> AgenticAILabUserProfileName AgenticAILabUserProfileModuleBundle... UserSettingSyntax... [Symbol] PooUserProfile)
;;   | contract: expands directly to the branded profile constructor
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-profile developer
;;         (modules
;;          (yuanxu-user-module-bundle (flow funflow +functional)))
;;         (settings surface: "agentic-ai-lab")
;;         (setting-keys surface))
;;       ;; => profile
;;       ```
;;     %
(defrules agentic-ai-lab-profile (modules settings setting-keys)
  ((_ binding-name
      profile-name
      (modules module-bundle ...)
      (settings setting ...)
      (setting-keys setting-key ...))
   (def binding-name
     (yuanxuUserProfile 'profile-name
                         (list module-bundle ...)
                         (yuanxu-settings setting ...)
                         (list 'setting-key ...))))
  ((_ profile-name
      (modules module-bundle ...)
      (settings setting ...)
      (setting-keys setting-key ...))
   (yuanxuUserProfile 'profile-name
                       (list module-bundle ...)
                       (yuanxu-settings setting ...)
                       (list 'setting-key ...))))
