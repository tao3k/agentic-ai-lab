;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :clan/poo/object .ref)
        :std/test
        :poo-flow/modules/temporal-causality/interface)
(export temporal-conclusions-test)

(def (root)
  (poo-flow-temporal-conclusion-root
   "c1" "patient-7" "prescription" "cut-1" "projection-1"
   "policy-1" "generation-1"
   "dose-10" "proof-1"))

(def (impact complete? changed?)
  (let* ((index (poo-flow-temporal-dependency-index
                 "dependencies" "cut-1" "projection-1" complete?
                 (list (poo-flow-temporal-derivation
                        "c1" "cut-1" "projection-1" "policy-1"
                        '("prescription-event") '()))))
         (changed (if changed? '("prescription-event") '("other-event"))))
    (poo-flow-temporal-reverse-dependency-plan
     index "cut-2" "projection-2" changed)))

(def temporal-conclusions-test
  (test-suite "immutable temporal conclusions and selection planning"
    (yuanxu-test-case "correction and retraction preserve a branched history"
      (let* ((prior (root))
             (plan (impact #t #t))
             (corrected (poo-flow-temporal-conclusion-change
                         "c2" prior plan 'correct "dose-8" "proof-2"
                         "policy-1" "generation-2"))
             (retracted (poo-flow-temporal-conclusion-change
                         "c3" prior plan 'retract #f "retraction-proof-3"
                         "policy-1" "generation-3"))
             (first-journal (poo-flow-temporal-conclusion-journal
                             "history" (list prior)))
             (journal (poo-flow-temporal-conclusion-journal-extend
                       first-journal (list retracted corrected)))
             (reordered (poo-flow-temporal-conclusion-journal
                         "history" (list corrected retracted prior))))
        (check (poo-flow-temporal-conclusion-journal? journal) => #t)
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
        (check (.ref (poo-flow-temporal-conclusion-journal-replay journal)
                     'semantic-digest)
               => (.ref journal 'semantic-digest))
        (let (forged
              (poo-flow-temporal-conclusion-journal-value
               "history" (.ref journal 'semantic-digest)
               (list prior corrected)))
          (check (poo-flow-temporal-conclusion-journal? forged) => #t)
          (check-exception
           (poo-flow-temporal-conclusion-journal-replay forged) true)
          (check-exception
           (poo-flow-temporal-conclusion-journal-extend forged
                                                        (list retracted)) true)
          (check-exception
           (poo-flow-temporal-selection-prepare
            forged corrected
            (poo-flow-temporal-selection-observation
             "observation-7" "patient-7" "prescription" 7 "c1") 7)
           true))))

    (yuanxu-test-case "valid-time reprojection creates a new conclusion version"
      (let* ((validity
              (poo-flow-temporal-interval
               "window"
               (poo-flow-temporal-instant "start" "valid" 1 "ledger" 'observed)
               (poo-flow-temporal-instant "end" "valid" 10 "ledger" 'observed)
               #t #f))
             (journal (poo-flow-temporal-evidence-journal
                       "evidence" "txn"
                       (list (poo-flow-temporal-evidence-revision
                              "r1" "prescription-event" 'assert #f
                              (poo-flow-temporal-instant
                               "admit" "txn" 1 "ledger" 'observed)
                              validity "content"))))
             (cut (poo-flow-temporal-instant
                   "cut" "txn" 2 "ledger" 'observed))
             (valid-3 (poo-flow-temporal-instant
                       "query" "valid" 3 "ledger" 'observed))
             (valid-4 (poo-flow-temporal-instant
                       "query" "valid" 4 "ledger" 'observed))
             (before (poo-flow-temporal-evidence-as-of
                      journal cut valid-3))
             (after (poo-flow-temporal-evidence-as-of
                     journal cut valid-4))
             (prior (poo-flow-temporal-conclusion-root
                     "c1" "patient-7" "prescription"
                     (.ref before 'cut-digest) (.ref before 'projection-digest)
                     "policy-1" "generation-1" "dose-10" "proof-1"))
             (index (poo-flow-temporal-dependency-index
                     "index" (.ref before 'cut-digest)
                     (.ref before 'projection-digest) #t
                     (list (poo-flow-temporal-derivation
                            "c1" (.ref before 'cut-digest)
                            (.ref before 'projection-digest) "policy-1"
                            '("prescription-event") '()))))
             (plan (poo-flow-temporal-reverse-dependency-plan-from-projections
                    index journal cut valid-3 valid-4))
             (next (poo-flow-temporal-conclusion-change
                    "c2" prior plan 'correct "dose-10" "proof-2"
                    "policy-1" "generation-2"))
             (history (poo-flow-temporal-conclusion-journal
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
             (corrected (poo-flow-temporal-conclusion-change
                         "c2" prior plan 'correct "dose-8" "proof-2"
                         "policy-1" "generation-2"))
             (retracted (poo-flow-temporal-conclusion-change
                         "c3" prior plan 'retract #f "proof-3"
                         "policy-1" "generation-3"))
             (journal (poo-flow-temporal-conclusion-journal
                       "history" (list prior corrected retracted)))
             (observed (poo-flow-temporal-selection-observation
                        "observation-7" "patient-7" "prescription" 7 "c1"))
             (correction-plan (poo-flow-temporal-selection-prepare
                               journal corrected observed 7))
             (retraction-plan (poo-flow-temporal-selection-prepare
                               journal retracted observed 7))
             (after-race (poo-flow-temporal-selection-observation
                          "observation-8" "patient-7" "prescription" 8 "c2"))
             (stale (poo-flow-temporal-selection-prepare
                     journal retracted after-race 7)))
        (check (.ref correction-plan 'status) => 'cas-ready)
        (check (.ref correction-plan 'proposed-version) => 8)
        (check (.ref (poo-flow-temporal-selection-plan-replay
                     correction-plan journal corrected observed) 'status)
               => 'cas-ready)
        (check (.ref retraction-plan 'proposed-revision-identity) => "c3")
        (check (.ref stale 'status) => 'conflict)
        (check (.ref stale 'observed-version) => 8)
        (check (.ref stale 'observed-revision-identity) => "c2")
        (check (.ref stale 'proposed-version) => #f)
        (check (.ref stale 'runtime-executed?) => #f)
        (check-exception
         (poo-flow-temporal-selection-plan-replay
          correction-plan journal corrected after-race) true)
        (check-exception
         (poo-flow-temporal-selection-plan-replay
          correction-plan journal retracted observed) true)
        (check-exception
         (poo-flow-temporal-selection-plan-replay
          (poo-flow-temporal-selection-plan-value
           "forged-journal-digest" "observation-7" "patient-7"
           "prescription" 7 "c1" 8 7 "c1" "c2" "proof-2"
           'cas-ready)
          journal corrected observed) true)
        (check-exception
         (poo-flow-temporal-selection-prepare
          journal
          (poo-flow-temporal-conclusion-revision-value
           "c2" "patient-7" "prescription" "cut-2" "projection-2"
           "policy-1"
           "generation-2" 'correct "c1" "counterfeit-result"
           "proof-2" (.ref plan 'index-digest))
          observed 7) true)))

    (yuanxu-test-case "incomplete or unaffected frontier cannot change a conclusion"
      (check-exception
       (poo-flow-temporal-conclusion-change
        "c2" (root) (impact #f #t) 'correct "dose-8" "proof-2"
        "policy-1" "generation-2") true)
      (check-exception
       (poo-flow-temporal-conclusion-change
        "c2" (root) (impact #t #f) 'retract #f "proof-2"
        "policy-1" "generation-2") true)
      (check-exception
       (poo-flow-temporal-conclusion-change
        "c2"
        (poo-flow-temporal-conclusion-root
         "c1" "patient-7" "prescription" "cut-1" "projection-other"
         "policy-1" "generation-1" "dose-10" "proof-1")
        (impact #t #t) 'correct "dose-8" "proof-2"
        "policy-1" "generation-2") true))

    (yuanxu-test-case "journal rejects missing and cyclic supersession"
      (check-exception
       (poo-flow-temporal-conclusion-journal
        "missing" (list
                   (poo-flow-temporal-conclusion-revision-value
                    "orphan" "patient-7" "prescription" "cut-2"
                    "projection-2"
                    "policy" "generation" 'correct "absent" "dose-8"
                    "proof" "index"))) true)
      (check-exception
       (poo-flow-temporal-conclusion-journal
        "cycle"
        (list (poo-flow-temporal-conclusion-revision-value
               "a" "patient-7" "prescription" "cut-a" "projection-a"
               "policy"
               "generation" 'correct "b" "dose-a" "proof-a" "index")
              (poo-flow-temporal-conclusion-revision-value
               "b" "patient-7" "prescription" "cut-b" "projection-b"
               "policy"
               "generation" 'correct "a" "dose-b" "proof-b" "index"))) true))))
