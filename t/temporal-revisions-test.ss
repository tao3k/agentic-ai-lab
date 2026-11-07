;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :clan/poo/object .ref)
        :std/test
        :agentic-ai-lab/modules/temporal-causality/interface)
(export temporal-revisions-test)

(def (instant id domain position (modality 'observed))
  (agentic-ai-lab-temporal-instant id domain position "ledger" modality))

(def (validity id lower upper)
  (agentic-ai-lab-temporal-interval
   id (instant (string-append id "/start") "valid" lower)
   (instant (string-append id "/end") "valid" upper) #t #f))

(def (assertion)
  (agentic-ai-lab-temporal-evidence-revision
   "r1" "subject" 'assert #f (instant "admit-1" "txn" 10)
   (validity "old" 1 5) "content-old"))

(def (correction id position)
  (agentic-ai-lab-temporal-evidence-revision
   id "subject" 'correct "r1" (instant id "txn" position)
   (validity id 2 6) (string-append "content-" id)))

(def temporal-revisions-test
  (test-suite "bitemporal evidence revisions"
    (yuanxu-test-case "late correction preserves the prior admission cut"
      (let* ((first (assertion))
             (fixed (correction "r2" 20))
             (early (agentic-ai-lab-temporal-evidence-journal
                     "history" "txn" (list first)))
             (full (agentic-ai-lab-temporal-evidence-journal
                    "history" "txn" (list fixed first)))
             (reordered (agentic-ai-lab-temporal-evidence-journal
                         "history" "txn" (list first fixed)))
             (as-of (instant "as-of-15" "txn" 15))
             (old (agentic-ai-lab-temporal-evidence-as-of
                   early as-of (instant "valid-3" "valid" 3)))
             (replayed (agentic-ai-lab-temporal-evidence-as-of
                        full as-of (instant "valid-3" "valid" 3)))
             (updated (agentic-ai-lab-temporal-evidence-as-of
                       full (instant "as-of-25" "txn" 25)
                       (instant "valid-3" "valid" 3))))
        (check (agentic-ai-lab-temporal-evidence-snapshot? old) => #t)
        (check (.ref old 'active-revision-identities) => '("r1"))
        (check (.ref updated 'active-revision-identities) => '("r2"))
        (check (.ref full 'semantic-digest)
               => (.ref reordered 'semantic-digest))
        (check (.ref replayed 'cut-digest) => (.ref old 'cut-digest))
        (check (.ref replayed 'projection-digest)
               => (.ref old 'projection-digest))
        (check (equal? (.ref early 'semantic-digest)
                       (.ref full 'semantic-digest)) => #f)
        (check (.ref replayed 'future-revision-identities) => '("r2"))))

    (yuanxu-test-case "valid time and admission time remain independent"
      (let* ((journal (agentic-ai-lab-temporal-evidence-journal
                       "history" "txn"
                       (list (assertion) (correction "r2" 20))))
             (outside (agentic-ai-lab-temporal-evidence-as-of
                       journal (instant "as-of-25" "txn" 25)
                       (instant "valid-1" "valid" 1)))
             (unknown (agentic-ai-lab-temporal-evidence-as-of
                       journal (instant "as-of-25" "txn" 25)
                       (instant "valid-declared" "valid" 3 'declared)))
             (incomparable (agentic-ai-lab-temporal-evidence-as-of
                            journal (instant "as-of-25" "txn" 25)
                            (instant "other-domain" "external" 3)))
             (reused-id-earlier (agentic-ai-lab-temporal-evidence-as-of
                                 journal (instant "as-of-25" "txn" 25)
                                 (instant "reused" "valid" 1)))
             (reused-id-later (agentic-ai-lab-temporal-evidence-as-of
                               journal (instant "as-of-25" "txn" 25)
                               (instant "reused" "valid" 3))))
        (check (.ref outside 'outside-valid-subject-identities)
               => '("subject"))
        (check (.ref unknown 'uncertain-subject-identities)
               => '("subject"))
        (check (.ref incomparable 'incomparable-subject-identities)
               => '("subject"))
        (check (.ref outside 'cut-digest) => (.ref unknown 'cut-digest))
        (check (equal? (.ref outside 'projection-digest)
                       (.ref unknown 'projection-digest)) => #f)
        (check (equal? (.ref unknown 'projection-digest)
                       (.ref incomparable 'projection-digest)) => #f)
        (check (.ref reused-id-earlier 'cut-digest)
               => (.ref reused-id-later 'cut-digest))
        (check (equal? (.ref reused-id-earlier 'valid-at-instant-digest)
                       (.ref reused-id-later 'valid-at-instant-digest)) => #f)
        (check (equal? (.ref reused-id-earlier 'projection-digest)
                       (.ref reused-id-later 'projection-digest)) => #f)))

    (yuanxu-test-case "retraction removes current applicability, not history"
      (let* ((withdrawal
              (agentic-ai-lab-temporal-evidence-revision
               "r3" "subject" 'retract "r2"
               (instant "admit-3" "txn" 30) #f #f))
             (journal (agentic-ai-lab-temporal-evidence-journal
                       "history" "txn"
                       (list withdrawal (correction "r2" 20) (assertion))))
             (before (agentic-ai-lab-temporal-evidence-as-of
                      journal (instant "as-of-25" "txn" 25) #f))
             (after (agentic-ai-lab-temporal-evidence-as-of
                     journal (instant "as-of-35" "txn" 35) #f)))
        (check (.ref before 'active-revision-identities) => '("r2"))
        (check (.ref after 'active-revision-identities) => '())
        (check (.ref after 'retracted-subject-identities) => '("subject"))
        (check (.ref after 'visible-revision-identities)
               => '("r1" "r2" "r3"))))

    (yuanxu-test-case "concurrent corrections expose conflict"
      (let* ((journal (agentic-ai-lab-temporal-evidence-journal
                       "branched" "txn"
                       (list (assertion) (correction "r2" 20)
                             (correction "r3" 22))))
             (receipt (agentic-ai-lab-temporal-evidence-as-of
                       journal (instant "as-of-25" "txn" 25) #f)))
        (check (.ref receipt 'conflicted-subject-identities)
               => '("subject"))
        (check (.ref receipt 'active-revision-identities) => '())))

    (yuanxu-test-case "predecessor and admission clock are checked"
      (let* ((valid (agentic-ai-lab-temporal-evidence-journal
                     "valid" "txn" (list (assertion))))
             (forged (agentic-ai-lab-temporal-evidence-journal-value
                      "valid" "sha256:wrong" "txn" (.ref valid 'revisions))))
        (check-exception
         (agentic-ai-lab-temporal-evidence-as-of
          forged (instant "as-of-15" "txn" 15) #f) true))
      (check-exception
       (agentic-ai-lab-temporal-evidence-journal
        "missing" "txn" (list (correction "r2" 20))) true)
      (check-exception
       (agentic-ai-lab-temporal-evidence-journal
        "backward" "txn"
        (list (assertion) (correction "r2" 9))) true)
      (check-exception
       (agentic-ai-lab-temporal-evidence-journal
        "wrong-clock" "txn"
        (list
         (agentic-ai-lab-temporal-evidence-revision
          "other" "subject" 'assert #f
          (instant "other-clock" "external" 10)
          (validity "other" 1 5) "content"))) true))))
