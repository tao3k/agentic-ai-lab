;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: defines the Runtime v0 wire ABI for protocol-person promotion.
;;; Invariant: ABI receipts preserve policy decision and provenance identities.
(import (only-in :clan/poo/object .o .ref object?)
        :poo-flow/modules/governance/policy/protocol-person-promotion
        :poo-flow/modules/workflow/contracts/runtime-v0-abi-schema)

(export #t)

(def +poo-flow-runtime-language-promotion-request-schema+
  (string->symbol
   (.ref +poo-flow-runtime-v0-abi-schema+ 'promotion-request-schema)))

(def +poo-flow-runtime-language-promotion-receipt-schema+
  (string->symbol
   (.ref +poo-flow-runtime-v0-abi-schema+ 'promotion-receipt-schema)))

(def +poo-flow-runtime-language-promotion-required-capabilities+
  '(PROMOTION_MATERIALIZE
    INJECTION_RECEIPT
    ROLLBACK
    EXACTLY_ONCE
    LANGUAGE_QUALIFICATION))

(def +poo-flow-runtime-language-promotion-outcomes+
  '(accepted
    materialized
    injected
    replayed-active
    rejected-stale-epoch
    rejected-capability
    rolled-back
    failed))

;; : (-> PooPromotionIntent PooRuntimeLanguagePromotionIdempotencyKey)
(def (poo-flow-runtime-language-promotion-idempotency-key intent)
  (.o (kind 'poo-flow.runtime-language.promotion-idempotency-key.1)
      (promotion-id (.ref intent 'promotion-id))
      (materialization-id (.ref intent 'materialization-id))
      (candidate-digest (.ref intent 'candidate-digest))
      (injection-target (.ref intent 'injection-target))))

;; : (-> PooRuntimeLanguagePromotionIdempotencyKey Alist)
(def (poo-flow-runtime-language-promotion-idempotency-key->alist key)
  (list (cons 'kind (.ref key 'kind))
        (cons 'promotion-id (.ref key 'promotion-id))
        (cons 'materialization-id (.ref key 'materialization-id))
        (cons 'candidate-digest (.ref key 'candidate-digest))
        (cons 'injection-target (.ref key 'injection-target))))

;; : (-> PooPromotionIntent PooPromotionValidationReceipt PooRuntimeLanguagePromotionRequest)
(def (poo-flow-runtime-language-promotion-request intent validation-receipt)
  (unless (and (object? intent)
               (eq? (.ref intent 'kind) 'poo-flow-promotion-intent))
    (error "runtime language ABI requires a POO promotion intent" intent))
  (unless (and (poo-flow-promotion-validation-receipt?
                validation-receipt)
               (poo-flow-promotion-validation-receipt-approved?
                validation-receipt))
    (error "runtime language ABI rejects an unapproved promotion"
           validation-receipt))
  (unless (and (equal? (.ref intent 'promotion-id)
                       (poo-flow-promotion-validation-receipt-promotion-id
                        validation-receipt))
               (equal? (.ref intent 'candidate-digest)
                       (poo-flow-promotion-validation-receipt-candidate-digest
                        validation-receipt)))
    (error "promotion intent and validation receipt identities differ"
           intent validation-receipt))
  (.o (kind +poo-flow-runtime-language-promotion-request-schema+)
      (abi-major (.ref +poo-flow-runtime-v0-abi-schema+ 'abi-major))
      (abi-minor (.ref +poo-flow-runtime-v0-abi-schema+ 'abi-minor))
      (required-capabilities
       +poo-flow-runtime-language-promotion-required-capabilities+)
      (idempotency-key
       (poo-flow-runtime-language-promotion-idempotency-key intent))
      (promotion-id (.ref intent 'promotion-id))
      (candidate-digest (.ref intent 'candidate-digest))
      (subject-id (.ref intent 'subject-id))
      (commitment-id (.ref intent 'commitment-id))
      (source-role (.ref intent 'source-role))
      (target-role (.ref intent 'target-role))
      (scope (.ref intent 'scope))
      (bundle-epoch (.ref intent 'expected-bundle-epoch))
      (authority-epoch (.ref intent 'expected-authority-epoch))
      (proof-epoch (.ref intent 'expected-proof-epoch))
      (evaluator-epoch (.ref intent 'expected-evaluator-epoch))
      (evidence-root (.ref intent 'evidence-root))
      (materialization-id (.ref intent 'materialization-id))
      (injection-target (.ref intent 'injection-target))
      (rollback-target (.ref intent 'rollback-target))
      (validation-receipt-schema
       (poo-flow-promotion-validation-receipt-schema validation-receipt))
      (approval-code
       (poo-flow-promotion-validation-receipt-approval-code
        validation-receipt))
      (checked-gates
       (poo-flow-promotion-validation-receipt-checked-gates
        validation-receipt))
      (runtime-executed #f)))

;; : (-> PooRuntimeLanguagePromotionRequest Alist)
(def (poo-flow-runtime-language-promotion-request->alist request)
  (let (key (.ref request 'idempotency-key))
    (list
     (cons 'kind (.ref request 'kind))
     (cons 'abi-major (.ref request 'abi-major))
     (cons 'abi-minor (.ref request 'abi-minor))
     (cons 'required-capabilities (.ref request 'required-capabilities))
     (cons 'idempotency-key
           (poo-flow-runtime-language-promotion-idempotency-key->alist key))
     (cons 'promotion-id (.ref request 'promotion-id))
     (cons 'candidate-digest (.ref request 'candidate-digest))
     (cons 'subject-id (.ref request 'subject-id))
     (cons 'commitment-id (.ref request 'commitment-id))
     (cons 'source-role (.ref request 'source-role))
     (cons 'target-role (.ref request 'target-role))
     (cons 'scope (.ref request 'scope))
     (cons 'bundle-epoch (.ref request 'bundle-epoch))
     (cons 'authority-epoch (.ref request 'authority-epoch))
     (cons 'proof-epoch (.ref request 'proof-epoch))
     (cons 'evaluator-epoch (.ref request 'evaluator-epoch))
     (cons 'evidence-root (.ref request 'evidence-root))
     (cons 'materialization-id (.ref request 'materialization-id))
     (cons 'injection-target (.ref request 'injection-target))
     (cons 'rollback-target (.ref request 'rollback-target))
     (cons 'validation-receipt-schema
           (.ref request 'validation-receipt-schema))
     (cons 'approval-code (.ref request 'approval-code))
     (cons 'checked-gates (.ref request 'checked-gates))
     (cons 'runtime-executed (.ref request 'runtime-executed)))))

;; : (-> OutputPort String Object Unit)
(def (runtime-language-abi-emit-field port name value)
  (display name port)
  (display "=" port)
  (display value port)
  (newline port))

;; : (-> PooRuntimeLanguagePromotionRequest String)
(def (poo-flow-runtime-language-promotion-request->vector request)
  (let ((port (open-output-string))
        (key (.ref request 'idempotency-key)))
    (runtime-language-abi-emit-field port "schema" (.ref request 'kind))
    (runtime-language-abi-emit-field port "abi-major" (.ref request 'abi-major))
    (runtime-language-abi-emit-field port "abi-minor" (.ref request 'abi-minor))
    (runtime-language-abi-emit-field
     port "required-capabilities" (.ref request 'required-capabilities))
    (runtime-language-abi-emit-field
     port "idempotency-key-schema" (.ref key 'kind))
    (runtime-language-abi-emit-field
     port "promotion-id" (.ref request 'promotion-id))
    (runtime-language-abi-emit-field
     port "materialization-id" (.ref request 'materialization-id))
    (runtime-language-abi-emit-field
     port "candidate-digest" (.ref request 'candidate-digest))
    (runtime-language-abi-emit-field
     port "subject-id" (.ref request 'subject-id))
    (runtime-language-abi-emit-field
     port "commitment-id" (.ref request 'commitment-id))
    (runtime-language-abi-emit-field
     port "source-role" (.ref request 'source-role))
    (runtime-language-abi-emit-field
     port "target-role" (.ref request 'target-role))
    (runtime-language-abi-emit-field port "scope" (.ref request 'scope))
    (runtime-language-abi-emit-field
     port "bundle-epoch" (.ref request 'bundle-epoch))
    (runtime-language-abi-emit-field
     port "authority-epoch" (.ref request 'authority-epoch))
    (runtime-language-abi-emit-field
     port "proof-epoch" (.ref request 'proof-epoch))
    (runtime-language-abi-emit-field
     port "evaluator-epoch" (.ref request 'evaluator-epoch))
    (runtime-language-abi-emit-field
     port "evidence-root" (.ref request 'evidence-root))
    (runtime-language-abi-emit-field
     port "injection-target" (.ref request 'injection-target))
    (runtime-language-abi-emit-field
     port "rollback-target" (.ref request 'rollback-target))
    (runtime-language-abi-emit-field
     port "validation-receipt-schema"
     (.ref request 'validation-receipt-schema))
    (runtime-language-abi-emit-field
     port "approval-code" (.ref request 'approval-code))
    (runtime-language-abi-emit-field
     port "checked-gates" (.ref request 'checked-gates))
    (get-output-string port)))

;; : (-> String)
(def (poo-flow-runtime-language-promotion-abi->c-header)
  (poo-flow-runtime-v0-abi-schema->c-header
   +poo-flow-runtime-v0-abi-schema+))

;; : (-> [Symbol] Boolean)
(def (poo-flow-runtime-language-promotion-capabilities-cover? supported)
  (let loop ((required
              +poo-flow-runtime-language-promotion-required-capabilities+))
    (or (null? required)
        (and (memq (car required) supported)
             (loop (cdr required))))))

;; : (-> PooRuntimeLanguagePromotionRequest PooRuntimeLanguageWorld Boolean)
(def (poo-flow-runtime-language-promotion-epochs-current? request world)
  (and (= (.ref request 'bundle-epoch) (.ref world 'bundle-epoch))
       (= (.ref request 'authority-epoch) (.ref world 'authority-epoch))
       (= (.ref request 'proof-epoch) (.ref world 'proof-epoch))
       (= (.ref request 'evaluator-epoch) (.ref world 'evaluator-epoch))))

;; : (-> PooRuntimeLanguagePromotionRequest PooRuntimeLanguageWorld Symbol String Symbol [Symbol] Integer Symbol MaybeString MaybeString MaybeString MaybeString PooRuntimeLanguagePromotionReceipt)
(def (poo-flow-runtime-language-promotion-receipt
      request world implementation-id-value implementation-version-value
      language-value supported-capabilities-value attempt-value outcome-value
      materialization-digest-value injection-receipt-digest-value
      rollback-receipt-digest-value causal-receipt-digest-value)
  (unless (and (object? request)
               (eq? (.ref request 'kind)
                    +poo-flow-runtime-language-promotion-request-schema+))
    (error "runtime receipt requires a canonical promotion request" request))
  (.o (kind +poo-flow-runtime-language-promotion-receipt-schema+)
      (abi-major (.ref request 'abi-major))
      (abi-minor (.ref request 'abi-minor))
      (idempotency-key (.ref request 'idempotency-key))
      (promotion-id (.ref request 'promotion-id))
      (materialization-id (.ref request 'materialization-id))
      (candidate-digest (.ref request 'candidate-digest))
      (implementation-id implementation-id-value)
      (implementation-version implementation-version-value)
      (language language-value)
      (supported-capabilities supported-capabilities-value)
      (capability-qualified
       (poo-flow-runtime-language-promotion-capabilities-cover?
        supported-capabilities-value))
      (attempt attempt-value)
      (outcome outcome-value)
      (observed-bundle-epoch (.ref world 'bundle-epoch))
      (observed-authority-epoch (.ref world 'authority-epoch))
      (observed-proof-epoch (.ref world 'proof-epoch))
      (observed-evaluator-epoch (.ref world 'evaluator-epoch))
      (epoch-current
       (poo-flow-runtime-language-promotion-epochs-current? request world))
      (materialization-digest materialization-digest-value)
      (injection-receipt-digest injection-receipt-digest-value)
      (rollback-receipt-digest rollback-receipt-digest-value)
      (causal-receipt-digest causal-receipt-digest-value)
      (runtime-executed #t)))

;; : (-> Object Boolean)
(def (runtime-language-abi-present? value)
  (and value
       (not (equal? value ""))
       (not (equal? value 'none))))

;; : (-> Symbol Boolean)
(def (runtime-language-abi-rejected-outcome? outcome)
  (memq outcome '(rejected-stale-epoch rejected-capability failed)))

;; : (-> PooRuntimeLanguagePromotionReceipt [Symbol])
(def (poo-flow-runtime-language-promotion-receipt-failures receipt)
  (let ((outcome (.ref receipt 'outcome))
        (qualified? (.ref receipt 'capability-qualified))
        (current? (.ref receipt 'epoch-current))
        (materialization (.ref receipt 'materialization-digest))
        (injection (.ref receipt 'injection-receipt-digest))
        (rollback (.ref receipt 'rollback-receipt-digest))
        (causal (.ref receipt 'causal-receipt-digest)))
    (filter-map
     (lambda (check) (and (not (car check)) (cdr check)))
     (list
           (cons (and (integer? (.ref receipt 'attempt))
                      (> (.ref receipt 'attempt) 0))
                 'invalid-attempt)
           (cons (memq outcome +poo-flow-runtime-language-promotion-outcomes+)
                 'invalid-outcome)
           (cons (or qualified? (eq? outcome 'rejected-capability))
                 'unsupported-capability-effect)
           (cons (or (not qualified?)
                     (not (eq? outcome 'rejected-capability)))
                 'false-capability-rejection)
           (cons (or current? (eq? outcome 'rejected-stale-epoch))
                 'stale-epoch-effect)
           (cons (or (not current?)
                     (not (eq? outcome 'rejected-stale-epoch)))
                 'false-stale-rejection)
           (cons (or (not (eq? outcome 'materialized))
                     (runtime-language-abi-present? materialization))
                 'materialization-digest-missing)
           (cons (or (not (memq outcome '(injected replayed-active)))
                     (and (runtime-language-abi-present? materialization)
                          (runtime-language-abi-present? injection)))
                 'injection-receipt-incomplete)
           (cons (or (not (eq? outcome 'replayed-active))
                     (runtime-language-abi-present? causal))
                 'replay-causal-receipt-missing)
           (cons (or (not (eq? outcome 'rolled-back))
                     (runtime-language-abi-present? rollback))
                 'rollback-receipt-missing)
           (cons (or (not (runtime-language-abi-rejected-outcome? outcome))
                     (and (not (runtime-language-abi-present? materialization))
                          (not (runtime-language-abi-present? injection))
                          (not (runtime-language-abi-present? rollback))))
                 'rejected-outcome-carried-effects)
           (cons (.ref receipt 'runtime-executed)
                 'runtime-execution-receipt-missing)))))

;; : (-> PooRuntimeLanguagePromotionReceipt Boolean)
(def (poo-flow-runtime-language-promotion-receipt-valid? receipt)
  (null? (poo-flow-runtime-language-promotion-receipt-failures receipt)))

;; : (-> PooRuntimeLanguagePromotionReceipt Boolean)
(def (poo-flow-runtime-language-promotion-receipt-active? receipt)
  (and (poo-flow-runtime-language-promotion-receipt-valid? receipt)
       (memq (.ref receipt 'outcome) '(injected replayed-active))
       #t))

;; : (-> PooRuntimeLanguagePromotionReceipt Alist)
(def (poo-flow-runtime-language-promotion-receipt->alist receipt)
  (list
   (cons 'kind (.ref receipt 'kind))
   (cons 'abi-major (.ref receipt 'abi-major))
   (cons 'abi-minor (.ref receipt 'abi-minor))
   (cons 'idempotency-key
         (poo-flow-runtime-language-promotion-idempotency-key->alist
          (.ref receipt 'idempotency-key)))
   (cons 'promotion-id (.ref receipt 'promotion-id))
   (cons 'materialization-id (.ref receipt 'materialization-id))
   (cons 'candidate-digest (.ref receipt 'candidate-digest))
   (cons 'implementation-id (.ref receipt 'implementation-id))
   (cons 'implementation-version (.ref receipt 'implementation-version))
   (cons 'language (.ref receipt 'language))
   (cons 'supported-capabilities (.ref receipt 'supported-capabilities))
   (cons 'capability-qualified (.ref receipt 'capability-qualified))
   (cons 'attempt (.ref receipt 'attempt))
   (cons 'outcome (.ref receipt 'outcome))
   (cons 'observed-bundle-epoch (.ref receipt 'observed-bundle-epoch))
   (cons 'observed-authority-epoch (.ref receipt 'observed-authority-epoch))
   (cons 'observed-proof-epoch (.ref receipt 'observed-proof-epoch))
   (cons 'observed-evaluator-epoch (.ref receipt 'observed-evaluator-epoch))
   (cons 'epoch-current (.ref receipt 'epoch-current))
   (cons 'materialization-digest (.ref receipt 'materialization-digest))
   (cons 'injection-receipt-digest
         (.ref receipt 'injection-receipt-digest))
   (cons 'rollback-receipt-digest
         (.ref receipt 'rollback-receipt-digest))
   (cons 'causal-receipt-digest (.ref receipt 'causal-receipt-digest))
   (cons 'runtime-executed (.ref receipt 'runtime-executed))
   (cons 'valid
         (poo-flow-runtime-language-promotion-receipt-valid? receipt))
   (cons 'failures
         (poo-flow-runtime-language-promotion-receipt-failures receipt))))

;; : (-> [PooRuntimeLanguagePromotionReceipt] Boolean)
(def (poo-flow-runtime-language-promotion-receipts-exactly-once? receipts)
  (= 1
     (foldl
      (lambda (receipt committed)
        (if (and (poo-flow-runtime-language-promotion-receipt-valid? receipt)
                 (eq? (.ref receipt 'outcome) 'injected))
          (+ committed 1)
          committed))
      0
      receipts)))
