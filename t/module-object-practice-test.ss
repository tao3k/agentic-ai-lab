;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: executable POO best-practice guard for module object layering.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
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
        :yuanxu/graph/interface
        :yuanxu/module-system/schema/interface)

(export module-object-practice-test)

;; : (-> YuanxuGraph Symbol MaybeAny)
(def (slot-value node slot-name)
  (let (entry (assoc slot-name (yuanxu-graph-root-payload node)))
    (if entry (cdr entry) #f)))

;; : (-> Integer Symbol)
(def (large-object-field-name index)
  (string->symbol
   (string-append "field-" (number->string index))))

;; : (-> Integer PooModuleFieldContract)
(def (large-object-field index)
  (yuanxu-module-field-contract
   (large-object-field-name index)
   YuanxuModuleAnyType
   'override
   #f
   '((scope . large-object-performance)
     (owner . object-core))))

;; : (-> Integer PooModuleFieldContract)
(def (large-object-list-field index)
  (yuanxu-module-field-contract
   (large-object-field-name index)
   YuanxuModuleListType
   'append
   '()
   '((scope . large-object-performance)
     (owner . object-core))))

;; : TestSuite
;;; This suite keeps object-extension examples executable as policy evidence for
;;; downstream module authors.
;; : TestCase
(def (module-object-practice-projection-case)
  (yuanxu-test-case "projects object-owned field contracts into the extension graph"
        (let* ((capabilities-field
                (yuanxu-module-field-contract
                 'capabilities
                 YuanxuModuleListType
                 'append
                 '(filesystem-read)
                 '((scope . best-practice)
                   (owner . object-core))))
               (note-field
                (yuanxu-module-field-contract
                 'note
                 YuanxuModuleStringType
                 'override
                 "unset"
                 '((scope . best-practice)
                   (owner . object-core))))
               (practice-object
                (yuanxu-module-object
                 'objects.practice.profile
                 '()
                 (list capabilities-field note-field)
                 '((namespace . objects.practice)
                   (domain . profile))))
               (base-node
                (yuanxu-module-object-node practice-object '() '()))
               (contributions
                (yuanxu-module-object-contributions
                 practice-object
                 '((capabilities . (process-run cache-mount))
                   (note . "object-core owns contract wrappers"))))
               (extension-contributions
                (yuanxu-module-field-contributions->extensions contributions))
               (merge-result
                (yuanxu-module-field-contributions-resolve
                 base-node contributions))
               (resolved-node
                (yuanxu-module-field-resolution-result-root merge-result)))
          (check-equal? (yuanxu-module-object? practice-object) #t)
          (check-equal? (map yuanxu-module-field-contract-identity
                             (yuanxu-module-object-resolved-fields
                              practice-object))
                        '(capabilities note))
          (check-equal? (map yuanxu-module-field-contribution? contributions)
                        '(#t #t))
          (check-equal? (map yuanxu-graph-contribution?
                             extension-contributions)
                        '(#t #t))
          (check-equal? (yuanxu-module-field-resolution-result? merge-result) #t)
          (check-equal? (yuanxu-module-field-resolution-result-applied?
                         merge-result)
                        #t)
          (check-equal? (yuanxu-module-field-resolution-result-contributions
                         merge-result)
                        contributions)
          (check-equal? (slot-value resolved-node 'capabilities)
                        '(filesystem-read process-run cache-mount))
          (check-equal? (slot-value resolved-node 'note)
                        "object-core owns contract wrappers"))))

;; : TestCase
(def (module-object-practice-contribution-performance-case)
  (yuanxu-test-case "keeps large object contribution projection linear"
        (let* ((field-count 1000)
               (fields
                (agentic-ai-lab-performance-build-list field-count large-object-field))
               (practice-object
                (yuanxu-module-object
                 'objects.practice.large
                 '()
                 fields
                 '((namespace . objects.practice)
                   (domain . performance))))
               (entries
                (agentic-ai-lab-performance-build-list
                 field-count
                 (lambda (index)
                   (cons (large-object-field-name index)
                         (list index)))))
               (start-jiffy (current-jiffy))
               (contributions
                (yuanxu-module-object-contributions practice-object entries))
               (elapsed-ms
                (/ (* (- (current-jiffy) start-jiffy) 1000)
                   (jiffies-per-second)))
               (best-ms
                (benchmark-p95-elapsed-ms
                 5
                 (lambda ()
                   (yuanxu-module-object-contributions practice-object
                                                         entries)))))
          (check-equal? (length contributions) field-count)
          (check-equal? (yuanxu-module-field-contract-identity
                         (yuanxu-module-field-contribution-field
                          (car contributions)))
                        'field-0)
          (check-equal? (yuanxu-module-field-contribution-value
                         (car contributions))
                        '(0))
          (check-equal? (< elapsed-ms 1000) #t)
          (check-equal? (< best-ms 100) #t))))

;; : TestCase
(def (module-object-practice-merge-performance-case)
  (yuanxu-test-case "keeps large object slot config merge bounded"
        (let* ((field-count 1000)
               (fields
                (agentic-ai-lab-performance-build-list
                 field-count
                 large-object-list-field))
               (practice-object
                (yuanxu-module-object
                 'objects.practice.large-merge
                 '()
                 fields
                 '((namespace . objects.practice)
                   (domain . performance))))
               (base-entries
                (agentic-ai-lab-performance-build-list
                 field-count
                 (lambda (index)
                   (cons (large-object-field-name index)
                         (list index)))))
               (append-entries
                (agentic-ai-lab-performance-build-list
                 field-count
                 (lambda (index)
                   (cons (large-object-field-name index)
                         (list (+ index field-count))))))
               (base-node
                (yuanxu-module-object-node practice-object base-entries '()))
               (contributions
                (yuanxu-module-object-contributions practice-object
                                                      append-entries))
               (noop-contributions
                (yuanxu-module-object-contributions practice-object
                                                      base-entries))
               (start-jiffy (current-jiffy))
               (merge-result
                (yuanxu-module-field-contributions-resolve
                 base-node contributions))
               (elapsed-ms
                (/ (* (- (current-jiffy) start-jiffy) 1000)
                   (jiffies-per-second)))
               (best-ms
                (benchmark-p95-elapsed-ms
                 5
                 (lambda ()
                   (yuanxu-module-field-contributions-resolve
                    base-node contributions))))
               (noop-best-ms
                (benchmark-p95-elapsed-ms
                 5
                 (lambda ()
                   (yuanxu-module-field-contributions-resolve base-node
                                                    noop-contributions))))
               (noop-result
                (yuanxu-module-field-contributions-resolve
                 base-node noop-contributions))
               (resolved-node
                (yuanxu-module-field-resolution-result-root merge-result)))
          (check-equal? (yuanxu-module-field-resolution-result-applied?
                         merge-result)
                        #t)
          (check-equal? (length (yuanxu-graph-root-payload
                                 resolved-node))
                        field-count)
          (check-equal? (slot-value resolved-node 'field-0)
                        '(0 1000))
          (check-equal? (yuanxu-module-field-resolution-result-changed-passes
                         noop-result)
                        0)
          (check-equal? (< elapsed-ms 1000) #t)
          (check-equal? (< best-ms 100) #t)
          (check-equal? (< noop-best-ms 50) #t))))

;; : TestCase
(def (module-object-practice-transformer-case)
  (yuanxu-test-case "wraps standard list and map transformers as object contracts"
        (let* ((capabilities-field
                (yuanxu-module-field-contract
                 'capabilities
                 YuanxuModuleListType
                 'override
                 '(filesystem-read process-run cache-mount)
                 '((scope . best-practice)
                   (owner . object-core))))
               (metadata-field
                (yuanxu-module-field-contract
                 'metadata-map
                 YuanxuModuleMapType
                 'override
                 '((stage . default))
                 '((scope . best-practice)
                   (owner . object-core))))
               (practice-object
                (yuanxu-module-object
                 'objects.practice.transformers
                 '()
                 (list capabilities-field metadata-field)
                 '((namespace . objects.practice)
                   (domain . profile))))
               (base-node
                (yuanxu-module-object-node practice-object '() '()))
               (append-contribution
                (yuanxu-module-transformer-field-contribution
                 (yuanxu-module-object-identity practice-object)
                 capabilities-field
                 yuanxu-module-transformer-list-append-contract
                 '(network-access cache-mount)))
               (remove-contribution
                (yuanxu-module-transformer-field-contribution
                 (yuanxu-module-object-identity practice-object)
                 capabilities-field
                 yuanxu-module-transformer-list-remove-contract
                 '(process-run)))
               (map-set-contribution
                (yuanxu-module-transformer-field-contribution
                 (yuanxu-module-object-identity practice-object)
                 metadata-field
                 yuanxu-module-transformer-map-set-contract
                 '((stage . build)
                   (owner . object-core))))
               (merge-result
                (yuanxu-module-field-contributions-resolve
                 base-node
                 (list append-contribution
                       remove-contribution
                       map-set-contribution)))
               (resolved-node
                (yuanxu-module-field-resolution-result-root merge-result)))
          (check-equal? (yuanxu-module-transformer-contract?
                         yuanxu-module-transformer-list-append-contract)
                        #t)
          (check-equal? (yuanxu-module-transformer-contract-identity
                         yuanxu-module-transformer-list-remove-contract)
                        'list.remove)
          (check-equal? (yuanxu-module-transformer-contract-idempotent?
                         yuanxu-module-transformer-list-append-contract)
                        #t)
          (check-equal? (yuanxu-module-transformer-contract-diagnostics
                         yuanxu-module-transformer-list-append-contract
                         capabilities-field
                         '(network-access))
                        '())
          (check-equal? (yuanxu-module-field-contribution-merge
                         append-contribution)
                        'append)
          (check-equal? (yuanxu-module-field-contribution-merge
                         remove-contribution)
                        'remove)
          (check-equal? (yuanxu-module-field-contribution-merge
                         map-set-contribution)
                        'override)
          (check-equal? (yuanxu-module-transformer-contract-diagnostics
                         yuanxu-module-transformer-map-set-contract
                         capabilities-field
                         '((stage . build)))
                        '("transformer:map.set:field-kind-mismatch"))
          (check-equal? (yuanxu-module-transformer-contract-diagnostics
                         yuanxu-module-transformer-list-remove-contract
                         capabilities-field
                         'process-run)
                        '("transformer:list.remove:argument-kind-mismatch"))
          (check-equal? (yuanxu-module-field-resolution-result-applied?
                         merge-result)
                        #t)
          (check-equal? (slot-value resolved-node 'capabilities)
                        '(filesystem-read cache-mount network-access))
          (check-equal? (slot-value resolved-node 'metadata-map)
                        '((stage . build)
                          (owner . object-core))))))

;; : TestSuite
(def module-object-practice-test
  (test-suite "agentic-ai-lab module object best practices"
    (module-object-practice-projection-case)
    (module-object-practice-contribution-performance-case)
    (module-object-practice-merge-performance-case)
    (module-object-practice-transformer-case)))
