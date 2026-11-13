;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
        (only-in "./qualification/context-memory-init.ss" tao3k/agentic-ai-lab/t/qualification.context-memory-init.exports)
        (only-in :clan/poo/object .o .get .ref)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/objects AiAgenticContextScope.)
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs
        :tao3k/agentic-ai-lab/modules/query/semantic/context-restriction)
(export ai-agentic-context-core-test)

(def source "#+SEQ_TODO: TODO | DONE\n* TODO Review source evidence\n* DONE Historical task\n")
(def scope (.o (:: @ AiAgenticContextScope.)
  bundle: "bundle:1" organization: "org:1" epoch: 1 project: "project:1"
  worktree: "worktree:1" source-cut: "cut:1" actor: "actor:1" task: "task:1"
  destination: "provider:1"))
(def restriction (agentic-ai-lab-context-restriction "domain:1" '("actor:1") '("provider:1") '("org:1") 0 10))
(def (project (profile ContextCoreProfile))
  (agentic-ai-lab-ai-agentic-context-org-project scope source restriction profile))
;; Catch only the operation. A failed assertion must never be caught as the
;; expected exception; otherwise a missing refusal can silently pass the gate.
(def (rejected? operation)
  (with-catch (lambda (failure) #t) (lambda () (operation) #f)))
(def ai-agentic-context-core-test
  (test-suite "AI Agentic-context source and Feature boundaries"
    (test-case "refusal control cannot catch its own failed assertion"
      (check (rejected? (lambda () #t)) => #f)
      (check (rejected? (lambda () (error "controlled refusal"))) => #t))
    (yuanxu-test-case "core Org projection requires neither Session nor Memory"
      (let (p (project))
        (check (.ref p 'feature-ids) => '(ai-agentic-context/core))
        (check (length (.ref p 'content)) => 1)
        (check (.ref p 'complete?) => #t)
        (check (.ref p 'source-authenticated?) => #f)
        (check (.ref (agentic-ai-lab-ai-agentic-context-org-replay source p scope) 'semantic-digest)
               => (.ref p 'semantic-digest))))
    (yuanxu-test-case "init selects Memory from the real Context Interface"
      (def selected (.get tao3k/agentic-ai-lab/t/qualification.context-memory-init.exports
                          Context ai-agentic-context))
      (def profile (.get selected profile))
      (def projection (project profile))
      (check (.get profile feature-ids) => '(ai-agentic-context/core ai-agentic-context/memory))
      (check (.get projection feature-ids) => (.get profile feature-ids))
      (check (.get (agentic-ai-lab-ai-agentic-context-org-replay source projection scope) semantic-digest)
             => (.get projection semantic-digest))
      (check (.get ContextCoreProfile feature-ids) => '(ai-agentic-context/core)))
    (yuanxu-test-case "source edit refuses reuse of an admitted projection"
      (check
        (rejected?
          (lambda ()
            (agentic-ai-lab-ai-agentic-context-org-replay
              "* DONE Review source evidence\n"
              (project)
              scope)))
        => #t))
    (yuanxu-test-case "same-source replay refuses substituted runtime observation provenance"
      ;; Reusing the runtime replay result inside one call must not turn the
      ;; caller's embedded observation into an already-admitted artifact.
      (let* ((p (project)) (observation (.ref p 'observation)))
        (check
          (rejected?
            (lambda ()
              (agentic-ai-lab-ai-agentic-context-org-replay
                source
                (.o
                  (:: @ p)
                  observation:
                  (.o (:: @ observation) source-sha256: "forged-source-cut"))
                scope)))
          => #t)
        (check
          (rejected?
            (lambda ()
              (agentic-ai-lab-ai-agentic-context-org-replay
                source
                (.o (:: @ p) observation: (.o (:: @ observation) parser-identity: "foreign-parser"))
                scope)))
          => #t)
        (check
          (rejected?
            (lambda ()
              (agentic-ai-lab-ai-agentic-context-org-replay
                source
                (.o
                  (:: @ p)
                  observation:
                  (.o
                    (:: @ observation)
                    query:
                    (.o (:: @ (.ref observation 'query)) identity: "foreign-query")))
                scope)))
          => #t)))
    (yuanxu-test-case "same bytes cannot cross actor Session destination or epoch"
      (let (p (project))
        (check
          (rejected?
            (lambda ()
              (agentic-ai-lab-ai-agentic-context-org-replay
                source
                p
                (.o (:: @ scope) actor: "actor:2"))))
          => #t)
        (check
          (rejected?
            (lambda ()
              (agentic-ai-lab-ai-agentic-context-org-replay
                source
                p
                (.o (:: @ scope) session: "session:2" turn: 0))))
          => #t)
        (check
          (rejected?
            (lambda ()
              (agentic-ai-lab-ai-agentic-context-org-replay
                source
                p
                (.o (:: @ scope) destination: "provider:2"))))
          => #t)
        (check
          (rejected?
            (lambda ()
              (agentic-ai-lab-ai-agentic-context-org-replay source p (.o (:: @ scope) epoch: 2))))
          => #t)))
    (yuanxu-test-case "partial budgets cannot publish complete Context"
      (check
        (rejected?
          (lambda ()
            (agentic-ai-lab-ai-agentic-context-org-project
              scope
              source
              restriction
              ContextCoreProfile
              0)))
        => #t)
      (check
        (rejected?
          (lambda ()
            (agentic-ai-lab-ai-agentic-context-org-project
              scope
              source
              restriction
              ContextCoreProfile
              256
              2)))
        => #t))
    (yuanxu-test-case "content restriction Feature and authority substitution reject"
      (let (p (project))
        (check
          (rejected?
            (lambda ()
              (agentic-ai-lab-ai-agentic-context-org-replay source (.o (:: @ p) content: '()) scope)))
          => #t)
        (check
          (rejected?
            (lambda ()
              (agentic-ai-lab-ai-agentic-context-org-replay
                source
                (.o (:: @ p) scope: (.o (:: @ (.ref p 'scope)) actor: "actor:2"))
                scope)))
          => #t)
        (check
          (rejected?
            (lambda ()
              (agentic-ai-lab-ai-agentic-context-org-replay
                source
                (.o (:: @ p) feature-ids: '(ai-agentic-context/core ai-agentic-context/memory))
                scope)))
          => #t)
        (check
          (rejected?
            (lambda ()
              (agentic-ai-lab-ai-agentic-context-org-replay
                source
                (.o (:: @ p) action-authorized?: #t)
                scope)))
          => #t)
        (check
          (rejected?
            (lambda ()
              (agentic-ai-lab-ai-agentic-context-org-replay
                source
                (.o
                  (:: @ p)
                  restriction:
                  (agentic-ai-lab-context-restriction
                    "domain:1"
                    '("actor:1" "actor:2")
                    '("provider:1")
                    '("org:1")
                    0
                    10))
                scope)))
          => #t)))
    (yuanxu-test-case "Scope admission freezes caller strings"
      (let* ((actor-input (string-copy "actor:1"))
             (owned (agentic-ai-lab-ai-agentic-context-scope-admit (.o (:: @ scope) actor: actor-input))))
        (string-set! actor-input 0 #\X)
        (check (.ref owned 'actor) => "actor:1")))))
