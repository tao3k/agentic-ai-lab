;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        :clan/poo/object
        :agentic-ai-lab/modules/governance/policy/ai-security-executable-refinement)

(def evidence-root
  "sha256:5a9f2c4172506f36e22f17e01d60c771b7d9f9d66df72c7b20b0f2221a5b8f8a")

(def parent-root
  "sha256:26947281d5940bfa3c22d0b9ccf72d00f26e50a9047ad8b4f4c10f71b9ed258d")

(def (valid-envelope)
  (agentic-ai-lab-agent-action-evidence-envelope
   "action-2" "action-1" "observation-7" "decision-7"
   "agent:codex" "tool:filesystem-patch" "capability:repo-write"
   "workspace:agentic-ai-lab" evidence-root parent-root
   '("file:update") '("file:create" "file:update")))

(def (valid-policy)
  (agentic-ai-lab-ai-security-transition-policy
   '("capability:repo-write") "tool:filesystem-patch"
   '("workspace:agentic-ai-lab") "action-1" parent-root))

(export ai-security-executable-refinement-test)

(def ai-security-executable-refinement-test
  (test-suite
   "ai-security executable refinement"
   (yuanxu-test-case "POO engine accepts a confined action and replays it"
     (let* ((engine (agentic-ai-lab-ai-security-transition-engine))
            (receipt ((.ref engine 'execute) (valid-envelope) (valid-policy))))
       (check (.ref engine 'kind) => 'agentic-ai-lab-ai-security-transition-engine)
       (check (.ref receipt 'decision) => 'accepted)
       (check (length (.ref receipt 'invariants)) => 4)
       (check ((.ref engine 'replay-valid?)
               (valid-envelope) (valid-policy) receipt) => #t)))
   (yuanxu-test-case "capability amplification fails closed"
     (let* ((envelope
             (agentic-ai-lab-agent-action-evidence-envelope
              "action-2" "action-1" "observation-7" "decision-7"
              "agent:codex" "tool:filesystem-patch" "capability:admin"
              "workspace:agentic-ai-lab" evidence-root parent-root
              '("file:update") '("file:create" "file:update")))
            (receipt
             (agentic-ai-lab-ai-security-reference-transition
              envelope (valid-policy))))
	       (check (.ref receipt 'decision) => 'fail-closed)
	       (check (not (not (member 'capability-confinement
	                                (.ref receipt 'escalation-reasons)))) => #t)))
   (yuanxu-test-case "effect escape fails closed"
     (let* ((envelope
             (agentic-ai-lab-agent-action-evidence-envelope
              "action-2" "action-1" "observation-7" "decision-7"
              "agent:codex" "tool:filesystem-patch" "capability:repo-write"
              "workspace:agentic-ai-lab" evidence-root parent-root
              '("network:egress") '("file:create" "file:update")))
            (receipt
             (agentic-ai-lab-ai-security-reference-transition
              envelope (valid-policy))))
       (check (.ref receipt 'decision) => 'fail-closed)
       (check (not (not (member 'effect-containment
                                (.ref receipt 'escalation-reasons)))) => #t)))))
