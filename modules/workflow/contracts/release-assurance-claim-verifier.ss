;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: verifies release-assurance claims against manifest evidence.
;;; Invariant: verification can reject claims but never upgrades their assurance level.
(export #t)

(import (only-in :clan/poo/object .o .ref)
        (only-in :yuanxu/utilities/functional
                 yuanxu-set-subset?)
        :agentic-ai-lab/modules/workflow/contracts/release-assurance-manifest)

(def +agentic-ai-lab-assurance-levels+
  '(l0-interface l1-conformant l2-evidenced l3-mediated
                 l4-formally-linked))

(def +agentic-ai-lab-assurance-tcb-families+
  '(bundle-semantic authorization actual-effect evidence-history lean-claim))

(def (assurance-any? required present)
  (ormap (lambda (value) (member value present)) required))

(def (assurance-level-family? level family)
  (case level
    ((l0-interface) (memq family +agentic-ai-lab-assurance-tcb-families+))
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
     (yuanxu-set-subset? '(canonical-schema bundle-validator digest)
                           components))
    ((authorization)
     (yuanxu-set-subset?
      '(bundle-to-cedar-projector cedar-evaluator token-issuer digest
                                  revocation-state)
      components))
    ((actual-effect)
     (and (yuanxu-set-subset? '(c-abi-transition-engine runtime adapter)
                                components)
          (assurance-any? '(isolation independent-observation measurement
                                      attestation)
                          components)))
    ((evidence-history)
     (yuanxu-set-subset?
      '(canonical-event-hashing replay-protection batch-root)
      components))
    ((lean-claim)
     (yuanxu-set-subset?
      '(lean-kernel theorem-statement typed-decoder locked-import-environment
                    digest-binding)
      components))
    (else #f)))

(def (assurance-nonempty? value)
  (or (symbol? value)
      (and (string? value) (> (string-length value) 0))))

(def (assurance-evidence-valid? evidence)
  (and (agentic-ai-lab-assurance-evidence-reference? evidence)
       (assurance-nonempty?
        (agentic-ai-lab-assurance-evidence-reference-owner evidence))
       (assurance-nonempty?
        (agentic-ai-lab-assurance-evidence-reference-artifact evidence))
       (let (digest (agentic-ai-lab-assurance-evidence-reference-digest evidence))
         (and (string? digest) (> (string-length digest) 0)))))

(def (assurance-evidence-owner? owner evidence)
  (ormap (lambda (reference)
           (equal? owner
                   (agentic-ai-lab-assurance-evidence-reference-owner reference)))
         evidence))

(def (assurance-diagnostic code expected observed)
  (list (cons 'code code)
        (cons 'expected expected)
        (cons 'observed observed)))

(def (agentic-ai-lab-assurance-claim-verify claim)
  (let ((diagnostics '())
        (level (agentic-ai-lab-assurance-claim-level claim))
        (tcb (agentic-ai-lab-assurance-claim-tcb claim))
        (evidence (agentic-ai-lab-assurance-claim-evidence claim)))
    (def (reject! code expected observed)
      (set! diagnostics
            (cons (assurance-diagnostic code expected observed) diagnostics)))
    (unless (memq level +agentic-ai-lab-assurance-levels+)
      (reject! 'unknown-assurance-level +agentic-ai-lab-assurance-levels+ level))
    (if (not (agentic-ai-lab-assurance-tcb? tcb))
      (reject! 'invalid-claim-tcb 'agentic-ai-lab-assurance-tcb tcb)
      (let ((family (agentic-ai-lab-assurance-tcb-family tcb))
            (components (agentic-ai-lab-assurance-tcb-components tcb)))
        (unless (assurance-level-family? level family)
          (reject! 'claim-level-tcb-mismatch level family))
        (unless (assurance-tcb-components-valid? family components)
          (reject! 'incomplete-claim-tcb family components))))
    (unless (and (pair? evidence) (andmap assurance-evidence-valid? evidence))
      (reject! 'invalid-claim-evidence 'immutable-evidence-reference evidence))
    (when (and (eq? level 'l3-mediated)
               (not (assurance-evidence-owner? 'runtime-kernel evidence)))
      (reject! 'missing-mediation-evidence 'runtime-kernel
               (map agentic-ai-lab-assurance-evidence-reference-owner evidence)))
    (when (and (eq? level 'l4-formally-linked)
               (not (assurance-evidence-owner? 'lean evidence)))
      (reject! 'missing-lean-proof-evidence 'lean
               (map agentic-ai-lab-assurance-evidence-reference-owner evidence)))
    (let (diagnostic-values (reverse diagnostics))
      (.o (kind 'agentic-ai-lab.assurance-claim-verification-receipt.v1)
          (claim-id (agentic-ai-lab-assurance-claim-id claim))
          (declared-level level)
          (tcb-family
           (and (agentic-ai-lab-assurance-tcb? tcb)
                (agentic-ai-lab-assurance-tcb-family tcb)))
          (accepted? (null? diagnostic-values))
          (code (if (null? diagnostic-values) 'verified 'rejected))
          (diagnostics diagnostic-values)))))

(def (agentic-ai-lab-release-assurance-manifest-verify-claims manifest)
  (let (validation (agentic-ai-lab-release-assurance-manifest-validate manifest))
    (if (not (.ref validation 'accepted?))
      (.o (kind 'agentic-ai-lab.assurance-manifest-claim-receipt.v1)
          (accepted? #f)
          (code 'invalid-manifest)
          (claim-receipts '())
          (diagnostics (.ref validation 'diagnostics)))
      (let* ((receipts
              (map agentic-ai-lab-assurance-claim-verify
                   (agentic-ai-lab-release-assurance-manifest-claims manifest)))
             (accepted? (andmap (lambda (receipt)
                                  (.ref receipt 'accepted?))
                                receipts)))
        (let (accepted-value accepted?)
          (.o (kind 'agentic-ai-lab.assurance-manifest-claim-receipt.v1)
            (accepted? accepted-value)
            (code (if accepted? 'verified 'claim-rejected))
            (claim-receipts receipts)
            (diagnostics '())))))))
