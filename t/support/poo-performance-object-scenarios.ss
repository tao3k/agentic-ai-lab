;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: reusable native POO object scenarios for performance gates.

(import (only-in :clan/poo/object .ref)
        :yuanxu/module-system/schema/interface
        :yuanxu/graph/interface
        :yuanxu/module-system/schema/validation)

(export poo-performance-slot-ref/default
        poo-performance-build-list
        poo-performance-field-name
        poo-performance-field-contract
        poo-performance-field-contracts
        poo-performance-module-object
        poo-performance-module-object-catalog
        poo-performance-contribution-entries
        poo-performance-catalog-contributions
        poo-performance-override-slots
        poo-performance-snapshot-sum
        poo-performance-object-node-lookup-count
        poo-performance-extension-child-name
        poo-performance-extension-child
        poo-performance-extension-children
        poo-performance-extension-merge-root
        poo-performance-extension-node-extend-operations
        poo-performance-cross-contribution-child-name
        poo-performance-cross-contribution-child
        poo-performance-cross-contribution-create-operations
        poo-performance-cross-contribution-targeting-contributions
        poo-performance-local-slot-contributions)

;; : (-> Alist Symbol Value Value)
(def (poo-performance-slot-ref/default slots key default-value)
  (let (entry (assoc key slots))
    (if entry (cdr entry) default-value)))

;; poo-performance-build-list
;;   : (-> Integer (-> Integer Value) [Value])
;;   | doc m%
;;       `poo-performance-build-list count make-value` builds deterministic
;;       index-addressed fixture lists for synthetic benchmark data.
;;
;;       # Examples
;;       ```scheme
;;       (poo-performance-build-list 3 (lambda (index) index))
;;       ;; => (0 1 2)
;;       ```
;;     %
(def (poo-performance-build-list count make-value)
  (map make-value (iota count)))

;; : (-> Integer Symbol)
(def (poo-performance-field-name index)
  (string->symbol
   (string-append "field-" (number->string index))))

;; : (-> Integer PooModuleFieldContract)
(def (poo-performance-field-contract index)
  (yuanxu-module-field-contract
   (poo-performance-field-name index)
   YuanxuModuleAnyType
   'override
   index
   '((scenario . poo-performance))))

;; : (-> Integer [PooModuleFieldContract])
(def (poo-performance-field-contracts count)
  (poo-performance-build-list count poo-performance-field-contract))

;; : (-> Integer PooModuleObject)
(def (poo-performance-module-object field-count)
  (yuanxu-module-object
   'performance-object
   '()
   (poo-performance-field-contracts field-count)
   '((scenario . poo-performance))))

;; : (-> Integer Integer [PooModuleObject])
(def (poo-performance-module-object-catalog object-count field-count)
  (let (base-object
        (yuanxu-module-object
         'performance-base
         '()
         (poo-performance-field-contracts field-count)
         '((scenario . poo-performance-base))))
    (poo-performance-build-list
     object-count
     (lambda (index)
       (yuanxu-module-object
        (string->symbol
         (string-append "performance-child-"
                        (number->string index)))
        (list base-object)
        '()
        '((scenario . poo-performance-child)))))))

;; : (-> Integer PooModuleObjectContributionEntries)
(def (poo-performance-contribution-entries count)
  (poo-performance-build-list
   count
   (lambda (index)
     (cons (poo-performance-field-name index)
           (+ index 1000)))))

;; poo-performance-catalog-contributions
;;   : (-> [PooModuleObject] Integer [PooModuleFieldContribution])
;;   | doc m%
;;       `poo-performance-catalog-contributions objects field-count` projects
;;       one shared contribution-entry fixture through every object in order.
;;
;;       # Examples
;;       ```scheme
;;       (length (poo-performance-catalog-contributions
;;                (poo-performance-module-object-catalog 2 3)
;;                3))
;;       ;; => 6
;;       ```
;;     %
(def (poo-performance-values/rev-onto values values-rev)
  (let loop ((remaining-values values)
             (result values-rev))
    (if (null? remaining-values)
      result
      (loop (cdr remaining-values)
            (cons (car remaining-values) result)))))

;; : (-> [PooModuleObject] PooModuleObjectContributionEntries [PooModuleFieldContribution] [PooModuleFieldContribution])
(def (poo-performance-object-contributions/rev objects entries contributions-rev)
  (if (null? objects)
    contributions-rev
    (poo-performance-object-contributions/rev
     (cdr objects)
     entries
     (poo-performance-values/rev-onto
      (yuanxu-module-object-contributions (car objects) entries)
      contributions-rev))))

;; : (-> [PooModuleObject] Integer [PooModuleFieldContribution])
(def (poo-performance-catalog-contributions objects field-count)
  (let (entries (poo-performance-contribution-entries field-count))
    (reverse
     (poo-performance-object-contributions/rev objects entries '()))))

;; : (-> Integer Integer PooModuleSlotMap)
(def (poo-performance-override-slots count key-span)
  (poo-performance-build-list
   count
   (lambda (index)
     (cons (poo-performance-field-name (modulo index key-span))
           (+ index 2000)))))

;; poo-performance-snapshot-sum
;;   : (-> [Pair] Integer Integer)
;;   | doc m%
;;       `poo-performance-snapshot-sum slots rounds` repeats the same
;;       materialized slot-value sum to keep benchmark loops scalar and stable.
;;
;;       # Examples
;;       ```scheme
;;       (poo-performance-snapshot-sum '((a . 1) (b . 2)) 3)
;;       ;; => 9
;;       ```
;;     %
(def (poo-performance-snapshot-sum slots rounds)
  (* rounds (apply + (map cdr slots))))

;; poo-performance-object-node-lookup-count
;;   : (-> YuanxuGraph [Symbol] Integer Integer)
;;   | doc m%
;;       `poo-performance-object-node-lookup-count objects-node identities
;;       rounds` counts indexed object hits once, then scales by benchmark rounds.
;;
;;       # Examples
;;       ```scheme
;;       (poo-performance-object-node-lookup-count
;;        (yuanxu-module-objects-node
;;         (poo-performance-module-object-catalog 2 1))
;;        '(performance-child-0 missing)
;;        3)
;;       ;; => 3
;;       ```
;;     %
(def (poo-performance-object-node-lookup-count objects-node identities rounds)
  (let (objects-index (yuanxu-module-objects-index objects-node))
    (* rounds
       (length
        (filter (lambda (identity)
                  (yuanxu-module-objects-ref/index objects-index identity))
                identities)))))

;; : (-> Integer Symbol)
(def (poo-performance-extension-child-name index)
  (string->symbol
   (string-append "extension-child-" (number->string index))))

;; : (-> Integer Integer YuanxuGraph)
(def (poo-performance-extension-child index slot-offset)
  (yuanxu-graph-rooted
   (poo-performance-extension-child-name index)
   (list (cons 'value (+ slot-offset index)))
   '()))

;; : (-> Integer Integer [YuanxuGraph])
(def (poo-performance-extension-children count slot-offset)
  (poo-performance-build-list
   count
   (lambda (index)
     (poo-performance-extension-child index slot-offset))))

;; : (-> Integer YuanxuGraph)
(def (poo-performance-extension-merge-root count)
  (yuanxu-graph-rooted
   'extension-root
   '((kind . extension-merge-root))
   (poo-performance-extension-children count 1000)))

;; : (-> Integer Integer [PooGraphOperation])
(def (poo-performance-extension-node-extend-operations count key-span)
  (poo-performance-build-list
   count
   (lambda (index)
     (yuanxu-graph-node-extend
      (yuanxu-graph-rooted
       (poo-performance-extension-child-name (modulo index key-span))
       (list (cons 'value (+ 2000 index)))
       '())))))

;; : (-> Integer Symbol)
(def (poo-performance-cross-contribution-child-name index)
  (string->symbol
   (string-append "cross-contribution-child-" (number->string index))))

;; : (-> Integer YuanxuGraph)
(def (poo-performance-cross-contribution-child index)
  (yuanxu-graph-rooted
   (poo-performance-cross-contribution-child-name index)
   (list (cons 'created-order index))
   '()))

;; : (-> Integer [PooGraphOperation])
(def (poo-performance-cross-contribution-create-operations count)
  (poo-performance-build-list
   count
   (lambda (index)
     (yuanxu-graph-node-extend
      (poo-performance-cross-contribution-child index)))))

;; : (-> PooObject Symbol Value Value)
(def (agentic-ai-lab-performance-ref object key default)
  (try
    (.ref object key)
    (catch (e) default)))

;; : (-> PooObject Value)
(def (poo-performance-object-index-identity object)
  (or (agentic-ai-lab-performance-ref object 'identity #f)
      (agentic-ai-lab-performance-ref object 'name #f)))

;; : (-> [PooObject] HashTable)
(def (poo-performance-object-list-index objects)
  (let (index (make-hash-table))
    (for-each
     (lambda (object)
       (let (identity (poo-performance-object-index-identity object))
         (if identity
           (hash-put! index identity object)
           #f)))
     objects)
    index))

;; : (-> PooModuleObjectsNode HashTable)
(def (yuanxu-module-objects-index objects)
  (if (list? objects)
    (poo-performance-object-list-index objects)
    (let ((objects-index (agentic-ai-lab-performance-ref objects 'objects-index #f)))
      (if objects-index
        objects-index
        (let ((index (agentic-ai-lab-performance-ref objects 'index #f)))
          (if index
            index
            (let ((children (agentic-ai-lab-performance-ref objects 'children #f)))
              (if children
                (poo-performance-object-list-index children)
                (poo-performance-object-list-index
                 (agentic-ai-lab-performance-ref objects 'modules []))))))))))

;; : (-> Integer Symbol [PooGraphContribution])
(def (poo-performance-cross-contribution-targeting-contributions child-count target)
  (list
   (yuanxu-graph-contribution
    'extension-root
    (poo-performance-cross-contribution-create-operations child-count))
   (yuanxu-graph-contribution
    target
    (list (yuanxu-graph-slot-override 'targeted? #t)
          (yuanxu-graph-slot-override 'target-phase 'same-pass)))))

;; : (-> Symbol Integer [PooGraphContribution])
(def (poo-performance-local-slot-contributions target count)
  (poo-performance-build-list
   count
   (lambda (index)
     (yuanxu-graph-contribution
      target
      (list
       (yuanxu-graph-slot-override
        (poo-performance-field-name index)
        index))))))
