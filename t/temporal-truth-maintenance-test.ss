;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :clan/poo/object .ref)
        :std/test
        :poo-flow/modules/temporal-causality/interface)
(export temporal-truth-maintenance-test)

(def (derived id subjects conclusions)
  (poo-flow-temporal-derivation
   id "cut-1" "projection-1" "policy-1" subjects conclusions))

(def (instant id position)
  (poo-flow-temporal-instant id "txn" position "ledger" 'observed))

(def (validity)
  (poo-flow-temporal-interval
   "validity"
   (poo-flow-temporal-instant "start" "valid" 1 "ledger" 'observed)
   (poo-flow-temporal-instant "end" "valid" 10 "ledger" 'observed)
   #t #f))

(def temporal-truth-maintenance-test
  (test-suite "temporal reverse dependency planning"
    (yuanxu-test-case "changed evidence reaches downstream conclusions only"
      (let* ((index (poo-flow-temporal-dependency-index
                     "index-1" "cut-1" "projection-1" #t
                     (list (derived "dose" '("prescription") '())
                           (derived "alert" '() '("dose"))
                           (derived "audit" '() '("alert"))
                           (derived "release" '("deployment") '()))))
             (reordered (poo-flow-temporal-dependency-index
                         "index-1" "cut-1" "projection-1" #t
                         (list (derived "release" '("deployment") '())
                               (derived "audit" '() '("alert"))
                               (derived "dose" '("prescription") '())
                               (derived "alert" '() '("dose")))))
             (plan (poo-flow-temporal-reverse-dependency-plan
                    index "cut-2" "projection-2" '("prescription"))))
        (check (poo-flow-temporal-invalidation-plan? plan) => #t)
        (check (.ref plan 'affected-conclusion-identities)
               => '("alert" "audit" "dose"))
        (check (.ref plan 'scheduled-for-reevaluation-identities)
               => (.ref plan 'affected-conclusion-identities))
        (check (.ref plan 'index-digest) => (.ref index 'semantic-digest))
        (check (.ref index 'semantic-digest)
               => (.ref reordered 'semantic-digest))
        (check (.ref plan 'status) => 'scoped-complete)
        (check (.ref plan 'trigger) => 'premise-delta)
        (check (.ref plan 'runtime-executed?) => #f)))

    (yuanxu-test-case "cycles terminate and partial inventory does not certify absence"
      (let* ((index (poo-flow-temporal-dependency-index
                     "partial" "cut-1" "projection-1" #f
                     (list (derived "a" '("event") '("b"))
                           (derived "b" '() '("a")))))
             (hit (poo-flow-temporal-reverse-dependency-plan
                   index "cut-2" "projection-2" '("event")))
             (miss (poo-flow-temporal-reverse-dependency-plan
                    index "cut-2" "projection-2" '("unindexed"))))
        (check (.ref hit 'affected-conclusion-identities) => '("a" "b"))
        (check (.ref miss 'affected-conclusion-identities) => '())
        (check (.ref miss 'status) => 'partial)))

    (yuanxu-test-case "journal cuts supply changed subjects to the index"
      (let* ((first (poo-flow-temporal-evidence-revision
                     "r1" "subject" 'assert #f (instant "admit-1" 10)
                     (validity) "old"))
             (other (poo-flow-temporal-evidence-revision
                     "o1" "other" 'assert #f (instant "admit-o" 10)
                     (validity) "unrelated"))
             (fixed (poo-flow-temporal-evidence-revision
                     "r2" "subject" 'correct "r1" (instant "admit-2" 20)
                     (validity) "new"))
             (journal (poo-flow-temporal-evidence-journal
                       "journal" "txn" (list fixed other first)))
             (before (poo-flow-temporal-evidence-as-of
                      journal (instant "cut-15" 15) #f))
             (after (poo-flow-temporal-evidence-as-of
                     journal (instant "cut-25" 25) #f))
             (index (poo-flow-temporal-dependency-index
                     "index" (.ref before 'cut-digest)
                     (.ref before 'projection-digest) #t
                     (list (poo-flow-temporal-derivation
                            "dependent" (.ref before 'cut-digest)
                            (.ref before 'projection-digest) "policy"
                            '("subject") '())
                           (poo-flow-temporal-derivation
                            "independent" (.ref before 'cut-digest)
                            (.ref before 'projection-digest) "policy"
                            '("other") '()))))
             (plan (poo-flow-temporal-reverse-dependency-plan-from-cuts
                    index journal (instant "cut-15" 15)
                    (instant "cut-25" 25) #f)))
        (check (.ref plan 'changed-subject-identities) => '("subject"))
        (check (.ref plan 'affected-conclusion-identities) => '("dependent"))
        (check (.ref plan 'previous-cut-digest) => (.ref before 'cut-digest))
        (check (.ref plan 'revised-cut-digest) => (.ref after 'cut-digest))
        (check (.ref plan 'previous-projection-digest)
               => (.ref before 'projection-digest))
        (check (.ref plan 'revised-projection-digest)
               => (.ref after 'projection-digest))
        (check-exception
         (poo-flow-temporal-reverse-dependency-plan-from-cuts
          index journal (instant "cut-25" 25)
          (instant "cut-15" 15) #f) true)
        (check-exception
         (poo-flow-temporal-reverse-dependency-plan-from-cuts
          index journal before after #f) true)))

    (yuanxu-test-case "valid-time change reprojects every indexed derivation"
      (let* ((journal (poo-flow-temporal-evidence-journal
                       "journal" "txn"
                       (list (poo-flow-temporal-evidence-revision
                              "r1" "subject" 'assert #f
                              (instant "admit-1" 10) (validity) "content"))))
             (cut (instant "cut" 15))
             (valid-3 (poo-flow-temporal-instant
                       "valid-same-id" "valid" 3 "ledger" 'observed))
             (valid-4 (poo-flow-temporal-instant
                       "valid-same-id" "valid" 4 "ledger" 'observed))
             (prior (poo-flow-temporal-evidence-as-of
                     journal cut valid-3))
             (revised (poo-flow-temporal-evidence-as-of
                       journal cut valid-4))
             (index (poo-flow-temporal-dependency-index
                     "index" (.ref prior 'cut-digest)
                     (.ref prior 'projection-digest) #t
                     (list (poo-flow-temporal-derivation
                            "direct" (.ref prior 'cut-digest)
                            (.ref prior 'projection-digest) "policy"
                            '("subject") '())
                           (poo-flow-temporal-derivation
                            "parameter-only" (.ref prior 'cut-digest)
                            (.ref prior 'projection-digest) "policy"
                            '() '()))))
             (plan (poo-flow-temporal-reverse-dependency-plan-from-projections
                    index journal cut valid-3 valid-4)))
        (check (.ref prior 'active-revision-identities)
               => (.ref revised 'active-revision-identities))
        (check (.ref prior 'cut-digest) => (.ref revised 'cut-digest))
        (check (.ref plan 'changed-subject-identities) => '())
        (check (.ref plan 'affected-conclusion-identities)
               => '("direct" "parameter-only"))
        (check (.ref plan 'trigger) => 'valid-time-reprojection)
        (check-exception
         (poo-flow-temporal-reverse-dependency-plan-from-projections
          index journal cut valid-3 valid-3) true)
        (check-exception
         (poo-flow-temporal-reverse-dependency-plan-from-projections
          index journal cut valid-4 valid-3) true)
        (check-exception
         (poo-flow-temporal-reverse-dependency-plan-from-projections
          index journal prior revised valid-4) true)))

    (yuanxu-test-case "cut and premise inventories are validated"
      (check-exception
       (poo-flow-temporal-dependency-index
        "bad-cut" "cut-1" "projection-1" #t
        (list (poo-flow-temporal-derivation
               "a" "cut-other" "projection-1" "policy"
               '("event") '()))) true)
      (check-exception
       (poo-flow-temporal-dependency-index
        "bad-projection" "cut-1" "projection-1" #t
        (list (poo-flow-temporal-derivation
               "a" "cut-1" "projection-other" "policy"
               '("event") '()))) true)
      (check-exception
       (poo-flow-temporal-dependency-index
        "missing-parent" "cut-1" "projection-1" #t
        (list (derived "a" '() '("unknown")))) true)
      (check-exception
       (poo-flow-temporal-dependency-index
        "duplicate" "cut-1" "projection-1" #t
        (list (derived "a" '() '()) (derived "a" '() '()))) true)
      (check-exception
       (poo-flow-temporal-reverse-dependency-plan
        (poo-flow-temporal-dependency-index
         "valid" "cut-1" "projection-1" #t
         (list (derived "a" '("event") '())))
        "cut-1" "projection-1" '("event")) true))))
