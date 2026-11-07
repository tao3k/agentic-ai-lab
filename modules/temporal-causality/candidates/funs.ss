;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; A pure exchange boundary. Provider results and independent checks are
;;; declared evidence here; only their semantic owners can verify the bytes.
(import (only-in :clan/poo/object .ref)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :std/list/list any every delete-duplicates/hash)
        (only-in :agentic-ai-lab/modules/temporal-causality/candidates/types
                 agentic-ai-lab-candidate-scope?
                 agentic-ai-lab-candidate-receipt? agentic-ai-lab-candidate-check?)
        (only-in :agentic-ai-lab/modules/temporal-causality/candidates/objects
                 agentic-ai-lab-candidate-scope-value
                 agentic-ai-lab-candidate-receipt-value agentic-ai-lab-candidate-check-value
                 agentic-ai-lab-candidate-exchange-value))
(export agentic-ai-lab-candidate-scope agentic-ai-lab-candidate-receipt
        agentic-ai-lab-candidate-check agentic-ai-lab-candidate-exchange)

(def (text? value) (and (string? value) (> (string-length value) 0)))
(def (unique? values)
  (= (length values) (length (delete-duplicates/hash values))))
(def (sorted-text values) (list-sort string<? values))
(def (sorted-symbols values)
  (list-sort (lambda (a b) (string<? (symbol->string a) (symbol->string b)))
             values))
(def (ordered values)
  (list-sort (lambda (a b) (string<? (.ref a 'identity) (.ref b 'identity)))
             values))
(def (ids values) (map (lambda (value) (.ref value 'identity)) values))
(def (digest datum)
  (string-append "sha256:"
   (hex-encode (sha256 (string->utf8
    (call-with-output-string (lambda (port) (write datum port))))))))

(def (agentic-ai-lab-candidate-scope id cut generation coverage providers)
  (unless (and (text? id) (text? cut)
               (exact-integer? generation) (>= generation 0)
               (or (eq? coverage #f) (text? coverage))
               (list? providers) (not (null? providers))
               (every symbol? providers) (unique? providers))
    (error "invalid candidate scope"))
  (let (providers (sorted-symbols providers))
    (agentic-ai-lab-candidate-scope-value
     id (digest (list 'agentic-ai-lab.candidate-scope.v1 id cut generation
                      coverage providers))
     cut generation coverage providers)))

(def (replay-scope scope)
  (unless (agentic-ai-lab-candidate-scope? scope)
    (error "invalid candidate scope object"))
  (let (replayed
        (agentic-ai-lab-candidate-scope
         (.ref scope 'identity) (.ref scope 'evidence-cut-digest)
         (.ref scope 'generation) (.ref scope 'source-coverage-digest)
         (.ref scope 'required-providers)))
    (unless (equal? (.ref scope 'semantic-digest)
                    (.ref replayed 'semantic-digest))
      (error "candidate scope digest mismatch"))
    replayed))

(def (receipt-value id candidate scope-digest provider request source result
                    count complete?)
  (unless (and (every text? (list id candidate scope-digest request source result))
               (symbol? provider) (exact-integer? count) (>= count 0)
               (boolean? complete?))
    (error "invalid candidate receipt"))
  (agentic-ai-lab-candidate-receipt-value
   id (digest (list 'agentic-ai-lab.candidate-receipt.v1 id candidate scope-digest
                    provider request source result count complete?))
   candidate scope-digest provider request source result count complete?))

(def (agentic-ai-lab-candidate-receipt id candidate scope provider request source result
                                 count complete?)
  (let (scope (replay-scope scope))
    (receipt-value id candidate (.ref scope 'semantic-digest) provider
                   request source result count complete?)))

(def (replay-receipt receipt)
  (unless (agentic-ai-lab-candidate-receipt? receipt)
    (error "invalid candidate receipt object"))
  (let (replayed
        (receipt-value
         (.ref receipt 'identity) (.ref receipt 'candidate-identity)
         (.ref receipt 'scope-digest) (.ref receipt 'provider-identity)
         (.ref receipt 'request-digest) (.ref receipt 'source-receipt-digest)
         (.ref receipt 'result-digest) (.ref receipt 'result-count)
         (.ref receipt 'complete?)))
    (unless (equal? (.ref receipt 'semantic-digest)
                    (.ref replayed 'semantic-digest))
      (error "candidate receipt digest mismatch"))
    replayed))

(def (check-value id receipt-id receipt-digest verifier verdict basis)
  (unless (and (every text? (list id receipt-id receipt-digest verifier basis))
               (memq verdict '(valid invalid unknown)))
    (error "invalid candidate check"))
  (agentic-ai-lab-candidate-check-value
   id (digest (list 'agentic-ai-lab.candidate-check.v1 id receipt-id receipt-digest
                    verifier verdict basis))
   receipt-id receipt-digest verifier verdict basis))

(def (agentic-ai-lab-candidate-check id receipt verifier verdict basis)
  (let (receipt (replay-receipt receipt))
    (check-value id (.ref receipt 'identity) (.ref receipt 'semantic-digest)
                 verifier verdict basis)))

(def (replay-check check receipts-by-id)
  (unless (agentic-ai-lab-candidate-check? check)
    (error "invalid candidate check object"))
  (let (receipt (hash-get receipts-by-id (.ref check 'receipt-identity)))
    (unless (and receipt
                 (equal? (.ref receipt 'semantic-digest)
                         (.ref check 'receipt-digest)))
      (error "candidate check names an absent or revised receipt"))
    (let (replayed
          (check-value
           (.ref check 'identity) (.ref check 'receipt-identity)
           (.ref check 'receipt-digest) (.ref check 'verifier-identity)
           (.ref check 'verdict) (.ref check 'basis-digest)))
      (unless (equal? (.ref check 'semantic-digest)
                      (.ref replayed 'semantic-digest))
        (error "candidate check digest mismatch"))
      replayed)))

(def (agentic-ai-lab-candidate-exchange id candidate scope receipts checks)
  (unless (and (text? id) (text? candidate)
               (list? receipts) (list? checks))
    (error "invalid candidate exchange input"))
  (let* ((scope (replay-scope scope))
         (receipts (ordered (map replay-receipt receipts)))
         (receipts-by-id (make-hash-table)))
    (unless (unique? (ids receipts))
      (error "duplicate candidate receipt identity"))
    (for-each
     (lambda (receipt)
       (hash-put! receipts-by-id (.ref receipt 'identity) receipt))
     receipts)
    (let* ((checks
            (ordered (map (lambda (check)
                            (replay-check check receipts-by-id)) checks)))
           (all-ids (append (ids receipts) (ids checks))))
      (unless (unique? all-ids)
        (error "duplicate candidate exchange identity"))
      (let* ((required (.ref scope 'required-providers))
             (current
              (filter (lambda (receipt)
                        (and (equal? (.ref receipt 'candidate-identity)
                                     candidate)
                             (equal? (.ref receipt 'scope-digest)
                                     (.ref scope 'semantic-digest))
                             (memq (.ref receipt 'provider-identity) required)))
                      receipts))
             (stale
              (sorted-text
               (ids (filter (lambda (receipt) (not (memq receipt current)))
                            receipts))))
             (missing
              (filter (lambda (provider)
                        (not (any (lambda (receipt)
                                    (eq? (.ref receipt 'provider-identity)
                                         provider))
                                  current)))
                      required))
             (incomplete
              (sorted-text
               (ids (filter (lambda (receipt)
                              (not (.ref receipt 'complete?))) current))))
             (unchecked '())
             (invalid '())
             (contested '()))
        (for-each
         (lambda (provider)
           (let (group
                 (filter (lambda (receipt)
                           (eq? (.ref receipt 'provider-identity) provider))
                         current))
             (when (> (length group) 1)
               (set! contested (cons provider contested)))
             (for-each
              (lambda (receipt)
                (let* ((own-checks
                        (filter (lambda (check)
                                  (equal? (.ref check 'receipt-identity)
                                          (.ref receipt 'identity)))
                                checks))
                       (verdicts (map (lambda (check) (.ref check 'verdict))
                                      own-checks)))
                  (when (and (memq 'valid verdicts) (memq 'invalid verdicts))
                    (set! contested (cons provider contested)))
                  (when (memq 'invalid verdicts)
                    (set! invalid (cons (.ref receipt 'identity) invalid)))
                  (when (or (not (memq 'valid verdicts))
                            (memq 'unknown verdicts))
                    (set! unchecked
                          (cons (.ref receipt 'identity) unchecked)))))
              group)))
         required)
        (let* ((contested (sorted-symbols
                           (delete-duplicates/hash contested)))
               (unchecked (sorted-text unchecked))
               (invalid (sorted-text invalid))
               (status
                (cond ((pair? contested) 'contested)
                      ((pair? invalid) 'rejected)
                      ((or (eq? (.ref scope 'source-coverage-digest) #f)
                           (pair? stale) (pair? missing) (pair? incomplete)
                           (pair? unchecked)) 'pending)
                      (else 'reviewable)))
               (semantic-digest
                (digest (list 'agentic-ai-lab.candidate-exchange.v1 id candidate
                              (.ref scope 'semantic-digest)
                              (map (lambda (item) (.ref item 'semantic-digest))
                                   receipts)
                              (map (lambda (item) (.ref item 'semantic-digest))
                                   checks)
                              missing stale incomplete unchecked invalid
                              contested status))))
          (agentic-ai-lab-candidate-exchange-value
           id semantic-digest candidate scope receipts checks
           missing stale incomplete unchecked invalid contested status))))))
