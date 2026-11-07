;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; This Suite owns the isolated public Session import boundary. Context's
;;; combined native Suite deliberately reuses session-attempt-test instead:
;;; its process has already loaded Context and cannot witness this boundary.
(import :std/test
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :clan/poo/object .o .ref)
        (only-in :gerbil/runtime/loader list-modules)
        :agentic-ai-lab/modules/session/interface)
(export session-independent-test)

;; Observe the actual native loader, with a positive matcher control. No
;; descriptor-only inventory or conditional skip can establish independence.
(def (loaded-prefix? prefix)
  (ormap (lambda (entry) (string-prefix? prefix (car entry))) (list-modules)))

(def (input-ref)
  (.o (:: @ SessionInputRef.)
      producer: "fixture"
      contract: "v1"
      identity: "projection"
      digest: "content"
      scope-digest: "scope"
      source-vector-digest: "source"
      query-digest: "query"
      restriction-digest: "restriction"
      profile-digest: "profile"
      receipt-ref: "receipt"
      consumer-session: "independent"
      consumer-turn: 0
      complete?: #t))

(def session-independent-test
  (test-suite "Independent public Session consumer"
    (yuanxu-test-case "select claim and recover without loading Context or Memory"
      (check (loaded-prefix? "agentic-ai-lab/modules/session/") => #t)
      (check (loaded-prefix? "agentic-ai-lab/modules/ai-agentic-context/") => #f)
      (check (agentic-ai-lab-durable-policy?
               agentic-ai-lab-durable-policy/default) => #t)
      (check (length agentic-ai-lab-session-module-bundles) => 1)
      (check (length (agentic-ai-lab-session-cases
                       (session-case isolated
                         (metadata)
                         (objects)
                         (rows)
                         (row-groups)))) => 1)
      ;; Producer bindings stay opaque. Recovery fences the previous Attempt
      ;; without acquiring a Context service, Memory store or journal owner.
      (let* ((task (.o (:: @ SessionTask.) identity: "task" input: (input-ref)))
             (initial (agentic-ai-lab-session-schedule "independent"))
             (claim (agentic-ai-lab-session-claim
                      initial 0 task "attempt" "request" 0))
             (running (.ref claim 'schedule))
             (attempt (.ref running 'active))
             (recovery (agentic-ai-lab-session-recover running 1))
             (recovered (.ref recovery 'schedule)))
        (check (.ref claim 'accepted?) => #t)
        (check (.ref recovery 'accepted?) => #t)
        (check (.ref recovered 'status) => 'recovering)
        (check (.ref (agentic-ai-lab-session-complete recovered 2 attempt) 'reason)
               => 'wrong-attempt)
        (check (.ref (agentic-ai-lab-session-close recovered 2) 'reason)
               => 'pending-obligation))
      (check (loaded-prefix? "agentic-ai-lab/modules/ai-agentic-context/") => #f))))
