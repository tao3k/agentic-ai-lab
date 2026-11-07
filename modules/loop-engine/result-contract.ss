;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-engine structured result contract projection.
;;; Invariant: this owner validates declaration shape only; it never validates
;;; runtime model output or executes reviewer operations.

(import "core.ss"
        :yuanxu/utilities/final-projection-syntax)

(export agentic-ai-lab-user-loop-engine-intent-result-contract
        agentic-ai-lab-user-loop-engine-result-contract-valid?
        agentic-ai-lab-user-loop-engine-result-contract-diagnostics
        agentic-ai-lab-user-loop-engine-intent-role-result-contract)

;;; Result-contract diagnostics use the same alist receipt style as module
;;; doctor output, but they stay local to loop-engine handoff validation.
;; : (-> ResultContractDiagnosticCode ResultContractDiagnosticTarget ResultContractDiagnosticDetail ResultContractDiagnostic)
(def (agentic-ai-lab-user-loop-engine-result-contract-diagnostic code
                                                           target
                                                           detail)
  (yuanxu-product-field-rows
   (severity 'error)
   (code code)
   (target target)
   (detail detail)))

;;; Role contracts must be symbols because they are schema ids, not inline
;;; schemas. Inline schema payloads belong in a later schema registry layer.
;; : (-> ResultContractRole LoopEngineResultContract [ResultContractDiagnostic])
(def (agentic-ai-lab-user-loop-engine-result-contract-role-diagnostics role contract)
  (let (value (agentic-ai-lab-user-loop-engine-intent-ref contract role #f))
    (if (symbol? value)
      '()
      (list
        (agentic-ai-lab-user-loop-engine-result-contract-diagnostic
        'invalid-result-contract-role
        role
        (yuanxu-product-field-rows
         (expected 'symbol)
         (value value)))))))

;;; Role scanning preserves the canonical role order so diagnostics remain
;;; deterministic for agents comparing receipts.
;; : (-> [ResultContractRole] LoopEngineResultContract [ResultContractDiagnostic])
(def (agentic-ai-lab-user-loop-engine-result-contract-roles-diagnostics roles
                                                                  contract)
  (cond
   ((null? roles) '())
   (else
    (yuanxu-product-rows/tail
     (agentic-ai-lab-user-loop-engine-result-contract-role-diagnostics
      (car roles)
      contract)
     (agentic-ai-lab-user-loop-engine-result-contract-roles-diagnostics
      (cdr roles)
      contract)))))

;;; Required fields are checked as a flat symbol list to keep the user DSL
;;; compact and prevent nested payloads from masquerading as field names.
;; : (-> ResultRequiredFieldsCandidate Boolean)
(def (agentic-ai-lab-user-loop-engine-result-required-fields? value)
  (and (pair? value)
       (list? value)
       (andmap symbol? value)))

;;; Required fields must be non-empty because an empty structured result is not
;;; useful to downstream agents judging a governor or human-audit decision.
;; : (-> LoopEngineResultContract [ResultContractDiagnostic])
(def (agentic-ai-lab-user-loop-engine-result-required-fields-diagnostics contract)
  (let (fields (agentic-ai-lab-user-loop-engine-intent-ref
                contract
                'required-fields
                '()))
    (if (agentic-ai-lab-user-loop-engine-result-required-fields? fields)
      '()
      (list
        (agentic-ai-lab-user-loop-engine-result-contract-diagnostic
        'invalid-result-required-fields
        'required-fields
        (yuanxu-product-field-rows
         (expected '(non-empty-list-of-symbols))
         (value fields)))))))

;;; Format is a symbolic protocol selector. The runtime may interpret it later,
;;; but Scheme only validates that agents cannot replace it with nested data.
;; : (-> LoopEngineResultContract [ResultContractDiagnostic])
(def (agentic-ai-lab-user-loop-engine-result-format-diagnostics contract)
  (let (format (agentic-ai-lab-user-loop-engine-intent-ref
                contract
                'format
                #f))
    (if (symbol? format)
      '()
      (list
        (agentic-ai-lab-user-loop-engine-result-contract-diagnostic
        'invalid-result-format
        'format
        (yuanxu-product-field-rows
         (expected 'symbol)
         (value format)))))))

;;; Validation is intentionally structural. It validates the control-plane
;;; receipt shape that agents edit, not the future backend result payload.
;; : (-> LoopEngineResultContract [ResultContractDiagnostic])
(def (agentic-ai-lab-user-loop-engine-result-contract-diagnostics contract)
  (yuanxu-product-rows/tail
   (agentic-ai-lab-user-loop-engine-result-contract-roles-diagnostics
    +agentic-ai-lab-user-loop-engine-result-contract-roles+
    contract)
   (yuanxu-product-rows/tail
    (agentic-ai-lab-user-loop-engine-result-required-fields-diagnostics contract)
    (agentic-ai-lab-user-loop-engine-result-format-diagnostics contract))))

;;; `valid?` is a receipt summary for presentation and manifest consumers; it
;;; never suppresses the diagnostics payload that explains the invalid shape.
;; : (-> LoopEngineResultContract Boolean)
(def (agentic-ai-lab-user-loop-engine-result-contract-valid? contract)
  (null? (agentic-ai-lab-user-loop-engine-result-contract-diagnostics contract)))

;;; Result contracts are user-authored expectations for structured reviewer
;;; output. The projection is total so older loop-engine declarations keep the
;;; default governor node contract.
;; : (-> LoopEngineIntentRow LoopEngineResultContract)
(def (agentic-ai-lab-user-loop-engine-intent-result-contract intent)
  (let ((result-rows
         (agentic-ai-lab-user-loop-engine-intent-ref intent 'result '())))
    (let* ((contract
            (yuanxu-product-field-rows
             (kind 'loop-engine-result-contract)
             (contract +agentic-ai-lab-user-loop-engine-result-contract+)
             (default
              (agentic-ai-lab-user-loop-engine-section-ref
               result-rows
               'default
               +agentic-ai-lab-user-loop-engine-default-result-contract+))
             (auditor
              (agentic-ai-lab-user-loop-engine-section-ref
               result-rows
               'auditor
               +agentic-ai-lab-user-loop-engine-default-result-contract+))
             (verifier
              (agentic-ai-lab-user-loop-engine-section-ref
               result-rows
               'verifier
               +agentic-ai-lab-user-loop-engine-default-result-contract+))
             (reviewer
              (agentic-ai-lab-user-loop-engine-section-ref
               result-rows
               'reviewer
               (agentic-ai-lab-user-loop-engine-section-ref
                result-rows
                'verifier
                +agentic-ai-lab-user-loop-engine-default-result-contract+)))
             (governor
              (agentic-ai-lab-user-loop-engine-section-ref
               result-rows
               'governor
               +agentic-ai-lab-user-loop-engine-default-result-contract+))
             (human-audit
              (agentic-ai-lab-user-loop-engine-section-ref
               result-rows
               'human-audit
               +agentic-ai-lab-user-loop-engine-default-result-contract+))
             (format
              (agentic-ai-lab-user-loop-engine-section-ref
               result-rows
               'format
               'structured-alist))
             (required-fields
              (agentic-ai-lab-user-loop-engine-section-ref
               result-rows
               'required-fields
               '(decision summary evidence)))
             (source 'user-config-loop-engine)
             (runtime-executed #f)))
           (diagnostics
            (agentic-ai-lab-user-loop-engine-result-contract-diagnostics contract)))
      (yuanxu-product-rows/tail
       contract
       (yuanxu-product-field-rows
        (valid? (null? diagnostics))
        (diagnostic-count (length diagnostics))
        (diagnostics diagnostics))))))

;;; Role-specific lookup lets machine reviewers and human audit inherit the
;;; same result contract packet while keeping their schema ids explicit.
;; : (-> LoopEngineIntentRow ResultContractRole ResultContractId)
(def (agentic-ai-lab-user-loop-engine-intent-role-result-contract intent role)
  (let ((contracts
         (agentic-ai-lab-user-loop-engine-intent-result-contract intent)))
    (agentic-ai-lab-user-loop-engine-intent-ref
     contracts
     role
     (agentic-ai-lab-user-loop-engine-intent-ref
      contracts
      'default
      +agentic-ai-lab-user-loop-engine-default-result-contract+))))
