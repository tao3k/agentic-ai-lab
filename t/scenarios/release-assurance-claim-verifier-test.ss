;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        :clan/poo/object
        :agentic-ai-lab/modules/workflow/contracts/release-assurance-manifest
        :agentic-ai-lab/modules/workflow/contracts/release-assurance-claim-verifier)

(export release-assurance-claim-verifier-test)

(def (evidence id owner)
  (agentic-ai-lab-assurance-evidence-reference id owner "artifact" "digest"))
(def abi (agentic-ai-lab-assurance-abi-decision 'runtime-v0.1 #f 'ac10-review))
(def gate-evidence (evidence 'gate 'scheme))
(def gate (agentic-ai-lab-assurance-gate-result 'claims 'scheme 'passed gate-evidence))

(def bundle-tcb
  (agentic-ai-lab-assurance-tcb
   'bundle 'bundle-semantic '(canonical-schema bundle-validator digest)))
(def actual-effect-tcb
  (agentic-ai-lab-assurance-tcb
   'effect 'actual-effect
   '(c-abi-transition-engine runtime adapter independent-observation)))
(def lean-tcb
  (agentic-ai-lab-assurance-tcb
   'lean 'lean-claim
   '(lean-kernel theorem-statement typed-decoder locked-import-environment
                 digest-binding)))

(def (claim id level tcb refs)
  (agentic-ai-lab-assurance-claim id level 'scheme tcb refs '() 'fail-closed))
(def (manifest claims)
  (agentic-ai-lab-release-assurance-manifest
   'rc-1 "revision" 'host '((gerbil . "0.18.2"))
   '((bundle . "digest")) (list bundle-tcb actual-effect-tcb lean-tcb)
   claims (list gate) abi))

(def release-assurance-claim-verifier-test
  (test-suite "AC-10 S2 claim and TCB verifier"
    (yuanxu-test-case "claim-specific L1, L3, and L4 receipts verify"
      (let* ((claims
              (list (claim 'bundle 'l1-conformant bundle-tcb
                           (list (evidence 'bundle 'scheme)))
                    (claim 'effect 'l3-mediated actual-effect-tcb
                           (list (evidence 'effect 'runtime-kernel)))
                    (claim 'proof 'l4-formally-linked lean-tcb
                           (list (evidence 'proof 'lean)))))
             (receipt
              (agentic-ai-lab-release-assurance-manifest-verify-claims
               (manifest claims))))
        (check (.ref receipt 'accepted?) => #t)
        (check (map (lambda (value) (.ref value 'declared-level))
                    (.ref receipt 'claim-receipts))
               => '(l1-conformant l3-mediated l4-formally-linked))))
    (yuanxu-test-case "Lean TCB cannot globally promote an actual-effect claim"
      (let (receipt
            (agentic-ai-lab-assurance-claim-verify
             (claim 'effect 'l3-mediated lean-tcb
                    (list (evidence 'proof 'lean)))))
        (check (.ref receipt 'accepted?) => #f)
        (check (map (lambda (entry) (cdr (assq 'code entry)))
                    (.ref receipt 'diagnostics))
               => '(claim-level-tcb-mismatch missing-mediation-evidence))))
    (yuanxu-test-case "L3 requires mediation owner and isolation component"
      (let* ((cooperative
              (agentic-ai-lab-assurance-tcb
               'effect 'actual-effect '(c-abi-transition-engine runtime adapter)))
             (receipt
              (agentic-ai-lab-assurance-claim-verify
               (claim 'effect 'l3-mediated cooperative
                      (list (evidence 'runtime 'python))))))
        (check (.ref receipt 'accepted?) => #f)
        (check (map (lambda (entry) (cdr (assq 'code entry)))
                    (.ref receipt 'diagnostics))
               => '(incomplete-claim-tcb missing-mediation-evidence))))
    (yuanxu-test-case "L4 requires named Lean-owned immutable proof evidence"
      (let* ((missing-digest
              (agentic-ai-lab-assurance-evidence-reference
               'proof 'lean "artifact" ""))
             (receipt
              (agentic-ai-lab-assurance-claim-verify
               (claim 'proof 'l4-formally-linked lean-tcb
                      (list missing-digest)))))
        (check (.ref receipt 'accepted?) => #f)
        (check (map (lambda (entry) (cdr (assq 'code entry)))
                    (.ref receipt 'diagnostics))
               => '(invalid-claim-evidence))))
    (yuanxu-test-case "unknown level and incomplete manifest fail closed"
      (let* ((unknown
              (agentic-ai-lab-assurance-claim-verify
               (claim 'unknown 'l9-marketing bundle-tcb
                      (list (evidence 'bundle 'scheme)))))
             (invalid
              (agentic-ai-lab-release-assurance-manifest
               'rc "revision" 'host '() '() (list bundle-tcb) '() '() abi))
             (manifest-receipt
              (agentic-ai-lab-release-assurance-manifest-verify-claims invalid)))
        (check (.ref unknown 'accepted?) => #f)
        (check (.ref manifest-receipt 'code) => 'invalid-manifest)))))
