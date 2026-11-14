;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: internal construction for values already admitted by a Standard
;;; catalog and resolved by the bounded traversal in funs.ss.
;;; Invariant: selected members must be the exact objects held by the catalog
;;; indexes.  This avoids repeating their complete shape validation in both the
;;; bundle and its receipt without weakening the public constructors.

(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :std/hash/misc hash-ref)
        "types.ss")

(export standard-resolution-admitted-bundle
        standard-resolution-admitted-receipt)

(def (standard-resolution-catalog-shell? catalog)
  (and (object? catalog)
       (.slot? catalog 'kind)
       (eq? (.ref catalog 'kind) +agentic-ai-lab-standard-catalog-kind+)
       (.slot? catalog 'edition-index)
       (hash-table? (.ref catalog 'edition-index))
       (.slot? catalog 'artifact-index)
       (hash-table? (.ref catalog 'artifact-index))))

(def (standard-resolution-admitted-members? values expected-count index)
  (and (exact-integer? expected-count)
       (>= expected-count 0)
       (let loop ((rest values) (count 0))
         (cond
          ((pair? rest)
           (and (< count expected-count)
                (let (value (car rest))
                  (and (object? value)
                       (.slot? value 'identity)
                       (eq? value (hash-ref index (.ref value 'identity) #f))))
                (loop (cdr rest) (+ count 1))))
          ((null? rest) (= count expected-count))
          (else #f)))))

(def (standard-resolution-admitted-bundle
      catalog-value root-identities-value edition-values edition-count-value
      artifact-values artifact-count-value terminology-snapshot-digest-value
      byte-count-value maximum-depth-value operation-count-value
      closure-digest-value)
  (unless (and (standard-resolution-catalog-shell? catalog-value)
               (standard-resolution-admitted-members?
                edition-values edition-count-value
                (.ref catalog-value 'edition-index))
               (standard-resolution-admitted-members?
                artifact-values artifact-count-value
                (.ref catalog-value 'artifact-index)))
    (error "resolved Standard bundle contains a non-catalog member"))
  (.o kind: +agentic-ai-lab-standard-bundle-kind+
      root-identities: root-identities-value
      editions: edition-values
      artifacts: artifact-values
      terminology-snapshot-digest: terminology-snapshot-digest-value
      edition-count: edition-count-value
      artifact-count: artifact-count-value
      byte-count: byte-count-value
      maximum-depth: maximum-depth-value
      operation-count: operation-count-value
      closure-digest: closure-digest-value
      generation: closure-digest-value
      runtime-executed?: #f))

(def (standard-resolution-admitted-receipt root-identities-value bundle-value)
  (.o kind: +agentic-ai-lab-standard-resolution-receipt-kind+
      valid?: #t
      roots: root-identities-value
      bundle: bundle-value
      failures: '()
      first-failure: #f
      runtime-executed?: #f))
