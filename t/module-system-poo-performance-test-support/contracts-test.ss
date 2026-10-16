;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO performance contract and API-evidence test cases.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-fixture-ref
                 benchmark-receipt-pass?)
        "../support/poo-performance-fixtures"
        "../support/poo-performance"
        :core/object-family/indexed
        :poo-flow/modules/workflow/control-plane/runtime-protocol
        :core/module-system/schema/interface
        :core/extension-graph/interface
        :core/module-system/schema/validation)

(export contracts-test)

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-fixture-contract-case)
  (poo-flow-test-case "keeps every POO performance fixture inside upstream benchmark contract"
        (let (fixtures (poo-performance-fixtures))
        (check-equal? (length fixtures) 31)
        (check-equal?
         (map (lambda (fixture)
                (benchmark-fixture-ref fixture 'sourcePath))
              fixtures)
         poo-performance-fixture-paths)
        (check-equal?
         (map benchmark-fixture-contract-pass? fixtures)
         (map (lambda (_) #t) fixtures))
        (check-equal?
         (map poo-performance-api-evidence-contract-pass?
              fixtures)
         (map (lambda (_) #t) fixtures))
        (check-equal?
         (map poo-performance-fixture-policy-contract-pass?
              fixtures)
         (map (lambda (_) #t) fixtures)))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-fixture-policy-reject-case)
  (poo-flow-test-case "rejects fixtures that miss POO performance policy evidence"
        (let (fixture
              '((feature . missing-poo-policy)
                (iterations . 1000)
                (sourcePath . "missing")))
          (check-equal?
           (poo-performance-fixture-policy-contract-pass? fixture)
           #f))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-api-evidence-case)
  (poo-flow-test-case "keeps POO benchmark evidence anchored to gerbil-poo APIs"
        (let (receipt (poo-performance-api-usage-call-receipt))
          (check-equal? (cdr (assoc 'name receipt)) 'poo-api-evidence)
          (check-equal? (cdr (assoc 'color receipt)) 'blue)
          (check-equal? (cdr (assoc 'fallback receipt)) 'defaulted)
          (check-equal? (cdr (assoc 'dynamic receipt)) 'slot-added-through-api)
          (check-equal?
           (poo-performance-symbol-member?
            (cdr (assoc 'slots receipt))
            'dynamic)
           #t))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-large-profile-projection-case)
  (poo-flow-test-case "projects large POO profiles through stable descriptor vectors"
        (let (descriptors
              (poo-performance-large-profile-projection-descriptors))
          (check-equal? (vector-length descriptors) 10)
          (check-equal?
           (cdr (assoc 'value (vector-ref descriptors 0)))
           'large-profile)
          (check-equal?
           (poo-performance-family-ref
            +poo-performance-large-runtime-profile-family+
            (vector-ref descriptors 0)
            'name
            #f)
           'profile-id)
          (check-equal?
           (cdr (assoc 'value (vector-ref descriptors 9)))
           128)
          (check-equal?
           (poo-performance-large-profile-projection-valid-count 1000)
           1000)
          (check-equal?
           (benchmark-receipt-pass?
            (poo-performance-large-profile-projection-gate-receipt 1000))
           #t))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-indexed-family-layout-case)
  (poo-flow-test-case "reuses indexed POO family layout for large profile projection"
        (let* ((object (poo-performance-large-profile-indexed-object))
               (descriptors
                (poo-performance-large-profile-indexed-descriptors)))
          (check-equal?
           (poo-performance-indexed-family-ref
            +poo-performance-large-runtime-profile-layout+
            object
            'profile-id
            #f)
           'large-profile)
          (check-equal?
           (poo-performance-indexed-family-ref
            +poo-performance-large-runtime-profile-layout+
            object
            'limit
            #f)
           128)
          (check-equal?
           (poo-performance-indexed-family-ref
            +poo-performance-large-runtime-profile-layout+
            object
            'missing-slot
            'missing-value)
           'missing-value)
          (check-equal? (vector-length descriptors) 10)
          (check-equal?
           (cdr (assoc 'value (vector-ref descriptors 0)))
           'large-profile)
          (check-equal?
           (poo-performance-large-profile-indexed-valid-count 1000)
           1000))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-indexed-family-core-case)
  (poo-flow-test-case "projects stable POO family slots through indexed module API"
        (let* ((family
                (poo-indexed-family
                 'module-indexed-family
                 'poo-flow.module-system.indexed-family
                 '(profile-id limit)))
               (object
                (poo-indexed-family-object family '(large-profile 128)))
               (lenses
                (poo-indexed-family-lenses
                 family
                 '((profile-id . profile-id)
                   (limit . limit))))
               (descriptors
                (poo-indexed-family-project-descriptors
                 family
                 object
                 lenses
                 (lambda (_family descriptor-name value)
                   (cons descriptor-name value)))))
          (check-equal?
           (poo-indexed-family-ref family object 'profile-id #f)
           'large-profile)
          (check-equal?
           (poo-indexed-family-ref family object 'limit #f)
           128)
          (check-equal?
           (poo-indexed-family-ref family object 'missing-slot 'missing)
           'missing)
          (check-equal? (vector-length descriptors) 2)
          (check-equal?
           (vector-ref descriptors 0)
           '(profile-id . large-profile))
          (check-equal?
           (vector-ref descriptors 1)
           '(limit . 128)))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-generated-receipt-boundary-case)
  (poo-flow-test-case "projects generated receipt accessors only at runtime boundary"
        (let (receipt-alist
              (poo-performance-generated-receipt-boundary-alist))
          (check-equal?
           (poo-performance-family-ref
            +poo-performance-benchmark-receipt-family+
            receipt-alist
            'status
            #f)
           'ready)
          (check-equal? (cdr (assoc 'profile-id receipt-alist)) 41)
          (check-equal? (cdr (assoc 'status receipt-alist)) 'ready)
          (check-equal?
           (cdr (assoc 'runtime receipt-alist))
           'runtime-language)
          (check-equal?
           (poo-performance-generated-receipt-boundary-valid-count 1000)
           1000)
          (check-equal?
           (benchmark-receipt-pass?
            (poo-performance-generated-receipt-boundary-gate-receipt 1000))
           #t))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-runtime-response-family-case)
  (poo-flow-test-case "reuses runtime response family descriptors at adapter boundary"
        (let* ((adapter-response
                (make-adapter-result
                 'request-1
                 'completed
                 'runtime-value
                 'artifact-1
                 #f))
               (runtime-family-response
                (adapter-result->runtime-response
                 adapter-response
                 '((adapter . python-runtime))))
               (normalized-response
                (normalize-runtime-response
                 '((request-id . request-1)
                   (artifact-handle . artifact-1))
                 (runtime-response->alist runtime-family-response))))
          (check-equal?
           (runtime-alist-ref
            (runtime-response-metadata runtime-family-response)
            'response-family
            #f)
           'poo-flow-runtime-response-family)
          (check-equal?
           (runtime-response-family-ref
            +runtime-response-family+
            runtime-family-response
            'status
            #f)
           'completed)
          (check-equal?
           (runtime-response-family-ref
            (runtime-response-family 'other-runtime-response-family
                                     +runtime-response-schema+)
            runtime-family-response
            'status
            'family-mismatch)
           'family-mismatch)
          (check-equal? (adapter-result? normalized-response) #t)
          (check-equal?
           (adapter-result-status normalized-response)
           'completed))))

;; : TestSuite
(def contracts-test
  (test-suite "poo-flow module system POO performance contracts"
    (module-system-poo-performance-fixture-contract-case)
    (module-system-poo-performance-fixture-policy-reject-case)
    (module-system-poo-performance-api-evidence-case)
    (module-system-poo-performance-large-profile-projection-case)
    (module-system-poo-performance-indexed-family-layout-case)
    (module-system-poo-indexed-family-core-case)
    (module-system-poo-performance-generated-receipt-boundary-case)
    (module-system-poo-performance-runtime-response-family-case)))
