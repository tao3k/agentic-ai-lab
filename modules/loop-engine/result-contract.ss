;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-engine structured result contract projection.
;;; Invariant: this owner validates declaration shape only; it never validates
;;; runtime model output or executes reviewer operations.

(import "core.ss"
        :core/utilities/final-projection-syntax)

(export poo-flow-user-loop-engine-intent-result-contract
        poo-flow-user-loop-engine-result-contract-valid?
        poo-flow-user-loop-engine-result-contract-diagnostics
        poo-flow-user-loop-engine-intent-role-result-contract)

;;; Result-contract diagnostics use the same alist receipt style as module
;;; doctor output, but they stay local to loop-engine handoff validation.
;; : (-> ResultContractDiagnosticCode ResultContractDiagnosticTarget ResultContractDiagnosticDetail ResultContractDiagnostic)
(def (poo-flow-user-loop-engine-result-contract-diagnostic code
                                                           target
                                                           detail)
  (poo-flow-product-field-rows
   (severity 'error)
   (code code)
   (target target)
   (detail detail)))

;;; Role contracts must be symbols because they are schema ids, not inline
;;; schemas. Inline schema payloads belong in a later schema registry layer.
;; : (-> ResultContractRole LoopEngineResultContract [ResultContractDiagnostic])
(def (poo-flow-user-loop-engine-result-contract-role-diagnostics role contract)
  (let (value (poo-flow-user-loop-engine-intent-ref contract role #f))
    (if (symbol? value)
      '()
      (list
        (poo-flow-user-loop-engine-result-contract-diagnostic
        'invalid-result-contract-role
        role
        (poo-flow-product-field-rows
         (expected 'symbol)
         (value value)))))))

;;; Role scanning preserves the canonical role order so diagnostics remain
;;; deterministic for agents comparing receipts.
;; : (-> [ResultContractRole] LoopEngineResultContract [ResultContractDiagnostic])
(def (poo-flow-user-loop-engine-result-contract-roles-diagnostics roles
                                                                  contract)
  (cond
   ((null? roles) '())
   (else
    (poo-flow-product-rows/tail
     (poo-flow-user-loop-engine-result-contract-role-diagnostics
      (car roles)
      contract)
     (poo-flow-user-loop-engine-result-contract-roles-diagnostics
      (cdr roles)
      contract)))))

;;; Required fields are checked as a flat symbol list to keep the user DSL
;;; compact and prevent nested payloads from masquerading as field names.
;; : (-> ResultRequiredFieldsCandidate Boolean)
(def (poo-flow-user-loop-engine-result-required-fields? value)
  (and (pair? value)
       (list? value)
       (andmap symbol? value)))

;;; Required fields must be non-empty because an empty structured result is not
;;; useful to downstream agents judging a governor or human-audit decision.
;; : (-> LoopEngineResultContract [ResultContractDiagnostic])
(def (poo-flow-user-loop-engine-result-required-fields-diagnostics contract)
  (let (fields (poo-flow-user-loop-engine-intent-ref
                contract
                'required-fields
                '()))
    (if (poo-flow-user-loop-engine-result-required-fields? fields)
      '()
      (list
        (poo-flow-user-loop-engine-result-contract-diagnostic
        'invalid-result-required-fields
        'required-fields
        (poo-flow-product-field-rows
         (expected '(non-empty-list-of-symbols))
         (value fields)))))))

;;; Format is a symbolic protocol selector. The runtime may interpret it later,
;;; but Scheme only validates that agents cannot replace it with nested data.
;; : (-> LoopEngineResultContract [ResultContractDiagnostic])
(def (poo-flow-user-loop-engine-result-format-diagnostics contract)
  (let (format (poo-flow-user-loop-engine-intent-ref
                contract
                'format
                #f))
    (if (symbol? format)
      '()
      (list
        (poo-flow-user-loop-engine-result-contract-diagnostic
        'invalid-result-format
        'format
        (poo-flow-product-field-rows
         (expected 'symbol)
         (value format)))))))

;;; Validation is intentionally structural. It validates the control-plane
;;; receipt shape that agents edit, not the future backend result payload.
;; : (-> LoopEngineResultContract [ResultContractDiagnostic])
(def (poo-flow-user-loop-engine-result-contract-diagnostics contract)
  (poo-flow-product-rows/tail
   (poo-flow-user-loop-engine-result-contract-roles-diagnostics
    +poo-flow-user-loop-engine-result-contract-roles+
    contract)
   (poo-flow-product-rows/tail
    (poo-flow-user-loop-engine-result-required-fields-diagnostics contract)
    (poo-flow-user-loop-engine-result-format-diagnostics contract))))

;;; `valid?` is a receipt summary for presentation and manifest consumers; it
;;; never suppresses the diagnostics payload that explains the invalid shape.
;; : (-> LoopEngineResultContract Boolean)
(def (poo-flow-user-loop-engine-result-contract-valid? contract)
  (null? (poo-flow-user-loop-engine-result-contract-diagnostics contract)))

;;; Result contracts are user-authored expectations for structured reviewer
;;; output. The projection is total so older loop-engine declarations keep the
;;; default governor node contract.
;; : (-> LoopEngineIntentRow LoopEngineResultContract)
(def (poo-flow-user-loop-engine-intent-result-contract intent)
  (let ((result-rows
         (poo-flow-user-loop-engine-intent-ref intent 'result '())))
    (let* ((contract
            (poo-flow-product-field-rows
             (kind 'loop-engine-result-contract)
             (contract +poo-flow-user-loop-engine-result-contract+)
             (default
              (poo-flow-user-loop-engine-section-ref
               result-rows
               'default
               +poo-flow-user-loop-engine-default-result-contract+))
             (auditor
              (poo-flow-user-loop-engine-section-ref
               result-rows
               'auditor
               +poo-flow-user-loop-engine-default-result-contract+))
             (verifier
              (poo-flow-user-loop-engine-section-ref
               result-rows
               'verifier
               +poo-flow-user-loop-engine-default-result-contract+))
             (reviewer
              (poo-flow-user-loop-engine-section-ref
               result-rows
               'reviewer
               (poo-flow-user-loop-engine-section-ref
                result-rows
                'verifier
                +poo-flow-user-loop-engine-default-result-contract+)))
             (governor
              (poo-flow-user-loop-engine-section-ref
               result-rows
               'governor
               +poo-flow-user-loop-engine-default-result-contract+))
             (human-audit
              (poo-flow-user-loop-engine-section-ref
               result-rows
               'human-audit
               +poo-flow-user-loop-engine-default-result-contract+))
             (format
              (poo-flow-user-loop-engine-section-ref
               result-rows
               'format
               'structured-alist))
             (required-fields
              (poo-flow-user-loop-engine-section-ref
               result-rows
               'required-fields
               '(decision summary evidence)))
             (source 'user-config-loop-engine)
             (runtime-executed #f)))
           (diagnostics
            (poo-flow-user-loop-engine-result-contract-diagnostics contract)))
      (poo-flow-product-rows/tail
       contract
       (poo-flow-product-field-rows
        (valid? (null? diagnostics))
        (diagnostic-count (length diagnostics))
        (diagnostics diagnostics))))))

;;; Role-specific lookup lets machine reviewers and human audit inherit the
;;; same result contract packet while keeping their schema ids explicit.
;; : (-> LoopEngineIntentRow ResultContractRole ResultContractId)
(def (poo-flow-user-loop-engine-intent-role-result-contract intent role)
  (let ((contracts
         (poo-flow-user-loop-engine-intent-result-contract intent)))
    (poo-flow-user-loop-engine-intent-ref
     contracts
     role
     (poo-flow-user-loop-engine-intent-ref
      contracts
      'default
      +poo-flow-user-loop-engine-default-result-contract+))))
