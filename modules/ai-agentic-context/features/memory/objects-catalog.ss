;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: memory catalog objects and lookup helpers.

(import (only-in :clan/poo/object .o .ref object? object<-alist)
        :yuanxu/utilities/final-projection-syntax
        :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/session/transform
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/objects-core)

(export agentic-ai-lab-memory-catalog-summary
        agentic-ai-lab-memory-catalog
        agentic-ai-lab-memory-catalog?
        agentic-ai-lab-memory-catalog-ref
        agentic-ai-lab-memory-catalog-store-refs
        agentic-ai-lab-memory-catalog-store-count
        agentic-ai-lab-memory-store-spec-find
        agentic-ai-lab-memory-catalog-find
        agentic-ai-lab-memory-catalog->alist)

(def (agentic-ai-lab-memory-catalog-summary stores)
  (cons (map agentic-ai-lab-memory-store-spec-ref stores)
        (length stores)))

;; : (-> Symbol [PooMemoryStoreSpec] [Alist] PooMemoryCatalog)
(def (agentic-ai-lab-memory-catalog catalog-ref stores . maybe-metadata)
  (agentic-ai-lab-session-require "memory catalog ref must be a symbol"
                            (symbol? catalog-ref)
                            catalog-ref)
  (agentic-ai-lab-session-require "memory catalog stores must be specs"
                            (agentic-ai-lab-session-every? agentic-ai-lab-memory-store-spec?
                                                     stores)
                            stores)
  (let* ((catalog-summary (agentic-ai-lab-memory-catalog-summary stores))
         (store-refs (car catalog-summary))
         (store-count (cdr catalog-summary)))
    (object<-alist
     (list
      (cons 'kind +agentic-ai-lab-ai-agentic-context-memory-catalog-kind+)
      (cons 'schema 'agentic-ai-lab.modules.memory-core.catalog.v1)
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
(def (agentic-ai-lab-memory-catalog? value)
  (and (object? value)
       (eq? (agentic-ai-lab-memory-slot value 'kind #f)
            +agentic-ai-lab-ai-agentic-context-memory-catalog-kind+)))

;; : (-> PooMemoryCatalog Symbol)
(def (agentic-ai-lab-memory-catalog-ref catalog)
  (.ref catalog 'catalog-ref))

;; : (-> PooMemoryCatalog [Symbol])
(def (agentic-ai-lab-memory-catalog-store-refs catalog)
  (.ref catalog 'store-refs))

;; : (-> PooMemoryCatalog Integer)
(def (agentic-ai-lab-memory-catalog-store-count catalog)
  (.ref catalog 'store-count))

;; : (-> [PooMemoryStoreSpec] Symbol MaybePooMemoryStoreSpec)
(def (agentic-ai-lab-memory-store-spec-find stores store-ref)
  (cond
   ((null? stores) #f)
   ((eq? (agentic-ai-lab-memory-store-spec-ref (car stores)) store-ref) (car stores))
   (else
    (agentic-ai-lab-memory-store-spec-find (cdr stores) store-ref))))

;; : (-> PooMemoryCatalog Symbol MaybePooMemoryStoreSpec)
(def (agentic-ai-lab-memory-catalog-find catalog store-ref)
  (agentic-ai-lab-memory-store-spec-find (.ref catalog 'stores) store-ref))
;; : (-> PooMemoryCatalog Alist)
(defpoo-final-projection
  agentic-ai-lab-memory-catalog->alist (catalog)
  (bindings ((checked-catalog
              (agentic-ai-lab-session-require
               "memory catalog projection requires a memory catalog"
               (agentic-ai-lab-memory-catalog? catalog)
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
