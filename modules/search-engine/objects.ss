;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Backend-neutral Search role objects and immutable declaration prototypes.
(import :yuanxu/object-family/role-syntax
        :agentic-ai-lab/modules/search-engine/types)

(export agentic-ai-lab-search-framework-role
        agentic-ai-lab-search-acquisition-role
        agentic-ai-lab-search-refinement-role
        agentic-ai-lab-search-reasoning-role
        agentic-ai-lab-search-projection-role
        agentic-ai-lab-search-stage-prototype
        agentic-ai-lab-search-composition-prototype
        agentic-ai-lab-search-strategy-prototype)

(def agentic-ai-lab-search-framework-role
  (poo-core-role-object
   (slots ((search/framework? #t)
           (search/factor? #f)
           (control-owner 'consumer)
           (execution-owner 'consumer-runtime)))
   (supers)))

(def agentic-ai-lab-search-acquisition-role
  (poo-core-role-object
   (slots ((search/factor? #t)
           (search/stage-role 'acquisition)))
   (supers agentic-ai-lab-search-framework-role)))

(def agentic-ai-lab-search-refinement-role
  (poo-core-role-object
   (slots ((search/factor? #t)
           (search/stage-role 'refinement)))
   (supers agentic-ai-lab-search-framework-role)))

(def agentic-ai-lab-search-reasoning-role
  (poo-core-role-object
   (slots ((search/factor? #t)
           (search/stage-role 'reasoning)))
   (supers agentic-ai-lab-search-framework-role)))

(def agentic-ai-lab-search-projection-role
  (poo-core-role-object
   (slots ((search/factor? #t)
           (search/stage-role 'projection)))
   (supers agentic-ai-lab-search-framework-role)))

(def agentic-ai-lab-search-stage-prototype
  (poo-core-role-object
   (slots ((schema +agentic-ai-lab-search-schema+)
           (kind 'search-stage)
           (name #f)
           (operation #f)
           (arguments '())
           (input-domain #f)
           (output-domain #f)
           (flow #f)
           (metadata '())))
   (supers agentic-ai-lab-search-framework-role)))

(def agentic-ai-lab-search-composition-prototype
  (poo-core-role-object
   (slots ((schema +agentic-ai-lab-search-schema+)
           (kind 'search-composition)
           (name #f)
           (mode #f)
           (children '())
           (input-domain #f)
           (output-domain #f)
           (flow #f)
           (metadata '())))
   (supers agentic-ai-lab-search-framework-role)))

(def agentic-ai-lab-search-strategy-prototype
  (poo-core-role-object
   (slots ((schema +agentic-ai-lab-search-schema+)
           (kind 'search-strategy)
           (name #f)
           (root #f)
           (policy '())
           (dag-receipt #f)
           (metadata '())))
   (supers agentic-ai-lab-search-framework-role)))
