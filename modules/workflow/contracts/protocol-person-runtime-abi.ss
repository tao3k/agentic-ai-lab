;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: validates protocol-person promotion messages at the Runtime v0 ABI edge.
;;; Invariant: only schema-valid requests and receipts cross the runtime boundary.
(import (only-in :clan/poo/object .o .ref object?)
        :agentic-ai-lab/modules/governance/policy/protocol-person-promotion
        :agentic-ai-lab/modules/workflow/contracts/runtime-v0-abi-schema)

(export +agentic-ai-lab-runtime-language-promotion-request-schema+
        +agentic-ai-lab-runtime-language-promotion-receipt-schema+
        +agentic-ai-lab-runtime-language-promotion-required-capabilities+
        +agentic-ai-lab-runtime-language-promotion-outcomes+
        agentic-ai-lab-runtime-language-promotion-idempotency-key
        agentic-ai-lab-runtime-language-promotion-idempotency-key->alist
        agentic-ai-lab-runtime-language-promotion-request
        agentic-ai-lab-runtime-language-promotion-request->alist
        agentic-ai-lab-runtime-language-promotion-request->vector
        agentic-ai-lab-runtime-language-promotion-abi->c-header
        agentic-ai-lab-runtime-language-promotion-capabilities-cover?
        agentic-ai-lab-runtime-language-promotion-epochs-current?
        agentic-ai-lab-runtime-language-promotion-receipt
        agentic-ai-lab-runtime-language-promotion-receipt-failures
        agentic-ai-lab-runtime-language-promotion-receipt-valid?
        agentic-ai-lab-runtime-language-promotion-receipt-active?
        agentic-ai-lab-runtime-language-promotion-receipt->alist
        agentic-ai-lab-runtime-language-promotion-receipts-exactly-once?
        +agentic-ai-lab-runtime-language-source-query-receipt-schema+
        +agentic-ai-lab-runtime-language-admission-receipt-schema+
        +agentic-ai-lab-contract-artifact-projection-receipt-schema+
        +agentic-ai-lab-runtime-language-source-representations+
        +agentic-ai-lab-contract-artifact-kinds+
        +agentic-ai-lab-runtime-language-admission-outcomes+
        agentic-ai-lab-runtime-language-source-query-receipt
        agentic-ai-lab-runtime-language-source-query-receipt-failures
        agentic-ai-lab-runtime-language-source-query-receipt-valid?
        agentic-ai-lab-runtime-language-source-query-receipt->alist
        agentic-ai-lab-runtime-language-admission-receipt
        agentic-ai-lab-runtime-language-admission-receipt-failures
        agentic-ai-lab-runtime-language-admission-receipt-valid?
        agentic-ai-lab-runtime-language-admission-receipt-admitted?
        agentic-ai-lab-runtime-language-admission-receipt->alist
        agentic-ai-lab-contract-artifact-projection-receipt
        agentic-ai-lab-contract-artifact-projection-receipt-failures
        agentic-ai-lab-contract-artifact-projection-receipt-valid?
        agentic-ai-lab-contract-artifact-projection-receipt->alist)

(import :agentic-ai-lab/modules/workflow/contracts/protocol-person-promotion-abi)

(def +agentic-ai-lab-runtime-language-source-query-receipt-schema+
  (string->symbol
   (.ref +agentic-ai-lab-runtime-v0-abi-schema+ 'source-query-receipt-schema)))

(def +agentic-ai-lab-runtime-language-admission-receipt-schema+
  (string->symbol
   (.ref +agentic-ai-lab-runtime-v0-abi-schema+ 'runtime-admission-receipt-schema)))

(def +agentic-ai-lab-contract-artifact-projection-receipt-schema+
  (string->symbol
   (.ref +agentic-ai-lab-runtime-v0-abi-schema+
         'contract-artifact-projection-receipt-schema)))

(def +agentic-ai-lab-runtime-language-source-representations+
  '(json ast-data))

(def +agentic-ai-lab-contract-artifact-kinds+
  '(abi-vector c-header json-schema python-type rust-type gerbil-poo
    lean-proposition))

(def +agentic-ai-lab-runtime-language-admission-outcomes+
  '(admitted rejected))

(def (runtime-language-identity-present? value)
  (and value
       (not (equal? value ""))
       (not (equal? value '()))))

(def (runtime-language-version-present? value)
  (and (string? value)
       (runtime-language-identity-present? value)))

(def (agentic-ai-lab-runtime-language-source-query-receipt
      source-language-value
      source-content-id-value
      source-version-value
      parser-id-value
      parser-version-value
      query-id-value
      query-version-value
      selected-node-identities-value
      representation-value
      provenance-root-value
      result-digest-value)
  (.o (kind +agentic-ai-lab-runtime-language-source-query-receipt-schema+)
      (source-language source-language-value)
      (source-content-id source-content-id-value)
      (source-version source-version-value)
      (parser-id parser-id-value)
      (parser-version parser-version-value)
      (query-id query-id-value)
      (query-version query-version-value)
      (selected-node-identities selected-node-identities-value)
      (representation representation-value)
      (provenance-root provenance-root-value)
      (result-digest result-digest-value)))

(def (agentic-ai-lab-runtime-language-source-query-receipt-failures receipt)
  (let ((failures '()))
    (def (fail! code)
      (set! failures (cons code failures)))
    (unless (and (object? receipt)
                 (eq? (.ref receipt 'kind)
                      +agentic-ai-lab-runtime-language-source-query-receipt-schema+))
      (fail! 'invalid-source-query-receipt-schema))
    (when (object? receipt)
      (unless (runtime-language-identity-present?
               (.ref receipt 'source-language))
        (fail! 'missing-source-language))
      (unless (runtime-language-identity-present?
               (.ref receipt 'source-content-id))
        (fail! 'missing-source-content-id))
      (unless (runtime-language-version-present?
               (.ref receipt 'source-version))
        (fail! 'missing-source-version))
      (unless (runtime-language-identity-present? (.ref receipt 'parser-id))
        (fail! 'missing-parser-id))
      (unless (runtime-language-version-present?
               (.ref receipt 'parser-version))
        (fail! 'missing-parser-version))
      (unless (runtime-language-identity-present? (.ref receipt 'query-id))
        (fail! 'missing-query-id))
      (unless (runtime-language-version-present?
               (.ref receipt 'query-version))
        (fail! 'missing-query-version))
      (unless (pair? (.ref receipt 'selected-node-identities))
        (fail! 'missing-selected-node-identities))
      (unless (member (.ref receipt 'representation)
                      +agentic-ai-lab-runtime-language-source-representations+)
        (fail! 'unsupported-source-representation))
      (unless (runtime-language-identity-present?
               (.ref receipt 'provenance-root))
        (fail! 'missing-provenance-root))
      (unless (runtime-language-identity-present?
               (.ref receipt 'result-digest))
        (fail! 'missing-query-result-digest)))
    (reverse failures)))

(def (agentic-ai-lab-runtime-language-source-query-receipt-valid? receipt)
  (null? (agentic-ai-lab-runtime-language-source-query-receipt-failures receipt)))

(def (agentic-ai-lab-runtime-language-source-query-receipt->alist receipt)
  (list
   (cons 'kind (.ref receipt 'kind))
   (cons 'source-language (.ref receipt 'source-language))
   (cons 'source-content-id (.ref receipt 'source-content-id))
   (cons 'source-version (.ref receipt 'source-version))
   (cons 'parser-id (.ref receipt 'parser-id))
   (cons 'parser-version (.ref receipt 'parser-version))
   (cons 'query-id (.ref receipt 'query-id))
   (cons 'query-version (.ref receipt 'query-version))
   (cons 'selected-node-identities
         (.ref receipt 'selected-node-identities))
   (cons 'representation (.ref receipt 'representation))
   (cons 'provenance-root (.ref receipt 'provenance-root))
   (cons 'result-digest (.ref receipt 'result-digest))
   (cons 'valid
         (agentic-ai-lab-runtime-language-source-query-receipt-valid? receipt))
   (cons 'failures
         (agentic-ai-lab-runtime-language-source-query-receipt-failures receipt))))

(def (agentic-ai-lab-runtime-language-admission-receipt
      source-query-receipt-value
      contract-id-value
      contract-version-value
      adapter-id-value
      adapter-version-value
      target-language-value
      normalized-semantic-digest-value
      admission-outcome-value
      failure-codes-value)
  (.o (kind +agentic-ai-lab-runtime-language-admission-receipt-schema+)
      (source-query-receipt source-query-receipt-value)
      (source-query-result-digest
       (and (object? source-query-receipt-value)
            (.ref source-query-receipt-value 'result-digest)))
      (contract-id contract-id-value)
      (contract-version contract-version-value)
      (adapter-id adapter-id-value)
      (adapter-version adapter-version-value)
      (target-language target-language-value)
      (normalized-semantic-digest normalized-semantic-digest-value)
      (admission-outcome admission-outcome-value)
      (failure-codes failure-codes-value)))

(def (agentic-ai-lab-runtime-language-admission-receipt-failures receipt)
  (let ((failures '()))
    (def (fail! code)
      (set! failures (cons code failures)))
    (unless (and (object? receipt)
                 (eq? (.ref receipt 'kind)
                      +agentic-ai-lab-runtime-language-admission-receipt-schema+))
      (fail! 'invalid-admission-receipt-schema))
    (when (object? receipt)
      (unless (agentic-ai-lab-runtime-language-source-query-receipt-valid?
               (.ref receipt 'source-query-receipt))
        (fail! 'invalid-source-query-receipt))
      (unless (runtime-language-identity-present? (.ref receipt 'contract-id))
        (fail! 'missing-contract-id))
      (unless (runtime-language-version-present?
               (.ref receipt 'contract-version))
        (fail! 'missing-contract-version))
      (unless (runtime-language-identity-present? (.ref receipt 'adapter-id))
        (fail! 'missing-adapter-id))
      (unless (runtime-language-version-present?
               (.ref receipt 'adapter-version))
        (fail! 'missing-adapter-version))
      (unless (runtime-language-identity-present?
               (.ref receipt 'target-language))
        (fail! 'missing-target-language))
      (unless (member (.ref receipt 'admission-outcome)
                      +agentic-ai-lab-runtime-language-admission-outcomes+)
        (fail! 'unsupported-admission-outcome))
      (when (eq? (.ref receipt 'admission-outcome) 'admitted)
        (unless (runtime-language-identity-present?
                 (.ref receipt 'normalized-semantic-digest))
          (fail! 'missing-normalized-semantic-digest))
        (unless (null? (.ref receipt 'failure-codes))
          (fail! 'admitted-projection-has-failures)))
      (when (eq? (.ref receipt 'admission-outcome) 'rejected)
        (unless (pair? (.ref receipt 'failure-codes))
          (fail! 'rejected-projection-missing-failures))))
    (reverse failures)))

(def (agentic-ai-lab-runtime-language-admission-receipt-valid? receipt)
  (null? (agentic-ai-lab-runtime-language-admission-receipt-failures receipt)))

(def (agentic-ai-lab-runtime-language-admission-receipt-admitted? receipt)
  (and (agentic-ai-lab-runtime-language-admission-receipt-valid? receipt)
       (eq? (.ref receipt 'admission-outcome) 'admitted)))

(def (agentic-ai-lab-runtime-language-admission-receipt->alist receipt)
  (list
   (cons 'kind (.ref receipt 'kind))
   (cons 'source-query-result-digest
         (.ref receipt 'source-query-result-digest))
   (cons 'contract-id (.ref receipt 'contract-id))
   (cons 'contract-version (.ref receipt 'contract-version))
   (cons 'adapter-id (.ref receipt 'adapter-id))
   (cons 'adapter-version (.ref receipt 'adapter-version))
   (cons 'target-language (.ref receipt 'target-language))
   (cons 'normalized-semantic-digest
         (.ref receipt 'normalized-semantic-digest))
   (cons 'admission-outcome (.ref receipt 'admission-outcome))
   (cons 'failure-codes (.ref receipt 'failure-codes))
   (cons 'valid
         (agentic-ai-lab-runtime-language-admission-receipt-valid? receipt))
   (cons 'admitted
         (agentic-ai-lab-runtime-language-admission-receipt-admitted? receipt))
   (cons 'failures
         (agentic-ai-lab-runtime-language-admission-receipt-failures receipt))))
(def (agentic-ai-lab-contract-artifact-projection-receipt
      projection-id-value
      contract-id-value
      contract-version-value
      source-contract-digest-value
      projector-id-value
      projector-version-value
      artifact-kind-value
      artifact-id-value
      output-digest-value)
  (.o (kind +agentic-ai-lab-contract-artifact-projection-receipt-schema+)
      (projection-id projection-id-value)
      (contract-id contract-id-value)
      (contract-version contract-version-value)
      (source-contract-digest source-contract-digest-value)
      (projector-id projector-id-value)
      (projector-version projector-version-value)
      (artifact-kind artifact-kind-value)
      (artifact-id artifact-id-value)
      (output-digest output-digest-value)))

(def (agentic-ai-lab-contract-artifact-projection-receipt-failures receipt)
  (let ((failures '()))
    (def (fail! code)
      (set! failures (cons code failures)))
    (unless (and (object? receipt)
                 (eq? (.ref receipt 'kind)
                      +agentic-ai-lab-contract-artifact-projection-receipt-schema+))
      (fail! 'invalid-artifact-projection-receipt-schema))
    (when (object? receipt)
      (unless (runtime-language-identity-present?
               (.ref receipt 'projection-id))
        (fail! 'missing-projection-id))
      (unless (runtime-language-identity-present? (.ref receipt 'contract-id))
        (fail! 'missing-contract-id))
      (unless (runtime-language-version-present?
               (.ref receipt 'contract-version))
        (fail! 'missing-contract-version))
      (unless (runtime-language-identity-present?
               (.ref receipt 'source-contract-digest))
        (fail! 'missing-source-contract-digest))
      (unless (runtime-language-identity-present? (.ref receipt 'projector-id))
        (fail! 'missing-projector-id))
      (unless (runtime-language-version-present?
               (.ref receipt 'projector-version))
        (fail! 'missing-projector-version))
      (unless (member (.ref receipt 'artifact-kind)
                      +agentic-ai-lab-contract-artifact-kinds+)
        (fail! 'unsupported-artifact-kind))
      (unless (runtime-language-identity-present? (.ref receipt 'artifact-id))
        (fail! 'missing-artifact-id))
      (unless (runtime-language-identity-present? (.ref receipt 'output-digest))
        (fail! 'missing-output-digest)))
    (reverse failures)))

(def (agentic-ai-lab-contract-artifact-projection-receipt-valid? receipt)
  (null? (agentic-ai-lab-contract-artifact-projection-receipt-failures receipt)))

(def (agentic-ai-lab-contract-artifact-projection-receipt->alist receipt)
  (list
   (cons 'kind (.ref receipt 'kind))
   (cons 'projection-id (.ref receipt 'projection-id))
   (cons 'contract-id (.ref receipt 'contract-id))
   (cons 'contract-version (.ref receipt 'contract-version))
   (cons 'source-contract-digest (.ref receipt 'source-contract-digest))
   (cons 'projector-id (.ref receipt 'projector-id))
   (cons 'projector-version (.ref receipt 'projector-version))
   (cons 'artifact-kind (.ref receipt 'artifact-kind))
   (cons 'artifact-id (.ref receipt 'artifact-id))
   (cons 'output-digest (.ref receipt 'output-digest))
   (cons 'valid
         (agentic-ai-lab-contract-artifact-projection-receipt-valid? receipt))
   (cons 'failures
         (agentic-ai-lab-contract-artifact-projection-receipt-failures receipt))))
