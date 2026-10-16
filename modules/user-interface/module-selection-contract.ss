;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: contract gate for public `use-module` declarations.
;;; Invariant: macros may stay ergonomic, but every expansion must produce
;;; concrete module selections rather than category aliases or loose data.

(import (only-in :clan/poo/object .o .ref)
        (only-in :poo-flow/modules/ai-agentic-context/config poo-flow-ai-agentic-context-module)
        :poo-flow/modules/user-interface/module-selection
        :core/utilities/final-projection-syntax)

(export poo-flow-use-module-contract-validation-kind
        poo-flow-use-module-contract-validation-schema
        poo-flow-use-module-contract-validation
        poo-flow-use-module-contract-validation-valid?
        poo-flow-use-module-contract-validation-diagnostics
        poo-flow-require-use-module-contract!
        poo-flow-modules-system-use-module/contract)

;; : String
(def poo-flow-use-module-contract-validation-kind
  "poo-flow.use-module.contract-validation")

;; : String
(def poo-flow-use-module-contract-validation-schema
  "poo-flow.use-module.contract-validation/v1")

;;; These names are valid user-facing categories, but not concrete modules.
;;; Keeping the deny-list here makes the public macro fail before the generic
;;; fallback can classify an unknown category spelling as a custom module.
;; : (-> Symbol Boolean)
(def (poo-flow-use-module-category-symbol? module)
  (or (eq? module 'workflow)
      (eq? module 'flow)
      (eq? module 'sandbox)
      (eq? module 'loop)
      (eq? module 'custom)))

;; : (-> Symbol String Value Value Alist)
(def (poo-flow-use-module-contract-diagnostic code message subject evidence)
  (poo-flow-product-field-rows
   (code code)
   (message message)
   (subject subject)
   (evidence evidence)))

;;; Flags are intentionally shallow here: feature payloads such as `(+cicd ...)`
;;; and config pairs such as `(:config . profiles)` are both symbol-keyed
;;; declaration entries. Their internal payload contracts belong to module owners.
;; : (-> UserModuleFlagEntryCandidate Boolean)
(def (poo-flow-use-module-flag-entry? value)
  (or (symbol? value)
      (and (pair? value)
           (symbol? (car value)))))

;;; Boundary: use module flag list predicate is the policy-visible edge for
;;; module-system behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> UserModuleFlagListCandidate Boolean)
(def (poo-flow-use-module-flag-list? values)
  (cond
   ((null? values) #t)
   ((pair? values)
    (and (poo-flow-use-module-flag-entry? (car values))
         (poo-flow-use-module-flag-list? (cdr values))))
   (else #f)))

;;; Module-level diagnostics run before row diagnostics so caller mistakes such
;;; as `(use-module workflow ...)` are reported against the requested module, not
;;; only against the derived `(custom . workflow)` selection row.
;; : (-> Symbol [PooUserModuleSelection] [Alist])
(def (poo-flow-use-module-contract-module-diagnostics module selections)
  (poo-flow-product-rows/tail
   (if (symbol? module)
     '()
     (list
      (poo-flow-use-module-contract-diagnostic
       'use-module-module-not-symbol
       "use-module expects a concrete module symbol"
       module
       selections)))
   (poo-flow-product-rows/tail
    (if (and (symbol? module)
             (poo-flow-use-module-category-symbol? module))
      (list
       (poo-flow-use-module-contract-diagnostic
        'use-module-category-as-module
        "use-module expects a concrete module, not a category"
        module
        '((category-symbols . (workflow flow sandbox loop custom))
          (example . (use-module funflow)))))
      '())
    (if (list? selections)
      '()
      (list
       (poo-flow-use-module-contract-diagnostic
        'use-module-selection-list-not-list
        "use-module must return a list of module selection objects"
        module
        selections))))))

;;; The module-system key is the canonical category/module pair. Validating it
;;; here prevents `(use-module workflow ...)` from degrading into a custom row.
;; : (-> Symbol PooUserModuleSelectionCandidate [Alist])
(def (poo-flow-use-module-contract-diagnostic/unless valid?
                                                        code
                                                        message
                                                        module
                                                        value)
  (if valid?
    '()
    (list
     (poo-flow-use-module-contract-diagnostic code message module value))))

;; : (-> Symbol Symbol Symbol [Alist])
(def (poo-flow-use-module-contract-group-mismatch-diagnostics module
                                                              group
                                                              selected-module)
  (let (expected-group
        (and (symbol? selected-module)
             (poo-flow-modules-system-use-module-group selected-module)))
    (poo-flow-use-module-contract-diagnostic/unless
     (and (symbol? group)
          expected-group
          (eq? group expected-group))
     'use-module-group-mismatch
     "use-module selection group must match module routing"
     module
     (poo-flow-product-field-rows
      (group group)
      (module selected-module)
      (expected-group expected-group)))))

;;; Boundary: use module contract category module diagnostics is the policy-
;;; visible edge for module-system behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> Symbol Symbol [Alist])
(def (poo-flow-use-module-contract-category-module-diagnostics module
                                                               selected-module)
  (if (and (symbol? selected-module)
           (poo-flow-use-module-category-symbol? selected-module))
    (list
     (poo-flow-use-module-contract-diagnostic
      'use-module-selection-category-as-module
      "use-module selection stores a category where a module is required"
      module
      selected-module))
    '()))

;; : (-> Symbol Symbol Symbol [Alist])
(def (poo-flow-use-module-contract-selection-field-diagnostics module
                                                               group
                                                               selected-module
                                                               flags)
  (append
   (poo-flow-use-module-contract-diagnostic/unless
    (symbol? group)
    'use-module-group-not-symbol
    "use-module selection group must be a symbol"
    module
    group)
   (poo-flow-use-module-contract-diagnostic/unless
    (symbol? selected-module)
    'use-module-selected-module-not-symbol
    "use-module selection module must be a symbol"
    module
    selected-module)
   (poo-flow-use-module-contract-category-module-diagnostics
    module
    selected-module)
   (poo-flow-use-module-contract-group-mismatch-diagnostics
    module
    group
    selected-module)
   (poo-flow-use-module-contract-diagnostic/unless
    (poo-flow-use-module-flag-list? flags)
    'use-module-flags-invalid
    "use-module selection flags must be symbols or symbol-keyed entries"
    module
    flags)))

;;; Boundary: use module contract selection diagnostics is the policy-visible
;;; edge for module-system behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> Symbol PooUserModuleSelectionCandidate [Alist])
(def (poo-flow-use-module-contract-selection-diagnostics module selection)
  (if (poo-flow-user-module-selection? selection)
    (let* ((key (poo-flow-user-module-selection-key selection))
           (group (car key))
           (selected-module (cdr key))
           (flags (poo-flow-user-module-selection-flags selection)))
      (poo-flow-use-module-contract-selection-field-diagnostics
       module
       group
       selected-module
       flags))
    (list
     (poo-flow-use-module-contract-diagnostic
      'use-module-selection-not-object
      "use-module returned a non-selection value"
      module
      selection))))

;;; Boundary: use module contract selections diagnostics is the policy-visible
;;; edge for module-system behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> Symbol [PooUserModuleSelection] [Alist])
(def (poo-flow-use-module-contract-selections-diagnostics module selections)
  (cond
   ((null? selections) '())
   ((pair? selections)
    (append (poo-flow-use-module-contract-selection-diagnostics
             module
             (car selections))
            (poo-flow-use-module-contract-selections-diagnostics
             module
             (cdr selections))))
   (else '())))

;;; Validation stays receipt-shaped because callers may want diagnostics without
;;; aborting module load. The checks are deliberately limited to declaration
;;; shape: concrete module symbol, routed group, selection object, and flag
;;; entry shape. Catalog resolution and backend profile validation happen later.
;; : (-> Symbol [PooUserModuleSelection] Alist)
(def (poo-flow-use-module-contract-validation module selections)
  (let* ((module-diagnostics
          (poo-flow-use-module-contract-module-diagnostics module selections))
         (selection-diagnostics
          (if (list? selections)
            (poo-flow-use-module-contract-selections-diagnostics
             module
             selections)
            '()))
         (diagnostics
          (append module-diagnostics selection-diagnostics)))
    (list
     (cons 'kind poo-flow-use-module-contract-validation-kind)
     (cons 'schema poo-flow-use-module-contract-validation-schema)
     (cons 'module module)
     (cons 'selection-count
           (if (list? selections) (length selections) 0))
     (cons 'valid (null? diagnostics))
     (cons 'diagnostics diagnostics)
     (cons 'checked-signals
           '(concrete-module-symbol
             category-not-used-as-module
             selection-list
             selection-object-kind
             routed-group
             symbol-keyed-flags)))))

;;; Projection helpers intentionally keep the receipt as an alist, not a POO
;;; object, because macro callers need simple diagnostics during expansion/load
;;; tests. Runtime adapters should consume later module objects, not this gate.
;; : (-> PooUseModuleContractValidation Boolean)
(def (poo-flow-use-module-contract-validation-valid? validation)
  (let (entry (assoc 'valid validation))
    (and entry (cdr entry))))

;;; Boundary: use module contract validation diagnostics is the policy-visible
;;; edge for module-system behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> PooUseModuleContractValidation [Alist])
(def (poo-flow-use-module-contract-validation-diagnostics validation)
  (let (entry (assoc 'diagnostics validation))
    (if entry (cdr entry) '())))

;;; Public `use-module` calls use this fail-fast gate so category/module
;;; mistakes stop at declaration load. This keeps `(use-module workflow ...)`
;;; from silently becoming `(custom . workflow)` before presentation or resolver
;;; code has a chance to inspect it.
;; : (-> Symbol [PooUserModuleSelection] [PooUserModuleSelection])
(def (poo-flow-require-use-module-contract! module selections)
  (let (validation (poo-flow-use-module-contract-validation module selections))
    (if (poo-flow-use-module-contract-validation-valid? validation)
      selections
      (error "poo-flow use-module declaration failed contract validation"
             validation))))

;;; Macro expansion routes through this wrapper, not the primitive constructor,
;;; so every syntax branch shares one contract surface. Tests may still call the
;;; primitive when they need to construct intentionally invalid receipts.
;; : (-> Symbol [UserModuleFlagEntry] [PooUserModuleSelection])
(def (poo-flow-modules-system-use-module/contract module flags)
  (let (selections (poo-flow-require-use-module-contract!
                    module (poo-flow-modules-system-use-module module flags)))
    (if (eq? module 'ai-agentic-context)
      (let* ((descriptor (poo-flow-ai-agentic-context-module
                          (if (memq '+memory flags) #t #f)))
             (manifest (.ref (.ref descriptor 'config) 'feature-manifest)))
        (map (lambda (selection)
               (.o (:: @ selection) module-descriptor: descriptor
                   feature-manifest: manifest)) selections))
      selections)))
