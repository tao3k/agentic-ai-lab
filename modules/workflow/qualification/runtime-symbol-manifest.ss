;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Scheme owns JSON runtime-symbol manifest validation.
;;; Invariant: shell collection supplies nm facts but cannot decide manifest validity.

(export #t)

(import (only-in :clan/poo/object .cc .def .ref)
        (only-in :std/list/walist PureAList? walist->list)
        (only-in :std/encoding/json
                 JSONReadOptions
                 current-json-read-options
                 read-json))

(def +poo-flow-runtime-symbol-manifest-schema+
  "poo-flow.runtime-symbol-manifest.v1")
(def +poo-flow-runtime-symbol-manifest-version+ 1)

;;; Optimization boundary: parsed manifests share one fixed native POO shape.
(.def poo-flow-runtime-symbol-manifest-prototype
  kind: 'poo-flow.runtime-symbol-manifest.v1
  schema: #f
  schema-version: #f
  abi: #f
  required-symbols: #f
  forbidden-fragments: #f
  owners: #f)

;;; Optimization boundary: verification receipts specialize one fixed slot layout.
(.def poo-flow-runtime-symbol-manifest-receipt-prototype
  kind: 'poo-flow.runtime-symbol-manifest-receipt.v1
  schema: "poo-flow.runtime-symbol-manifest-receipt.v1"
  schema-version: 1
  accepted?: #f
  abi: #f
  expected-symbols: '()
  actual-symbols: '()
  forbidden-symbols: '()
  diagnostics: '())

(def (symbol-manifest-ref rows key default)
  (let (entry (assq key rows))
    (if entry (cdr entry) default)))

(def (symbol-string-list? values)
  (and (list? values) (andmap string? values)))

(def (canonical-symbols values)
  (list-sort string<? (append values '())))

(def (invalid-symbol-manifest)
  poo-flow-runtime-symbol-manifest-prototype)

(def (poo-flow-runtime-symbol-manifest-read port)
  (with-catch
   (lambda (_failure) (invalid-symbol-manifest))
   (lambda ()
     (let (decoded
           (parameterize ((current-json-read-options
                           (JSONReadOptions key-as-symbol: #t)))
             (read-json port)))
       (if (not (PureAList? decoded))
           (invalid-symbol-manifest)
           (let (rows (walist->list decoded))
             (.cc poo-flow-runtime-symbol-manifest-prototype
                  'schema (symbol-manifest-ref rows 'schema #f)
                  'schema-version (symbol-manifest-ref rows 'schemaVersion #f)
                  'abi (symbol-manifest-ref rows 'abi #f)
                  'required-symbols (symbol-manifest-ref rows 'requiredSymbols #f)
                  'forbidden-fragments (symbol-manifest-ref rows 'forbiddenFragments #f)
                  'owners (symbol-manifest-ref rows 'owners #f))))))))

(def (poo-flow-runtime-symbol-manifest-read-file path)
  (call-with-input-file path poo-flow-runtime-symbol-manifest-read))

;; : (-> Boolean [String] [String] [String] [Symbol])
(def (runtime-symbol-manifest-diagnostics shape-valid? expected actual
                                          forbidden-symbols)
  (cond
   ((not shape-valid?) '(invalid-or-unknown-manifest))
   ((not (equal? expected actual)) '(exported-symbol-drift))
   ((pair? forbidden-symbols) '(forbidden-symbol))
   (else '())))

;; : (-> PooRuntimeSymbolManifest [String] [String] [String] Boolean SymbolManifestAnalysis)
(def (runtime-symbol-manifest-analysis manifest required forbidden
                                       actual-symbols shape-valid?)
  (if shape-valid?
    (let* ((expected (canonical-symbols required))
           (actual (canonical-symbols actual-symbols))
           (forbidden-symbols
            (filter (lambda (symbol)
                      (ormap (lambda (fragment)
                               (string-contains symbol fragment))
                             forbidden))
                    actual)))
      (list expected actual forbidden-symbols (.ref manifest 'abi)))
    (list '() '() '() #f)))

(def (poo-flow-runtime-symbol-manifest-verify manifest actual-symbols)
  (let* ((required (.ref manifest 'required-symbols))
         (forbidden (.ref manifest 'forbidden-fragments))
         (shape-valid?
          (and (equal? (.ref manifest 'schema)
                       +poo-flow-runtime-symbol-manifest-schema+)
               (equal? (.ref manifest 'schema-version)
                       +poo-flow-runtime-symbol-manifest-version+)
               (string? (.ref manifest 'abi))
               (symbol-string-list? required)
               (symbol-string-list? forbidden)
               (symbol-string-list? (.ref manifest 'owners))
               (symbol-string-list? actual-symbols)))
         (analysis
          (runtime-symbol-manifest-analysis
           manifest required forbidden actual-symbols shape-valid?))
         (expected (list-ref analysis 0))
         (actual (list-ref analysis 1))
         (forbidden-symbols (list-ref analysis 2))
         (abi (list-ref analysis 3))
         (accepted?
          (and shape-valid? (equal? expected actual)
               (null? forbidden-symbols))))
    (.cc poo-flow-runtime-symbol-manifest-receipt-prototype
         'accepted? accepted?
         'abi abi
         'expected-symbols expected
         'actual-symbols actual
         'forbidden-symbols forbidden-symbols
         'diagnostics
         (runtime-symbol-manifest-diagnostics
          shape-valid? expected actual forbidden-symbols))))
