;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :clan/poo/object .ref)
        :std/test
        :agentic-ai-lab/modules/temporal-causality/interface)
(export temporal-conclusions-test)

(def (root)
  (agentic-ai-lab-temporal-conclusion-root
   "c1" "patient-7" "prescription" "cut-1" "projection-1"
   "policy-1" "generation-1"
   "dose-10" "proof-1"))

(def (impact complete? changed?)
  (let* ((index (agentic-ai-lab-temporal-dependency-index
                 "dependencies" "cut-1" "projection-1" complete?
                 (list (agentic-ai-lab-temporal-derivation
                        "c1" "cut-1" "projection-1" "policy-1"
                        '("prescription-event") '()))))
         (changed (if changed? '("prescription-event") '("other-event"))))
    (agentic-ai-lab-temporal-reverse-dependency-plan
     index "cut-2" "projection-2" changed)))

(def temporal-conclusions-test
  (test-suite "immutable temporal conclusions and selection planning"
    (yuanxu-test-case "correction and retraction preserve a branched history"
      (let* ((prior (root))
             (plan (impact #t #t))
             (corrected (agentic-ai-lab-temporal-conclusion-change
                         "c2" prior plan 'correct "dose-8" "proof-2"
                         "policy-1" "generation-2"))
             (retracted (agentic-ai-lab-temporal-conclusion-change
                         "c3" prior plan 'retract #f "retraction-proof-3"
                         "policy-1" "generation-3"))
             (first-journal (agentic-ai-lab-temporal-conclusion-journal
                             "history" (list prior)))
             (journal (agentic-ai-lab-temporal-conclusion-journal-extend
                       first-journal (list retracted corrected)))
             (reordered (agentic-ai-lab-temporal-conclusion-journal
                         "history" (list corrected retracted prior))))
        (check (agentic-ai-lab-temporal-conclusion-journal? journal) => #t)
        (check (.ref prior 'result-identity) => "dose-10")
        (check (.ref prior 'cut-digest) => "cut-1")
        (check (.ref prior 'projection-digest) => "projection-1")
        (check (.ref corrected 'predecessor-identity) => "c1")
        (check (.ref corrected 'cut-digest) => "cut-2")
        (check (.ref corrected 'projection-digest) => "projection-2")
        (check (.ref retracted 'result-identity) => #f)
        (check (.ref retracted 'proof-identity) => "retraction-proof-3")
        (check (length (.ref first-journal 'revisions)) => 1)
        (check (length (.ref journal 'revisions)) => 3)
        (check (equal? (.ref first-journal 'semantic-digest)
                       (.ref journal 'semantic-digest)) => #f)
        (check (.ref journal 'semantic-digest)
               => (.ref reordered 'semantic-digest))
        (check (.ref (agentic-ai-lab-temporal-conclusion-journal-replay journal)
                     'semantic-digest)
               => (.ref journal 'semantic-digest))
        (let (forged
              (agentic-ai-lab-temporal-conclusion-journal-value
               "history" (.ref journal 'semantic-digest)
               (list prior corrected)))
          (check (agentic-ai-lab-temporal-conclusion-journal? forged) => #t)
          (check-exception
           (agentic-ai-lab-temporal-conclusion-journal-replay forged) true)
          (check-exception
           (agentic-ai-lab-temporal-conclusion-journal-extend forged
                                                        (list retracted)) true)
          (check-exception
           (agentic-ai-lab-temporal-selection-prepare
            forged corrected
            (agentic-ai-lab-temporal-selection-observation
             "observation-7" "patient-7" "prescription" 7 "c1") 7)
           true))))

    (yuanxu-test-case "valid-time reprojection creates a new conclusion version"
      (let* ((validity
              (agentic-ai-lab-temporal-interval
               "window"
               (agentic-ai-lab-temporal-instant "start" "valid" 1 "ledger" 'observed)
               (agentic-ai-lab-temporal-instant "end" "valid" 10 "ledger" 'observed)
               #t #f))
             (journal (agentic-ai-lab-temporal-evidence-journal
                       "evidence" "txn"
                       (list (agentic-ai-lab-temporal-evidence-revision
                              "r1" "prescription-event" 'assert #f
                              (agentic-ai-lab-temporal-instant
                               "admit" "txn" 1 "ledger" 'observed)
                              validity "content"))))
             (cut (agentic-ai-lab-temporal-instant
                   "cut" "txn" 2 "ledger" 'observed))
             (valid-3 (agentic-ai-lab-temporal-instant
                       "query" "valid" 3 "ledger" 'observed))
             (valid-4 (agentic-ai-lab-temporal-instant
                       "query" "valid" 4 "ledger" 'observed))
             (before (agentic-ai-lab-temporal-evidence-as-of
                      journal cut valid-3))
             (after (agentic-ai-lab-temporal-evidence-as-of
                     journal cut valid-4))
             (prior (agentic-ai-lab-temporal-conclusion-root
                     "c1" "patient-7" "prescription"
                     (.ref before 'cut-digest) (.ref before 'projection-digest)
                     "policy-1" "generation-1" "dose-10" "proof-1"))
             (index (agentic-ai-lab-temporal-dependency-index
                     "index" (.ref before 'cut-digest)
                     (.ref before 'projection-digest) #t
                     (list (agentic-ai-lab-temporal-derivation
                            "c1" (.ref before 'cut-digest)
                            (.ref before 'projection-digest) "policy-1"
                            '("prescription-event") '()))))
             (plan (agentic-ai-lab-temporal-reverse-dependency-plan-from-projections
                    index journal cut valid-3 valid-4))
             (next (agentic-ai-lab-temporal-conclusion-change
                    "c2" prior plan 'correct "dose-10" "proof-2"
                    "policy-1" "generation-2"))
             (history (agentic-ai-lab-temporal-conclusion-journal
                       "history" (list prior next))))
        (check (.ref before 'active-revision-identities)
               => (.ref after 'active-revision-identities))
        (check (.ref next 'cut-digest) => (.ref prior 'cut-digest))
        (check (.ref next 'projection-digest) => (.ref after 'projection-digest))
        (check (.ref next 'predecessor-identity) => "c1")
        (check (length (.ref history 'revisions)) => 2)))

    (yuanxu-test-case "CAS plans expose a stale pointer without publishing"
      (let* ((prior (root))
             (plan (impact #t #t))
             (corrected (agentic-ai-lab-temporal-conclusion-change
                         "c2" prior plan 'correct "dose-8" "proof-2"
                         "policy-1" "generation-2"))
             (retracted (agentic-ai-lab-temporal-conclusion-change
                         "c3" prior plan 'retract #f "proof-3"
                         "policy-1" "generation-3"))
             (journal (agentic-ai-lab-temporal-conclusion-journal
                       "history" (list prior corrected retracted)))
             (observed (agentic-ai-lab-temporal-selection-observation
                        "observation-7" "patient-7" "prescription" 7 "c1"))
             (correction-plan (agentic-ai-lab-temporal-selection-prepare
                               journal corrected observed 7))
             (retraction-plan (agentic-ai-lab-temporal-selection-prepare
                               journal retracted observed 7))
             (after-race (agentic-ai-lab-temporal-selection-observation
                          "observation-8" "patient-7" "prescription" 8 "c2"))
             (stale (agentic-ai-lab-temporal-selection-prepare
                     journal retracted after-race 7)))
        (check (.ref correction-plan 'status) => 'cas-ready)
        (check (.ref correction-plan 'proposed-version) => 8)
        (check (.ref (agentic-ai-lab-temporal-selection-plan-replay
                     correction-plan journal corrected observed) 'status)
               => 'cas-ready)
        (check (.ref retraction-plan 'proposed-revision-identity) => "c3")
        (check (.ref stale 'status) => 'conflict)
        (check (.ref stale 'observed-version) => 8)
        (check (.ref stale 'observed-revision-identity) => "c2")
        (check (.ref stale 'proposed-version) => #f)
        (check (.ref stale 'runtime-executed?) => #f)
        (check-exception
         (agentic-ai-lab-temporal-selection-plan-replay
          correction-plan journal corrected after-race) true)
        (check-exception
         (agentic-ai-lab-temporal-selection-plan-replay
          correction-plan journal retracted observed) true)
        (check-exception
         (agentic-ai-lab-temporal-selection-plan-replay
          (agentic-ai-lab-temporal-selection-plan-value
           "forged-journal-digest" "observation-7" "patient-7"
           "prescription" 7 "c1" 8 7 "c1" "c2" "proof-2"
           'cas-ready)
          journal corrected observed) true)
        (check-exception
         (agentic-ai-lab-temporal-selection-prepare
          journal
          (agentic-ai-lab-temporal-conclusion-revision-value
           "c2" "patient-7" "prescription" "cut-2" "projection-2"
           "policy-1"
           "generation-2" 'correct "c1" "counterfeit-result"
           "proof-2" (.ref plan 'index-digest))
          observed 7) true)))

    (yuanxu-test-case "incomplete or unaffected frontier cannot change a conclusion"
      (check-exception
       (agentic-ai-lab-temporal-conclusion-change
        "c2" (root) (impact #f #t) 'correct "dose-8" "proof-2"
        "policy-1" "generation-2") true)
      (check-exception
       (agentic-ai-lab-temporal-conclusion-change
        "c2" (root) (impact #t #f) 'retract #f "proof-2"
        "policy-1" "generation-2") true)
      (check-exception
       (agentic-ai-lab-temporal-conclusion-change
        "c2"
        (agentic-ai-lab-temporal-conclusion-root
         "c1" "patient-7" "prescription" "cut-1" "projection-other"
         "policy-1" "generation-1" "dose-10" "proof-1")
        (impact #t #t) 'correct "dose-8" "proof-2"
        "policy-1" "generation-2") true))

    (yuanxu-test-case "journal rejects missing and cyclic supersession"
      (check-exception
       (agentic-ai-lab-temporal-conclusion-journal
        "missing" (list
                   (agentic-ai-lab-temporal-conclusion-revision-value
                    "orphan" "patient-7" "prescription" "cut-2"
                    "projection-2"
                    "policy" "generation" 'correct "absent" "dose-8"
                    "proof" "index"))) true)
      (check-exception
       (agentic-ai-lab-temporal-conclusion-journal
        "cycle"
        (list (agentic-ai-lab-temporal-conclusion-revision-value
               "a" "patient-7" "prescription" "cut-a" "projection-a"
               "policy"
               "generation" 'correct "b" "dose-a" "proof-a" "index")
              (agentic-ai-lab-temporal-conclusion-revision-value
               "b" "patient-7" "prescription" "cut-b" "projection-b"
               "policy"
               "generation" 'correct "a" "dose-b" "proof-b" "index"))) true))))
