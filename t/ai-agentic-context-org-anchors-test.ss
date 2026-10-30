;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :clan/poo/object .o .ref)
        :agentic-ai-lab/modules/ai-agentic-context/objects
        :agentic-ai-lab/modules/ai-agentic-context/types
        :agentic-ai-lab/modules/ai-agentic-context/funs-features
        :agentic-ai-lab/modules/ai-agentic-context/funs-projection
        :agentic-ai-lab/modules/ai-agentic-context/funs-anchors
        :agentic-ai-lab/modules/ai-agentic-context/funs-session
        (only-in :agentic-ai-lab/modules/session/funs-attempt agentic-ai-lab-session-schedule agentic-ai-lab-session-claim)
        :agentic-ai-lab/modules/query/semantic/context-restriction)
(export ai-agentic-context-org-anchors-test)
(def scope (.o (:: @ AiAgenticContextScope.) bundle: "bundle" organization: "org" epoch: 1
  project: "project" worktree: "worktree" source-cut: "cut" actor: "actor" task: "task"
  destination: "provider" session: "session" turn: 0))
(def restriction (agentic-ai-lab-context-restriction "domain" '("actor") '("provider") '("org") 0 10))
(def profile (agentic-ai-lab-ai-agentic-context-profile #f))
(def source "* TODO Parent\n:PROPERTIES:\n:ID: parent\n:END:\n** TODO 子项\n:PROPERTIES:\n:ID: child-α\n:END:\n")
(def (project text (scope-value scope))
  (agentic-ai-lab-ai-agentic-context-org-project scope-value text restriction profile))
(def (anchors text ids) (agentic-ai-lab-ai-agentic-context-org-anchors text (project text) scope ids))
(def ai-agentic-context-org-anchors-test
  (test-suite "Orgize property ID Context and Session bindings"
    (yuanxu-test-case "parser-owned ID spans bind exact parent and child containers"
      (let (bound (anchors source '("parent" "child-α")))
        (check (agentic-ai-lab-ai-agentic-context-org-anchor-shape? (car bound)) => #t)
        (check (.ref (car bound) 'container-start) => 0)
        (check (> (.ref (cadr bound) 'container-start) 0) => #t)
        (for-each (lambda (anchor)
          (check (utf8->string (subu8vector (string->utf8 source)
                    (.ref anchor 'value-start) (.ref anchor 'value-end))) => (.ref anchor 'org-id))
          (check (.ref anchor 'session) => "session")
          (check (.ref anchor 'action-authorized?) => #f)) bound)
        (check (map (lambda (a) (.ref a 'semantic-digest))
                 (agentic-ai-lab-ai-agentic-context-org-anchors-replay source (project source) scope bound))
               => (map (lambda (a) (.ref a 'semantic-digest)) bound))))
    (yuanxu-test-case "document ID and case-insensitive property key are source-backed"
      (let (a (car (anchors ":PROPERTIES:\n:id: document\n:END:\n* TODO Work\n" '("document"))))
        (check (.ref a 'container-kind) => 'OrgFile)))
    (yuanxu-test-case "unselected headline cannot supply a Task anchor"
      (check-exception (anchors "* DONE Closed\n:PROPERTIES:\n:ID: closed\n:END:\n" '("closed")) true))
    (yuanxu-test-case "literal block and nested quote IDs are not headline identities"
      (for-each (lambda (text) (check-exception (anchors text '("fake")) true))
        (list "* TODO Work\n#+begin_src org\n:PROPERTIES:\n:ID: fake\n:END:\n#+end_src\n"
              "* TODO Work\n#+begin_quote\n:PROPERTIES:\n:ID: fake\n:END:\n#+end_quote\n")))
    (yuanxu-test-case "duplicate empty and missing IDs are rejected"
      (check-exception (anchors "* TODO A\n:PROPERTIES:\n:ID: same\n:END:\n* TODO B\n:PROPERTIES:\n:ID: same\n:END:\n" '("same")) true)
      (check-exception (anchors "* TODO A\n:PROPERTIES:\n:ID:\n:END:\n" '("missing")) true)
      (check-exception (anchors source '("parent" "parent")) true)
      (check-exception (anchors source '("missing")) true))
    (yuanxu-test-case "source correction and forged spans invalidate old anchors"
      (let* ((old (anchors source '("parent")))
             (changed "* TODO A\n:PROPERTIES:\n:ID: parent\n:END:\n"))
        (check-exception (agentic-ai-lab-ai-agentic-context-org-anchors-replay changed (project changed) scope old) true)
        (check-exception (agentic-ai-lab-ai-agentic-context-org-anchors-replay source (project source) scope
           (list (.o (:: @ (car old)) value-end: (+ 1 (.ref (car old) 'value-end))))) true)
        (check-exception (agentic-ai-lab-ai-agentic-context-org-anchors-replay source (project source) scope
           (list (.o (:: @ (car old)) session: "foreign"))) true)))
    (yuanxu-test-case "Context builds Task references that survive exact Session claim"
      (let* ((task (agentic-ai-lab-ai-agentic-context-session-task source (project source) scope "receipt" 3 '("parent" "child-α")))
             (r (agentic-ai-lab-session-claim (agentic-ai-lab-session-schedule "session") 0 task "attempt" "request" 0)))
        (check (.ref r 'accepted?) => #t)
        (check (.ref (.ref (.ref r 'schedule) 'active) 'anchor-refs)
               => (map (lambda (a) (.ref a 'semantic-digest)) (.ref task 'anchor-bindings)))
        (check (.ref (.ref (.ref r 'schedule) 'active) 'task-revision) => 3)
        (check (.ref r 'runtime-published?) => #f)))
    (yuanxu-test-case "new Session or Turn requires newly bound anchors"
      (let* ((old (anchors source '("parent"))) (next-scope (.o (:: @ scope) turn: 1)))
        (check-exception (agentic-ai-lab-ai-agentic-context-org-anchors-replay source (project source next-scope) next-scope old) true)))))
