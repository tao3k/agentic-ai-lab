;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :std/test test-suite test-case check-equal?)
        (only-in :clan/poo/object .o .ref .get)
        (only-in "../dev/d2/init.ss" tao3k/agentic-ai-lab/dev/d2.init.exports))
(def ContextProfile (.get tao3k/agentic-ai-lab/dev/d2.init.exports modules d2 profiles ContextEvolution))
(def ExperienceWindow. (.get ContextProfile Window))
(def context-evolution-evaluate (.get ContextProfile evaluate))
(def context-evolution-rows (.get ContextProfile rows))
(include "../dev/d2/context-evolution-example.ss")
(export context-window-ascent-test)

(def (contains-row? result relation row)
  (if (member row (context-evolution-rows result relation)) #t #f))

(def context-window-ascent-test
  (test-suite "ASCENT Scheme Context windows"
    (test-case "a late observation cannot be known in an earlier cut"
      (let (result (context-evolution-evaluate (context-evolution-example)))
        (check-equal? (contains-row? result 'Member '(early r1 clean-run)) #t)
        (check-equal? (contains-row? result 'Member '(early r1 counterexample)) #f)
        (check-equal? (contains-row? result 'Member '(later r1 counterexample)) #t)
        (check-equal? (contains-row? result 'KnowledgeCandidate '(early r1 diagnostic-method)) #t)
        (check-equal? (contains-row? result 'KnowledgeCandidate '(later r1 diagnostic-method)) #f)))
    (test-case "contrary evidence preserves both competing hypotheses"
      (let (result (context-evolution-evaluate (context-evolution-example)))
        (check-equal? (contains-row? result 'Conflicted '(later r1 stale-inputs)) #t)
        (check-equal? (contains-row? result 'Support '(later r1 compiler-abi counterexample)) #t)
        (check-equal? (contains-row? result 'Support '(later r1 stale-inputs clean-run)) #t)
        (check-equal? (contains-row? result 'VisualEdge '(later r1 counterexample stale-inputs contradicts)) #t)))
    (test-case "recursive impact changes applicability without erasing membership"
      (let* ((base (context-evolution-example))
             (before (context-evolution-evaluate base))
             (after (context-evolution-evaluate
                     (.o (:: @ base) changes: (list (.o identity: 'clean-run))))))
        (check-equal? (contains-row? after 'Affected '(diagnostic-method)) #t)
        (check-equal? (contains-row? after 'Member '(early r1 clean-run)) #t)
        (check-equal? (contains-row? after 'Usable '(early r1 clean-run)) #f)
        (check-equal? (contains-row? after 'KnowledgeCandidate '(early r1 diagnostic-method)) #f)
        (check-equal? (contains-row? before 'KnowledgeCandidate '(early r1 diagnostic-method)) #t)))
    (test-case "unknown requirement inventory cannot produce a knowledge candidate"
      (let* ((base (context-evolution-example))
             (result (context-evolution-evaluate (.o (:: @ base) complete-inventories: '()))))
        (check-equal? (context-evolution-rows result 'KnowledgeCandidate) '())))
    (test-case "old source cuts remain historical but cannot satisfy current obligations"
      (let* ((base (context-evolution-example))
             (result (context-evolution-evaluate
                      (.o (:: @ base) current-cuts: (list (.o scope: 'project cut: 'source-v2))))))
        (check-equal? (contains-row? result 'Member '(early r1 clean-run)) #t)
        (check-equal? (context-evolution-rows result 'Support) '())
        (check-equal? (context-evolution-rows result 'KnowledgeCandidate) '())))
    (test-case "a model can add a new hypothesis without changing the rules"
      (let* ((base (context-evolution-example))
             (extended (.o (:: @ base)
                         hypotheses: (cons (.o identity: 'new-model-idea scope: 'project)
                                           (.ref base 'hypotheses))
                         supports: (cons (.o evidence: 'counterexample hypothesis: 'new-model-idea)
                                         (.ref base 'supports))))
             (result (context-evolution-evaluate extended)))
        (check-equal? (contains-row? result 'Support '(later r1 new-model-idea counterexample)) #t)
        (check-equal? (contains-row? result 'Support '(later r1 compiler-abi counterexample)) #t)
        (check-equal? (contains-row? result 'Conflicted '(later r1 stale-inputs)) #t)))))
