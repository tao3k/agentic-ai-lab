;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test (only-in :poo-flow/testing-api yuanxu-test-case)
        (only-in :clan/poo/object .o .cc .ref)
        :poo-flow/modules/ai-agentic-context/use-host
        :poo-flow/modules/temporal-causality/truth-maintenance/support/policy-host
        :poo-flow/modules/temporal-causality/truth-maintenance/support/policy
        (only-in :poo-flow/modules/temporal-causality/time/objects poo-flow-temporal-instant))
(export context-use-host-test)
(def (at n) (poo-flow-temporal-instant (string-append "at-" (number->string n)) "clock" n "host" 'observed))
(def policy (poo-flow-temporal-support-policy "policy" "r1" (at 1) (at 4)))
(def contract (poo-flow-context-use-contract "actor" "task" "context-policy" '("fact") '("receipt") #t))
(def (grant id generation enabled (scope contract) (policy-digest (.ref policy 'semantic-digest)))
  (poo-flow-context-use-grant id generation "manifest" "admission" scope "policy" policy-digest '(display) enabled))
(def (setup)
  (let ((h (poo-flow-context-use-host)) (p (poo-flow-temporal-support-policy-host)))
    (poo-flow-temporal-support-policy-host-refresh! p policy 1 (at 1))
    (poo-flow-context-use-host-refresh! h (grant "g" 1 #t)) (values h p)))
(def context-use-host-test
  (test-suite "Registered Context use Host"
    (yuanxu-test-case "purpose and current registered clock determine eligibility"
      (let-values (((h p) (setup)))
        (check (.ref (poo-flow-context-use-host-observe h p "g" 1 'display) 'decision) => 'allowed)
        (check (.ref (poo-flow-context-use-host-observe h p "g" 1 'action) 'decision) => 'denied)
        (poo-flow-temporal-support-policy-host-refresh! p policy 2 (at 4))
        (check (.ref (poo-flow-context-use-host-observe h p "g" 1 'display) 'decision) => 'expired)
        (check-exception (poo-flow-temporal-support-policy-host-refresh! p policy 3 (at 2)) true)))
    (yuanxu-test-case "revision drift and retained generation cannot select historical authority"
      (let-values (((h p) (setup)))
        (poo-flow-context-use-host-refresh! h (grant "g" 2 #t))
        (check (.ref (poo-flow-context-use-host-observe h p "g" 1 'display) 'decision) => 'denied)
        (check-exception (poo-flow-context-use-host-refresh! h (grant "g" 1 #t)) true)
        (check-exception (poo-flow-context-use-host-refresh! h (grant "g" 2 #f)) true)
        (poo-flow-context-use-host-refresh! h (grant "g" 3 #t contract "foreign-policy"))
        (check (.ref (poo-flow-context-use-host-observe h p "g" 3 'display) 'decision) => 'denied)))
    (yuanxu-test-case "revocation is terminal even when a later generation enables"
      (let-values (((h p) (setup)))
        (poo-flow-context-use-host-refresh! h (grant "g" 2 #f))
        (check (.ref (poo-flow-context-use-host-observe h p "g" 1 'display) 'decision) => 'revoked)
        (check-exception (poo-flow-context-use-host-refresh! h (grant "g" 3 #t)) true)
        (check (.ref (poo-flow-context-use-host-observe h p "g" 2 'display) 'decision) => 'revoked)))
    (yuanxu-test-case "contract is owned and failed registration is atomic"
      (let-values (((h p) (setup)))
        (check-exception (poo-flow-context-use-host-refresh! h (.cc (grant "g" 2 #t) (.o manifest-digest: "forged"))) true)
        (check-exception (grant "g" 2 #t (.cc contract (.o actor: "foreign"))) true)
        (check (.ref (.ref (.ref (poo-flow-context-use-host-observe h p "g" 1 'display) 'grant) 'contract) 'semantic-digest) => (.ref contract 'semantic-digest))
        (check-exception (poo-flow-context-use-host-observe h p "unknown" 1 'display) true)))
    (yuanxu-test-case "registry is bounded and rejects overflow before mutation"
      (let ((h (poo-flow-context-use-host)) (p (poo-flow-temporal-support-policy-host)))
        (poo-flow-temporal-support-policy-host-refresh! p policy 1 (at 1))
        (let loop ((n 0)) (when (< n 128)
          (poo-flow-context-use-host-refresh! h (grant (number->string n) 1 #t)) (loop (+ n 1))))
        (check-exception (poo-flow-context-use-host-refresh! h (grant "overflow" 1 #t)) true)
        (check (.ref (poo-flow-context-use-host-observe h p "0" 1 'display) 'decision) => 'allowed)))))
