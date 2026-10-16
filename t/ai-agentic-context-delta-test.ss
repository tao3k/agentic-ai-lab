;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test (only-in :core/observability/testing-case poo-flow-test-case)
        (only-in :clan/poo/object .o .ref)
        :poo-flow/modules/ai-agentic-context/objects
        :poo-flow/modules/ai-agentic-context/funs-features
        :poo-flow/modules/ai-agentic-context/funs-projection
        :poo-flow/modules/ai-agentic-context/funs-delta
        :poo-flow/modules/ai-agentic-context/funs-session
        :poo-flow/modules/query/semantic/context-restriction
        (only-in :poo-flow/modules/session/types poo-flow-session-input-ref-shape?))
(export ai-agentic-context-delta-test)
(def scope (.o (:: @ AiAgenticContextScope.) bundle: "b" organization: "o" epoch: 1
  project: "p" worktree: "w" source-cut: "cut:0" actor: "a" task: "t" destination: "d"))
(def target-scope (.o (:: @ scope) source-cut: "cut:1"))
(def restriction (poo-flow-context-restriction "domain" '("a") '("d") '("o") 0 10))
(def profile (poo-flow-ai-agentic-context-profile #f))
(def before "#+SEQ_TODO: TODO | DONE\n* TODO Original\n* TODO Retained\n")
(def after "#+SEQ_TODO: TODO | DONE\n* DONE Original\n* TODO Retained\n* TODO Added\n")
(def (base) (poo-flow-ai-agentic-context-org-project scope before restriction profile))
(def (target) (poo-flow-ai-agentic-context-org-project target-scope after restriction profile))
(def (admit delta)
  (poo-flow-ai-agentic-context-delta-admit before (base) delta after target-scope restriction profile))
(def unit-a '("a" (title "A")))
(def unit-b '("b" (title "B")))
(def unit-c '("c" (title "C")))
(def toy-base (.o semantic-digest: "base" content: (list unit-a unit-b)))
(def toy-target (.o semantic-digest: "target" content: (list unit-b unit-c)))
(def (toy) (poo-flow-ai-agentic-context-delta-between toy-base toy-target))
(def ai-agentic-context-delta-test
  (test-suite "Context Delta full-reprojection admission"
    (poo-flow-test-case "insert/delete reconstruction preserves untouched content"
      (let (r (poo-flow-ai-agentic-context-delta-apply toy-base (toy)))
        (check (.ref r 'accepted?) => #t)
        (check (.ref r 'content) => (list unit-b unit-c))))
    (poo-flow-test-case "replacement and target ordering are exact"
      (let* ((new (.o semantic-digest: "new" content: (list unit-b '("a" (title "Changed")))))
             (r (poo-flow-ai-agentic-context-delta-apply toy-base
                  (poo-flow-ai-agentic-context-delta-between toy-base new))))
        (check (.ref r 'content) => (.ref new 'content))))
    (poo-flow-test-case "wrong base is refused"
      (check (.ref (poo-flow-ai-agentic-context-delta-apply toy-base
        (.o (:: @ (toy)) base-digest: "foreign")) 'reason) => 'wrong-base))
    (poo-flow-test-case "wrong expected unit is refused"
      (check (.ref (poo-flow-ai-agentic-context-delta-apply toy-base
        (.o (:: @ (toy)) edits: (list (.o (:: @ AiAgenticContextEdit.) identity: "a"
          expected: '("a" (title "Forged")) replacement: #f)))) 'reason) => 'wrong-unit-version))
    (poo-flow-test-case "duplicate edits and missing order are refused"
      (let (d (toy))
        (check (.ref (poo-flow-ai-agentic-context-delta-apply toy-base
          (.o (:: @ d) edits: (append (.ref d 'edits) (.ref d 'edits)))) 'reason) => 'duplicate-identity)
        (check (.ref (poo-flow-ai-agentic-context-delta-apply toy-base
          (.o (:: @ d) order: '("b"))) 'reason) => 'incomplete-order)))
    (poo-flow-test-case "real source correction equals independent full projection"
      (let* ((d (poo-flow-ai-agentic-context-delta-between (base) (target))) (r (admit d)))
        (check (.ref r 'accepted?) => #t)
        (check (.ref (.ref r 'projection) 'semantic-digest) => (.ref (target) 'semantic-digest))
        (check (.ref (.ref r 'projection) 'content) => (.ref (target) 'content))
        (check (.ref r 'coverage) => 'full-reprojection)
        (check (.ref r 'action-authorized?) => #f)))
    (poo-flow-test-case "omitted deletion and forged target fail independent reprojection"
      (let* ((b (base)) (t (target)) (d (poo-flow-ai-agentic-context-delta-between b t))
             (no-edit (.o (:: @ d) edits: '() order: (map car (.ref b 'content)))))
        (check (.ref (admit no-edit) 'reason) => 'target-content-mismatch)
        (check (.ref (admit (.o (:: @ d) target-digest: "forged")) 'reason) => 'wrong-target)))
    (poo-flow-test-case "scope and profile changes require fresh construction"
      (let ((b (base)) (d (poo-flow-ai-agentic-context-delta-between (base) (target))))
        (check (.ref (poo-flow-ai-agentic-context-delta-admit before b d after
          (.o (:: @ target-scope) destination: "other") restriction profile) 'reason) => 'contract-mismatch)
        (check (.ref (poo-flow-ai-agentic-context-delta-admit before b d after target-scope
          restriction (poo-flow-ai-agentic-context-profile #t)) 'reason) => 'contract-mismatch)))
    (poo-flow-test-case "incremental source changes equal full projection"
      (for-each (lambda (source)
        (let* ((b (base))
               (full (poo-flow-ai-agentic-context-org-project target-scope source restriction profile))
               (inc (poo-flow-ai-agentic-context-org-project-incremental before b target-scope source restriction profile))
               (r (poo-flow-ai-agentic-context-delta-admit-incremental before b
                    (poo-flow-ai-agentic-context-delta-between b full) source target-scope restriction profile)))
          (check (.ref inc 'content) => (.ref full 'content))
          (check (.ref inc 'semantic-digest) => (.ref full 'semantic-digest))
          (check (.ref r 'accepted?) => #t)
          (check (.ref r 'coverage) => 'local-query-complete-domain)
          (check (.ref r 'action-authorized?) => #f)))
        (list before after "* TODO Added\n" "* DONE Closed\n"
          "#+SEQ_TODO: DONE | TODO\n* TODO Original\n* TODO Retained\n"
          "* TODO 中文\n* TODO Other\n" "")))
    (poo-flow-test-case "unchanged local inputs reuse results with new global identity"
      (let* ((b (base))
             (inc (poo-flow-ai-agentic-context-org-project-incremental before b target-scope
                    (string-append before "* TODO Added\n") restriction profile))
             (obs (.ref inc 'observation)))
        (check (.ref obs 'reused-node-count) => 2)
        (check (.ref obs 'evaluated-node-count) => 1)
        (check (equal? (caar (.ref b 'content)) (caar (.ref inc 'content))) => #f)))
    (poo-flow-test-case "forged cache cannot alter incremental results"
      (let* ((b (base))
             (forged (.o (:: @ b) observation: (.o (:: @ (.ref b 'observation))
                         node-snapshots: '() selection-rows: '())))
             (inc (poo-flow-ai-agentic-context-org-project-incremental before forged
                    target-scope before restriction profile)))
        (check (.ref inc 'content) => (.ref (poo-flow-ai-agentic-context-org-project
                      target-scope before restriction profile) 'content))
        (check (.ref (.ref inc 'observation) 'reused-node-count) => 2)))
    (poo-flow-test-case "Context produces exact source-replayed Session input proposal"
      (let* ((bound-scope (.o (:: @ scope) session: "session" turn: 7))
             (p (poo-flow-ai-agentic-context-org-project bound-scope before restriction profile))
             (input (poo-flow-ai-agentic-context-session-input before p bound-scope "receipt")))
        (check (poo-flow-session-input-ref-shape? input) => #t)
        (check (.ref input 'consumer-session) => "session")
        (check (.ref input 'consumer-turn) => 7)
        (check (.ref input 'identity) => (.ref p 'semantic-digest))
        (check (equal? (.ref input 'digest)
          (.ref (poo-flow-ai-agentic-context-session-input before p bound-scope "other-receipt") 'digest)) => #f)
        (check (.ref input 'digest) =>
          (.ref (poo-flow-ai-agentic-context-session-input before p bound-scope "receipt") 'digest))
        (check-exception (poo-flow-ai-agentic-context-session-input after p bound-scope "receipt") true)))
    (poo-flow-test-case "historical bytes and source mismatch cannot be trusted"
      (check-exception (poo-flow-ai-agentic-context-delta-admit "* TODO Forged\n" (base)
        (poo-flow-ai-agentic-context-delta-between (base) (target)) after target-scope restriction profile) true))))
