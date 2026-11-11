;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :clan/poo/object .o .ref .get)
        (only-in :clan/poo/mop validate TypeError?)
        (only-in :agentic-ai-lab/modules/ai-agentic-context/types AiAgenticContextAdmissionType AiAgenticContextScopeType)
        (only-in :agentic-ai-lab/modules/ai-agentic-context/objects AiAgenticContextScope.)
        (only-in :agentic-ai-lab/modules/ai-agentic-context/funs-scope agentic-ai-lab-ai-agentic-context-scope-admit))
(export context-scope-contract-test)
(def scope (.o (:: @ AiAgenticContextScope.)
  bundle: "bundle:1" organization: "org:1" epoch: 1 project: "project:1"
  worktree: "worktree:1" source-cut: "cut:1" actor: "actor:1" task: "task:1"
  destination: "provider:1"))
(def context-scope-contract-test
  (test-suite "Library Scope admission issuance"
    (test-case "shared Scope Function contract preserves checks and issuance"
      (let* ((checked (validate AiAgenticContextAdmissionType
                        agentic-ai-lab-ai-agentic-context-scope-admit))
             (again (validate AiAgenticContextAdmissionType checked))
             (bad-result (validate AiAgenticContextAdmissionType (lambda (_) #f))))
        (check (eq? checked again) => #t)
        (check (eq? (validate AiAgenticContextScopeType (checked scope)) #f) => #f)
        (check (with-catch TypeError? (lambda () (checked #f) #f)) => #t)
        (check (with-catch TypeError? (lambda () (bad-result scope) #f)) => #t)))
    (test-case "public admission retains string ownership and lazy digest"
      (let* ((actor-input (string-copy "actor:1"))
             (admitted (agentic-ai-lab-ai-agentic-context-scope-admit (.o (:: @ scope) actor: actor-input))))
        (string-set! actor-input 0 #\X)
        (check (.ref admitted 'actor) => "actor:1")
        (check (.get admitted semantic-digest)
               => (.get (agentic-ai-lab-ai-agentic-context-scope-admit scope) semantic-digest))))))
