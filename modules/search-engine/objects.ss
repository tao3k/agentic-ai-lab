;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Backend-neutral Search role objects and immutable declaration prototypes.
(import :core/object-family/role-syntax
        :poo-flow/modules/search-engine/types)

(export poo-flow-search-framework-role
        poo-flow-search-acquisition-role
        poo-flow-search-refinement-role
        poo-flow-search-reasoning-role
        poo-flow-search-projection-role
        poo-flow-search-stage-prototype
        poo-flow-search-composition-prototype
        poo-flow-search-strategy-prototype)

(def poo-flow-search-framework-role
  (poo-core-role-object
   (slots ((search/framework? #t)
           (search/factor? #f)
           (control-owner 'consumer)
           (execution-owner 'consumer-runtime)))
   (supers)))

(def poo-flow-search-acquisition-role
  (poo-core-role-object
   (slots ((search/factor? #t)
           (search/stage-role 'acquisition)))
   (supers poo-flow-search-framework-role)))

(def poo-flow-search-refinement-role
  (poo-core-role-object
   (slots ((search/factor? #t)
           (search/stage-role 'refinement)))
   (supers poo-flow-search-framework-role)))

(def poo-flow-search-reasoning-role
  (poo-core-role-object
   (slots ((search/factor? #t)
           (search/stage-role 'reasoning)))
   (supers poo-flow-search-framework-role)))

(def poo-flow-search-projection-role
  (poo-core-role-object
   (slots ((search/factor? #t)
           (search/stage-role 'projection)))
   (supers poo-flow-search-framework-role)))

(def poo-flow-search-stage-prototype
  (poo-core-role-object
   (slots ((schema +poo-flow-search-schema+)
           (kind 'search-stage)
           (name #f)
           (operation #f)
           (arguments '())
           (input-domain #f)
           (output-domain #f)
           (flow #f)
           (metadata '())))
   (supers poo-flow-search-framework-role)))

(def poo-flow-search-composition-prototype
  (poo-core-role-object
   (slots ((schema +poo-flow-search-schema+)
           (kind 'search-composition)
           (name #f)
           (mode #f)
           (children '())
           (input-domain #f)
           (output-domain #f)
           (flow #f)
           (metadata '())))
   (supers poo-flow-search-framework-role)))

(def poo-flow-search-strategy-prototype
  (poo-core-role-object
   (slots ((schema +poo-flow-search-schema+)
           (kind 'search-strategy)
           (name #f)
           (root #f)
           (policy '())
           (dag-receipt #f)
           (metadata '())))
   (supers poo-flow-search-framework-role)))
