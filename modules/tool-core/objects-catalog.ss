;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO-native tool catalogs, lookups, and final projections.

(import (only-in :clan/poo/object .ref object? object<-alist)
        :yuanxu/utilities/final-projection-syntax
        :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/tool-core/objects-spec
        :agentic-ai-lab/modules/tool-core/objects-support)

(export +agentic-ai-lab-tool-core-catalog-kind+
        agentic-ai-lab-tool-catalog
        agentic-ai-lab-tool-catalog?
        agentic-ai-lab-tool-catalog-ref
        agentic-ai-lab-tool-catalog-tool-refs
        agentic-ai-lab-tool-catalog-tool-count
        agentic-ai-lab-tool-spec-find
        agentic-ai-lab-tool-catalog-find
        agentic-ai-lab-tool-catalog->alist)

(def +agentic-ai-lab-tool-core-catalog-kind+ 'agentic-ai-lab.tool-core.catalog)

;; : (-> [PooToolSpec] (Cons [Symbol] Integer))
(def (agentic-ai-lab-tool-catalog-summary tools)
  (cons (map agentic-ai-lab-tool-spec-ref tools)
        (length tools)))

;; : (-> Symbol [PooToolSpec] [Alist] PooToolCatalog)
(def (agentic-ai-lab-tool-catalog catalog-ref tools . maybe-metadata)
  (agentic-ai-lab-session-require "tool catalog ref must be a symbol"
                            (symbol? catalog-ref)
                            catalog-ref)
  (agentic-ai-lab-session-require "tool catalog tools must be specs"
                            (agentic-ai-lab-session-every? agentic-ai-lab-tool-spec?
                                                     tools)
                            tools)
  (let* ((catalog-summary (agentic-ai-lab-tool-catalog-summary tools))
         (tool-refs (car catalog-summary))
         (tool-count (cdr catalog-summary)))
    (object<-alist
     (list
      (cons 'kind +agentic-ai-lab-tool-core-catalog-kind+)
      (cons 'schema 'agentic-ai-lab.modules.tool-core.catalog.v1)
      (cons 'catalog-ref catalog-ref)
      (cons 'tools tools)
      (cons 'tool-refs tool-refs)
      (cons 'tool-count tool-count)
      (cons 'runtime-owner "marlin-agent-core")
      (cons 'runtime-executed #f)
      (cons 'metadata (if (null? maybe-metadata)
                          '()
                          (car maybe-metadata)))))))

;; : (-> POOObject Boolean)
(def (agentic-ai-lab-tool-catalog? value)
  (and (object? value)
       (eq? (agentic-ai-lab-tool-slot value 'kind #f)
            +agentic-ai-lab-tool-core-catalog-kind+)))

;; : (-> PooToolCatalog Symbol)
(def (agentic-ai-lab-tool-catalog-ref catalog)
  (.ref catalog 'catalog-ref))

;; : (-> PooToolCatalog [Symbol])
(def (agentic-ai-lab-tool-catalog-tool-refs catalog)
  (.ref catalog 'tool-refs))

;; : (-> PooToolCatalog Integer)
(def (agentic-ai-lab-tool-catalog-tool-count catalog)
  (.ref catalog 'tool-count))

;; : (-> [PooToolSpec] Symbol MaybePooToolSpec)
(def (agentic-ai-lab-tool-spec-find tools tool-ref)
  (cond
   ((null? tools) #f)
   ((eq? (agentic-ai-lab-tool-spec-ref (car tools)) tool-ref) (car tools))
   (else
    (agentic-ai-lab-tool-spec-find (cdr tools) tool-ref))))

;; : (-> PooToolCatalog Symbol MaybePooToolSpec)
(def (agentic-ai-lab-tool-catalog-find catalog tool-ref)
  (agentic-ai-lab-tool-spec-find (.ref catalog 'tools) tool-ref))

;; : (-> PooToolCatalog Alist)
(defpoo-final-projection
  agentic-ai-lab-tool-catalog->alist (catalog)
  (bindings ((checked-catalog
              (agentic-ai-lab-session-require
               "tool catalog projection requires a catalog"
               (agentic-ai-lab-tool-catalog? catalog)
               catalog))))
  (fields ((kind (.ref checked-catalog 'kind))
           (schema (.ref checked-catalog 'schema))
           (catalog-ref (.ref checked-catalog 'catalog-ref))
           (tool-count (.ref checked-catalog 'tool-count))
           (tool-refs (.ref checked-catalog 'tool-refs))
           (tools
            (agentic-ai-lab-tool-specs->alists (.ref checked-catalog 'tools)))
           (runtime-owner (.ref checked-catalog 'runtime-owner))
           (runtime-executed (.ref checked-catalog 'runtime-executed))
           (metadata (.ref checked-catalog 'metadata)))))
