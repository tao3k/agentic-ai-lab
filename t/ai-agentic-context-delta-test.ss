;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :clan/poo/object .o .ref)
        :agentic-ai-lab/modules/ai-agentic-context/objects
        :agentic-ai-lab/modules/ai-agentic-context/funs-features
        :agentic-ai-lab/modules/ai-agentic-context/funs-projection
        :agentic-ai-lab/modules/ai-agentic-context/funs-delta
        :agentic-ai-lab/modules/ai-agentic-context/funs-session
        :agentic-ai-lab/modules/query/semantic/context-restriction
        (only-in :agentic-ai-lab/modules/session/types agentic-ai-lab-session-input-ref-shape?))
(export ai-agentic-context-delta-test)
(def scope (.o (:: @ AiAgenticContextScope.) bundle: "b" organization: "o" epoch: 1
  project: "p" worktree: "w" source-cut: "cut:0" actor: "a" task: "t" destination: "d"))
(def target-scope (.o (:: @ scope) source-cut: "cut:1"))
(def restriction (agentic-ai-lab-context-restriction "domain" '("a") '("d") '("o") 0 10))
(def profile (agentic-ai-lab-ai-agentic-context-profile #f))
(def before "#+SEQ_TODO: TODO | DONE\n* TODO Original\n* TODO Retained\n")
(def after "#+SEQ_TODO: TODO | DONE\n* DONE Original\n* TODO Retained\n* TODO Added\n")
(def (base) (agentic-ai-lab-ai-agentic-context-org-project scope before restriction profile))
(def (target) (agentic-ai-lab-ai-agentic-context-org-project target-scope after restriction profile))
(def (admit delta)
  (agentic-ai-lab-ai-agentic-context-delta-admit before (base) delta after target-scope restriction profile))
(def unit-a '("a" (title "A")))
(def unit-b '("b" (title "B")))
(def unit-c '("c" (title "C")))
(def toy-base (.o semantic-digest: "base" content: (list unit-a unit-b)))
(def toy-target (.o semantic-digest: "target" content: (list unit-b unit-c)))
(def (toy) (agentic-ai-lab-ai-agentic-context-delta-between toy-base toy-target))
(def ai-agentic-context-delta-test
  (test-suite "Context Delta full-reprojection admission"
    (yuanxu-test-case "insert/delete reconstruction preserves untouched content"
      (let (r (agentic-ai-lab-ai-agentic-context-delta-apply toy-base (toy)))
        (check (.ref r 'accepted?) => #t)
        (check (.ref r 'content) => (list unit-b unit-c))))
    (yuanxu-test-case "replacement and target ordering are exact"
      (let* ((new (.o semantic-digest: "new" content: (list unit-b '("a" (title "Changed")))))
             (r (agentic-ai-lab-ai-agentic-context-delta-apply toy-base
                  (agentic-ai-lab-ai-agentic-context-delta-between toy-base new))))
        (check (.ref r 'content) => (.ref new 'content))))
    (yuanxu-test-case "wrong base is refused"
      (check (.ref (agentic-ai-lab-ai-agentic-context-delta-apply toy-base
        (.o (:: @ (toy)) base-digest: "foreign")) 'reason) => 'wrong-base))
    (yuanxu-test-case "wrong expected unit is refused"
      (check (.ref (agentic-ai-lab-ai-agentic-context-delta-apply toy-base
        (.o (:: @ (toy)) edits: (list (.o (:: @ AiAgenticContextEdit.) identity: "a"
          expected: '("a" (title "Forged")) replacement: #f)))) 'reason) => 'wrong-unit-version))
    (yuanxu-test-case "duplicate edits and missing order are refused"
      (let (d (toy))
        (check (.ref (agentic-ai-lab-ai-agentic-context-delta-apply toy-base
          (.o (:: @ d) edits: (append (.ref d 'edits) (.ref d 'edits)))) 'reason) => 'duplicate-identity)
        (check (.ref (agentic-ai-lab-ai-agentic-context-delta-apply toy-base
          (.o (:: @ d) order: '("b"))) 'reason) => 'incomplete-order)))
    (yuanxu-test-case "real source correction equals independent full projection"
      (let* ((d (agentic-ai-lab-ai-agentic-context-delta-between (base) (target))) (r (admit d)))
        (check (.ref r 'accepted?) => #t)
        (check (.ref (.ref r 'projection) 'semantic-digest) => (.ref (target) 'semantic-digest))
        (check (.ref (.ref r 'projection) 'content) => (.ref (target) 'content))
        (check (.ref r 'coverage) => 'full-reprojection)
        (check (.ref r 'action-authorized?) => #f)))
    (yuanxu-test-case "omitted deletion and forged target fail independent reprojection"
      (let* ((b (base)) (t (target)) (d (agentic-ai-lab-ai-agentic-context-delta-between b t))
             (no-edit (.o (:: @ d) edits: '() order: (map car (.ref b 'content)))))
        (check (.ref (admit no-edit) 'reason) => 'target-content-mismatch)
        (check (.ref (admit (.o (:: @ d) target-digest: "forged")) 'reason) => 'wrong-target)))
    (yuanxu-test-case "scope and profile changes require fresh construction"
      (let ((b (base)) (d (agentic-ai-lab-ai-agentic-context-delta-between (base) (target))))
        (check (.ref (agentic-ai-lab-ai-agentic-context-delta-admit before b d after
          (.o (:: @ target-scope) destination: "other") restriction profile) 'reason) => 'contract-mismatch)
        (check (.ref (agentic-ai-lab-ai-agentic-context-delta-admit before b d after target-scope
          restriction (agentic-ai-lab-ai-agentic-context-profile #t)) 'reason) => 'contract-mismatch)))
    (yuanxu-test-case "incremental source changes equal full projection"
      (for-each (lambda (source)
        (let* ((b (base))
               (full (agentic-ai-lab-ai-agentic-context-org-project target-scope source restriction profile))
               (inc (agentic-ai-lab-ai-agentic-context-org-project-incremental before b target-scope source restriction profile))
               (r (agentic-ai-lab-ai-agentic-context-delta-admit-incremental before b
                    (agentic-ai-lab-ai-agentic-context-delta-between b full) source target-scope restriction profile)))
          (check (.ref inc 'content) => (.ref full 'content))
          (check (.ref inc 'semantic-digest) => (.ref full 'semantic-digest))
          (check (.ref r 'accepted?) => #t)
          (check (.ref r 'coverage) => 'local-query-complete-domain)
          (check (.ref r 'action-authorized?) => #f)))
        (list before after "* TODO Added\n" "* DONE Closed\n"
          "#+SEQ_TODO: DONE | TODO\n* TODO Original\n* TODO Retained\n"
          "* TODO 中文\n* TODO Other\n" "")))
    (yuanxu-test-case "unchanged local inputs reuse results with new global identity"
      (let* ((b (base))
             (inc (agentic-ai-lab-ai-agentic-context-org-project-incremental before b target-scope
                    (string-append before "* TODO Added\n") restriction profile))
             (obs (.ref inc 'observation)))
        (check (.ref obs 'reused-node-count) => 2)
        (check (.ref obs 'evaluated-node-count) => 1)
        (check (equal? (caar (.ref b 'content)) (caar (.ref inc 'content))) => #f)))
    (yuanxu-test-case "forged cache cannot alter incremental results"
      (let* ((b (base))
             (forged (.o (:: @ b) observation: (.o (:: @ (.ref b 'observation))
                         node-snapshots: '() selection-rows: '())))
             (inc (agentic-ai-lab-ai-agentic-context-org-project-incremental before forged
                    target-scope before restriction profile)))
        (check (.ref inc 'content) => (.ref (agentic-ai-lab-ai-agentic-context-org-project
                      target-scope before restriction profile) 'content))
        (check (.ref (.ref inc 'observation) 'reused-node-count) => 2)))
    (yuanxu-test-case "Context produces exact source-replayed Session input proposal"
      (let* ((bound-scope (.o (:: @ scope) session: "session" turn: 7))
             (p (agentic-ai-lab-ai-agentic-context-org-project bound-scope before restriction profile))
             (input (agentic-ai-lab-ai-agentic-context-session-input before p bound-scope "receipt")))
        (check (agentic-ai-lab-session-input-ref-shape? input) => #t)
        (check (.ref input 'consumer-session) => "session")
        (check (.ref input 'consumer-turn) => 7)
        (check (.ref input 'identity) => (.ref p 'semantic-digest))
        (check (equal? (.ref input 'digest)
          (.ref (agentic-ai-lab-ai-agentic-context-session-input before p bound-scope "other-receipt") 'digest)) => #f)
        (check (.ref input 'digest) =>
          (.ref (agentic-ai-lab-ai-agentic-context-session-input before p bound-scope "receipt") 'digest))
        (check-exception (agentic-ai-lab-ai-agentic-context-session-input after p bound-scope "receipt") true)))
    (yuanxu-test-case "historical bytes and source mismatch cannot be trusted"
      (check-exception (agentic-ai-lab-ai-agentic-context-delta-admit "* TODO Forged\n" (base)
        (agentic-ai-lab-ai-agentic-context-delta-between (base) (target)) after target-scope restriction profile) true))))
