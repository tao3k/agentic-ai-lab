;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :asp-gerbil-scheme/src/build-api/native-import-closure
                 asp-gerbil-scheme-native-import-closure)
        :std/test (only-in :poo-flow/testing-api poo-flow-test-case)
        (only-in :clan/poo/object .o .ref)
        :poo-flow/modules/ai-agentic-context/interface
        :poo-flow/modules/query/semantic/context-restriction
        :poo-flow/modules/workflow/scenario/configuration/module-activation
        :core/module-system/selection/contract
        :poo-flow/modules/module-authoring/module-descriptor
        :core/feature-system/model
        :core/feature-system/feature-manifest)
(export ai-agentic-context-core-test)
(def source "#+SEQ_TODO: TODO | DONE\n* TODO Review source evidence\n* DONE Historical task\n")
(def scope (.o (:: @ AiAgenticContextScope.)
  bundle: "bundle:1" organization: "org:1" epoch: 1 project: "project:1"
  worktree: "worktree:1" source-cut: "cut:1" actor: "actor:1" task: "task:1"
  destination: "provider:1"))
(def restriction (poo-flow-context-restriction "domain:1" '("actor:1") '("provider:1") '("org:1") 0 10))
(def (project (profile (poo-flow-ai-agentic-context-profile #f)))
  (poo-flow-ai-agentic-context-org-project scope source restriction profile))
(def ai-agentic-context-core-test
  (test-suite "AI Agentic-context source and Feature boundaries"
    (test-case "public module publication closes the selection adapter build input"
      (let (sources (asp-gerbil-scheme-native-import-closure
                     (current-directory)
                     '("modules/ai-agentic-context/interface.ss")))
        (check (ormap (lambda (path)
                        (string-suffix? "modules/ai-agentic-context/selection-adapter.ss" path))
                      sources) => #t)))
    (poo-flow-test-case "core Org projection requires neither Session nor Memory"
      (let (p (project))
        (check (.ref p 'feature-ids) => '(ai-agentic-context/core))
        (check (length (.ref p 'content)) => 1)
        (check (.ref p 'complete?) => #t)
        (check (.ref p 'source-authenticated?) => #f)
        (check (.ref (poo-flow-ai-agentic-context-org-replay source p scope) 'semantic-digest)
               => (.ref p 'semantic-digest))))
    (poo-flow-test-case "Context composes independent Session and owns only Memory Feature"
      (check (.ref (poo-flow-ai-agentic-context-profile #t) 'feature-ids)
             => '(ai-agentic-context/core ai-agentic-context/memory))
      (let* ((context (poo-flow-ai-agentic-context-module #f))
             (closure (poo-flow-module-closure (list context))))
        (check (poo-flow-module-name (car (poo-flow-module-import-configs
                  (poo-flow-module-imports context)))) => 'session)
        (check (length closure) => 2)
        (check (length (poo-flow-module-activation-modules
                        (activate-poo-flow-modules (list context)))) => 2)
        (check (validate-poo-flow-module-imports (list context)) => #t)
        (check (.ref (.ref (poo-flow-module-config context) 'feature-manifest) 'feature-ids)
               => '(ai-agentic-context/core)))
      (check (.ref ai-agentic-context-memory-feature 'owner-module-id) => 'ai-agentic-context)
      (check (.ref (feature-manifest-bundle 'missing-core (list ai-agentic-context-memory-feature)) 'accepted?) => #f))
    (poo-flow-test-case "public Context selection preserves native Session dependency"
      (let* ((selection (car (poo-flow-modules-system-use-module/ai
                              'ai-agentic-context '(+memory))))
             (descriptor (.ref selection 'module-descriptor)))
        (check (.ref (.ref selection 'feature-manifest) 'feature-ids)
               => '(ai-agentic-context/core ai-agentic-context/memory))
        (check (length (poo-flow-module-closure (list descriptor))) => 2))
      (check (length (poo-flow-modules-system-use-module/ai 'session '(+lineage))) => 1))
    (poo-flow-test-case "source edit refuses reuse of an admitted projection"
      (check-exception
        (poo-flow-ai-agentic-context-org-replay "* DONE Review source evidence\n" (project) scope) true))
    (poo-flow-test-case "same bytes cannot cross actor Session destination or epoch"
      (let (p (project))
        (check-exception (poo-flow-ai-agentic-context-org-replay source p (.o (:: @ scope) actor: "actor:2")) true)
        (check-exception (poo-flow-ai-agentic-context-org-replay source p (.o (:: @ scope) session: "session:2" turn: 0)) true)
        (check-exception (poo-flow-ai-agentic-context-org-replay source p (.o (:: @ scope) destination: "provider:2")) true)
        (check-exception (poo-flow-ai-agentic-context-org-replay source p (.o (:: @ scope) epoch: 2)) true)))
    (poo-flow-test-case "partial budgets cannot publish complete Context"
      (check-exception (poo-flow-ai-agentic-context-org-project scope source restriction (poo-flow-ai-agentic-context-profile #f) 0) true)
      (check-exception (poo-flow-ai-agentic-context-org-project scope source restriction (poo-flow-ai-agentic-context-profile #f) 256 2) true))
    (poo-flow-test-case "content restriction Feature and authority substitution reject"
      (let (p (project))
        (check-exception (poo-flow-ai-agentic-context-org-replay source (.o (:: @ p) content: '()) scope) true)
        (check-exception (poo-flow-ai-agentic-context-org-replay source
          (.o (:: @ p) scope: (.o (:: @ (.ref p 'scope)) actor: "actor:2")) scope) true)
        (check-exception (poo-flow-ai-agentic-context-org-replay source (.o (:: @ p) feature-ids: '(ai-agentic-context/core ai-agentic-context/memory)) scope) true)
        (check-exception (poo-flow-ai-agentic-context-org-replay source (.o (:: @ p) action-authorized?: #t) scope) true)
        (check-exception (poo-flow-ai-agentic-context-org-replay source (.o (:: @ p) restriction:
           (poo-flow-context-restriction "domain:1" '("actor:1" "actor:2") '("provider:1") '("org:1") 0 10)) scope) true)))
    (poo-flow-test-case "Scope admission freezes caller strings"
      (let* ((actor-input (string-copy "actor:1"))
             (owned (poo-flow-ai-agentic-context-scope-admit (.o (:: @ scope) actor: actor-input))))
        (string-set! actor-input 0 #\X)
        (check (.ref owned 'actor) => "actor:1")))))
