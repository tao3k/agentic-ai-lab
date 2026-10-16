;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         :std/test
        :clan/poo/object
        :poo-flow/modules/governance/policy/authorized-effect-token
        :poo-flow/modules/authorization/providers/cedar/decision
        :poo-flow/modules/governance/policy/strict-mediation
        :poo-flow/modules/proof/projections/authorized-effect-evidence
        :poo-flow/modules/tool-core/calling-control)


(def binding
  (poo-flow-effect-binding "bundle" 7 "policy" "entities" "allow"
                           "intent" 'attempt-1 'external-tool 'python-runtime
                           'session-1 1 1 'arena-1 3 0 16 "payload" 'lease-1))
(def root (poo-flow-semantic-root "bundle" "policy" "entities" "allow" "intent"))
(def validity (poo-flow-token-validity 10 10 20 4))
(def token (poo-flow-authorized-effect-token 'token-1 'nonce-1 root binding validity
                                              'strict 1 'scheme-control "sig"))
(def context (poo-flow-token-validation-context root binding 15 4 '()))

(def authorized-effect-token-test
  (test-suite "AC-08 AuthorizedEffectToken"
    (poo-flow-test-case "valid token reserves and commits deterministic root"
      (let* ((validation (poo-flow-authorized-effect-token-validate token context))
             (left (poo-flow-authorized-effect-token-consume token validation "root-0" "obs"))
             (right (poo-flow-authorized-effect-token-consume token validation "root-0" "obs")))
        (check (.ref validation 'accepted?) => #t)
        (check (.ref validation 'code) => 'token-reserved)
        (check (.ref left 'execution-root) => (.ref right 'execution-root))))
    (poo-flow-test-case "semantic reconstruction preserves binding and token digests"
      (let* ((binding-copy
              (poo-flow-effect-binding
               "bundle" 7 "policy" "entities" "allow" "intent"
               'attempt-1 'external-tool 'python-runtime 'session-1
               1 1 'arena-1 3 0 16 "payload" 'lease-1))
             (root-copy
              (poo-flow-semantic-root
               "bundle" "policy" "entities" "allow" "intent"))
             (validity-copy (poo-flow-token-validity 10 10 20 4))
             (token-copy
              (poo-flow-authorized-effect-token
               'token-1 'nonce-1 root-copy binding-copy validity-copy
               'strict 1 'scheme-control "sig")))
        (check (poo-flow-effect-binding-digest binding)
               => (poo-flow-effect-binding-digest binding-copy))
        (check (poo-flow-authorized-effect-token-digest token)
               => (poo-flow-authorized-effect-token-digest token-copy))))
    (poo-flow-test-case "one-shot nonce reuse fails closed"
      (let (receipt (poo-flow-authorized-effect-token-validate
                     token (poo-flow-token-validation-context root binding 15 4 '(nonce-1))))
        (check (.ref receipt 'accepted?) => #f)
        (check (.ref receipt 'code) => 'token-reuse)))
    (poo-flow-test-case "binding substitution and stale revocation fail closed"
      (let* ((other (poo-flow-effect-binding "bundle" 8 "policy" "entities" "allow"
                                             "intent" 'attempt-1 'external-tool 'python-runtime
                                             'session-1 1 1 'arena-1 3 0 16 "payload" 'lease-1))
             (substitution (poo-flow-authorized-effect-token-validate
                            token (poo-flow-token-validation-context root other 15 4 '())))
             (stale (poo-flow-authorized-effect-token-validate
                     token (poo-flow-token-validation-context root binding 15 5 '()))))
        (check (.ref substitution 'code) => 'binding-substitution)
        (check (.ref stale 'code) => 'stale-revocation-epoch)))
    (poo-flow-test-case "expiry and diagnostic execution fail closed"
      (let* ((expired (poo-flow-authorized-effect-token-validate
                       token (poo-flow-token-validation-context root binding 21 4 '())))
             (diagnostic-token (poo-flow-authorized-effect-token
                                'token-2 'nonce-2 root binding validity 'diagnostic 1
                                'scheme-control "sig"))
             (diagnostic (poo-flow-authorized-effect-token-validate diagnostic-token context)))
        (check (.ref expired 'code) => 'token-expired)
        (check (.ref diagnostic 'code) => 'diagnostic-cannot-execute)))
    (poo-flow-test-case "tool boundary requires committed token consumption"
      (let* ((validation (poo-flow-authorized-effect-token-validate token context))
             (consumption (poo-flow-authorized-effect-token-consume
                           token validation "root-0" "observation"))
             (mediated (poo-flow-tool-call-mediated-receipt
                        (.o (kind 'runtime-receipt)) validation consumption)))
        (check (.ref mediated 'status) => 'committed)
        (check (.ref mediated 'execution-root) =>
               (.ref consumption 'execution-root))))
    (poo-flow-test-case "Strict mediation commits, rejects forks, and spends unknown outcomes"
      (let* ((state (poo-flow-strict-mediation-state "root-0" 0 '() 4))
             (committed (poo-flow-strict-mediate state token context "root-0" "obs"))
             (committed-again
              (poo-flow-strict-mediate state token context "root-0" "obs"))
             (next (poo-flow-strict-mediation-result-state committed))
             (next-again
              (poo-flow-strict-mediation-result-state committed-again))
             (forked (poo-flow-strict-mediate state token context "other" "obs"))
             (unknown-token (poo-flow-authorized-effect-token
                             'token-3 'nonce-3 root binding validity 'strict 1
                             'scheme-control "sig"))
             (unknown-context (poo-flow-token-validation-context
                               root binding 15 4 (.ref next 'consumed-nonces)))
             (unknown (poo-flow-strict-mediate
                       next unknown-token unknown-context
                       (.ref next 'execution-root) #f)))
        (check (.ref (poo-flow-strict-mediation-result-receipt committed) 'outcome)
               => 'committed)
        (check (.ref (poo-flow-strict-mediation-result-receipt committed) 'after-root)
               =>
               (.ref (poo-flow-strict-mediation-result-receipt committed-again)
                     'after-root))
        (check (.ref next 'sequence) => (.ref next-again 'sequence))
        (check (.ref next 'consumed-nonces) => (.ref next-again 'consumed-nonces))
        (check (.ref (poo-flow-strict-mediation-result-receipt forked) 'code)
               => 'execution-root-fork)
        (check (.ref (poo-flow-strict-mediation-result-receipt unknown) 'outcome)
               => 'indeterminate)
        (check (member 'nonce-3
                       (.ref (poo-flow-strict-mediation-result-state unknown)
                             'consumed-nonces))
               ? values)))
    (poo-flow-test-case "Cedar projection binds decision digest without owning semantics"
      (let* ((decision (poo-flow-cedar-decision
                        'decision-1 'permit 'policy-1 "policy" "entities" '()))
             (semantic (poo-flow-cedar-decision->semantic-root
                        decision "bundle" "intent"))
             (cedar-binding
              (poo-flow-effect-binding
               "bundle" 7 "policy" "entities" (.ref decision 'decision-digest)
               "intent" 'attempt-2 'external-tool 'python-runtime 'session-1
               2 2 'arena-1 3 16 16 "payload-2" 'lease-2))
             (cedar-token
              (poo-flow-cedar-decision->authorized-effect-token
               decision 'token-4 'nonce-4 semantic cedar-binding validity
               'strict 1 'scheme-control "sig"))
             (forbid (poo-flow-cedar-decision
                      'decision-2 'forbid 'policy-1 "policy" "entities"
                      '(explicit-deny))))
        (check (poo-flow-cedar-decision-permit? decision) => #t)
        (check (poo-flow-cedar-decision-permit? forbid) => #f)
        (check (.ref cedar-token 'semantic-root) => semantic)
        (check (.ref cedar-binding 'decision-digest) =>
               (.ref decision 'decision-digest))))
    (poo-flow-test-case "proof levels never upgrade missing or unknown evidence"
      (let* ((l2 (poo-flow-authorized-effect-proof-facts
                  'effect-1 #t #t #t #t #t 'committed 'strict #f #f #f #f))
             (l3 (poo-flow-authorized-effect-proof-facts
                  'effect-2 #t #t #t #t #t 'committed 'strict
                  'evidence-row-1 "kernel-sig" #t #t))
             (unknown (poo-flow-authorized-effect-proof-facts
                       'effect-3 #t #t #t #t #f 'indeterminate 'strict
                       'evidence-row-2 "kernel-sig" #t #t))
             (wire (poo-flow-authorized-effect-proof-facts->ffi-wire l3)))
        (check (poo-flow-authorized-effect-proof-claim-level l2) => 'l2-evidenced)
        (check (poo-flow-authorized-effect-proof-claim-level l3) => 'l3-verified)
        (check (poo-flow-authorized-effect-proof-claim-level unknown) => 'l1-mediated)
        (check (cdr (assq 'claim-level wire)) => 'l3-verified))))
  )
