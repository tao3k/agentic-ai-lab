;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :clan/poo/object .o .ref)
        (only-in :std/list/list find)
        (only-in :std/string/misc string-contains)
        (only-in :orgize/languages/org/modules/org-elements/syntax
                 org-elements property)
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/types
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/objects
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/org-contract/elements
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-org-elements-gql
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-org-progressive-rules)
(export org-elements-gql-progressive-test)

(def adr-org
  (string-append
   ":PROPERTIES:\n"
   ":ID: adr-doc-root\n"
   ":CONTRACT_ID: context.governance.work.v1\n"
   ":CONTRACT_REVISION: 1\n"
   ":GITOPS_PROJECT: marlin-agent-core\n"
   ":GITOPS_WORKTREE: feat/org-elements-gql\n"
   ":END:\n"
   "#+title: Shared Architecture Notes\n\n"
   "* Org Elements to GQL Architecture :ATTACH:\n"
   ":PROPERTIES:\n"
   ":ID: adr-org-gql\n"
   ":ARCH_COMPONENT: marlin-context-system\n"
   ":AGENT_ID: agent/architect-01\n"
   ":AGENT_TIER: high\n"
   ":REVIEWER_AGENT_ID: agent/reviewer-01\n"
   ":TASK_ID: task/adr-org-gql\n"
   ":END:\n\n"
   "#+NAME: adr-turn-1\n"
   "#+BEGIN_SRC llm :model claude-opus-4-6 :thinking high :results drawer replace\n"
   "Design the Org Elements to ISO GQL projection.\n"
   "#+END_SRC\n\n"
   "#+RESULTS: adr-turn-1\n"
   ":RESULTS:\n"
   "#+BEGIN_THINKING\n"
   "Private reasoning trace that stays folded at L2.\n"
   "#+END_THINKING\n"
   "See [[attachment:org-gql-flow.png]] for the exact graph schema.\n"
   ":END:\n\n"
   "* DONE Settled Legacy Cleanup\n"
   ":PROPERTIES:\n"
   ":ID: done-legacy-1\n"
   ":END:\n"
   "Completed cleanup notes.\n"))

(def plan-org
  (string-append
   ":PROPERTIES:\n"
   ":ID: plan-doc-root\n"
   ":CONTRACT_ID: context.governance.task.v1\n"
   ":CONTRACT_REVISION: 1\n"
   ":GITOPS_PROJECT: marlin-agent-core\n"
   ":GITOPS_WORKTREE: feat/org-elements-gql\n"
   ":END:\n"
   "#+title: Shared Execution Stream\n\n"
   "* Project Progressive Rules\n"
   "#+begin_src scheme :org-progressive-rules\n"
   "(split-line-watermark 800)\n"
   "(default-focus-depth 2)\n"
   "(require-sod-reviewer #t)\n"
   "(fold-thinking-by-default #t)\n"
   "(allow-agent-drill-down #t)\n"
   "#+end_src\n\n"
   "* TODO [#A] Compile Org Elements to GQL [1/2]\n"
   "SCHEDULED: <2026-11-21 Sat 09:00>\n"
   ":PROPERTIES:\n"
   ":ID: task-compile-gql\n"
   ":ARCH_COMPONENT: marlin-context-system\n"
   ":AGENT_ID: agent/builder-mid-01\n"
   ":AGENT_TIER: mid\n"
   ":REVIEWER_AGENT_ID: agent/architect-01\n"
   ":TASK_ID: task/compile-gql\n"
   ":DEPENDS_ON: adr-org-gql\n"
   ":END:\n"
   "- [X] Project native Org Elements into YuanxuGraph\n"
   "- [ ] Lower Org Elements selectors to GraphSyntaxProgram\n\n"
   "#+NAME: builder-turn-1\n"
   "#+BEGIN_SRC llm :model qwen-coder-plus :thinking low :results drawer replace\n"
   "Implement the GQL lowering pass.\n"
   "#+END_SRC\n\n"
   "* TODO [#B] Wire Marlin Scheme dispatch [0/1]\n"
   "DEADLINE: <2026-11-22 Sun 18:00>\n"
   ":PROPERTIES:\n"
   ":ID: task-wire-marlin\n"
   ":ARCH_COMPONENT: marlin-context-system\n"
   ":AGENT_ID: agent/builder-mid-02\n"
   ":AGENT_TIER: mid\n"
   ":REVIEWER_AGENT_ID: agent/architect-01\n"
   ":TASK_ID: task/wire-marlin\n"
   ":DEPENDS_ON: task-compile-gql\n"
   ":END:\n"
   "- [ ] Export through scheme/interface.ss\n\n"
   "* Security Anomaly Inquiry\n"
   ":PROPERTIES:\n"
   ":ID: inquiry-sec-01\n"
   ":ACTIVE_DEFEATERS: D1_net_policy\n"
   ":END:\n"
   "#+NAME: sec-turn-1\n"
   "#+BEGIN_SRC llm :model claude-opus-4-6 :thinking high :results drawer replace\n"
   "Investigate egress anomaly.\n"
   "#+END_SRC\n\n"
   "#+RESULTS: sec-turn-1\n"
   ":RESULTS:\n"
   "#+BEGIN_THINKING\n"
   "Critical defeater reasoning must expand at L3.\n"
   "#+END_THINKING\n"
   "Read-discriminator audit proposed.\n"
   ":END:\n"))

(def org-elements-gql-progressive-test
  (test-suite "Org Elements -> ISO GQL, ASCENT Progressive Disclosure & Two-Stage Repair"

    (yuanxu-test-case "Org Elements project into YuanxuGraph and compile directly to ISO GQL"
      (let* ((adr-cut (context-org-source "architecture/adr.org" 1 adr-org #t))
             (plan-cut (context-org-source "work/plan.org" 1 plan-org #t))
             (eg (agentic-ai-lab-ai-agentic-context-org-element-graph
                  'test/org-elements-gql (list adr-cut plan-cut) #t))
             ;; 1. Native Orgize `OrgElementQuery` value compiles to GQL!
             (todo-sel (agentic-ai-lab-ai-agentic-context-org-elements-select
                        eg (org-elements headline (property todo-type "todo")) 'q-open-todos 32))
             ;; 2. Relational checklist selector `(child-of headline)`
             (unchecked-sel (agentic-ai-lab-ai-agentic-context-org-elements-select
                             eg '(org-elements item (child-of headline) (property checkbox "[ ]"))
                             'q-unchecked 32))
             ;; 3. Cross-file `:DEPENDS_ON:` selector
             (deps-sel (agentic-ai-lab-ai-agentic-context-org-elements-select
                        eg '(org-elements headline (depends-on target) (property todo-type "todo"))
                        'q-deps 32))
             ;; 4. Org-Attach `attachment:` link selector
             (attach-sel (agentic-ai-lab-ai-agentic-context-org-elements-select
                          eg '(org-elements link (child-of headline) (property protocol "attachment"))
                          'q-attach 32))
             ;; 5. Org-Babel `src-block` -> `RESULTS` drawer selector
             (babel-sel (agentic-ai-lab-ai-agentic-context-org-elements-select
                         eg '(org-elements src-block (produces-results drawer) (property language "llm"))
                         'q-babel 32))
             ;; 6. Compound `all-of` + `property-contains` residual DNF predicate
             (compound-sel (agentic-ai-lab-ai-agentic-context-org-elements-select
                            eg '(org-elements headline
                                              (all-of (property todo-type "todo")
                                                      (property agent-tier "mid")
                                                      (property-contains title "Compile")))
                            'q-compound 32)))
        (check (agentic-ai-lab-ai-agentic-context-org-element-graph-shape? eg) => #t)
        ;; Verify ISO GQL source rendering
        (check (and (string-contains (.ref todo-sel 'gql) "MATCH (h:OrgHeadline)") #t) => #t)
        (check (and (string-contains (.ref todo-sel 'gql) "WHERE h.todoType = 'todo'") #t) => #t)
        (check (length (.ref todo-sel 'nodes)) => 2)
        ;; Unchecked checklist items across tasks
        (check (and (string-contains (.ref unchecked-sel 'gql) "-[:HAS_ITEM]->(i:OrgListItem)") #t) => #t)
        (check (length (.ref unchecked-sel 'nodes)) => 2)
        ;; Cross-file `:DEPENDS_ON:` edges (`task-compile-gql -> adr-org-gql`, `task-wire-marlin -> task-compile-gql`)
        (check (and (string-contains (.ref deps-sel 'gql) "-[:DEPENDS_ON]->(dep:OrgHeadline)") #t) => #t)
        (check (length (.ref deps-sel 'rows)) => 2)
        ;; `org-attach` link projected with `attachDir = "data/adr-org-gql"` and `imageLink = #t`
        (check (length (.ref attach-sel 'nodes)) => 1)
        (let (ln (car (.ref attach-sel 'nodes)))
          (check (.ref ln 'targetPath) => "org-gql-flow.png")
          (check (.ref ln 'attachDir) => "data/adr-org-gql")
          (check (.ref ln 'imageLink) => #t))
        ;; Org-Babel blocks with affiliated `#+RESULTS:`
        (check (and (string-contains (.ref babel-sel 'gql) "-[:PRODUCES_RESULTS]->(dr:OrgDrawer)") #t) => #t)
        (check (length (.ref babel-sel 'nodes)) => 2)
        ;; Compound predicate narrows to single matching task
        (check (length (.ref compound-sel 'nodes)) => 1)
        (check (.ref (car (.ref compound-sel 'nodes)) 'propertyId) => "task-compile-gql")))

    (yuanxu-test-case "Ready-task slices unblock settled ADR dependency and block open TODO dependency"
      (let* ((adr-cut (context-org-source "architecture/adr.org" 1 adr-org #t))
             (plan-cut (context-org-source "work/plan.org" 1 plan-org #t))
             (eg (agentic-ai-lab-ai-agentic-context-org-element-graph
                  'test/ready-slices (list adr-cut plan-cut) #t))
             (ready (agentic-ai-lab-ai-agentic-context-ready-task-slices eg "mid"))
             (slices (.ref ready 'slices)))
        ;; Only `task-compile-gql` is ready; `task-wire-marlin` is blocked by open `task-compile-gql`!
        (check (length slices) => 1)
        (let (sl (car slices))
          (check (.ref sl 'propertyId) => "task-compile-gql")
          (check (.ref sl 'uncheckedItems) => '("Lower Org Elements selectors to GraphSyntaxProgram"))
          (check (length (.ref sl 'dependencySlices)) => 1)
          (check (.ref (car (.ref sl 'dependencySlices)) 'propertyId) => "adr-org-gql")
          (check (length (.ref sl 'attachments)) => 1)
          (check (.ref (car (.ref sl 'attachments)) 'targetPath) => "org-gql-flow.png"))))

    (yuanxu-test-case "ASCENT computes L0..L3 progressive disclosure, drill-down, and dynamic Flash facets"
      (let* ((adr-cut (context-org-source "architecture/adr.org" 1 adr-org #t))
             (plan-cut (context-org-source "work/plan.org" 1 plan-org #t))
             (eg (agentic-ai-lab-ai-agentic-context-org-element-graph
                  'test/ascent-progressive (list adr-cut plan-cut) #t))
             (cfg (agentic-ai-lab-ai-agentic-context-parse-rule-overrides plan-org))
             ;; Focus on `task-compile-gql` with `cross-module` signal; no drill-down yet
             (plan1 (agentic-ai-lab-ai-agentic-context-ascent-progressive-plan
                     eg (.o rule-config: cfg
                            focus-property-ids: '("task-compile-gql")
                            case-signals: '(cross-module))))
             (depth-of (lambda (p pid)
                         (.ref (find (lambda (d) (equal? (.ref d 'propertyId) pid))
                                     (.ref p 'headlineDisclosures))
                               'depth)))
             (view1 (agentic-ai-lab-ai-agentic-context-render-progressive-org eg plan1))
             ;; Now agent requests explicit drill-down of `adr-org-gql` to L3!
             (plan2 (agentic-ai-lab-ai-agentic-context-ascent-progressive-plan
                     eg (.o rule-config: cfg
                            focus-property-ids: '("task-compile-gql")
                            drill-downs: '(("adr-org-gql" . 3))
                            case-signals: '(cross-module))))
             (view2 (agentic-ai-lab-ai-agentic-context-render-progressive-org eg plan2)))
        (check (.ref cfg 'split-line-watermark) => 800)
        (check (.ref cfg 'require-sod-reviewer?) => #t)
        ;; L0..L3 lattice levels derived by `gerbil-ascent`!
        (check (depth-of plan1 "done-legacy-1") => 0)      ;; settled DONE -> L0 skeleton
        (check (depth-of plan1 "task-wire-marlin") => 0)   ;; blocked TODO -> L0 skeleton
        (check (depth-of plan1 "task-compile-gql") => 2)   ;; focus -> L2
        (check (depth-of plan1 "adr-org-gql") => 2)        ;; 1-hop settled DEPENDS_ON ADR -> L2
        (check (depth-of plan1 "inquiry-sec-01") => 3)     ;; active defeater -> L3!
        ;; At L2, ADR's `#+BEGIN_THINKING` is folded; defeater's L3 thinking is visible!
        (check (not (string-contains view1 "Private reasoning trace that stays folded at L2.")) => #t)
        (check (and (string-contains view1 "folded at L2") #t) => #t)
        (check (and (string-contains view1 "Critical defeater reasoning must expand at L3.") #t) => #t)
        ;; After explicit Agent Drill-Down to L3, ADR's full thinking expands!
        (check (depth-of plan2 "adr-org-gql") => 3)
        (check (and (string-contains view2 "Private reasoning trace that stays folded at L2.") #t) => #t)
        ;; Dynamic facets deduced by ASCENT (`cross-module` => 3 -> 2 -> 1 & 6; attach => 5; defeater => 4)
        (let (facet-ids (map (cut .ref <> 'facetId) (.ref plan1 'triggeredFacets)))
          (check (and (memq 'invariant-section facet-ids) #t) => #t)
          (check (and (memq 'scheduled-todo-dag facet-ids) #t) => #t)
          (check (and (memq 'inline-checklist facet-ids) #t) => #t)
          (check (and (memq 'sod-reviewer facet-ids) #t) => #t)
          (check (and (memq 'attach-media facet-ids) #t) => #t)
          (check (and (memq 'competing-hypotheses facet-ids) #t) => #t))))

    (yuanxu-test-case "Two-stage Org repair: Stage 1 AST fixes ~90% syntax at 0 tokens; Stage 2 escalates semantic contract failures to Flash"
      (let* (;; Broken mechanical Org: missing root drawer, `*TODO` missing space, `:ATTACH` missing colon,
             ;; nested `:THINKING:` drawer inside `:RESULTS:`, `-[x]` checkbox, stale `[0/2]` cookie, unclosed `:RESULTS:`.
             (broken-mechanical
              (string-append
               "*TODO Fix parser bug [0/2] :ATTACH\n"
               ":PROPERTIES:\n"
               ":ID: fix-01\n"
               ":END:\n"
               "-[x] Reproduce failure\n"
               "- [] Add test\n\n"
               "#+NAME: turn-fix\n"
               "#+BEGIN_SRC llm :model flash :results drawer replace\n"
               "Explain fix.\n"
               "#+END_SRC\n\n"
               "#+RESULTS: turn-fix\n"
               ":RESULTS:\n"
               ":THINKING:\n"
               "Nested drawer gets rewritten to special block.\n"
               ":END:\n"
               "Fixed cleanly.\n"))
             (defaults (.o root-id: "seed-root-01"
                           contract-id: "context.session.seed.v1"
                           contract-revision: "1"
                           project-id: "marlin-agent-core"))
             (res1 (agentic-ai-lab-ai-agentic-context-repair-org
                    "tmp/0001.org" 1 broken-mechanical defaults))
             ;; Semantic violation: valid Org syntax, but inline `:org-contract` requires at least 1 `llm` src-block
             (broken-semantic
              (string-append
               ":PROPERTIES:\n"
               ":ID: sem-root-01\n"
               ":CONTRACT_ID: context.session.seed.v1\n"
               ":CONTRACT_REVISION: 1\n"
               ":GITOPS_PROJECT: marlin-agent-core\n"
               ":END:\n\n"
               "* Contract\n"
               ":PROPERTIES:\n"
               ":CONTRACT_ID: context.session.seed.v1\n"
               ":CONTRACT_SCOPE: document\n"
               ":END:\n"
               "#+begin_src scheme :org-contract\n"
               "(assert-org-element \"need.llm-turn\" error\n"
               "  (bindings)\n"
               "  (org-elements src-block (descendant-of scope) (property language \"llm\"))\n"
               "  (expect at-least 1)\n"
               "  (message \"Missing required llm Org-Babel turn\")\n"
               "  (fix \"Append a named #+BEGIN_SRC llm block\"))\n"
               "#+end_src\n\n"
               "* Empty Turn\n"
               ":PROPERTIES:\n"
               ":ID: sec-empty-1\n"
               ":END:\n"
               "No babel block yet.\n"))
             (res2 (agentic-ai-lab-ai-agentic-context-repair-org
                    "tmp/0002.org" 1 broken-semantic)))
        ;; Stage 1 repairs all mechanical defects at 0 tokens and admits a valid OrgSource cut!
        (check (.ref res1 'accepted?) => #t)
        (check (.ref res1 'stage) => 'ast-auto-repaired)
        (check (.ref res1 'flashRepairRequest) => #f)
        (check (and (string-contains (.ref res1 'repairedOrg) "* TODO Fix parser bug [1/2] :ATTACH:") #t) => #t)
        (check (and (string-contains (.ref res1 'repairedOrg) "#+BEGIN_THINKING") #t) => #t)
        (check (and (string-contains (.ref res1 'repairedOrg) "- [X] Reproduce failure") #t) => #t)
        (check (and (string-contains (.ref res1 'repairedOrg) "- [ ] Add test") #t) => #t)
        ;; Stage 2 escalates semantic contract gap to bounded Flash repair request!
        (check (.ref res2 'accepted?) => #f)
        (check (.ref res2 'stage) => 'needs-flash-semantic-repair)
        (let (req (.ref res2 'flashRepairRequest))
          (check (.ref req 'diagnostic) => "Missing required llm Org-Babel turn")
          (check (.ref req 'fixHint) => "Append a named #+BEGIN_SRC llm block"))))

    (yuanxu-test-case "Parser-verified Org-Babel upsert, checklist toggle, TODO->DONE, and safe fission"
      (let* (;; 1. Before `builder-turn-1` has `#+RESULTS:`, fission MUST fail closed (no mid-stream split)!
             (plan-cut-1 (context-org-source "tmp/0042.org" 1 plan-org #t)))
        (check-exception
         (agentic-ai-lab-ai-agentic-context-fission-subtree
          plan-cut-1 adr-org "task-compile-gql")
         true)
        ;; 2. Upsert `#+RESULTS: builder-turn-1`, check off item 1 (`[1/2] -> [2/2]`), mark `DONE`, then fission!
        (let* ((with-res (agentic-ai-lab-ai-agentic-context-babel-upsert-results
                          plan-org "builder-turn-1"
                          "Lowered Org Elements to GQL cleanly."
                          "Checked GraphSyntaxEquals pushdown."))
               (with-chk (agentic-ai-lab-ai-agentic-context-checklist-set
                          with-res "task-compile-gql" 1 #t))
               (with-done (agentic-ai-lab-ai-agentic-context-headline-set-todo
                           with-chk "task-compile-gql" "DONE"))
               (plan-cut-2 (context-org-source "tmp/0042.org" 2 with-done #t))
               (fission (agentic-ai-lab-ai-agentic-context-fission-subtree
                         plan-cut-2 adr-org "task-compile-gql")))
          (check (and (string-contains with-done "* DONE [#A] Compile Org Elements to GQL [2/2]") #t) => #t)
          (check (and (string-contains with-done "#+BEGIN_THINKING\nChecked GraphSyntaxEquals pushdown.\n#+END_THINKING") #t) => #t)
          (check (and (string-contains (.ref fission 'promotedSubtree) ":CONTEXT_ORIGIN_SOURCE: tmp/0042.org") #t) => #t)
          (check (and (string-contains (.ref fission 'promotedSubtree) ":CONTEXT_ORIGIN_ID: task-compile-gql") #t) => #t)
          (check (not (string-contains (.ref fission 'scratchOrg) ":ID: task-compile-gql")) => #t)
          (check (and (string-contains (.ref fission 'targetOrg) ":ID: task-compile-gql") #t) => #t))))))
