;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: executable POO best-practice guard for module object layering.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         :gerbil/runtime/gambit
        (only-in :std/test
                 check
                 check-eq?
                 check-equal?
                 check-false
                 check-not-equal?
                 check-output
                 check-true
                 test-error
                 test-suite)
        "./support/performance"
        (only-in :asp-gerbil-scheme/benchmark-api benchmark-p95-elapsed-ms)
        :core/graph/interface
        :core/module-system/schema/interface)

(export module-object-practice-test)

;; : (-> PooFlowGraph Symbol MaybeAny)
(def (slot-value node slot-name)
  (let (entry (assoc slot-name (poo-flow-graph-root-payload node)))
    (if entry (cdr entry) #f)))

;; : (-> Integer Symbol)
(def (large-object-field-name index)
  (string->symbol
   (string-append "field-" (number->string index))))

;; : (-> Integer PooModuleFieldContract)
(def (large-object-field index)
  (poo-flow-module-field-contract
   (large-object-field-name index)
   PooFlowModuleAnyType
   'override
   #f
   '((scope . large-object-performance)
     (owner . object-core))))

;; : (-> Integer PooModuleFieldContract)
(def (large-object-list-field index)
  (poo-flow-module-field-contract
   (large-object-field-name index)
   PooFlowModuleListType
   'append
   '()
   '((scope . large-object-performance)
     (owner . object-core))))

;; : TestSuite
;;; This suite keeps object-extension examples executable as policy evidence for
;;; downstream module authors.
;; : TestCase
(def (module-object-practice-projection-case)
  (poo-flow-test-case "projects object-owned field contracts into the extension graph"
        (let* ((capabilities-field
                (poo-flow-module-field-contract
                 'capabilities
                 PooFlowModuleListType
                 'append
                 '(filesystem-read)
                 '((scope . best-practice)
                   (owner . object-core))))
               (note-field
                (poo-flow-module-field-contract
                 'note
                 PooFlowModuleStringType
                 'override
                 "unset"
                 '((scope . best-practice)
                   (owner . object-core))))
               (practice-object
                (poo-flow-module-object
                 'objects.practice.profile
                 '()
                 (list capabilities-field note-field)
                 '((namespace . objects.practice)
                   (domain . profile))))
               (base-node
                (poo-flow-module-object-node practice-object '() '()))
               (contributions
                (poo-flow-module-object-contributions
                 practice-object
                 '((capabilities . (process-run cache-mount))
                   (note . "object-core owns contract wrappers"))))
               (extension-contributions
                (poo-flow-module-field-contributions->extensions contributions))
               (merge-result
                (poo-flow-module-field-contributions-resolve
                 base-node contributions))
               (resolved-node
                (poo-flow-module-field-resolution-result-root merge-result)))
          (check-equal? (poo-flow-module-object? practice-object) #t)
          (check-equal? (map poo-flow-module-field-contract-identity
                             (poo-flow-module-object-resolved-fields
                              practice-object))
                        '(capabilities note))
          (check-equal? (map poo-flow-module-field-contribution? contributions)
                        '(#t #t))
          (check-equal? (map poo-flow-graph-contribution?
                             extension-contributions)
                        '(#t #t))
          (check-equal? (poo-flow-module-field-resolution-result? merge-result) #t)
          (check-equal? (poo-flow-module-field-resolution-result-applied?
                         merge-result)
                        #t)
          (check-equal? (poo-flow-module-field-resolution-result-contributions
                         merge-result)
                        contributions)
          (check-equal? (slot-value resolved-node 'capabilities)
                        '(filesystem-read process-run cache-mount))
          (check-equal? (slot-value resolved-node 'note)
                        "object-core owns contract wrappers"))))

;; : TestCase
(def (module-object-practice-contribution-performance-case)
  (poo-flow-test-case "keeps large object contribution projection linear"
        (let* ((field-count 1000)
               (fields
                (poo-flow-performance-build-list field-count large-object-field))
               (practice-object
                (poo-flow-module-object
                 'objects.practice.large
                 '()
                 fields
                 '((namespace . objects.practice)
                   (domain . performance))))
               (entries
                (poo-flow-performance-build-list
                 field-count
                 (lambda (index)
                   (cons (large-object-field-name index)
                         (list index)))))
               (start-jiffy (current-jiffy))
               (contributions
                (poo-flow-module-object-contributions practice-object entries))
               (elapsed-ms
                (/ (* (- (current-jiffy) start-jiffy) 1000)
                   (jiffies-per-second)))
               (best-ms
                (benchmark-p95-elapsed-ms
                 5
                 (lambda ()
                   (poo-flow-module-object-contributions practice-object
                                                         entries)))))
          (check-equal? (length contributions) field-count)
          (check-equal? (poo-flow-module-field-contract-identity
                         (poo-flow-module-field-contribution-field
                          (car contributions)))
                        'field-0)
          (check-equal? (poo-flow-module-field-contribution-value
                         (car contributions))
                        '(0))
          (check-equal? (< elapsed-ms 1000) #t)
          (check-equal? (< best-ms 100) #t))))

;; : TestCase
(def (module-object-practice-merge-performance-case)
  (poo-flow-test-case "keeps large object slot config merge bounded"
        (let* ((field-count 1000)
               (fields
                (poo-flow-performance-build-list
                 field-count
                 large-object-list-field))
               (practice-object
                (poo-flow-module-object
                 'objects.practice.large-merge
                 '()
                 fields
                 '((namespace . objects.practice)
                   (domain . performance))))
               (base-entries
                (poo-flow-performance-build-list
                 field-count
                 (lambda (index)
                   (cons (large-object-field-name index)
                         (list index)))))
               (append-entries
                (poo-flow-performance-build-list
                 field-count
                 (lambda (index)
                   (cons (large-object-field-name index)
                         (list (+ index field-count))))))
               (base-node
                (poo-flow-module-object-node practice-object base-entries '()))
               (contributions
                (poo-flow-module-object-contributions practice-object
                                                      append-entries))
               (noop-contributions
                (poo-flow-module-object-contributions practice-object
                                                      base-entries))
               (start-jiffy (current-jiffy))
               (merge-result
                (poo-flow-module-field-contributions-resolve
                 base-node contributions))
               (elapsed-ms
                (/ (* (- (current-jiffy) start-jiffy) 1000)
                   (jiffies-per-second)))
               (best-ms
                (benchmark-p95-elapsed-ms
                 5
                 (lambda ()
                   (poo-flow-module-field-contributions-resolve
                    base-node contributions))))
               (noop-best-ms
                (benchmark-p95-elapsed-ms
                 5
                 (lambda ()
                   (poo-flow-module-field-contributions-resolve base-node
                                                    noop-contributions))))
               (noop-result
                (poo-flow-module-field-contributions-resolve
                 base-node noop-contributions))
               (resolved-node
                (poo-flow-module-field-resolution-result-root merge-result)))
          (check-equal? (poo-flow-module-field-resolution-result-applied?
                         merge-result)
                        #t)
          (check-equal? (length (poo-flow-graph-root-payload
                                 resolved-node))
                        field-count)
          (check-equal? (slot-value resolved-node 'field-0)
                        '(0 1000))
          (check-equal? (poo-flow-module-field-resolution-result-changed-passes
                         noop-result)
                        0)
          (check-equal? (< elapsed-ms 1000) #t)
          (check-equal? (< best-ms 100) #t)
          (check-equal? (< noop-best-ms 50) #t))))

;; : TestCase
(def (module-object-practice-transformer-case)
  (poo-flow-test-case "wraps standard list and map transformers as object contracts"
        (let* ((capabilities-field
                (poo-flow-module-field-contract
                 'capabilities
                 PooFlowModuleListType
                 'override
                 '(filesystem-read process-run cache-mount)
                 '((scope . best-practice)
                   (owner . object-core))))
               (metadata-field
                (poo-flow-module-field-contract
                 'metadata-map
                 PooFlowModuleMapType
                 'override
                 '((stage . default))
                 '((scope . best-practice)
                   (owner . object-core))))
               (practice-object
                (poo-flow-module-object
                 'objects.practice.transformers
                 '()
                 (list capabilities-field metadata-field)
                 '((namespace . objects.practice)
                   (domain . profile))))
               (base-node
                (poo-flow-module-object-node practice-object '() '()))
               (append-contribution
                (poo-flow-module-transformer-field-contribution
                 (poo-flow-module-object-identity practice-object)
                 capabilities-field
                 poo-flow-module-transformer-list-append-contract
                 '(network-access cache-mount)))
               (remove-contribution
                (poo-flow-module-transformer-field-contribution
                 (poo-flow-module-object-identity practice-object)
                 capabilities-field
                 poo-flow-module-transformer-list-remove-contract
                 '(process-run)))
               (map-set-contribution
                (poo-flow-module-transformer-field-contribution
                 (poo-flow-module-object-identity practice-object)
                 metadata-field
                 poo-flow-module-transformer-map-set-contract
                 '((stage . build)
                   (owner . object-core))))
               (merge-result
                (poo-flow-module-field-contributions-resolve
                 base-node
                 (list append-contribution
                       remove-contribution
                       map-set-contribution)))
               (resolved-node
                (poo-flow-module-field-resolution-result-root merge-result)))
          (check-equal? (poo-flow-module-transformer-contract?
                         poo-flow-module-transformer-list-append-contract)
                        #t)
          (check-equal? (poo-flow-module-transformer-contract-identity
                         poo-flow-module-transformer-list-remove-contract)
                        'list.remove)
          (check-equal? (poo-flow-module-transformer-contract-idempotent?
                         poo-flow-module-transformer-list-append-contract)
                        #t)
          (check-equal? (poo-flow-module-transformer-contract-diagnostics
                         poo-flow-module-transformer-list-append-contract
                         capabilities-field
                         '(network-access))
                        '())
          (check-equal? (poo-flow-module-field-contribution-merge
                         append-contribution)
                        'append)
          (check-equal? (poo-flow-module-field-contribution-merge
                         remove-contribution)
                        'remove)
          (check-equal? (poo-flow-module-field-contribution-merge
                         map-set-contribution)
                        'override)
          (check-equal? (poo-flow-module-transformer-contract-diagnostics
                         poo-flow-module-transformer-map-set-contract
                         capabilities-field
                         '((stage . build)))
                        '("transformer:map.set:field-kind-mismatch"))
          (check-equal? (poo-flow-module-transformer-contract-diagnostics
                         poo-flow-module-transformer-list-remove-contract
                         capabilities-field
                         'process-run)
                        '("transformer:list.remove:argument-kind-mismatch"))
          (check-equal? (poo-flow-module-field-resolution-result-applied?
                         merge-result)
                        #t)
          (check-equal? (slot-value resolved-node 'capabilities)
                        '(filesystem-read cache-mount network-access))
          (check-equal? (slot-value resolved-node 'metadata-map)
                        '((stage . build)
                          (owner . object-core))))))

;; : TestSuite
(def module-object-practice-test
  (test-suite "poo-flow module object best practices"
    (module-object-practice-projection-case)
    (module-object-practice-contribution-performance-case)
    (module-object-practice-merge-performance-case)
    (module-object-practice-transformer-case)))
