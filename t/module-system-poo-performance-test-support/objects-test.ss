;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO performance object and object-catalog test cases.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :clan/poo/object .ref object?)
        (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-fixture-ref
                 benchmark-receipt-pass?)
        "../support/poo-performance-fixtures"
        "../support/poo-performance-object-scenarios"
        "../support/poo-performance"
        :yuanxu/module-system/schema/interface
        :yuanxu/graph/interface
        :yuanxu/module-system/schema/validation)

(export objects-test)

;; : (-> Alist Unit)
(def (module-system-poo-performance-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] ")
  (write (benchmark-fixture-ref receipt 'feature))
  (display " ")
  (write receipt)
  (newline)
  (force-output))

;; : (-> String Integer Symbol)
;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-construction-case)
  (yuanxu-test-case "constructs large module objects at one boundary"
        (let* ((field-count 600)
               (object (poo-performance-module-object field-count))
               (receipt
                (poo-performance-run-gate
                 (poo-performance-construction-fixture)
                 (lambda ()
                   (poo-performance-module-object field-count)))))
          (check-equal? (yuanxu-module-object-identity object)
                        'performance-object)
          (check-equal? (length (yuanxu-module-object-fields object))
                        field-count)
          (check-equal? (benchmark-receipt-pass? receipt) #t))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-materialization-case)
  (yuanxu-test-case "materializes default slots once before repeated work"
        (let* ((object (poo-performance-module-object 400))
               (slots (yuanxu-module-object-default-slots object))
              (receipt
                (poo-performance-run-gate
                 (poo-performance-materialization-fixture)
                 (lambda ()
                   (poo-performance-snapshot-sum slots 20)))))
          (check-equal? (length slots) 400)
          (check-equal? (poo-performance-snapshot-sum slots 1)
                        79800)
          (check-equal? (benchmark-receipt-pass? receipt) #t))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-validation-case)
  (yuanxu-test-case "validates stable POO object shape once before scalar loop"
        (let* ((object (poo-performance-module-object 300))
               (valid? (yuanxu-module-object? object))
               (slots (yuanxu-module-object-default-slots object))
              (receipt
                (poo-performance-run-gate
                 (poo-performance-validation-fixture)
                 (lambda ()
                   (if valid?
                     (poo-performance-snapshot-sum slots 20)
                     0)))))
          (check-equal? valid? #t)
          (check-equal? (length slots) 300)
          (check-equal? (benchmark-receipt-pass? receipt) #t))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-catalog-validation-case)
  (yuanxu-test-case "validates inherited object catalogs with indexed field origins"
        (let* ((objects
                (poo-performance-module-object-catalog 40 160))
               (validations
                (yuanxu-module-objects-validation objects))
               (summary
                (yuanxu-module-objects-validation-summary validations))
               (receipt
                (poo-performance-run-gate
                 (poo-performance-catalog-validation-fixture)
                 (lambda ()
                   (yuanxu-module-objects-validation objects)))))
          (check-equal? (length validations) 40)
          (check-equal? (object? summary) #t)
          (check-equal? (.ref summary 'valid) #t)
          (check-equal? (.ref (car validations) 'resolved-field-count)
                        160)
          (module-system-poo-performance-display-receipt receipt)
          (check-equal? (benchmark-receipt-pass? receipt) #t))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-object-iteration-case)
  (yuanxu-test-case "iterates object graph nodes after one materialization boundary"
        (let* ((objects
                (poo-performance-module-object-catalog 80 120))
               (objects-node (yuanxu-module-objects-node objects))
               (identities
                (map yuanxu-module-object-identity objects))
               (receipt
                (poo-performance-run-gate
                 (poo-performance-object-iteration-fixture)
                 (lambda ()
                   (poo-performance-object-node-lookup-count
                    objects-node
                    identities
                    12)))))
          (check-equal? (length identities) 80)
          (check-equal?
           (poo-performance-object-node-lookup-count objects-node identities 1)
           80)
          (check-equal? (benchmark-receipt-pass? receipt) #t))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-clone-override-case)
  (yuanxu-test-case "applies clone overrides after one default-slot materialization"
        (let* ((object (poo-performance-module-object 320))
               (default-slots
                (yuanxu-module-object-default-slots object))
               (override-slots
                (poo-performance-override-slots 1200 160))
               (receipt
                (poo-performance-run-gate
                 (poo-performance-clone-override-fixture)
                 (lambda ()
                   (yuanxu-module-object-node/default-slots
                    object
                    default-slots
                    override-slots
                    '()))))
               (node
                (yuanxu-module-object-node/default-slots
                 object
                 default-slots
                 override-slots
                 '())))
          (check-equal? (length default-slots) 320)
          (check-equal? (length override-slots) 1200)
          (check-equal? (length (yuanxu-graph-root-payload node))
                        320)
          (check-equal? (benchmark-receipt-pass? receipt) #t))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-field-lookup-case)
  (yuanxu-test-case "reuses field contract lookup through contribution loops"
        (let* ((field-count 600)
               (object (poo-performance-module-object field-count))
               (entries
                (poo-performance-contribution-entries field-count))
              (receipt
                (poo-performance-run-gate
                 (poo-performance-field-lookup-fixture)
                 (lambda ()
                   (yuanxu-module-object-contributions object entries)))))
          (check-equal?
           (yuanxu-module-field-contract-identity
            (yuanxu-module-object-field object 'field-599))
           'field-599)
          (check-equal? (length entries) field-count)
          (check-equal? (benchmark-receipt-pass? receipt) #t))))

;; Registers one case in the enclosing TestSuite.
(def (module-system-poo-performance-composition-case)
  (yuanxu-test-case "composes object contributions through one merge boundary"
        (let* ((object-count 32)
               (field-count 80)
               (objects
                (poo-performance-module-object-catalog object-count field-count))
               (objects-node
                (yuanxu-module-objects-node objects))
               (contributions
                (poo-performance-catalog-contributions objects field-count))
               (result
                (yuanxu-module-objects-resolve-contributions/node objects-node
                                                     contributions))
              (receipt
                (poo-performance-run-gate
                 (poo-performance-composition-fixture)
                 (lambda ()
                   (yuanxu-module-objects-resolve-contributions/node
                    objects-node
                    contributions)))))
          (check-equal? (length contributions) (* object-count field-count))
          (check-equal?
           (yuanxu-module-field-resolution-result-applied? result)
           #t)
          (check-equal? (yuanxu-module-field-resolution-result-changed-passes result)
                        1)
          (check-equal? (benchmark-receipt-pass? receipt) #t))))

;; : TestSuite
(def objects-test
  (test-suite "agentic-ai-lab module system POO object performance"
    (module-system-poo-performance-construction-case)
    (module-system-poo-performance-materialization-case)
    (module-system-poo-performance-validation-case)
    (module-system-poo-performance-catalog-validation-case)
    (module-system-poo-performance-object-iteration-case)
    (module-system-poo-performance-clone-override-case)
    (module-system-poo-performance-field-lookup-case)
    (module-system-poo-performance-composition-case)))
