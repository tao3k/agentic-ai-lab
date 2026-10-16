;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: hygienic Doom-style module selection syntax.
;;; Invariant: expansion produces POO selection values only; source discovery,
;;; descriptor realization, and runtime effects stay behind loader boundaries.

(import (only-in :poo-flow/modules/user-interface/module-selection
                 poo-flow-user-module-bundle
                 poo-flow-user-custom-modules-selection
                 poo-flow-user-module-selection))

(export poo-flow-modules!)

;;; Engineering note: the category walker preserves declaration order and
;;; transfers control only when it encounters the next literal category marker.
;;   : (forall (module flag) (-> Symbol [(Pair module [flag])] [[PooUserModuleSelection]]))
;; poo-flow-modules/category
;;   : (-> ModuleCategory ModuleRows ModuleSelectionBundles)
;;   | contract: lower one qualified category segment into POO selection bundles
;;   | result: ordered bundles followed by bundles from subsequent category segments
;;   | doc m%
;;       Category rows contain module names and optional flags. Expansion quotes
;;       the qualified category/module identity without loading module sources.
;;
;;       # Examples
;;       ```scheme
;;       (poo-flow-modules/category flow (funflow +dag))
;;       ;; => one ((flow . funflow)) selection bundle
;;       ```
;;     %
(defrules poo-flow-modules/category
  (:core :flow :workflow :session :loop :sandbox :custom)
  ((_ category) '())
  ((_ category :core row ...) (poo-flow-modules! :core row ...))
  ((_ category :flow row ...) (poo-flow-modules! :flow row ...))
  ((_ category :workflow row ...) (poo-flow-modules! :flow row ...))
  ((_ category :session row ...) (poo-flow-modules! :session row ...))
  ((_ category :loop row ...) (poo-flow-modules! :loop row ...))
  ((_ category :sandbox row ...) (poo-flow-modules! :sandbox row ...))
  ((_ category :custom row ...) (poo-flow-modules! :custom row ...))
  ((_ category (module flag ...) row ...)
   (cons (poo-flow-user-module-bundle (category module flag ...))
         (poo-flow-modules/category category row ...))))

;;; Engineering note: ordinary custom rows are source-neutral. A user-owned
;;; private directory is the explicit `(module @ root flags ...)` escape hatch.
;;   : (forall (module root flag) (-> [(Pair module (Pair root [flag]))] [[PooUserModuleSelection]]))
;; poo-flow-modules/custom
;;   : (-> CustomModuleRows ModuleSelectionBundles)
;;   | contract: lower source-neutral rows and explicit @ roots into POO bundles
;;   | result: ordered custom bundles followed by any later qualified categories
;;   | doc m%
;;       Ordinary rows carry no source. An explicit root remains declaration
;;       data. Expansion never probes the filesystem or realizes a descriptor.
;;
;;       # Examples
;;       ```scheme
;;       (poo-flow-modules/custom (my-module @ "./modules/my-module" +doctor))
;;       ;; => one ((custom . my-module)) selection bundle
;;       ```
;;     %
(defrules poo-flow-modules/custom
  (:core :flow :workflow :session :loop :sandbox :custom @)
  ((_) '())
  ((_ :core row ...) (poo-flow-modules! :core row ...))
  ((_ :flow row ...) (poo-flow-modules! :flow row ...))
  ((_ :workflow row ...) (poo-flow-modules! :flow row ...))
  ((_ :session row ...) (poo-flow-modules! :session row ...))
  ((_ :loop row ...) (poo-flow-modules! :loop row ...))
  ((_ :sandbox row ...) (poo-flow-modules! :sandbox row ...))
  ((_ :custom row ...) (poo-flow-modules/custom row ...))
  ((_ (@ root flag ...) row ...)
   (cons (list (poo-flow-user-custom-modules-selection
                root (list 'flag ...)))
         (poo-flow-modules/custom row ...)))
  ((_ (module @ root flag ...) row ...)
   (cons (poo-flow-user-module-bundle (custom module root flag ...))
         (poo-flow-modules/custom row ...)))
  ((_ (module flag ...) row ...)
   (cons (list (poo-flow-user-module-selection
                'custom 'module (list 'flag ...)))
         (poo-flow-modules/custom row ...))))

;;; One macro serves the maintained collection and downstream init.ss files.
;;; Engineering note: literal markers make malformed top-level syntax fail at
;;; expansion time while leaving semantic flag validation to the data contract.
;;   : (forall (category module flag) (-> [(Pair category [(Pair module [flag])])] [[PooUserModuleSelection]]))
;; poo-flow-modules!
;;   : (-> QualifiedModuleDeclarations ModuleSelectionBundles)
;;   | contract: dispatch Doom-style category sections to hygienic row walkers
;;   | result: one ordered list of POO-native module selection bundles
;;   | doc m%
;;       The same declaration syntax is used by the repository-maintained
;;       collection and downstream init.ss files.
;;
;;       # Examples
;;       ```scheme
;;       (poo-flow-modules! :flow (funflow +dag))
;;       ;; => core and flow selection bundles in declaration order
;;       ```
;;     %
(defrules poo-flow-modules!
  (:core :flow :workflow :session :loop :sandbox :custom)
  ((_) '())
  ((_ :core row ...) (poo-flow-modules/category core row ...))
  ((_ :flow row ...) (poo-flow-modules/category flow row ...))
  ((_ :workflow row ...) (poo-flow-modules/category flow row ...))
  ((_ :session row ...) (poo-flow-modules/category session row ...))
  ((_ :loop row ...) (poo-flow-modules/category loop row ...))
  ((_ :sandbox row ...) (poo-flow-modules/category sandbox row ...))
  ((_ :custom row ...) (poo-flow-modules/custom row ...)))
