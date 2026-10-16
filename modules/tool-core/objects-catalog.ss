;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO-native tool catalogs, lookups, and final projections.

(import (only-in :clan/poo/object .ref object? object<-alist)
        :core/utilities/final-projection-syntax
        :poo-flow/modules/session/objects
        :poo-flow/modules/tool-core/objects-spec
        :poo-flow/modules/tool-core/objects-support)

(export +poo-flow-tool-core-catalog-kind+
        poo-flow-tool-catalog
        poo-flow-tool-catalog?
        poo-flow-tool-catalog-ref
        poo-flow-tool-catalog-tool-refs
        poo-flow-tool-catalog-tool-count
        poo-flow-tool-spec-find
        poo-flow-tool-catalog-find
        poo-flow-tool-catalog->alist)

(def +poo-flow-tool-core-catalog-kind+ 'poo-flow.tool-core.catalog)

;; : (-> [PooToolSpec] (Cons [Symbol] Integer))
(def (poo-flow-tool-catalog-summary tools)
  (cons (map poo-flow-tool-spec-ref tools)
        (length tools)))

;; : (-> Symbol [PooToolSpec] [Alist] PooToolCatalog)
(def (poo-flow-tool-catalog catalog-ref tools . maybe-metadata)
  (poo-flow-session-require "tool catalog ref must be a symbol"
                            (symbol? catalog-ref)
                            catalog-ref)
  (poo-flow-session-require "tool catalog tools must be specs"
                            (poo-flow-session-every? poo-flow-tool-spec?
                                                     tools)
                            tools)
  (let* ((catalog-summary (poo-flow-tool-catalog-summary tools))
         (tool-refs (car catalog-summary))
         (tool-count (cdr catalog-summary)))
    (object<-alist
     (list
      (cons 'kind +poo-flow-tool-core-catalog-kind+)
      (cons 'schema 'poo-flow.modules.tool-core.catalog.v1)
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
(def (poo-flow-tool-catalog? value)
  (and (object? value)
       (eq? (poo-flow-tool-slot value 'kind #f)
            +poo-flow-tool-core-catalog-kind+)))

;; : (-> PooToolCatalog Symbol)
(def (poo-flow-tool-catalog-ref catalog)
  (.ref catalog 'catalog-ref))

;; : (-> PooToolCatalog [Symbol])
(def (poo-flow-tool-catalog-tool-refs catalog)
  (.ref catalog 'tool-refs))

;; : (-> PooToolCatalog Integer)
(def (poo-flow-tool-catalog-tool-count catalog)
  (.ref catalog 'tool-count))

;; : (-> [PooToolSpec] Symbol MaybePooToolSpec)
(def (poo-flow-tool-spec-find tools tool-ref)
  (cond
   ((null? tools) #f)
   ((eq? (poo-flow-tool-spec-ref (car tools)) tool-ref) (car tools))
   (else
    (poo-flow-tool-spec-find (cdr tools) tool-ref))))

;; : (-> PooToolCatalog Symbol MaybePooToolSpec)
(def (poo-flow-tool-catalog-find catalog tool-ref)
  (poo-flow-tool-spec-find (.ref catalog 'tools) tool-ref))

;; : (-> PooToolCatalog Alist)
(defpoo-final-projection
  poo-flow-tool-catalog->alist (catalog)
  (bindings ((checked-catalog
              (poo-flow-session-require
               "tool catalog projection requires a catalog"
               (poo-flow-tool-catalog? catalog)
               catalog))))
  (fields ((kind (.ref checked-catalog 'kind))
           (schema (.ref checked-catalog 'schema))
           (catalog-ref (.ref checked-catalog 'catalog-ref))
           (tool-count (.ref checked-catalog 'tool-count))
           (tool-refs (.ref checked-catalog 'tool-refs))
           (tools
            (poo-flow-tool-specs->alists (.ref checked-catalog 'tools)))
           (runtime-owner (.ref checked-catalog 'runtime-owner))
           (runtime-executed (.ref checked-catalog 'runtime-executed))
           (metadata (.ref checked-catalog 'metadata)))))
