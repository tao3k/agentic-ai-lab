;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: assemble AC-10 release evidence without re-deciding owner results.

(export #t)

(import (only-in :clan/poo/object .ref object<-alist)
        :poo-flow/modules/workflow/contracts/release-assurance-manifest
        :poo-flow/modules/workflow/contracts/release-assurance-claim-verifier
        :poo-flow/modules/workflow/qualification/agentic-control-plane-fixture
        :poo-flow/modules/workflow/qualification/runner)

(def (release-gate-receipt run gate-id)
  (find (lambda (receipt) (eq? gate-id (.ref receipt 'gate-id)))
        (.ref run 'gate-receipts)))

(def (release-evidence run gate-id evidence-owner)
  (let (receipt (release-gate-receipt run gate-id))
    (unless receipt (error "missing release gate receipt" gate-id))
    (poo-flow-assurance-evidence-reference
     gate-id evidence-owner (.ref receipt 'artifact)
     (.ref receipt 'declaration-digest))))

(def (release-tcbs)
  (list
   (poo-flow-assurance-tcb
    'bundle-tcb 'bundle-semantic
    '(canonical-schema bundle-validator digest))
   (poo-flow-assurance-tcb
    'authorization-tcb 'authorization
    '(bundle-to-cedar-projector cedar-evaluator token-issuer digest
                                revocation-state))
   (poo-flow-assurance-tcb
    'actual-effect-tcb 'actual-effect
    '(c-abi-transition-engine runtime adapter independent-observation))
   (poo-flow-assurance-tcb
    'evidence-history-tcb 'evidence-history
    '(canonical-event-hashing replay-protection batch-root))
   (poo-flow-assurance-tcb
    'lean-tcb 'lean-claim
    '(lean-kernel theorem-statement typed-decoder locked-import-environment
                  digest-binding))))

(def (tcb-ref tcbs id)
  (find (lambda (tcb) (eq? id (poo-flow-assurance-tcb-id tcb))) tcbs))

(def (release-claims run tcbs)
  (list
   (poo-flow-assurance-claim
    'canonical-bundle 'l1-conformant 'scheme
    (tcb-ref tcbs 'bundle-tcb)
    (list (release-evidence run 'scheme-canonical-fixture 'scheme))
    '(out-of-band-effects) 'reject-bundle)
   (poo-flow-assurance-claim
    'authorized-effect 'l2-evidenced 'cedar
    (tcb-ref tcbs 'authorization-tcb)
    (list (release-evidence run 'python-proof-functional 'python))
    '(runtime-honesty out-of-band-effects) 'deny-effect)
   (poo-flow-assurance-claim
    'mediated-effect 'l3-mediated 'runtime-kernel
    (tcb-ref tcbs 'actual-effect-tcb)
    (list (release-evidence run 'runtime-c-functional 'runtime-kernel)
          (release-evidence run 'runtime-c-sanitizers 'runtime-kernel))
    '(effects-outside-declared-scope) 'reject-mediation)
   (poo-flow-assurance-claim
    'evidence-history 'l2-evidenced 'runtime-kernel
    (tcb-ref tcbs 'evidence-history-tcb)
    (list (release-evidence run 'runtime-c-leaks 'runtime-kernel)
          (release-evidence run 'performance-matrix 'scheme))
    '(external-anchor) 'reject-history)
   (poo-flow-assurance-claim
    'authorized-effect-theorem-set 'l4-formally-linked 'lean
    (tcb-ref tcbs 'lean-tcb)
    (list (release-evidence run 'lean-build 'lean)
          (release-evidence run 'lean-ffi-smoke 'lean))
    '(unnamed-claims actual-effect-mediation) 'reject-proof)))

(def (release-gate-results run)
  (map
   (lambda (receipt)
     (let (evidence
           (poo-flow-assurance-evidence-reference
            (.ref receipt 'gate-id) (.ref receipt 'owner)
            (.ref receipt 'artifact) (.ref receipt 'declaration-digest)))
       (poo-flow-assurance-gate-result
        (.ref receipt 'gate-id) (.ref receipt 'owner)
        (if (.ref receipt 'accepted?) 'passed 'failed) evidence)))
   (.ref run 'gate-receipts)))

(def (poo-flow-ac10-release-assurance-assemble run fixture host toolchains)
  (let* ((registry (poo-flow-agentic-control-plane-gate-registry))
         (run-verification (poo-flow-qualification-verify-run registry run)))
    (unless (and (eq? (.ref run 'mode) 'release)
                 (.ref run-verification 'accepted?))
      (error "release assurance requires verified release run"))
    (let* ((tcbs (release-tcbs))
           (claims (release-claims run tcbs))
           (identities
            (append (.ref fixture 'identities)
                    (list (cons 'qualification-gate-count
                                (length (.ref run 'gate-receipts))))))
           (manifest
            (poo-flow-release-assurance-manifest
             'ac10-release-candidate (.ref run 'source-revision)
             host toolchains identities tcbs claims
             (release-gate-results run)
             (poo-flow-assurance-abi-decision
              'runtime-v0.1 #f 'ac10-explicit-review)))
           (validation
            (poo-flow-release-assurance-manifest-validate manifest))
           (claim-verification
            (poo-flow-release-assurance-manifest-verify-claims manifest)))
      (unless (and (.ref validation 'accepted?)
                   (.ref claim-verification 'accepted?))
        (error "assembled release assurance manifest rejected"
               (.ref validation 'diagnostics)
               (.ref claim-verification 'claim-receipts)))
      (object<-alist
       (list (cons 'kind 'poo-flow.ac10-release-assurance-receipt.v1)
             (cons 'accepted? #t)
             (cons 'run-verification run-verification)
             (cons 'manifest manifest)
             (cons 'manifest-validation validation)
             (cons 'claim-verification claim-verification)
             (cons 'manifest-identity
                   (poo-flow-release-assurance-manifest-identity manifest)))))))
