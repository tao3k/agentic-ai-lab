;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        :clan/poo/object
        :agentic-ai-lab/modules/governance/policy/authorized-effect-token
        :agentic-ai-lab/modules/authorization/providers/cedar/decision
        :agentic-ai-lab/modules/governance/policy/strict-mediation
        :agentic-ai-lab/modules/proof/projections/authorized-effect-evidence
        :agentic-ai-lab/modules/tool-core/calling-control)


(def binding
  (agentic-ai-lab-effect-binding "bundle" 7 "policy" "entities" "allow"
                           "intent" 'attempt-1 'external-tool 'python-runtime
                           'session-1 1 1 'arena-1 3 0 16 "payload" 'lease-1))
(def root (agentic-ai-lab-semantic-root "bundle" "policy" "entities" "allow" "intent"))
(def validity (agentic-ai-lab-token-validity 10 10 20 4))
(def token (agentic-ai-lab-authorized-effect-token 'token-1 'nonce-1 root binding validity
                                              'strict 1 'scheme-control "sig"))
(def context (agentic-ai-lab-token-validation-context root binding 15 4 '()))

(def authorized-effect-token-test
  (test-suite "AC-08 AuthorizedEffectToken"
    (yuanxu-test-case "valid token reserves and commits deterministic root"
      (let* ((validation (agentic-ai-lab-authorized-effect-token-validate token context))
             (left (agentic-ai-lab-authorized-effect-token-consume token validation "root-0" "obs"))
             (right (agentic-ai-lab-authorized-effect-token-consume token validation "root-0" "obs")))
        (check (.ref validation 'accepted?) => #t)
        (check (.ref validation 'code) => 'token-reserved)
        (check (.ref left 'execution-root) => (.ref right 'execution-root))))
    (yuanxu-test-case "semantic reconstruction preserves binding and token digests"
      (let* ((binding-copy
              (agentic-ai-lab-effect-binding
               "bundle" 7 "policy" "entities" "allow" "intent"
               'attempt-1 'external-tool 'python-runtime 'session-1
               1 1 'arena-1 3 0 16 "payload" 'lease-1))
             (root-copy
              (agentic-ai-lab-semantic-root
               "bundle" "policy" "entities" "allow" "intent"))
             (validity-copy (agentic-ai-lab-token-validity 10 10 20 4))
             (token-copy
              (agentic-ai-lab-authorized-effect-token
               'token-1 'nonce-1 root-copy binding-copy validity-copy
               'strict 1 'scheme-control "sig")))
        (check (agentic-ai-lab-effect-binding-digest binding)
               => (agentic-ai-lab-effect-binding-digest binding-copy))
        (check (agentic-ai-lab-authorized-effect-token-digest token)
               => (agentic-ai-lab-authorized-effect-token-digest token-copy))))
    (yuanxu-test-case "one-shot nonce reuse fails closed"
      (let (receipt (agentic-ai-lab-authorized-effect-token-validate
                     token (agentic-ai-lab-token-validation-context root binding 15 4 '(nonce-1))))
        (check (.ref receipt 'accepted?) => #f)
        (check (.ref receipt 'code) => 'token-reuse)))
    (yuanxu-test-case "binding substitution and stale revocation fail closed"
      (let* ((other (agentic-ai-lab-effect-binding "bundle" 8 "policy" "entities" "allow"
                                             "intent" 'attempt-1 'external-tool 'python-runtime
                                             'session-1 1 1 'arena-1 3 0 16 "payload" 'lease-1))
             (substitution (agentic-ai-lab-authorized-effect-token-validate
                            token (agentic-ai-lab-token-validation-context root other 15 4 '())))
             (stale (agentic-ai-lab-authorized-effect-token-validate
                     token (agentic-ai-lab-token-validation-context root binding 15 5 '()))))
        (check (.ref substitution 'code) => 'binding-substitution)
        (check (.ref stale 'code) => 'stale-revocation-epoch)))
    (yuanxu-test-case "expiry and diagnostic execution fail closed"
      (let* ((expired (agentic-ai-lab-authorized-effect-token-validate
                       token (agentic-ai-lab-token-validation-context root binding 21 4 '())))
             (diagnostic-token (agentic-ai-lab-authorized-effect-token
                                'token-2 'nonce-2 root binding validity 'diagnostic 1
                                'scheme-control "sig"))
             (diagnostic (agentic-ai-lab-authorized-effect-token-validate diagnostic-token context)))
        (check (.ref expired 'code) => 'token-expired)
        (check (.ref diagnostic 'code) => 'diagnostic-cannot-execute)))
    (yuanxu-test-case "tool boundary requires committed token consumption"
      (let* ((validation (agentic-ai-lab-authorized-effect-token-validate token context))
             (consumption (agentic-ai-lab-authorized-effect-token-consume
                           token validation "root-0" "observation"))
             (mediated (agentic-ai-lab-tool-call-mediated-receipt
                        (.o (kind 'runtime-receipt)) validation consumption)))
        (check (.ref mediated 'status) => 'committed)
        (check (.ref mediated 'execution-root) =>
               (.ref consumption 'execution-root))))
    (yuanxu-test-case "Strict mediation commits, rejects forks, and spends unknown outcomes"
      (let* ((state (agentic-ai-lab-strict-mediation-state "root-0" 0 '() 4))
             (committed (agentic-ai-lab-strict-mediate state token context "root-0" "obs"))
             (committed-again
              (agentic-ai-lab-strict-mediate state token context "root-0" "obs"))
             (next (agentic-ai-lab-strict-mediation-result-state committed))
             (next-again
              (agentic-ai-lab-strict-mediation-result-state committed-again))
             (forked (agentic-ai-lab-strict-mediate state token context "other" "obs"))
             (unknown-token (agentic-ai-lab-authorized-effect-token
                             'token-3 'nonce-3 root binding validity 'strict 1
                             'scheme-control "sig"))
             (unknown-context (agentic-ai-lab-token-validation-context
                               root binding 15 4 (.ref next 'consumed-nonces)))
             (unknown (agentic-ai-lab-strict-mediate
                       next unknown-token unknown-context
                       (.ref next 'execution-root) #f)))
        (check (.ref (agentic-ai-lab-strict-mediation-result-receipt committed) 'outcome)
               => 'committed)
        (check (.ref (agentic-ai-lab-strict-mediation-result-receipt committed) 'after-root)
               =>
               (.ref (agentic-ai-lab-strict-mediation-result-receipt committed-again)
                     'after-root))
        (check (.ref next 'sequence) => (.ref next-again 'sequence))
        (check (.ref next 'consumed-nonces) => (.ref next-again 'consumed-nonces))
        (check (.ref (agentic-ai-lab-strict-mediation-result-receipt forked) 'code)
               => 'execution-root-fork)
        (check (.ref (agentic-ai-lab-strict-mediation-result-receipt unknown) 'outcome)
               => 'indeterminate)
        (check (member 'nonce-3
                       (.ref (agentic-ai-lab-strict-mediation-result-state unknown)
                             'consumed-nonces))
               ? values)))
    (yuanxu-test-case "Cedar projection binds decision digest without owning semantics"
      (let* ((decision (agentic-ai-lab-cedar-decision
                        'decision-1 'permit 'policy-1 "policy" "entities" '()))
             (semantic (agentic-ai-lab-cedar-decision->semantic-root
                        decision "bundle" "intent"))
             (cedar-binding
              (agentic-ai-lab-effect-binding
               "bundle" 7 "policy" "entities" (.ref decision 'decision-digest)
               "intent" 'attempt-2 'external-tool 'python-runtime 'session-1
               2 2 'arena-1 3 16 16 "payload-2" 'lease-2))
             (cedar-token
              (agentic-ai-lab-cedar-decision->authorized-effect-token
               decision 'token-4 'nonce-4 semantic cedar-binding validity
               'strict 1 'scheme-control "sig"))
             (forbid (agentic-ai-lab-cedar-decision
                      'decision-2 'forbid 'policy-1 "policy" "entities"
                      '(explicit-deny))))
        (check (agentic-ai-lab-cedar-decision-permit? decision) => #t)
        (check (agentic-ai-lab-cedar-decision-permit? forbid) => #f)
        (check (.ref cedar-token 'semantic-root) => semantic)
        (check (.ref cedar-binding 'decision-digest) =>
               (.ref decision 'decision-digest))))
    (yuanxu-test-case "proof levels never upgrade missing or unknown evidence"
      (let* ((l2 (agentic-ai-lab-authorized-effect-proof-facts
                  'effect-1 #t #t #t #t #t 'committed 'strict #f #f #f #f))
             (l3 (agentic-ai-lab-authorized-effect-proof-facts
                  'effect-2 #t #t #t #t #t 'committed 'strict
                  'evidence-row-1 "kernel-sig" #t #t))
             (unknown (agentic-ai-lab-authorized-effect-proof-facts
                       'effect-3 #t #t #t #t #f 'indeterminate 'strict
                       'evidence-row-2 "kernel-sig" #t #t))
             (wire (agentic-ai-lab-authorized-effect-proof-facts->ffi-wire l3)))
        (check (agentic-ai-lab-authorized-effect-proof-claim-level l2) => 'l2-evidenced)
        (check (agentic-ai-lab-authorized-effect-proof-claim-level l3) => 'l3-verified)
        (check (agentic-ai-lab-authorized-effect-proof-claim-level unknown) => 'l1-mediated)
        (check (cdr (assq 'claim-level wire)) => 'l3-verified))))
  )
