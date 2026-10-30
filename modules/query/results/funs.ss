;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Canonical, permutation-invariant digest of finite scalar relation rows.
(import (only-in :clan/poo/object .ref)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :std/list/list every delete-duplicates/hash)
        (only-in :agentic-ai-lab/modules/query/types
                 agentic-ai-lab-query-result-contract?)
        (only-in "types.ss"
                 agentic-ai-lab-query-result-cell? agentic-ai-lab-query-result-row?
                 agentic-ai-lab-query-result-set?)
        (only-in "objects.ss"
                 agentic-ai-lab-query-result-cell-value
                 agentic-ai-lab-query-result-row-value
                 agentic-ai-lab-query-result-set-value))
(export agentic-ai-lab-query-result-cell agentic-ai-lab-query-result-row
        agentic-ai-lab-query-result-set agentic-ai-lab-query-result-set-replay)

(def (identity? value)
  (or (symbol? value)
      (and (string? value) (> (string-length value) 0))))
(def (unique? values)
  (= (length values) (length (delete-duplicates/hash values))))
(def (identity-key value)
  (string-append (if (symbol? value) "symbol:" "string:")
                 (if (symbol? value) (symbol->string value) value)))
(def (identity<? a b)
  (string<? (identity-key a) (identity-key b)))
(def (digest datum)
  (string-append
   "sha256:"
   (hex-encode
    (sha256 (string->utf8
             (call-with-output-string
              (lambda (port) (write datum port))))))))
(def (result-digest datum)
  (string-append "agentic-ai-lab.query.scalar-row-v1:" (digest datum)))

(def (agentic-ai-lab-query-result-cell field value)
  (unless (and (symbol? field)
               (or (string? value) (symbol? value) (boolean? value)
                   (and (number? value) (exact? value))))
    (error "invalid scalar query result cell"))
  (agentic-ai-lab-query-result-cell-value
   (digest (list 'agentic-ai-lab.query.result-cell.v1 field value))
   field value))

(def (replay-cell cell)
  (unless (agentic-ai-lab-query-result-cell? cell)
    (error "invalid query result cell object"))
  (let (replayed
        (agentic-ai-lab-query-result-cell (.ref cell 'field) (.ref cell 'value)))
    (unless (equal? (.ref cell 'semantic-digest)
                    (.ref replayed 'semantic-digest))
      (error "query result cell digest mismatch"))
    replayed))

(def (agentic-ai-lab-query-result-row id cells)
  (unless (and (identity? id) (list? cells) (pair? cells))
    (error "invalid query result row"))
  (let (cells
        (list-sort
         (lambda (a b) (identity<? (.ref a 'field) (.ref b 'field)))
         (map replay-cell cells)))
    (unless (unique? (map (lambda (cell) (.ref cell 'field)) cells))
      (error "duplicate query result field"))
    (agentic-ai-lab-query-result-row-value
     (digest (list 'agentic-ai-lab.query.result-row.v1 id
                   (map (lambda (cell) (.ref cell 'semantic-digest)) cells)))
     id cells)))

(def (replay-row row)
  (unless (agentic-ai-lab-query-result-row? row)
    (error "invalid query result row object"))
  (let (replayed
        (agentic-ai-lab-query-result-row (.ref row 'identity) (.ref row 'cells)))
    (unless (equal? (.ref row 'semantic-digest)
                    (.ref replayed 'semantic-digest))
      (error "query result row digest mismatch"))
    replayed))

(def (agentic-ai-lab-query-result-set id contract query version revision rows
                                complete?)
  (unless (and (identity? id) (agentic-ai-lab-query-result-contract? contract)
               (identity? query) (identity? version) (identity? revision)
               (list? rows) (boolean? complete?))
    (error "invalid query result set"))
  (let* ((rows
          (list-sort
           (lambda (a b) (identity<? (.ref a 'identity) (.ref b 'identity)))
           (map replay-row rows)))
         (required (.ref contract 'required-fields)))
    (unless (and (unique? (map (lambda (row) (.ref row 'identity)) rows))
                 (<= (length rows) (.ref contract 'max-results))
                 (every
                  (lambda (row)
                    (let (fields
                          (map (lambda (cell) (.ref cell 'field))
                               (.ref row 'cells)))
                      (every (lambda (field) (memq field fields)) required)))
                  rows))
      (error "query result rows violate result contract"))
    (agentic-ai-lab-query-result-set-value
     id query version revision (.ref contract 'identity)
     rows (length rows)
     (result-digest
      (list 'agentic-ai-lab.query.result-set.v1
            query version revision (.ref contract 'identity)
            complete?
            (map (lambda (row) (.ref row 'semantic-digest)) rows)))
     complete?)))

(def (agentic-ai-lab-query-result-set-replay result-set contract)
  (unless (and (agentic-ai-lab-query-result-set? result-set)
               (agentic-ai-lab-query-result-contract? contract)
               (equal? (.ref result-set 'result-contract-identity)
                       (.ref contract 'identity)))
    (error "invalid query result set replay"))
  (let (replayed
        (agentic-ai-lab-query-result-set
         (.ref result-set 'identity) contract
         (.ref result-set 'query-identity)
         (.ref result-set 'query-version)
         (.ref result-set 'semantic-revision)
         (.ref result-set 'rows) (.ref result-set 'complete?)))
    (unless (and (equal? (.ref result-set 'semantic-digest)
                         (.ref replayed 'semantic-digest))
                 (equal? (.ref result-set 'result-digest)
                         (.ref replayed 'result-digest))
                 (= (.ref result-set 'result-count)
                    (.ref replayed 'result-count)))
      (error "query result set digest or count mismatch"))
    replayed))
