;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :clan/poo/mop define-type Type. element?)
        (only-in :std/list/list every))
(export AgenticAILabCandidateScope AgenticAILabCandidateReceipt
        AgenticAILabCandidateCheck AgenticAILabCandidateExchange
        agentic-ai-lab-candidate-scope? agentic-ai-lab-candidate-receipt?
        agentic-ai-lab-candidate-check? agentic-ai-lab-candidate-exchange?)

(def (text? value) (and (string? value) (> (string-length value) 0)))
(def (texts? value) (and (list? value) (every text? value)))
(def (symbols? value) (and (list? value) (every symbol? value)))
(def (slots? value names)
  (and (object? value) (every (lambda (name) (.slot? value name)) names)))
(def (common? value tag names)
  (and (slots? value (append '(kind identity semantic-digest) names))
       (eq? (.ref value 'kind) tag)
       (text? (.ref value 'identity))
       (text? (.ref value 'semantic-digest))))

(def (scope-shape? value)
  (and (common? value 'agentic-ai-lab.temporal-causality.candidate-scope
                '(evidence-cut-digest generation source-coverage-digest
                                      required-providers))
       (text? (.ref value 'evidence-cut-digest))
       (exact-integer? (.ref value 'generation))
       (>= (.ref value 'generation) 0)
       (let (coverage (.ref value 'source-coverage-digest))
         (or (eq? coverage #f) (text? coverage)))
       (symbols? (.ref value 'required-providers))))
(define-type (AgenticAILabCandidateScope @ Type.) .element?: scope-shape?)
(def (agentic-ai-lab-candidate-scope? value)
  (element? AgenticAILabCandidateScope value))

(def (receipt-shape? value)
  (and (common? value 'agentic-ai-lab.temporal-causality.candidate-receipt
                '(candidate-identity scope-digest provider-identity
                                      request-digest source-receipt-digest
                                      result-digest result-count complete?))
       (every text? (map (lambda (slot) (.ref value slot))
                         '(candidate-identity scope-digest request-digest
                                              source-receipt-digest result-digest)))
       (symbol? (.ref value 'provider-identity))
       (exact-integer? (.ref value 'result-count))
       (>= (.ref value 'result-count) 0)
       (boolean? (.ref value 'complete?))))
(define-type (AgenticAILabCandidateReceipt @ Type.) .element?: receipt-shape?)
(def (agentic-ai-lab-candidate-receipt? value)
  (element? AgenticAILabCandidateReceipt value))

(def (check-shape? value)
  (and (common? value 'agentic-ai-lab.temporal-causality.candidate-check
                '(receipt-identity receipt-digest verifier-identity
                                   verdict basis-digest))
       (every text? (map (lambda (slot) (.ref value slot))
                         '(receipt-identity receipt-digest verifier-identity
                                            basis-digest)))
       (memq (.ref value 'verdict) '(valid invalid unknown))))
(define-type (AgenticAILabCandidateCheck @ Type.) .element?: check-shape?)
(def (agentic-ai-lab-candidate-check? value)
  (element? AgenticAILabCandidateCheck value))

(def (exchange-shape? value)
  (and (common? value 'agentic-ai-lab.temporal-causality.candidate-exchange
                '(candidate-identity scope receipts checks
                                      missing-providers stale-receipts
                                      incomplete-receipts unchecked-receipts
                                      invalid-receipts
                                      contested-providers status admitted?))
       (text? (.ref value 'candidate-identity))
       (agentic-ai-lab-candidate-scope? (.ref value 'scope))
       (and (list? (.ref value 'receipts))
            (every agentic-ai-lab-candidate-receipt? (.ref value 'receipts)))
       (and (list? (.ref value 'checks))
            (every agentic-ai-lab-candidate-check? (.ref value 'checks)))
       (symbols? (.ref value 'missing-providers))
       (symbols? (.ref value 'contested-providers))
       (texts? (.ref value 'stale-receipts))
       (texts? (.ref value 'incomplete-receipts))
       (texts? (.ref value 'unchecked-receipts))
       (texts? (.ref value 'invalid-receipts))
       (memq (.ref value 'status) '(reviewable pending contested rejected))
       (eq? (.ref value 'admitted?) #f)))
(define-type (AgenticAILabCandidateExchange @ Type.) .element?: exchange-shape?)
(def (agentic-ai-lab-candidate-exchange? value)
  (element? AgenticAILabCandidateExchange value))
