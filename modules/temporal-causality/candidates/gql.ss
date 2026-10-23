;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Bind a Query source receipt to an exact Temporal cut.  This projects
;;; declared provider metadata; it cannot verify result rows or execution.
(import (only-in :clan/poo/object .ref)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :agentic-ai-lab/modules/query/types
                 agentic-ai-lab-query? agentic-ai-lab-query-element-space?
                 agentic-ai-lab-query-provider?
                 agentic-ai-lab-source-query-receipt?)
        (only-in :agentic-ai-lab/modules/query/funs agentic-ai-lab-query-admit)
        (only-in :agentic-ai-lab/modules/query/contracts
                 agentic-ai-lab-query-source-content-identity
                 agentic-ai-lab-query-bind-execution-receipt)
        (only-in :agentic-ai-lab/modules/query/objects
                 agentic-ai-lab-query-execution-candidate)
        (only-in :agentic-ai-lab/modules/query/results/types
                 agentic-ai-lab-query-result-set?)
        (only-in :agentic-ai-lab/modules/query/results/funs
                 agentic-ai-lab-query-result-set-replay)
        (only-in :agentic-ai-lab/modules/temporal-causality/candidates/types
                 agentic-ai-lab-candidate-scope? agentic-ai-lab-candidate-receipt?)
        (only-in :agentic-ai-lab/modules/temporal-causality/candidates/funs
                 agentic-ai-lab-candidate-receipt agentic-ai-lab-candidate-check))
(export agentic-ai-lab-gql-candidate-receipt agentic-ai-lab-gql-candidate-row-check)

(def (receipt-digest receipt)
  (string-append
   "sha256:"
   (hex-encode
    (sha256
     (string->utf8
      (call-with-output-string
       (lambda (port)
         (write
          (cons 'agentic-ai-lab.gql-source-receipt.v1
                (map (lambda (slot) (.ref receipt slot))
                     '(provider-identity query-identity query-version
                       semantic-revision source-content-identity
                       parser-identity provenance-root result-digest
                       result-count complete? result-contract-identity
                       admitted? diagnostics runtime-executed?
                       mutation-authority? action-authority?)))
          port))))))))

(def (agentic-ai-lab-gql-candidate-receipt id candidate scope query element-space
                                     provider source-receipt)
  (unless (and (agentic-ai-lab-candidate-scope? scope)
               (agentic-ai-lab-query? query)
               (agentic-ai-lab-query-element-space? element-space)
               (agentic-ai-lab-query-provider? provider)
               (agentic-ai-lab-source-query-receipt? source-receipt))
    (error "invalid GQL candidate bridge input"))
  (let* ((admission (agentic-ai-lab-query-admit query element-space))
         (source-digest (agentic-ai-lab-query-source-content-identity query))
         (execution-candidate
          (agentic-ai-lab-query-execution-candidate
           (.ref source-receipt 'provider-identity)
           (.ref source-receipt 'query-identity)
           (.ref source-receipt 'query-version)
           (.ref source-receipt 'semantic-revision)
           (.ref source-receipt 'source-content-identity)
           (.ref source-receipt 'parser-identity)
           (.ref source-receipt 'provenance-root)
           (.ref source-receipt 'result-digest)
           (.ref source-receipt 'result-count)
           (.ref source-receipt 'complete?)))
         (rebound
          (agentic-ai-lab-query-bind-execution-receipt
           provider query admission execution-candidate)))
    (unless (and (memq 'gql (.ref scope 'required-providers))
                 (equal? (.ref scope 'evidence-cut-digest)
                         (.ref element-space 'semantic-revision))
                 (.ref element-space 'complete?)
                 (.ref admission 'accepted?)
                 (.ref source-receipt 'admitted?)
                 (.ref rebound 'admitted?)
                 (equal? (receipt-digest source-receipt)
                         (receipt-digest rebound)))
      (error "GQL candidate receipt does not match Temporal cut and Query"))
    (agentic-ai-lab-candidate-receipt
     id candidate scope 'gql source-digest (receipt-digest source-receipt)
     (.ref source-receipt 'result-digest)
     (.ref source-receipt 'result-count)
     (.ref source-receipt 'complete?))))

;;; Only checks the supplied scalar rows against a declared result digest.
;;; It cannot attest that a Provider produced either the rows or the digest.
(def (agentic-ai-lab-gql-candidate-row-check id candidate-receipt query result-set)
  (unless (and (agentic-ai-lab-candidate-receipt? candidate-receipt)
               (agentic-ai-lab-query? query)
               (agentic-ai-lab-query-result-set? result-set))
    (error "invalid GQL candidate row-check input"))
  (let (result-set
        (agentic-ai-lab-query-result-set-replay
         result-set (.ref query 'result-contract)))
    (unless (and (>= (string-length (.ref candidate-receipt 'result-digest)) 29)
                 (string=?
                  (substring (.ref candidate-receipt 'result-digest) 0 29)
                  "agentic-ai-lab.query.scalar-row-v1:")
                 (eq? (.ref candidate-receipt 'provider-identity) 'gql)
                 (equal? (.ref candidate-receipt 'request-digest)
                         (agentic-ai-lab-query-source-content-identity query))
                 (equal? (.ref result-set 'query-identity)
                         (.ref query 'identity))
                 (equal? (.ref result-set 'query-version)
                         (.ref query 'version))
                 (equal? (.ref result-set 'semantic-revision)
                         (.ref query 'semantic-revision)))
      (error "GQL result set does not match candidate Query"))
    (agentic-ai-lab-candidate-check
     id candidate-receipt "agentic-ai-lab/query/scalar-row-check-v1"
     (cond ((or (not (equal? (.ref candidate-receipt 'result-digest)
                             (.ref result-set 'result-digest)))
                (not (= (.ref candidate-receipt 'result-count)
                        (.ref result-set 'result-count)))
                (not (eq? (.ref candidate-receipt 'complete?)
                          (.ref result-set 'complete?))))
            'invalid)
           ((not (.ref result-set 'complete?)) 'unknown)
           (else 'valid))
     (.ref result-set 'semantic-digest))))
