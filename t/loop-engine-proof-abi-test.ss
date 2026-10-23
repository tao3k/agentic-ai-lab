;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: proof ABI tests pin the Scheme-to-Lean proof-case vector shape.
;;; Invariant: these tests do not execute runtime work or call the proof checker.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-eq?
                 check-equal?
                 test-suite)
        :poo-flow/modules/loop-engine/proof-abi)

(export loop-engine-proof-abi-test)

;; : (-> LoopEngineProofAbiKey LoopEngineProofAbiRow LoopEngineProofAbiValue)
(def (proof-abi-field key row)
  (let (cell (assq key row))
    (if cell (cdr cell) #f)))

;; : (-> LoopEngineProofAbiValue Bool)
(def (truthy? value)
  (if value #t #f))

;; : (-> Unit TestSuite)
(def loop-engine-proof-abi-test
  (test-suite "poo-flow loop engine proof ABI"
    (yuanxu-test-case "obligation tags define a stable uint32 mask"
      (check-eq? +poo-flow-loop-engine-proof-obligation-count+ 10)
      (check-eq? +poo-flow-loop-engine-proof-required-obligation-mask+ 1023)
      (check-equal?
       (map car +poo-flow-loop-engine-proof-obligation-tags+)
       '(ui-config-well-formed
         ui-profile-policy-linked
         loop-strategy-plan-well-formed
         execution-policy-capability-bounded
         policy-strategy-deterministic
         runtime-command-inert
         workflow-agreement-linked
         sandbox-boundary-linked
         runtime-handoff-owner-linked
         proof-case-vector-complete))
      (check-eq?
       (proof-abi-field 'obligation-schema-version
                        (poo-flow-loop-engine-proof-c-abi))
       +poo-flow-loop-engine-proof-obligation-schema-version+))
    (yuanxu-test-case "obligations are proof-case records"
      (for-each
       (lambda (obligation)
         (check-eq?
          (truthy?
           (member (proof-abi-field 'domain obligation)
                   +poo-flow-loop-engine-proof-obligation-domains+))
          #t)
         (check-eq?
          (truthy?
           (member (proof-abi-field 'case-family obligation)
                   +poo-flow-loop-engine-proof-obligation-case-families+))
          #t)
         (check-eq? (list? (proof-abi-field 'evidence-fields obligation)) #t)
         (check-eq? (proof-abi-field 'runtime-executed obligation) #f))
       +poo-flow-loop-engine-proof-obligations+))
    (yuanxu-test-case "manifest carries the proof-case vector contract"
      (let (manifest
            (poo-flow-loop-engine-proof-manifest
             'request-1
             'artifact-1
             '(runtime-command-contract)
             '(object-families)
             '(receipt-contracts)
             '(runtime-packet-contracts)))
        (check-eq? (proof-abi-field 'proof-owner manifest) 'lean)
        (check-eq? (proof-abi-field 'proof-checker manifest) 'axle)
        (check-eq? (proof-abi-field 'runtime-executed manifest) #f)
        (check-equal?
         (proof-abi-field 'proof-case-vector-contract manifest)
         '(name claim source domain case-family evidence-fields runtime-executed))
        (check-equal?
         (proof-abi-field 'obligation-tags manifest)
         +poo-flow-loop-engine-proof-obligation-tags+)))))
