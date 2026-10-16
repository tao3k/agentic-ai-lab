;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: user-facing Gerbil module authoring and catalog forms.
;;; Invariant: macros expand to hygienic Gerbil bindings and POO values.
;;; Intent: borrow Doom-style compactness without inventing an alist/record DSL.
;;; Parser policy should treat this file as syntax over the public POO API.

(import (only-in :clan/poo/object .o)
        :core/object-family/role-syntax
        :poo-flow/modules/user-interface/module-value-catalog)

(export defpoo-flow-module-object-block
        poo-flow-module-option-block
        poo-flow-module-hook-block
        poo-flow-module-when
        defpoo-flow-module-set)

;; : (forall (a) (-> [a] [a] [a]))
(def (poo-flow-module-set-values/tail values tail)
  (append values tail))

;; : (forall (a) (-> [[a]] [a] [a]))
(def (poo-flow-module-set-groups/tail groups tail)
  (if (null? groups)
    tail
    (poo-flow-module-set-values/tail
     (car groups)
     (poo-flow-module-set-groups/tail (cdr groups) tail))))

;; : (forall (a) (-> [a] [[a]] [a]))
(def (poo-flow-module-set-groups->values values groups)
  (poo-flow-module-set-values/tail
   values
   (poo-flow-module-set-groups/tail groups '())))

;;; Boundary: higher-order macro factory for hygienic POO slot blocks.
;;; The generated macro preserves caller bindings and only constructs POO values.
;;; It is not a DSL parser: keyword slots are Gerbil syntax accepted by .o.
;; defpoo-flow-module-object-block
;;   : (-> Identifier Syntax)
;;   | doc m%
;;       `defpoo-flow-module-object-block` documents the module-system boundary
;;       that the Gerbil policy harness treats as agent-facing behavior. The
;;       example keeps the call shape visible without duplicating
;;       implementation details.
;;
;;       # Examples
;;       ```scheme
;;       (defpoo-flow-module-object-block ...)
;;       ;; => policy-visible result
;;       ```
;;     %
(defrules defpoo-flow-module-object-block ()
  ((_ macro-name)
   (defrules macro-name ()
     ((_ . slots)
      (.o . slots)))))

;;; Boundary: option blocks are syntax for POO slot objects.
;;; The macro preserves keyword slots and performs no schema validation.
;;; Users may pass the result to interface schemas or module config values.
;; : (-> ModuleOptionKeywordSyntax... POOObject)
(defpoo-flow-module-object-block poo-flow-module-option-block)

;;; Boundary: hook blocks become POO objects consumed by descriptor projection.
;;; Hook payload identifiers stay quoted and are never invoked here.
;;; Each hook id owns one list of payload symbols for later runtime owners.
;; poo-flow-module-hook-block
;;   : (-> HookBlockSyntax... ModuleHooks)
;;   | doc m%
;;       `poo-flow-module-hook-block` documents the module-system boundary that
;;       the Gerbil policy harness treats as agent-facing behavior. The example
;;       keeps the call shape visible without duplicating implementation
;;       details.
;;
;;       # Examples
;;       ```scheme
;;       (poo-flow-module-hook-block ...)
;;       ;; => policy-visible result
;;       ```
;;     %
(defrules poo-flow-module-hook-block ()
  ((_ (hook-id hook-value ...) ...)
   (poo-core-role-object
    (slots ((hook-id (list 'hook-value ...)) ...))
    (supers (.o)))))

;;; Boundary: conditional module inclusion returns a module list.
;;; The condition is evaluated where the user writes the module set.
;;; No catalog lookup, activation, or source loading occurs in this helper.
;; poo-flow-module-when
;;   : (-> Boolean PooModuleDescriptor... [PooModuleDescriptor])
;;   | doc m%
;;       `poo-flow-module-when` documents the module-system boundary that the
;;       Gerbil policy harness treats as agent-facing behavior. The example
;;       keeps the call shape visible without duplicating implementation
;;       details.
;;
;;       # Examples
;;       ```scheme
;;       (poo-flow-module-when ...)
;;       ;; => policy-visible result
;;       ```
;;     %
(defrules poo-flow-module-when ()
  ((_ condition module ...)
   (if condition
     (list module ...)
     '())))

;;; Boundary: module-set syntax collects already-built POO module values.
;;; Clauses after the required modules block must evaluate to module lists.
;;; The generated catalog is a value catalog and remains activation-free.
;; defpoo-flow-module-set
;;   : (-> ModuleSetSyntax PooModuleValueCatalogExpansion)
;;   | doc m%
;;       `defpoo-flow-module-set` documents the module-system boundary that the
;;       Gerbil policy harness treats as agent-facing behavior. The example
;;       keeps the call shape visible without duplicating implementation
;;       details.
;;
;;       # Examples
;;       ```scheme
;;       (defpoo-flow-module-set ...)
;;       ;; => policy-visible result
;;       ```
;;     %
(defrules defpoo-flow-module-set (modules)
  ((_ binding
      (modules module ...)
      module-clause ...)
   (def binding
     (apply pooFlowModuleCatalog
            (poo-flow-module-set-groups->values
             (list module ...)
             (list module-clause ...))))))
