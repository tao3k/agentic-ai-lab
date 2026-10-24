;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :asp-gerbil-scheme/src/build-api/native-import-closure
                 asp-gerbil-scheme-native-import-closure)
        :std/test (only-in :agentic-ai-lab/testing-api yuanxu-test-case)
        (only-in :clan/poo/object .o .ref)
        :agentic-ai-lab/modules/ai-agentic-context/interface
        :agentic-ai-lab/modules/query/semantic/context-restriction
        :agentic-ai-lab/modules/workflow/scenario/configuration/module-activation
        :yuanxu/module-system/selection/contract
        :agentic-ai-lab/modules/module-authoring/module-descriptor
        :yuanxu/feature-system/model
        :yuanxu/feature-system/feature-manifest)
(export ai-agentic-context-core-test)
(def source "#+SEQ_TODO: TODO | DONE\n* TODO Review source evidence\n* DONE Historical task\n")
(def scope (.o (:: @ AiAgenticContextScope.)
  bundle: "bundle:1" organization: "org:1" epoch: 1 project: "project:1"
  worktree: "worktree:1" source-cut: "cut:1" actor: "actor:1" task: "task:1"
  destination: "provider:1"))
(def restriction (agentic-ai-lab-context-restriction "domain:1" '("actor:1") '("provider:1") '("org:1") 0 10))
(def (project (profile (agentic-ai-lab-ai-agentic-context-profile #f)))
  (agentic-ai-lab-ai-agentic-context-org-project scope source restriction profile))
(def ai-agentic-context-core-test
  (test-suite "AI Agentic-context source and Feature boundaries"
    (test-case "public module publication closes the selection adapter build input"
      (let (sources (asp-gerbil-scheme-native-import-closure
                     (current-directory)
                     '("modules/ai-agentic-context/interface.ss")))
        (check (ormap (lambda (path)
                        (string-suffix? "modules/ai-agentic-context/selection-adapter.ss" path))
                      sources) => #t)))
    (yuanxu-test-case "core Org projection requires neither Session nor Memory"
      (let (p (project))
        (check (.ref p 'feature-ids) => '(ai-agentic-context/core))
        (check (length (.ref p 'content)) => 1)
        (check (.ref p 'complete?) => #t)
        (check (.ref p 'source-authenticated?) => #f)
        (check (.ref (agentic-ai-lab-ai-agentic-context-org-replay source p scope) 'semantic-digest)
               => (.ref p 'semantic-digest))))
    (yuanxu-test-case "Context composes independent Session and owns only Memory Feature"
      (check (.ref (agentic-ai-lab-ai-agentic-context-profile #t) 'feature-ids)
             => '(ai-agentic-context/core ai-agentic-context/memory))
      (let* ((context (agentic-ai-lab-ai-agentic-context-module #f))
             (closure (agentic-ai-lab-module-closure (list context))))
        (check (agentic-ai-lab-module-name (car (agentic-ai-lab-module-import-configs
                  (yuanxu-module-imports context)))) => 'session)
        (check (length closure) => 2)
        (check (length (agentic-ai-lab-module-activation-modules
                        (activate-agentic-ai-lab-modules (list context)))) => 2)
        (check (validate-yuanxu-module-imports (list context)) => #t)
        (check (.ref (.ref (agentic-ai-lab-module-config context) 'feature-manifest) 'feature-ids)
               => '(ai-agentic-context/core)))
      (check (.ref ai-agentic-context-memory-feature 'owner-module-id) => 'ai-agentic-context)
      (check (.ref (feature-manifest-bundle 'missing-core (list ai-agentic-context-memory-feature)) 'accepted?) => #f))
    (yuanxu-test-case "public Context selection preserves native Session dependency"
      (let* ((selection (car (agentic-ai-lab-modules-system-use-module/ai
                              'ai-agentic-context '(+memory))))
             (descriptor (.ref selection 'module-descriptor)))
        (check (.ref (.ref selection 'feature-manifest) 'feature-ids)
               => '(ai-agentic-context/core ai-agentic-context/memory))
        (check (length (agentic-ai-lab-module-closure (list descriptor))) => 2))
      (check (length (agentic-ai-lab-modules-system-use-module/ai 'session '(+lineage))) => 1))
    (yuanxu-test-case "source edit refuses reuse of an admitted projection"
      (check-exception
        (agentic-ai-lab-ai-agentic-context-org-replay "* DONE Review source evidence\n" (project) scope) true))
    (yuanxu-test-case "same bytes cannot cross actor Session destination or epoch"
      (let (p (project))
        (check-exception (agentic-ai-lab-ai-agentic-context-org-replay source p (.o (:: @ scope) actor: "actor:2")) true)
        (check-exception (agentic-ai-lab-ai-agentic-context-org-replay source p (.o (:: @ scope) session: "session:2" turn: 0)) true)
        (check-exception (agentic-ai-lab-ai-agentic-context-org-replay source p (.o (:: @ scope) destination: "provider:2")) true)
        (check-exception (agentic-ai-lab-ai-agentic-context-org-replay source p (.o (:: @ scope) epoch: 2)) true)))
    (yuanxu-test-case "partial budgets cannot publish complete Context"
      (check-exception (agentic-ai-lab-ai-agentic-context-org-project scope source restriction (agentic-ai-lab-ai-agentic-context-profile #f) 0) true)
      (check-exception (agentic-ai-lab-ai-agentic-context-org-project scope source restriction (agentic-ai-lab-ai-agentic-context-profile #f) 256 2) true))
    (yuanxu-test-case "content restriction Feature and authority substitution reject"
      (let (p (project))
        (check-exception (agentic-ai-lab-ai-agentic-context-org-replay source (.o (:: @ p) content: '()) scope) true)
        (check-exception (agentic-ai-lab-ai-agentic-context-org-replay source
          (.o (:: @ p) scope: (.o (:: @ (.ref p 'scope)) actor: "actor:2")) scope) true)
        (check-exception (agentic-ai-lab-ai-agentic-context-org-replay source (.o (:: @ p) feature-ids: '(ai-agentic-context/core ai-agentic-context/memory)) scope) true)
        (check-exception (agentic-ai-lab-ai-agentic-context-org-replay source (.o (:: @ p) action-authorized?: #t) scope) true)
        (check-exception (agentic-ai-lab-ai-agentic-context-org-replay source (.o (:: @ p) restriction:
           (agentic-ai-lab-context-restriction "domain:1" '("actor:1" "actor:2") '("provider:1") '("org:1") 0 10)) scope) true)))
    (yuanxu-test-case "Scope admission freezes caller strings"
      (let* ((actor-input (string-copy "actor:1"))
             (owned (agentic-ai-lab-ai-agentic-context-scope-admit (.o (:: @ scope) actor: actor-input))))
        (string-set! actor-input 0 #\X)
        (check (.ref owned 'actor) => "actor:1")))))
