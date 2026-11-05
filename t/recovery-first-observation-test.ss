;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test :clan/poo/object
  "../modules/ai-agentic-context/recovery-observation.ss")
(export recovery-first-observation-test)
(def base
  (.o (:: @ RecoveryObservation.) identity: 'recovery revision: 'first
    intents: (list (.o command: 'edit task: 'repair revision: 'spec attempt: 'old scope: 'workspace epoch: 'old-owner))
    journal-heads: (list (.o scope: 'workspace cut: 'journal-now epoch: 'new-owner))
    scans: (list (.o identity: 'scan command: 'edit scope: 'workspace cut: 'journal-now epoch: 'new-owner coverage: 'complete outcome: 'missing))
    workspace-cuts: (list (.o scope: 'workspace cut: 'read-now))
    requirements: (list (.o command: 'edit aspect: 'writer-reconciliation)
                        (.o command: 'edit aspect: 'whole-change)
                        (.o command: 'edit aspect: 'task-acceptance))
    hypotheses: (list (.o command: 'edit identity: 'our-write question: 'inspect-origin)
                      (.o command: 'edit identity: 'other-writer question: 'inspect-other-history))))
(def (rows input relation) (recovery-observation-rows (recovery-observation-evaluate input) relation))
(def (has? result row) (if (member row result) #t #f))
(def matching-read
  (.o identity: 'read command: 'edit scope: 'workspace cut: 'read-now coherent: #t content: 'matches-desired))
(def recovery-first-observation-test
  (test-suite "First recovery observation retains uncertainty and responsibility"
    (test-case "missing receipt is not evidence that the write did not happen"
      (check-equal? (rows base 'ReceiptGap) '((edit scan)))
      (check-equal? (rows base 'HistoricalEffect) '())
      (check-equal? (has? (rows base 'Unknown) '(edit historical-effect)) #t))
    (test-case "matching fresh content discharges only the content question"
      (def observed (.o (:: @ base) reads: (list matching-read)))
      (def r (recovery-observation-evaluate observed))
      (check-equal? (recovery-observation-rows r 'CurrentContent) '((edit matches-desired read)))
      (check-equal? (has? (recovery-observation-rows r 'Unknown) '(edit current-content)) #f)
      (check-equal? (has? (recovery-observation-rows r 'Unknown) '(edit historical-effect)) #t)
      (check-equal? (length (recovery-observation-rows r 'Explore)) 2)
      (check-equal? (has? (recovery-observation-rows r 'Obligation) '(edit task-acceptance)) #t)
      (check-equal? (has? (rows base 'Unknown) '(edit current-content)) #t))
    (test-case "unknown journal coverage cannot prove a receipt gap"
      (def partial (.o (:: @ base) scans:
        (list (.o identity: 'partial command: 'edit scope: 'workspace cut: 'journal-now epoch: 'new-owner coverage: 'unknown outcome: 'missing))))
      (check-equal? (rows partial 'ReceiptGap) '())
      (check-equal? (has? (rows partial 'Obligation) '(edit journal-coverage)) #t)
      (check-equal? (has? (rows partial 'Obligation) '(edit writer-reconciliation)) #t)
      (check-equal? (has? (rows partial 'Obligation) '(edit whole-change)) #t)
      (check-equal? (has? (rows partial 'Obligation) '(edit task-acceptance)) #t))
    (test-case "old journal epoch and changed workspace cuts cannot act as current witnesses"
      (def stale (.o (:: @ base)
        journal-heads: (list (.o scope: 'workspace cut: 'journal-newer epoch: 'newer-owner))
        workspace-cuts: (list (.o scope: 'workspace cut: 'read-newer)) reads: (list matching-read)))
      (check-equal? (rows stale 'ReceiptGap) '())
      (check-equal? (rows stale 'CurrentContent) '()))
    (test-case "unstable reads and wrong-attempt witnesses leave history unresolved"
      (def bad (.o (:: @ base) reads: (list (.o (:: @ matching-read) coherent: #f))
        history: (list (.o identity: 'late command: 'edit attempt: 'replacement scope: 'workspace epoch: 'old-owner outcome: 'applied))))
      (check-equal? (rows bad 'CurrentContent) '())
      (check-equal? (rows bad 'HistoricalEffect) '()))
    (test-case "a qualified original witness resolves history but not independent acceptance"
      (def recovered (.o (:: @ base) history:
        (list (.o identity: 'origin command: 'edit attempt: 'old scope: 'workspace epoch: 'old-owner outcome: 'applied))))
      (check-equal? (rows recovered 'HistoricalEffect) '((edit applied origin)))
      (check-equal? (has? (rows recovered 'Obligation) '(edit historical-effect)) #f)
      (check-equal? (has? (rows recovered 'Obligation) '(edit task-acceptance)) #t))
    (test-case "opposing historical witnesses preserve conflict rather than pick the first"
      (def conflicting (.o (:: @ base) history:
        (list (.o identity: 'yes command: 'edit attempt: 'old scope: 'workspace epoch: 'old-owner outcome: 'applied)
              (.o identity: 'no command: 'edit attempt: 'old scope: 'workspace epoch: 'old-owner outcome: 'not-applied))))
      (def result (recovery-observation-evaluate conflicting))
      (check-equal? (length (recovery-observation-rows result 'HistoricalEffect)) 2)
      (check-equal? (recovery-observation-rows result 'ConflictingHistory) '((edit)))
      (check-equal? (has? (recovery-observation-rows result 'Unknown) '(edit historical-effect)) #t)
      (check-equal? (length (recovery-observation-rows result 'Explore)) 2))
    (test-case "a generic reconciliation cannot masquerade as a read or historical witness"
      (def substituted (.o (:: @ base) reconciliations:
        (list (.o identity: 'fake-read command: 'edit attempt: 'old aspect: 'current-content)
              (.o identity: 'fake-history command: 'edit attempt: 'old aspect: 'historical-effect))))
      (check-equal? (has? (rows substituted 'Unknown) '(edit current-content)) #t)
      (check-equal? (has? (rows substituted 'Unknown) '(edit historical-effect)) #t))
    (test-case "independent acceptance does not rewrite the old effect history"
      (def accepted (.o (:: @ base) reads: (list matching-read)
        reconciliations: (list (.o identity: 'accepted-state command: 'edit attempt: 'old aspect: 'task-acceptance))))
      (def result (recovery-observation-evaluate accepted))
      (check-equal? (has? (recovery-observation-rows result 'Obligation) '(edit task-acceptance)) #f)
      (check-equal? (has? (recovery-observation-rows result 'Unknown) '(edit historical-effect)) #t)
      (check-equal? (has? (recovery-observation-rows result 'Obligation) '(edit writer-reconciliation)) #t))
    (test-case "a file observation cannot invent a missing command identity"
      (def no-intent (.o (:: @ base) intents: '() reads: (list matching-read)))
      (check-equal? (rows no-intent 'CurrentContent) '())
      (check-equal? (rows no-intent 'ReceiptGap) '())
      (check-equal? (rows no-intent 'Obligation) '()))
    (test-case "another declared responsibility needs no new workflow rule"
      (def extended (.o (:: @ base) revision: 'extended
        requirements: (cons (.o command: 'edit aspect: 'review-port) (.ref base 'requirements))))
      (check-equal? (has? (rows extended 'Obligation) '(edit review-port)) #t)
      (def reviewed (.o (:: @ extended) revision: 'reviewed
        reconciliations: (list (.o identity: 'review command: 'edit attempt: 'old aspect: 'review-port))))
      (check-equal? (has? (rows reviewed 'Obligation) '(edit review-port)) #f)
      (check-equal? (has? (rows reviewed 'Unknown) '(edit historical-effect)) #t))
    (test-case "the model may add another hypothesis without changing the rule program"
      (def expanded (.o (:: @ base) hypotheses:
        (cons (.o command: 'edit identity: 'partial-edit question: 'inspect-remaining-files) (.ref base 'hypotheses))))
      (check-equal? (length (rows expanded 'Explore)) 3)) ))
