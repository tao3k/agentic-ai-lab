;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test (only-in :agentic-ai-lab/testing-api yuanxu-test-case)
        (only-in :clan/poo/object .o .cc .ref)
        :agentic-ai-lab/modules/ai-agentic-context/use-host
        :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy-host
        :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy
        (only-in :agentic-ai-lab/modules/temporal-causality/time/objects agentic-ai-lab-temporal-instant))
(export context-use-host-test)
(def (at n) (agentic-ai-lab-temporal-instant (string-append "at-" (number->string n)) "clock" n "host" 'observed))
(def policy (agentic-ai-lab-temporal-support-policy "policy" "r1" (at 1) (at 4)))
(def contract (agentic-ai-lab-context-use-contract "actor" "task" "context-policy" '("fact") '("receipt") #t))
(def (grant id generation enabled (scope contract) (policy-digest (.ref policy 'semantic-digest)))
  (agentic-ai-lab-context-use-grant id generation "manifest" "admission" scope "policy" policy-digest '(display) enabled))
(def (setup)
  (let ((h (agentic-ai-lab-context-use-host)) (p (agentic-ai-lab-temporal-support-policy-host)))
    (agentic-ai-lab-temporal-support-policy-host-refresh! p policy 1 (at 1))
    (agentic-ai-lab-context-use-host-refresh! h (grant "g" 1 #t)) (values h p)))
(def context-use-host-test
  (test-suite "Registered Context use Host"
    (yuanxu-test-case "purpose and current registered clock determine eligibility"
      (let-values (((h p) (setup)))
        (check (.ref (agentic-ai-lab-context-use-host-observe h p "g" 1 'display) 'decision) => 'allowed)
        (check (.ref (agentic-ai-lab-context-use-host-observe h p "g" 1 'action) 'decision) => 'denied)
        (agentic-ai-lab-temporal-support-policy-host-refresh! p policy 2 (at 4))
        (check (.ref (agentic-ai-lab-context-use-host-observe h p "g" 1 'display) 'decision) => 'expired)
        (check-exception (agentic-ai-lab-temporal-support-policy-host-refresh! p policy 3 (at 2)) true)))
    (yuanxu-test-case "revision drift and retained generation cannot select historical authority"
      (let-values (((h p) (setup)))
        (agentic-ai-lab-context-use-host-refresh! h (grant "g" 2 #t))
        (check (.ref (agentic-ai-lab-context-use-host-observe h p "g" 1 'display) 'decision) => 'denied)
        (check-exception (agentic-ai-lab-context-use-host-refresh! h (grant "g" 1 #t)) true)
        (check-exception (agentic-ai-lab-context-use-host-refresh! h (grant "g" 2 #f)) true)
        (agentic-ai-lab-context-use-host-refresh! h (grant "g" 3 #t contract "foreign-policy"))
        (check (.ref (agentic-ai-lab-context-use-host-observe h p "g" 3 'display) 'decision) => 'denied)))
    (yuanxu-test-case "revocation is terminal even when a later generation enables"
      (let-values (((h p) (setup)))
        (agentic-ai-lab-context-use-host-refresh! h (grant "g" 2 #f))
        (check (.ref (agentic-ai-lab-context-use-host-observe h p "g" 1 'display) 'decision) => 'revoked)
        (check-exception (agentic-ai-lab-context-use-host-refresh! h (grant "g" 3 #t)) true)
        (check (.ref (agentic-ai-lab-context-use-host-observe h p "g" 2 'display) 'decision) => 'revoked)))
    (yuanxu-test-case "contract is owned and failed registration is atomic"
      (let-values (((h p) (setup)))
        (check-exception (agentic-ai-lab-context-use-host-refresh! h (.cc (grant "g" 2 #t) (.o manifest-digest: "forged"))) true)
        (check-exception (grant "g" 2 #t (.cc contract (.o actor: "foreign"))) true)
        (check (.ref (.ref (.ref (agentic-ai-lab-context-use-host-observe h p "g" 1 'display) 'grant) 'contract) 'semantic-digest) => (.ref contract 'semantic-digest))
        (check-exception (agentic-ai-lab-context-use-host-observe h p "unknown" 1 'display) true)))
    (yuanxu-test-case "registry is bounded and rejects overflow before mutation"
      (let ((h (agentic-ai-lab-context-use-host)) (p (agentic-ai-lab-temporal-support-policy-host)))
        (agentic-ai-lab-temporal-support-policy-host-refresh! p policy 1 (at 1))
        (let loop ((n 0)) (when (< n 128)
          (agentic-ai-lab-context-use-host-refresh! h (grant (number->string n) 1 #t)) (loop (+ n 1))))
        (check-exception (agentic-ai-lab-context-use-host-refresh! h (grant "overflow" 1 #t)) true)
        (check (.ref (agentic-ai-lab-context-use-host-observe h p "0" 1 'display) 'decision) => 'allowed)))))
