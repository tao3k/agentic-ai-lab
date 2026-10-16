;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         :std/test
        :clan/poo/object
        :poo-flow/modules/workflow/contracts/release-assurance-manifest
        :poo-flow/modules/workflow/contracts/release-assurance-claim-verifier)

(export release-assurance-claim-verifier-test)

(def (evidence id owner)
  (poo-flow-assurance-evidence-reference id owner "artifact" "digest"))
(def abi (poo-flow-assurance-abi-decision 'runtime-v0.1 #f 'ac10-review))
(def gate-evidence (evidence 'gate 'scheme))
(def gate (poo-flow-assurance-gate-result 'claims 'scheme 'passed gate-evidence))

(def bundle-tcb
  (poo-flow-assurance-tcb
   'bundle 'bundle-semantic '(canonical-schema bundle-validator digest)))
(def actual-effect-tcb
  (poo-flow-assurance-tcb
   'effect 'actual-effect
   '(c-abi-transition-engine runtime adapter independent-observation)))
(def lean-tcb
  (poo-flow-assurance-tcb
   'lean 'lean-claim
   '(lean-kernel theorem-statement typed-decoder locked-import-environment
                 digest-binding)))

(def (claim id level tcb refs)
  (poo-flow-assurance-claim id level 'scheme tcb refs '() 'fail-closed))
(def (manifest claims)
  (poo-flow-release-assurance-manifest
   'rc-1 "revision" 'host '((gerbil . "0.18.2"))
   '((bundle . "digest")) (list bundle-tcb actual-effect-tcb lean-tcb)
   claims (list gate) abi))

(def release-assurance-claim-verifier-test
  (test-suite "AC-10 S2 claim and TCB verifier"
    (poo-flow-test-case "claim-specific L1, L3, and L4 receipts verify"
      (let* ((claims
              (list (claim 'bundle 'l1-conformant bundle-tcb
                           (list (evidence 'bundle 'scheme)))
                    (claim 'effect 'l3-mediated actual-effect-tcb
                           (list (evidence 'effect 'runtime-kernel)))
                    (claim 'proof 'l4-formally-linked lean-tcb
                           (list (evidence 'proof 'lean)))))
             (receipt
              (poo-flow-release-assurance-manifest-verify-claims
               (manifest claims))))
        (check (.ref receipt 'accepted?) => #t)
        (check (map (lambda (value) (.ref value 'declared-level))
                    (.ref receipt 'claim-receipts))
               => '(l1-conformant l3-mediated l4-formally-linked))))
    (poo-flow-test-case "Lean TCB cannot globally promote an actual-effect claim"
      (let (receipt
            (poo-flow-assurance-claim-verify
             (claim 'effect 'l3-mediated lean-tcb
                    (list (evidence 'proof 'lean)))))
        (check (.ref receipt 'accepted?) => #f)
        (check (map (lambda (entry) (cdr (assq 'code entry)))
                    (.ref receipt 'diagnostics))
               => '(claim-level-tcb-mismatch missing-mediation-evidence))))
    (poo-flow-test-case "L3 requires mediation owner and isolation component"
      (let* ((cooperative
              (poo-flow-assurance-tcb
               'effect 'actual-effect '(c-abi-transition-engine runtime adapter)))
             (receipt
              (poo-flow-assurance-claim-verify
               (claim 'effect 'l3-mediated cooperative
                      (list (evidence 'runtime 'python))))))
        (check (.ref receipt 'accepted?) => #f)
        (check (map (lambda (entry) (cdr (assq 'code entry)))
                    (.ref receipt 'diagnostics))
               => '(incomplete-claim-tcb missing-mediation-evidence))))
    (poo-flow-test-case "L4 requires named Lean-owned immutable proof evidence"
      (let* ((missing-digest
              (poo-flow-assurance-evidence-reference
               'proof 'lean "artifact" ""))
             (receipt
              (poo-flow-assurance-claim-verify
               (claim 'proof 'l4-formally-linked lean-tcb
                      (list missing-digest)))))
        (check (.ref receipt 'accepted?) => #f)
        (check (map (lambda (entry) (cdr (assq 'code entry)))
                    (.ref receipt 'diagnostics))
               => '(invalid-claim-evidence))))
    (poo-flow-test-case "unknown level and incomplete manifest fail closed"
      (let* ((unknown
              (poo-flow-assurance-claim-verify
               (claim 'unknown 'l9-marketing bundle-tcb
                      (list (evidence 'bundle 'scheme)))))
             (invalid
              (poo-flow-release-assurance-manifest
               'rc "revision" 'host '() '() (list bundle-tcb) '() '() abi))
             (manifest-receipt
              (poo-flow-release-assurance-manifest-verify-claims invalid)))
        (check (.ref unknown 'accepted?) => #f)
        (check (.ref manifest-receipt 'code) => 'invalid-manifest)))))
