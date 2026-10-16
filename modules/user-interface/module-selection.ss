;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO Flow user-facing facts for hot-plug module selection.
;;; Invariant: this module stays below profile/doctor presentation logic.
;;; Descriptor realization stays in package-root modules.
;;; Intent: keep the downstream surface focused on POO Flow module activation.

(import (only-in :clan/poo/object .o .ref)
        :poo-flow/modules/module-authoring/module-interface
        (only-in :core/object-family/syntax
                 defpoo-object-family)
        :core/utilities/final-projection-syntax
        :poo-flow/modules/module-authoring/module-imports
        :core/module-system/source/objects
        :poo-flow/modules/user-interface/selection-flags)

(export poo-flow-user-config-kind
        poo-flow-user-module-selection-kind
        poo-flow-user-config-presentation-kind
        pooFlowUserConfig
        poo-flow-user-config?
        poo-flow-user-config-modules
        poo-flow-user-config-settings
        poo-flow-user-config-module-keys
        poo-flow-user-module-bundles->modules
        poo-flow-user-module-bundles-extend
        poo-flow-user-module-selections-extend
        poo-flow-user-module-selection-extend
        poo-flow-user-module-selection-extend-flags
        poo-flow-user-module-selection->alist
        poo-flow-user-module-selection?
        poo-flow-user-module-selection-key
        poo-flow-user-module-selection-flags
        poo-flow-user-module-selection-source-ref
        poo-flow-user-module-selection-entrypoint
        poo-flow-user-module-selection-has-flag?
        poo-flow-user-module-selection-has-flags?
        poo-flow-user-module-selection-flag-entry
        poo-flow-user-module-selection-feature-fact
        poo-flow-user-module-selection
        poo-flow-user-custom-module-selection
        poo-flow-user-custom-modules-selection
        poo-flow-user-module-selection-feature?
        poo-flow-user-modules-feature?
        poo-flow-user-config-feature?
        poo-flow-user-config-feature-facts
        poo-flow-settings
        poo-flow-user-settings->alist
        poo-flow-modules-system-use-module-group
        poo-flow-modules-system-use-module
        poo-flow-user-module-bundle
        poo-flow-user-module-when)

;;; Boundary: public ids are receipt vocabulary, not runtime owners.
;; : (-> Unit PooFlowUserConfigKind)
(def poo-flow-user-config-kind
  "poo-flow.modules.user-config.v1")

;;; Module selections are user-facing hot-plug facts, so their kind id stays
;;; separate from realized descriptor and module contract ids.
;; : (-> Unit PooFlowUserModuleSelectionKind)
(def poo-flow-user-module-selection-kind
  "poo-flow.modules.user-selection.v1")

;;; Presentation ids are user-facing doctor data, not activation receipts.
;; : (-> Unit PooFlowUserConfigPresentationKind)
(def poo-flow-user-config-presentation-kind
  "poo-flow.modules.user-config.presentation.v1")

;;; Boundary: user modules are hot-plug selections, not descriptors.
;; : (-> Symbol Symbol [Symbol] MaybePooModuleSourceRef MaybePath POOObject)
(def (poo-flow-user-module-selection/source
      group
      module
      flags
      source-ref-value
      entrypoint-value)
  (.o kind: poo-flow-user-module-selection-kind
      user-group: group
      user-module: module
      selection-flags: flags
      source-ref: source-ref-value
      entrypoint: entrypoint-value
      enabled?: #t))

;;; The short constructor is the normal user-facing path for root init rows; it
;;; intentionally leaves source and entrypoint empty until custom modules opt in.
;; : (-> Symbol Symbol [Symbol] POOObject)
(def (poo-flow-user-module-selection group module flags)
  (poo-flow-user-module-selection/source group module flags 'none 'none))

;;; Custom module selections mirror Doom private modules: init.ss selects the
;;; module, and the user-owned directory contributes interface.ss as entrypoint.
;; : (-> Symbol Path [Symbol] POOObject)
(def (poo-flow-user-custom-module-selection module module-root-path flags)
  (poo-flow-user-module-selection/source
   'custom
   module
   flags
   (make-poo-flow-module-custom-interface-source module-root-path)
   (poo-flow-module-custom-interface-entrypoint module-root-path)))

;;; An anonymous @ row denotes a complete modules directory. It remains one
;;; declaration value until poo-flow-load-modules discovers its child module trees.
(def (poo-flow-user-custom-modules-selection modules-root-path flags)
  (poo-flow-user-module-selection/source
   'custom
   'modules
   flags
   (make-poo-flow-module-custom-collection-source modules-root-path)
   'discover))

;;; Module-name routing keeps the user DSL on concrete modules such as
;;; `(use-module nono-sandbox ...)`, while the profile data still stores the
;;; canonical group/module key used by feature checks and presentation.
;; : (-> Symbol Symbol)
(def (poo-flow-modules-system-use-module-group module)
  (cond
   ((eq? module 'funflow) 'flow)
   ((eq? module 'loop-engine) 'flow)
   ((eq? module 'workflow) 'flow)
   ((eq? module 'custom-task) 'flow)
   ((eq? module 'text) 'flow)
   ((eq? module 'session) 'session)
   ((eq? module 'tool-core) 'session)
   ((eq? module 'ai-agentic-context) 'agentic)
   ((eq? module 'model-core) 'session)
   ((eq? module 'governor) 'loop)
   ((or (eq? module 'sandbox-core)
        (eq? module 'agent-sandbox)
        (eq? module 'nono-sandbox)
        (eq? module 'docker)
        (eq? module 'cubeSandbox)
        (eq? module 'docker-sandbox))
    'sandbox)
   (else 'custom)))

;; : (-> Symbol [UserModuleFlagEntry] [PooUserModuleSelection])
(def (poo-flow-modules-system-use-module module flags)
  (list
   (poo-flow-user-module-selection
    (poo-flow-modules-system-use-module-group module)
    module
    flags)))

;;; Doom-style module bundles keep the user surface compact: users write
;;; unquoted group/module/flag symbols, while upstream stores plain data.
;; | UserModuleBundleClause = (Group Module Flag...)
;; poo-flow-user-module-bundle
;;   : (-> UserModuleBundleClause... [PooFlowUserModuleSelection])
;;   | contract: produces user selections only, never descriptors
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-user-module-bundle
;;         (flow workflow +typed-receipts)
;;         (sandbox marlin +nono +cube +doctor))
;;       ;; => selections
;;       ```
;;     %
(defrules poo-flow-user-module-bundle (custom)
  ((_)
   '())
  ((_ (custom module module-root-path flag ...) module-clause ...)
   (cons (poo-flow-user-custom-module-selection
          'module
          module-root-path
          (list 'flag ...))
         (poo-flow-user-module-bundle module-clause ...)))
  ((_ (group module flag ...) module-clause ...)
   (cons (poo-flow-user-module-selection 'group 'module (list 'flag ...))
         (poo-flow-user-module-bundle module-clause ...))))

;;; Conditional module bundles mirror Doom-style feature gates while remaining
;;; ordinary Scheme control flow at the user declaration site.
;; | UserModuleCondition = Boolean
;; poo-flow-user-module-when
;;   : (-> UserModuleCondition UserModuleBundleClause... [PooFlowUserModuleSelection])
;;   | contract: false conditions return an empty selection list
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-user-module-when enable-sandbox?
;;         (sandbox marlin +doctor))
;;       ;; => selections-or-empty
;;       ```
;;     %
(defrules poo-flow-user-module-when ()
  ((_ condition module-clause ...)
   (if condition
     (poo-flow-user-module-bundle module-clause ...)
     '())))

;; : (-> PooUserModuleSelectionCandidate Boolean)
(defpoo-object-family poo-flow-user-module-selection-kind
  poo-flow-user-module-selection?
  (accessors
   (poo-flow-user-module-selection-flags selection-flags))
  (projections))

;; : (-> POOObject Pair)
(def (poo-flow-user-module-selection-key selection)
  (cons (.ref selection 'user-group)
        (.ref selection 'user-module)))

;;; Selection extension is declaration-layer normalization only; the result is
;;; still a user selection and is not a descriptor or activation closure.
;; : (-> PooUserModuleSelection PooUserModuleSelection PooUserModuleSelection)
(def (poo-flow-user-module-selection-extend base-selection extra-selection)
  (poo-flow-user-module-selection/source
   (.ref base-selection 'user-group)
   (.ref base-selection 'user-module)
   (poo-flow-user-module-selection-extend-flags
    (poo-flow-user-module-selection-flags base-selection)
    (poo-flow-user-module-selection-flags extra-selection))
   (poo-flow-user-module-selection-extend-slot
    (.ref base-selection 'source-ref)
    (.ref extra-selection 'source-ref))
   (poo-flow-user-module-selection-extend-slot
    (.ref base-selection 'entrypoint)
    (.ref extra-selection 'entrypoint))))

;;; A matching `(group . module)` row is updated in place so extension profiles
;;; do not manufacture duplicate-module warnings for intentional flag patches.
;; : (-> [PooUserModuleSelection] PooUserModuleSelection [PooUserModuleSelection])
(def (poo-flow-user-module-selections-extend-one selections extra-selection)
  (cond
   ((null? selections) (list extra-selection))
   ((equal? (poo-flow-user-module-selection-key (car selections))
            (poo-flow-user-module-selection-key extra-selection))
    (cons (poo-flow-user-module-selection-extend (car selections) extra-selection)
          (cdr selections)))
   (else
    (cons (car selections)
          (poo-flow-user-module-selections-extend-one
           (cdr selections)
           extra-selection)))))

;;; The fold is explicit to keep declaration order stable and visible in
;;; downstream presentation receipts.
;; : (-> [PooUserModuleSelection] [PooUserModuleSelection] [PooUserModuleSelection])
(def (poo-flow-user-module-selections-extend/add normalized extra-selections)
  (cond
   ((null? extra-selections) normalized)
   (else
    (poo-flow-user-module-selections-extend/add
     (poo-flow-user-module-selections-extend-one normalized (car extra-selections))
     (cdr extra-selections)))))

;;; Public selection extension stays below profile construction so callers can
;;; normalize bundles without importing profile or doctor presentation logic.
;; : (-> [PooUserModuleSelection] [PooUserModuleSelection] [PooUserModuleSelection])
(def (poo-flow-user-module-selections-extend base-selections extra-selections)
  (poo-flow-user-module-selections-extend/add base-selections extra-selections))

;;; Bundle reconstruction keeps the public profile shape intact after extension
;;; normalization; each normalized selection becomes one declarative bundle row.
;; : (-> [PooUserModuleSelection] [[PooUserModuleSelection]])
(def (poo-flow-user-module-selections->bundles selections)
  (map list selections))

;;; Profile extension produces normalized bundles so user-visible optional flags
;;; can patch kernel modules without surfacing duplicate-module diagnostics.
;; : (-> [[PooUserModuleSelection]] [[PooUserModuleSelection]] [[PooUserModuleSelection]])
(def (poo-flow-user-module-bundles-extend base-bundles extra-bundles)
  (poo-flow-user-module-selections->bundles
   (poo-flow-user-module-selections-extend
    (poo-flow-user-module-bundles->modules base-bundles)
    (poo-flow-user-module-bundles->modules extra-bundles))))

;;; Boundary: user module selection source ref is the policy-visible edge for
;;; module-system behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> POOObject MaybePooModuleSourceRef)
(def (poo-flow-user-module-selection-source-ref selection)
  (let ((source-ref (.ref selection 'source-ref)))
    (if (eq? source-ref 'none) #f source-ref)))

;;; Boundary: user module selection entrypoint is the policy-visible edge for
;;; module-system behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> POOObject MaybePath)
(def (poo-flow-user-module-selection-entrypoint selection)
  (let ((entrypoint (.ref selection 'entrypoint)))
    (if (eq? entrypoint 'none) #f entrypoint)))

;; : (-> UserModuleFlagEntry Symbol Boolean)
(def (poo-flow-user-module-selection-flag-entry? entry flag)
  (or (equal? entry flag)
      (and (pair? entry)
           (equal? (car entry) flag))))

;;; Flag lookup accepts either a bare flag or a pair-shaped flag entry, because
;;; user declarations may attach metadata while predicates still answer yes/no.
;; poo-flow-user-module-selection-has-flag?
;;   : (-> POOObject Symbol Boolean)
;;   | contract: checks declared user-module flags without descriptor realization
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-user-module-selection-has-flag? selection '+doctor)
;;       ;; => #t
;;       ```
;;     %
(def (poo-flow-user-module-selection-has-flag? selection flag)
  (and (find (lambda (entry)
               (poo-flow-user-module-selection-flag-entry? entry flag))
             (poo-flow-user-module-selection-flags selection))
       #t))

;;; Flag entry lookup returns the raw flag payload so nested declarations such
;;; as =(+cicd ...)= can be presented without descriptor realization.
;; : (-> Symbol [UserModuleFlagEntry] MaybeUserModuleFlagEntry)
(def (poo-flow-user-module-selection-flag-entry/find flag flags)
  (cond
   ((null? flags) #f)
   ((poo-flow-user-module-selection-flag-entry? (car flags) flag)
    (car flags))
   (else
    (poo-flow-user-module-selection-flag-entry/find flag (cdr flags)))))

;; : (-> POOObject Symbol MaybeUserModuleFlagEntry)
(def (poo-flow-user-module-selection-flag-entry selection flag)
  (poo-flow-user-module-selection-flag-entry/find
   flag
   (poo-flow-user-module-selection-flags selection)))

;;; User-interface presentation must show the config body the user wrote, not
;;; the resolved backend profile objects used for validation and runtime handoff.
;; : (-> Symbol Boolean)
(def (poo-flow-user-module-selection-presentation-config-flag? flag-key)
  (or (equal? flag-key ':binding)
      (equal? flag-key ':config)
      (equal? flag-key ':backend-capability-registry)
      (equal? flag-key ':user-config)))

;;; Boundary: user module selection presentation flags is the policy-visible
;;; edge for module-system behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;;; Boundary: user module selection presentation flags drop config is the
;;; policy-visible edge for module-system behavior, keeping validation, lookup,
;;; or projection responsibilities centralized for callers.
;; : (-> [UserModuleFlagEntry] [UserModuleFlagEntry])
(def (poo-flow-user-module-selection-presentation-flags/drop-config flags)
  (cond
   ((null? flags) '())
   ((and (pair? (car flags))
         (poo-flow-user-module-selection-presentation-config-flag?
          (caar flags)))
    (poo-flow-user-module-selection-presentation-flags/drop-config
     (cdr flags)))
   (else
    (cons (car flags)
          (poo-flow-user-module-selection-presentation-flags/drop-config
           (cdr flags))))))

;;; Boundary: user module selection presentation flags is the policy-visible
;;; edge for module-system behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> PooUserModuleSelection [UserModuleFlagEntry])
(def (poo-flow-user-module-selection-presentation-flags selection)
  (let* ((flags (poo-flow-user-module-selection-flags selection))
         (user-config-entry
          (poo-flow-user-module-selection-flag-entry/find ':user-config flags)))
    (if (and user-config-entry (pair? user-config-entry))
      (append
       (poo-flow-user-module-selection-presentation-flags/drop-config flags)
       (list (cons ':config (cdr user-config-entry))))
      flags)))

;;; Multiple-flag checks keep callers from reimplementing list scans when they
;;; need to test a declared module mode such as `+strategy +policy`.
;; : (-> POOObject [Symbol] Boolean)
(def (poo-flow-user-module-selection-has-flags? selection flags)
  (cond
   ((null? flags) #t)
   ((poo-flow-user-module-selection-has-flag? selection (car flags))
    (poo-flow-user-module-selection-has-flags? selection (cdr flags)))
   (else #f)))

;;; Boundary: a feature is a selected module plus flags in the user declaration
;;; layer. This mirrors Doom's convenient predicate shape without inheriting
;;; Doom's package or load-cache semantics.
;; : (-> PooUserModuleSelection Symbol Symbol [Symbol] Boolean)
(def (poo-flow-user-module-selection-feature? selection group module flags)
  (and (equal? (poo-flow-user-module-selection-key selection)
               (cons group module))
       (poo-flow-user-module-selection-has-flags? selection flags)))

;;; Module-list feature checks are used by profiles and config projections so
;;; downstream tooling can ask about capabilities without realizing descriptors.
;; : (-> [PooUserModuleSelection] Symbol Symbol Symbol... Boolean)
(def (poo-flow-user-modules-feature? selected-modules group module . flags)
  (cond
   ((null? selected-modules) #f)
   ((poo-flow-user-module-selection-feature? (car selected-modules)
                                             group
                                             module
                                             flags)
    #t)
   (else
    (apply poo-flow-user-modules-feature?
           (cdr selected-modules)
           group
           module
           flags))))

;;; Config-level feature checks are the stable public predicate for user tools;
;;; callers pass declared group/module/flags and receive a pure Boolean fact.
;; : (-> PooUserConfig Symbol Symbol Symbol... Boolean)
(def (poo-flow-user-config-feature? config group module . flags)
  (apply poo-flow-user-modules-feature?
         (poo-flow-user-config-modules config)
         group
         module
         flags))

;;; Loop-engine sections keep workflow-owned loop configuration visible without

;; : (-> [Value] [PooSandboxProfile])

;; : (-> [Value] [Value] Symbol)


;;; Boundary: indexed feature facts preserve init.ss declaration order for help
;;; and doctor output. The index is explanatory metadata only; resolver and
;;; loader code remain responsible for any later execution ordering.
;; : (-> PooUserModuleSelection MaybeInteger Alist)
(defpoo-final-projection
  poo-flow-user-module-selection-feature-fact/index (selection index)
  (bindings ())
  (fields ((declaration-index index)
           (declaration-phase 'init-selection)
           (key (poo-flow-user-module-selection-key selection))
           (group (.ref selection 'user-group))
           (module (.ref selection 'user-module))
           (flags
            (poo-flow-user-module-selection-presentation-flags selection))
           (source-ref
            (poo-flow-user-module-selection-source-ref-alist selection))
           (entrypoint
            (poo-flow-user-module-selection-entrypoint selection))
           (package-management? #f)
           (dependency-installation? #f)
           (descriptor-realized? #f)
           (loader-executed? #f))))

;;; Single-selection facts are useful for focused assertions where no profile
;;; order exists yet, so the declaration index is intentionally absent.
;; : (-> PooUserModuleSelection Alist)
(def (poo-flow-user-module-selection-feature-fact selection)
  (poo-flow-user-module-selection-feature-fact/index selection #f))

;;; Config feature facts preserve declaration order so help and doctor output
;;; stay aligned with the user's init.ss rows.
;; : (-> [PooUserModuleSelection] Integer [Alist])
(def (poo-flow-user-config-feature-facts/add selected-modules index)
  (cond
   ((null? selected-modules) '())
   (else
    (cons (poo-flow-user-module-selection-feature-fact/index
           (car selected-modules)
           index)
          (poo-flow-user-config-feature-facts/add
           (cdr selected-modules)
           (+ index 1))))))

;; : (-> PooUserConfig [Alist])
(def (poo-flow-user-config-feature-facts config)
  (poo-flow-user-config-feature-facts/add
   (poo-flow-user-config-modules config)
   0))

;;; Boundary: user module selection source ref projection is the policy-visible
;;; edge for module-system behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> PooUserModuleSelection MaybeAlist)
(def (poo-flow-user-module-selection-source-ref-alist selection)
  (let ((source-ref (poo-flow-user-module-selection-source-ref selection)))
    (if source-ref
      (poo-flow-module-source-ref->alist source-ref)
      #f)))

;;; Selection presentation keeps hot-plug choices inspectable without resolving
;;; them into descriptors or touching upstream catalogs.
;; : (-> PooUserModuleSelection Alist)
(defpoo-final-projection
  poo-flow-user-module-selection->alist (selection)
  (bindings ())
  (fields ((group (.ref selection 'user-group))
           (module (.ref selection 'user-module))
           (key (poo-flow-user-module-selection-key selection))
           (source-ref
            (poo-flow-user-module-selection-source-ref-alist selection))
           (entrypoint
            (poo-flow-user-module-selection-entrypoint selection))
           (flags
            (poo-flow-user-module-selection-presentation-flags selection))
           (enabled? (.ref selection 'enabled?)))))

;;; Settings deliberately remain a plain POO slot object: this layer captures
;;; user-authored option facts, while option merge semantics stay in the module
;;; system evaluator.
;; | UserSettingSyntax = SlotKeyword Value ...
;; poo-flow-settings
;;   : (-> UserSettingSyntax POOObject)
;;   | contract: captures user settings without validating option schemas
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-settings timeout: 30 retries: 2)
;;       ;; => settings
;;       ```
;;     %
(defrules poo-flow-settings ()
  ((_ setting ...)
   (.o setting ...)))

;;; Empty profiles are legal for tests and downstream bootstrap templates.
;; poo-flow-user-module-bundles->modules
;;   : (-> [[PooUserModuleSelection]] [PooUserModuleSelection])
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-user-module-bundles->modules [[a b] [c]])
;;       ;; => [a b c]
;;       ```
;;     %
(def (poo-flow-user-module-bundle->modules/rev modules modules-rev)
  (if (null? modules)
    modules-rev
    (poo-flow-user-module-bundle->modules/rev
     (cdr modules)
     (cons (car modules) modules-rev))))

;; : (-> [[PooUserModuleSelection]] [PooUserModuleSelection] [PooUserModuleSelection])
(def (poo-flow-user-module-bundles->modules/rev module-bundles modules-rev)
  (if (null? module-bundles)
    modules-rev
    (poo-flow-user-module-bundles->modules/rev
     (cdr module-bundles)
     (poo-flow-user-module-bundle->modules/rev
      (car module-bundles)
      modules-rev))))

(def (poo-flow-user-module-bundles->modules module-bundles)
  (reverse
   (poo-flow-user-module-bundles->modules/rev module-bundles '())))

;;; Boundary: top-level user config groups module choices and strategy settings.
;; : (-> [PooUserModuleSelection] POOObject POOObject)
(def (pooFlowUserConfig modules settings)
  (.o kind: poo-flow-user-config-kind
      user-modules: modules
      user-settings: settings))

;; : (-> PooUserConfigCandidate Boolean)
(defpoo-object-family poo-flow-user-config-kind
  poo-flow-user-config?
  (accessors
   (poo-flow-user-config-modules user-modules)
   (poo-flow-user-config-settings user-settings))
  (projections))

;;; Module key projection is a user-facing summary for selected groups and
;;; names. It intentionally drops flags because flag checks stay per selection.
;; : (-> [PooUserModuleSelection] [Pair] [Pair])
(def (poo-flow-user-config-module-keys/rev modules keys-rev)
  (if (null? modules)
    keys-rev
    (poo-flow-user-config-module-keys/rev
     (cdr modules)
     (cons (poo-flow-user-module-selection-key (car modules)) keys-rev))))

;; : (-> PooUserConfig [Pair])
(def (poo-flow-user-config-module-keys config)
  (reverse
   (poo-flow-user-config-module-keys/rev
    (poo-flow-user-config-modules config)
    '())))

;;; Settings presentation is intentionally shallow: user settings remain slots,
;;; while schema validation and merge semantics belong to upstream descriptors.
;; : (-> POOObject [Symbol] Alist Alist)
(def (poo-flow-user-settings->alist/rev settings setting-keys rows-rev)
  (if (null? setting-keys)
    rows-rev
    (poo-flow-user-settings->alist/rev
     settings
     (cdr setting-keys)
     (cons (cons (car setting-keys) (.ref settings (car setting-keys)))
           rows-rev))))

;; : (-> POOObject [Symbol] Alist)
(def (poo-flow-user-settings->alist settings setting-keys)
  (reverse
   (poo-flow-user-settings->alist/rev settings setting-keys '())))
