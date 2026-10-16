;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: memory catalog objects and lookup helpers.

(import (only-in :clan/poo/object .o .ref object? object<-alist)
        :core/utilities/final-projection-syntax
        :poo-flow/modules/session/objects
        :poo-flow/modules/session/transform
        :poo-flow/modules/ai-agentic-context/features/memory/objects-core)

(export poo-flow-memory-catalog-summary
        poo-flow-memory-catalog
        poo-flow-memory-catalog?
        poo-flow-memory-catalog-ref
        poo-flow-memory-catalog-store-refs
        poo-flow-memory-catalog-store-count
        poo-flow-memory-store-spec-find
        poo-flow-memory-catalog-find
        poo-flow-memory-catalog->alist)

(def (poo-flow-memory-catalog-summary stores)
  (cons (map poo-flow-memory-store-spec-ref stores)
        (length stores)))

;; : (-> Symbol [PooMemoryStoreSpec] [Alist] PooMemoryCatalog)
(def (poo-flow-memory-catalog catalog-ref stores . maybe-metadata)
  (poo-flow-session-require "memory catalog ref must be a symbol"
                            (symbol? catalog-ref)
                            catalog-ref)
  (poo-flow-session-require "memory catalog stores must be specs"
                            (poo-flow-session-every? poo-flow-memory-store-spec?
                                                     stores)
                            stores)
  (let* ((catalog-summary (poo-flow-memory-catalog-summary stores))
         (store-refs (car catalog-summary))
         (store-count (cdr catalog-summary)))
    (object<-alist
     (list
      (cons 'kind +poo-flow-ai-agentic-context-memory-catalog-kind+)
      (cons 'schema 'poo-flow.modules.memory-core.catalog.v1)
      (cons 'catalog-ref catalog-ref)
      (cons 'stores stores)
      (cons 'store-refs store-refs)
      (cons 'store-count store-count)
      (cons 'runtime-owner "marlin-agent-core")
      (cons 'runtime-executed #f)
      (cons 'metadata (if (null? maybe-metadata)
                        '()
                        (car maybe-metadata)))))))

;; : (-> POOObject Boolean)
(def (poo-flow-memory-catalog? value)
  (and (object? value)
       (eq? (poo-flow-memory-slot value 'kind #f)
            +poo-flow-ai-agentic-context-memory-catalog-kind+)))

;; : (-> PooMemoryCatalog Symbol)
(def (poo-flow-memory-catalog-ref catalog)
  (.ref catalog 'catalog-ref))

;; : (-> PooMemoryCatalog [Symbol])
(def (poo-flow-memory-catalog-store-refs catalog)
  (.ref catalog 'store-refs))

;; : (-> PooMemoryCatalog Integer)
(def (poo-flow-memory-catalog-store-count catalog)
  (.ref catalog 'store-count))

;; : (-> [PooMemoryStoreSpec] Symbol MaybePooMemoryStoreSpec)
(def (poo-flow-memory-store-spec-find stores store-ref)
  (cond
   ((null? stores) #f)
   ((eq? (poo-flow-memory-store-spec-ref (car stores)) store-ref) (car stores))
   (else
    (poo-flow-memory-store-spec-find (cdr stores) store-ref))))

;; : (-> PooMemoryCatalog Symbol MaybePooMemoryStoreSpec)
(def (poo-flow-memory-catalog-find catalog store-ref)
  (poo-flow-memory-store-spec-find (.ref catalog 'stores) store-ref))
;; : (-> PooMemoryCatalog Alist)
(defpoo-final-projection
  poo-flow-memory-catalog->alist (catalog)
  (bindings ((checked-catalog
              (poo-flow-session-require
               "memory catalog projection requires a memory catalog"
               (poo-flow-memory-catalog? catalog)
               catalog))))
  (fields ((kind (.ref checked-catalog 'kind))
           (schema (.ref checked-catalog 'schema))
           (catalog-ref (.ref checked-catalog 'catalog-ref))
           (stores (.ref checked-catalog 'stores))
           (store-refs (.ref checked-catalog 'store-refs))
           (store-count (.ref checked-catalog 'store-count))
           (runtime-owner (.ref checked-catalog 'runtime-owner))
           (runtime-executed (.ref checked-catalog 'runtime-executed))
           (metadata (.ref checked-catalog 'metadata)))))
