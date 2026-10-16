;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
        (only-in :std/test check-equal? test-suite)
        (only-in :clan/poo/object .o .ref)
        (only-in :poo-flow/modules/query/semantic/orgize-interface
                 make-org-element-graph-view org-element-query
                 org-elements property descendant-of)
        :poo-flow/modules/session/config
        :poo-flow/modules/ai-agentic-context/features/memory/config
        :poo-flow/modules/ai-agentic-context/features/memory/org-selection
        :poo-flow/modules/session/org-memory-selection)

(export memory-org-selection-test)

;;; The fixture uses Orgize's public Scheme query DSL. POO Flow does not parse
;;; Org text or reimplement Element query or Memory semantics.
(def org-graph
  (make-org-element-graph-view
   (list (.o id: 0 parent: #f kind: "org-data" todo-type: #f)
         (.o id: 1 parent: 0 kind: "headline" todo-type: "todo")
         (.o id: 2 parent: 0 kind: "headline" todo-type: "done"))
   (lambda (record) (.ref record 'id))
   (lambda (record) (.ref record 'parent))
   (lambda (record) (.ref record 'kind))
   (lambda (record name)
     (and (equal? name "todo-type") (.ref record 'todo-type)))))

(def org-query
  (org-element-query "tasks.open"
    (org-elements headline (property todo-type "todo")
                  (descendant-of scope))))

(def org-selection
  (poo-flow-memory-org-select
   "project-one" "worktree-a" "notes/memory.org" "cut-a"
   "bytes-sha256" org-graph org-query 0))

(def org-store
  (poo-flow-memory-store-spec
   'memory/team 'org-worktree 'worktree '(worktree)
   '(exact-key) '(append) "marlin-agent-core" 'memory/team
   #t 'marlin-memory-adapter))

(def org-intent
  (poo-flow-session-memory-intent
   'intent/team 'memory/team 'worktree '(review) 'append))

(def org-session
  (poo-flow-session-value
   'session/one '()
   (poo-flow-session-lineage 'session/one '() 'root)
   (poo-flow-session-placement 'profile/test)))

(def (org-context worktree-id cut bytes query expected current granted? active?)
  (poo-flow-session-org-memory-selection-context
   "project-one" worktree-id cut bytes query
   expected current granted? active?))

(def memory-org-selection-test
  (test-suite "POO Flow consumes Orgize Scheme selection"
    (poo-flow-test-case "Orgize named query selects only current headline"
      (check-equal? (poo-flow-memory-org-selection? org-selection) #t)
      (check-equal? (.ref org-selection 'query-id) "tasks.open")
      (check-equal? (.ref org-selection 'candidate-record-ids) '(1))
      (check-equal? (.ref org-selection 'orgize-evaluated?) #t)
      (check-equal? (.ref org-selection 'semantic-admitted?) #f)
      (check-equal? (.ref org-selection 'memory-published?) #f))
    (poo-flow-test-case "same-cut policy match still lacks source admission"
      (let (proposal
            (poo-flow-session-org-memory-selection-intent
             org-selection org-intent org-store org-session
             (org-context "worktree-a" "cut-a" "bytes-sha256"
                          "tasks.open" 3 3 #t #t)))
        (check-equal?
         (poo-flow-session-org-memory-selection-intent-policy-eligible?
          proposal) #t)
        (check-equal?
         (poo-flow-session-org-memory-selection-intent-eligible? proposal) #f)
        (check-equal?
         (poo-flow-session-org-memory-selection-intent-diagnostics proposal)
         '(unverified-source-graph))
        (check-equal? (.ref proposal 'semantic-admitted?) #f)
        (check-equal? (.ref proposal 'memory-published?) #f)))
    (poo-flow-test-case "same digest with forged graph cannot qualify"
      (let* ((forged-graph
              (make-org-element-graph-view
               (list (.o id: 0 parent: #f kind: "org-data" todo-type: #f)
                     (.o id: 1 parent: 0 kind: "headline" todo-type: "done")
                     (.o id: 2 parent: 0 kind: "headline" todo-type: "todo"))
               (lambda (record) (.ref record 'id))
               (lambda (record) (.ref record 'parent))
               (lambda (record) (.ref record 'kind))
               (lambda (record name)
                 (and (equal? name "todo-type") (.ref record 'todo-type)))))
             (forged-selection
              (poo-flow-memory-org-select
               "project-one" "worktree-a" "notes/memory.org" "cut-a"
               "bytes-sha256" forged-graph org-query 0))
             (proposal
              (poo-flow-session-org-memory-selection-intent
               forged-selection org-intent org-store org-session
               (org-context "worktree-a" "cut-a" "bytes-sha256"
                            "tasks.open" 3 3 #t #t))))
        (check-equal? (.ref forged-selection 'candidate-record-ids) '(2))
        (check-equal?
         (poo-flow-session-org-memory-selection-intent-policy-eligible?
          proposal) #t)
        (check-equal?
         (poo-flow-session-org-memory-selection-intent-eligible? proposal) #f)
        (check-equal?
         (poo-flow-session-org-memory-selection-intent-diagnostics proposal)
         '(unverified-source-graph))))
    (poo-flow-test-case "foreign WorkTree, stale cut, query and head are refused"
      (let (proposal
            (poo-flow-session-org-memory-selection-intent
             org-selection org-intent org-store org-session
             (org-context "worktree-b" "cut-b" "bytes-sha256"
                          "tasks.done" 3 4 #t #t)))
        (check-equal?
         (poo-flow-session-org-memory-selection-intent-diagnostics proposal)
         '(foreign-scope stale-source-cut query-not-granted stale-memory-head
                         unverified-source-graph))))
    (poo-flow-test-case "changed bytes at same cut are refused"
      (let (proposal
            (poo-flow-session-org-memory-selection-intent
             org-selection org-intent org-store org-session
             (org-context "worktree-a" "cut-a" "new-bytes"
                          "tasks.open" 3 3 #t #t)))
        (check-equal?
         (poo-flow-session-org-memory-selection-intent-diagnostics proposal)
         '(stale-org-bytes unverified-source-graph))))
    (poo-flow-test-case "revoked read and inactive Session are refused"
      (let (proposal
            (poo-flow-session-org-memory-selection-intent
             org-selection org-intent org-store org-session
             (org-context "worktree-a" "cut-a" "bytes-sha256"
                          "tasks.open" 3 3 #f #f)))
        (check-equal?
         (poo-flow-session-org-memory-selection-intent-diagnostics proposal)
         '(read-not-granted session-inactive unverified-source-graph))))))
