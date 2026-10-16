;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: verifies release-assurance claims against manifest evidence.
;;; Invariant: verification can reject claims but never upgrades their assurance level.
(export #t)

(import (only-in :clan/poo/object .o .ref)
        (only-in :core/utilities/functional
                 poo-flow-set-subset?)
        :poo-flow/modules/workflow/contracts/release-assurance-manifest)

(def +poo-flow-assurance-levels+
  '(l0-interface l1-conformant l2-evidenced l3-mediated
                 l4-formally-linked))

(def +poo-flow-assurance-tcb-families+
  '(bundle-semantic authorization actual-effect evidence-history lean-claim))

(def (assurance-any? required present)
  (ormap (lambda (value) (member value present)) required))

(def (assurance-level-family? level family)
  (case level
    ((l0-interface) (memq family +poo-flow-assurance-tcb-families+))
    ((l1-conformant)
     (memq family '(bundle-semantic authorization actual-effect
                                    evidence-history)))
    ((l2-evidenced)
     (memq family '(bundle-semantic authorization evidence-history)))
    ((l3-mediated) (eq? family 'actual-effect))
    ((l4-formally-linked) (eq? family 'lean-claim))
    (else #f)))

(def (assurance-tcb-components-valid? family components)
  (case family
    ((bundle-semantic)
     (poo-flow-set-subset? '(canonical-schema bundle-validator digest)
                           components))
    ((authorization)
     (poo-flow-set-subset?
      '(bundle-to-cedar-projector cedar-evaluator token-issuer digest
                                  revocation-state)
      components))
    ((actual-effect)
     (and (poo-flow-set-subset? '(c-abi-transition-engine runtime adapter)
                                components)
          (assurance-any? '(isolation independent-observation measurement
                                      attestation)
                          components)))
    ((evidence-history)
     (poo-flow-set-subset?
      '(canonical-event-hashing replay-protection batch-root)
      components))
    ((lean-claim)
     (poo-flow-set-subset?
      '(lean-kernel theorem-statement typed-decoder locked-import-environment
                    digest-binding)
      components))
    (else #f)))

(def (assurance-nonempty? value)
  (or (symbol? value)
      (and (string? value) (> (string-length value) 0))))

(def (assurance-evidence-valid? evidence)
  (and (poo-flow-assurance-evidence-reference? evidence)
       (assurance-nonempty?
        (poo-flow-assurance-evidence-reference-owner evidence))
       (assurance-nonempty?
        (poo-flow-assurance-evidence-reference-artifact evidence))
       (let (digest (poo-flow-assurance-evidence-reference-digest evidence))
         (and (string? digest) (> (string-length digest) 0)))))

(def (assurance-evidence-owner? owner evidence)
  (ormap (lambda (reference)
           (equal? owner
                   (poo-flow-assurance-evidence-reference-owner reference)))
         evidence))

(def (assurance-diagnostic code expected observed)
  (list (cons 'code code)
        (cons 'expected expected)
        (cons 'observed observed)))

(def (poo-flow-assurance-claim-verify claim)
  (let ((diagnostics '())
        (level (poo-flow-assurance-claim-level claim))
        (tcb (poo-flow-assurance-claim-tcb claim))
        (evidence (poo-flow-assurance-claim-evidence claim)))
    (def (reject! code expected observed)
      (set! diagnostics
            (cons (assurance-diagnostic code expected observed) diagnostics)))
    (unless (memq level +poo-flow-assurance-levels+)
      (reject! 'unknown-assurance-level +poo-flow-assurance-levels+ level))
    (if (not (poo-flow-assurance-tcb? tcb))
      (reject! 'invalid-claim-tcb 'poo-flow-assurance-tcb tcb)
      (let ((family (poo-flow-assurance-tcb-family tcb))
            (components (poo-flow-assurance-tcb-components tcb)))
        (unless (assurance-level-family? level family)
          (reject! 'claim-level-tcb-mismatch level family))
        (unless (assurance-tcb-components-valid? family components)
          (reject! 'incomplete-claim-tcb family components))))
    (unless (and (pair? evidence) (andmap assurance-evidence-valid? evidence))
      (reject! 'invalid-claim-evidence 'immutable-evidence-reference evidence))
    (when (and (eq? level 'l3-mediated)
               (not (assurance-evidence-owner? 'runtime-kernel evidence)))
      (reject! 'missing-mediation-evidence 'runtime-kernel
               (map poo-flow-assurance-evidence-reference-owner evidence)))
    (when (and (eq? level 'l4-formally-linked)
               (not (assurance-evidence-owner? 'lean evidence)))
      (reject! 'missing-lean-proof-evidence 'lean
               (map poo-flow-assurance-evidence-reference-owner evidence)))
    (let (diagnostic-values (reverse diagnostics))
      (.o (kind 'poo-flow.assurance-claim-verification-receipt.v1)
          (claim-id (poo-flow-assurance-claim-id claim))
          (declared-level level)
          (tcb-family
           (and (poo-flow-assurance-tcb? tcb)
                (poo-flow-assurance-tcb-family tcb)))
          (accepted? (null? diagnostic-values))
          (code (if (null? diagnostic-values) 'verified 'rejected))
          (diagnostics diagnostic-values)))))

(def (poo-flow-release-assurance-manifest-verify-claims manifest)
  (let (validation (poo-flow-release-assurance-manifest-validate manifest))
    (if (not (.ref validation 'accepted?))
      (.o (kind 'poo-flow.assurance-manifest-claim-receipt.v1)
          (accepted? #f)
          (code 'invalid-manifest)
          (claim-receipts '())
          (diagnostics (.ref validation 'diagnostics)))
      (let* ((receipts
              (map poo-flow-assurance-claim-verify
                   (poo-flow-release-assurance-manifest-claims manifest)))
             (accepted? (andmap (lambda (receipt)
                                  (.ref receipt 'accepted?))
                                receipts)))
        (let (accepted-value accepted?)
          (.o (kind 'poo-flow.assurance-manifest-claim-receipt.v1)
            (accepted? accepted-value)
            (code (if accepted? 'verified 'claim-rejected))
            (claim-receipts receipts)
            (diagnostics '())))))))
