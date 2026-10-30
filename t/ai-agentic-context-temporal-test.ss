;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test (only-in :agentic-ai-lab/testing-api yuanxu-test-case)
        (only-in :clan/poo/object .o .ref)
        :agentic-ai-lab/modules/ai-agentic-context/interface
        :agentic-ai-lab/modules/temporal-causality/time/objects
        :agentic-ai-lab/modules/temporal-causality/time/uncertainty-funs)
(export ai-agentic-context-temporal-test)
(def (at n (domain-value "clock") (modality-value 'observed))
  (agentic-ai-lab-temporal-instant (number->string n) domain-value n "test-clock" modality-value))
(def (policy (modality-value 'observed))
  (agentic-ai-lab-ai-agentic-context-temporal-policy "policy" 1
    (agentic-ai-lab-temporal-interval "window" (at 2 "clock" modality-value) (at 8 "clock" modality-value) #t #f)
    'policy-clock '(prepare disclose)))
(def (clock low high (domain-value "clock") (role-value 'policy-clock))
  (agentic-ai-lab-temporal-bounded-observation "clock-observation" role-value "clock-source"
    (at low domain-value) (at high domain-value) 1 (at high domain-value)
    "clock-receipt" #f "attempt" "test-clock.v1"))
(def (status low high)
  (.ref (agentic-ai-lab-ai-agentic-context-temporal-assess (policy) (clock low high) 'disclose) 'status))
(def ai-agentic-context-temporal-test
  (test-suite "Context temporal lifecycle window policy"
    (yuanxu-test-case "observed interval wholly inside the policy window is eligible"
      (check (status 2 2) => 'eligible) (check (status 3 7) => 'eligible)
      (let (r (agentic-ai-lab-ai-agentic-context-temporal-assess (policy) (clock 3 4) 'disclose))
        (check (.ref r 'source-authenticated?) => #f) (check (.ref r 'action-authorized?) => #f)
        (check (.ref r 'runtime-published?) => #f) (check (.ref r 'durable?) => #f)))
    (yuanxu-test-case "half-open expiry and future effectiveness remain separate"
      (check (status 0 1) => 'not-yet-effective)
      (check (status 8 8) => 'expired) (check (status 8 9) => 'expired))
    (yuanxu-test-case "uncertainty crossing either boundary cannot authorize use"
      (check (status 1 2) => 'uncertain) (check (status 7 8) => 'uncertain)
      (check (status 0 9) => 'uncertain))
    (yuanxu-test-case "matching numeric coordinates cannot cross clock domains"
      (check (.ref (agentic-ai-lab-ai-agentic-context-temporal-assess (policy) (clock 3 4 "foreign") 'disclose) 'status)
        => 'incomparable))
    (yuanxu-test-case "declared policy time is unknown rather than observed evidence"
      (check (.ref (agentic-ai-lab-ai-agentic-context-temporal-assess (policy 'declared) (clock 3 4) 'disclose) 'status)
        => 'unknown))
    (yuanxu-test-case "clock role and purpose are explicit policy inputs"
      (check (.ref (agentic-ai-lab-ai-agentic-context-temporal-assess (policy) (clock 3 4 "clock" 'event-time) 'disclose) 'status)
        => 'unsupported-clock)
      (check (.ref (agentic-ai-lab-ai-agentic-context-temporal-assess (policy) (clock 3 4) 'publish-memory) 'status)
        => 'purpose-denied))
    (yuanxu-test-case "policy owns interval strings and refuses digest or boundary substitution"
      (let* ((domain-value (string-copy "clock"))
             (interval-value (agentic-ai-lab-temporal-interval "window" (at 2 domain-value) (at 8 domain-value) #t #f))
             (p (agentic-ai-lab-ai-agentic-context-temporal-policy "policy" 1 interval-value 'policy-clock '(disclose))))
        (string-set! domain-value 0 #\x)
        (check (.ref (agentic-ai-lab-ai-agentic-context-temporal-assess p (clock 3 4) 'disclose) 'status) => 'eligible)
        (check-exception (agentic-ai-lab-ai-agentic-context-temporal-policy-replay (.o (:: @ p) revision: 2)) true)
        (check-exception (agentic-ai-lab-ai-agentic-context-temporal-policy "policy" 1
           (agentic-ai-lab-temporal-interval "window" (at 2) (at 8) #t #t) 'policy-clock '(disclose)) true)
        (check-exception (agentic-ai-lab-ai-agentic-context-temporal-policy "policy" 1 interval-value 'policy-clock '(disclose disclose)) true)))))
