;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test (only-in :clan/poo/object .ref)
        :agentic-ai-lab/modules/ai-agentic-context/clue-query
        (only-in :gerbil-ascent/rules/declaration rule-module-program)
        (only-in :gerbil-ascent/program/session gerbil-ascent-open-session
          gerbil-ascent-session-run gerbil-ascent-session-replace-source!))
(export clue-query-test)

(def (rows session name)
  (let (result (gerbil-ascent-session-run session))
    (check-equal? (.ref result 'finished) #t)
    ((.ref result 'rows-of) name)))

(def (clue-session)
  (let (session (gerbil-ascent-open-session
                 (rule-module-program (make-clue-query-evidence))))
    (gerbil-ascent-session-run session)
    session))

(def clue-query-test
  (test-suite "Agent-selected clue query remains evidence-bound"
    (test-case "hypotheses and factors remain visible without becoming support"
      (let (session (clue-session))
        (gerbil-ascent-session-replace-source! session 'question '(("header-write")))
        (gerbil-ascent-session-replace-source! session 'clue
          '(("h" "digest-h" "header-write" "support" "hypothesis" "agent")
            ("o" "digest-o" "header-write" "support" "observation" "trace")))
        (gerbil-ascent-session-replace-source! session 'factor
          '(("h" "digest-h" "publication-order" "candidate")))
        (check-equal? (rows session 'support) [])
        (check-equal? (rows session 'conditional)
          '(("header-write" "h" "digest-h" "support" "agent")))
        (check-equal? (rows session 'relevant_factor)
          '(("header-write" "h" "digest-h" "publication-order" "candidate" "hypothesis")))
        (check-equal? (rows session 'unknown) '(("header-write")))))
    (test-case "two admitted sides retain independent references and withdraw"
      (let (session (clue-session))
        (gerbil-ascent-session-replace-source! session 'question '(("header-write")))
        (gerbil-ascent-session-replace-source! session 'clue
          '(("positive" "digest-positive" "header-write" "support" "observation" "trace-a")
            ("negative" "digest-negative" "header-write" "counter" "observation" "trace-b")))
        (gerbil-ascent-session-replace-source! session 'attested
          '(("positive" "digest-positive" "receipt-a")
            ("negative" "digest-negative" "receipt-b")))
        (check-equal? (rows session 'support)
          '(("header-write" "positive" "digest-positive" "trace-a" "receipt-a")))
        (check-equal? (rows session 'counterevidence)
          '(("header-write" "negative" "digest-negative" "trace-b" "receipt-b")))
        (check-equal? (rows session 'conflict) '(("header-write")))
        (check-equal? (rows session 'unknown) [])
        (gerbil-ascent-session-replace-source! session 'attested
          '(("positive" "digest-positive" "receipt-a")))
        (check-equal? (rows session 'counterevidence) [])
        (check-equal? (rows session 'conflict) [])
        (check-equal? (rows session 'support)
          '(("header-write" "positive" "digest-positive" "trace-a" "receipt-a")))
        (gerbil-ascent-session-replace-source! session 'attested [])
        (check-equal? (rows session 'support) [])
        (check-equal? (rows session 'unknown) '(("header-write")))))
    (test-case "Agent may leave the first scope without losing source clues"
      (let (session (clue-session))
        (gerbil-ascent-session-replace-source! session 'clue
          '(("a" "digest-a" "header-write" "support" "observation" "trace-a")
            ("b" "digest-b" "gc-pause" "support" "observation" "trace-b")))
        (gerbil-ascent-session-replace-source! session 'attested
          '(("a" "digest-a" "receipt-a") ("b" "digest-b" "receipt-b")))
        (gerbil-ascent-session-replace-source! session 'question '(("header-write")))
        (check-equal? (length (rows session 'support)) 1)
        (gerbil-ascent-session-replace-source! session 'question '(("gc-pause")))
        (check-equal? (rows session 'support)
          '(("gc-pause" "b" "digest-b" "trace-b" "receipt-b")))))
    (test-case "a second Agent question expands the graph one hop at a time"
      (let (session (clue-session))
        (gerbil-ascent-session-replace-source! session 'clue
          '(("a" "digest-a" "header-write" "support" "observation" "trace-a")
            ("b" "digest-b" "gc-pause" "support" "observation" "trace-b")))
        (gerbil-ascent-session-replace-source! session 'attested
          '(("a" "digest-a" "receipt-a") ("b" "digest-b" "receipt-b")))
        (gerbil-ascent-session-replace-source! session 'link
          '(("header-write" "gc-pause" "related" "a" "digest-a")
            ("gc-pause" "vm-owner" "related" "b" "digest-b")))
        (gerbil-ascent-session-replace-source! session 'question '(("header-write")))
        (check-equal? (rows session 'neighbor)
          '(("header-write" "gc-pause" "related" "a" "digest-a"
             "support" "receipt-a")))
        (gerbil-ascent-session-replace-source! session 'question '(("gc-pause")))
        (check-equal? (rows session 'neighbor)
          '(("gc-pause" "vm-owner" "related" "b" "digest-b"
             "support" "receipt-b")))))
    (test-case "changed clue content cannot inherit an old attestation"
      (let (session (clue-session))
        (gerbil-ascent-session-replace-source! session 'question '(("header-write")))
        (gerbil-ascent-session-replace-source! session 'clue
          '(("same-id" "new-digest" "header-write" "support" "observation" "trace")))
        (gerbil-ascent-session-replace-source! session 'attested
          '(("same-id" "old-digest" "receipt-old")))
        (check-equal? (rows session 'support) [])
        (check-equal? (rows session 'unknown) '(("header-write")))
        (gerbil-ascent-session-replace-source! session 'attested
          '(("same-id" "new-digest" "receipt-new")))
        (check-equal? (rows session 'support)
          '(("header-write" "same-id" "new-digest" "trace" "receipt-new")))
        (gerbil-ascent-session-replace-source! session 'factor
          '(("same-id" "old-digest" "publication-order" "old")))
        (gerbil-ascent-session-replace-source! session 'link
          '(("header-write" "gc-pause" "related" "same-id" "old-digest")))
        (check-equal? (rows session 'relevant_factor) [])
        (check-equal? (rows session 'neighbor) [])
        (gerbil-ascent-session-replace-source! session 'link
          '(("header-write" "gc-pause" "related" "same-id" "new-digest")))
        (check-equal? (rows session 'neighbor)
          '(("header-write" "gc-pause" "related" "same-id" "new-digest"
             "support" "receipt-new")))))))
