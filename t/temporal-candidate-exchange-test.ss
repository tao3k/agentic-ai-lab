;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :clan/poo/object .ref)
        :std/test
        :agentic-ai-lab/modules/temporal-causality/candidates/interface)
(export temporal-candidate-exchange-test)

(def (scope generation coverage)
  (agentic-ai-lab-candidate-scope
   "scope" "sha256:cut" generation coverage '(gql ascent)))
(def (receipt id candidate scope provider complete?)
  (agentic-ai-lab-candidate-receipt
   id candidate scope provider (string-append "sha256:request/" id)
   (string-append "sha256:provider/" id)
   (string-append "sha256:result/" id) 2 complete?))
(def (check-receipt id receipt verdict)
  (agentic-ai-lab-candidate-check
   id receipt (string-append "verifier/" id) verdict
   (string-append "sha256:basis/" id)))

(def temporal-candidate-exchange-test
  (test-suite "candidate exchange binds cut, provider and separate checks"
    (yuanxu-test-case "complete declared receipts are reviewable, never admitted"
      (let* ((cut (scope 1 "sha256:coverage"))
             (gql (receipt "g" "candidate" cut 'gql #t))
             (ascent (receipt "a" "candidate" cut 'ascent #t))
             (gql-check (check-receipt "gc" gql 'valid))
             (ascent-check (check-receipt "ac" ascent 'valid))
             (first (agentic-ai-lab-candidate-exchange
                     "x" "candidate" cut (list gql ascent)
                     (list gql-check ascent-check)))
             (reordered (agentic-ai-lab-candidate-exchange
                         "x" "candidate" cut (list ascent gql)
                         (list ascent-check gql-check))))
        (check (.ref first 'status) => 'reviewable)
        (check (.ref first 'admitted?) => #f)
        (check (.ref first 'missing-providers) => '())
        (check (.ref first 'semantic-digest)
               => (.ref reordered 'semantic-digest))))

    (yuanxu-test-case "revision retires otherwise complete receipts"
      (let* ((old (scope 1 "sha256:coverage"))
             (new (scope 2 "sha256:coverage"))
             (gql (receipt "g" "candidate" old 'gql #t))
             (ascent (receipt "a" "candidate" old 'ascent #t))
             (exchange (agentic-ai-lab-candidate-exchange
                        "x" "candidate" new (list gql ascent)
                        (list (check-receipt "gc" gql 'valid)
                              (check-receipt "ac" ascent 'valid)))))
        (check (.ref exchange 'status) => 'pending)
        (check (.ref exchange 'stale-receipts) => '("a" "g"))
        (check (.ref exchange 'missing-providers) => '(ascent gql))))

    (yuanxu-test-case "missing coverage, provider, completion and check stay pending"
      (let* ((cut (scope 1 #f))
             (gql (receipt "g" "candidate" cut 'gql #f))
             (exchange (agentic-ai-lab-candidate-exchange
                        "x" "candidate" cut (list gql) '())))
        (check (.ref exchange 'status) => 'pending)
        (check (.ref exchange 'missing-providers) => '(ascent))
        (check (.ref exchange 'incomplete-receipts) => '("g"))
        (check (.ref exchange 'unchecked-receipts) => '("g"))))

    (yuanxu-test-case "coverage and unknown verdict each block an otherwise complete handoff"
      (let* ((cut (scope 1 #f))
             (gql (receipt "g" "candidate" cut 'gql #t))
             (ascent (receipt "a" "candidate" cut 'ascent #t))
             (gql-valid (check-receipt "gv" gql 'valid))
             (ascent-valid (check-receipt "av" ascent 'valid))
             (no-coverage (agentic-ai-lab-candidate-exchange
                           "x" "candidate" cut (list gql ascent)
                           (list gql-valid ascent-valid)))
             (with-coverage (scope 1 "sha256:coverage"))
             (gql-current (receipt "gc" "candidate" with-coverage 'gql #t))
             (ascent-current (receipt "ac" "candidate" with-coverage
                                      'ascent #t))
             (unknown (agentic-ai-lab-candidate-exchange
                       "y" "candidate" with-coverage
                       (list gql-current ascent-current)
                       (list (check-receipt "gcv" gql-current 'valid)
                             (check-receipt "acu" ascent-current 'unknown)))))
        (check (.ref no-coverage 'status) => 'pending)
        (check (.ref no-coverage 'missing-providers) => '())
        (check (.ref no-coverage 'unchecked-receipts) => '())
        (check (.ref unknown 'status) => 'pending)
        (check (.ref unknown 'unchecked-receipts) => '("ac"))))

    (yuanxu-test-case "conflicting or invalid checks cannot be reviewable"
      (let* ((cut (scope 1 "sha256:coverage"))
             (gql (receipt "g" "candidate" cut 'gql #t))
             (ascent (receipt "a" "candidate" cut 'ascent #t))
             (valid (check-receipt "yes" gql 'valid))
             (invalid (check-receipt "no" gql 'invalid))
             (ascent-valid (check-receipt "ac" ascent 'valid))
             (before (agentic-ai-lab-candidate-exchange
                      "before" "candidate" cut (list gql ascent)
                      (list valid ascent-valid)))
             (contested (agentic-ai-lab-candidate-exchange
                         "x" "candidate" cut (list gql ascent)
                         (list valid invalid ascent-valid)))
             (rejected (agentic-ai-lab-candidate-exchange
                        "y" "candidate" cut (list gql ascent)
                        (list invalid ascent-valid))))
        (check (.ref before 'status) => 'reviewable)
        (check (.ref contested 'status) => 'contested)
        (check (.ref contested 'contested-providers) => '(gql))
        (check (.ref rejected 'status) => 'rejected)
        (check (.ref rejected 'invalid-receipts) => '("g"))))

    (yuanxu-test-case "foreign candidate and duplicate provider stay out of review"
      (let* ((cut (scope 1 "sha256:coverage"))
             (gql (receipt "g" "other" cut 'gql #t))
             (a1 (receipt "a1" "candidate" cut 'ascent #t))
             (a2 (receipt "a2" "candidate" cut 'ascent #t))
             (exchange (agentic-ai-lab-candidate-exchange
                        "x" "candidate" cut (list gql a1 a2)
                        (list (check-receipt "c1" a1 'valid)
                              (check-receipt "c2" a2 'valid)))))
        (check (.ref exchange 'status) => 'contested)
        (check (.ref exchange 'stale-receipts) => '("g"))
        (check (.ref exchange 'contested-providers) => '(ascent))))

    (yuanxu-test-case "forged digest and revised check binding are rejected"
      (let* ((cut (scope 1 "sha256:coverage"))
             (gql (receipt "g" "candidate" cut 'gql #t))
             (forged (agentic-ai-lab-candidate-receipt-value
                      "g" "sha256:forged" "candidate"
                      (.ref cut 'semantic-digest) 'gql
                      (.ref gql 'request-digest)
                      (.ref gql 'source-receipt-digest)
                      (.ref gql 'result-digest) 2 #t))
             (checked (check-receipt "c" gql 'valid))
             (changed (agentic-ai-lab-candidate-receipt
                       "g" "candidate" cut 'gql "sha256:other-request"
                       "sha256:provider/g" "sha256:result/g" 2 #t)))
        (check-exception
         (agentic-ai-lab-candidate-exchange "x" "candidate" cut (list forged) '())
         true)
        (check-exception
         (agentic-ai-lab-candidate-exchange
          "x" "candidate" cut (list changed) (list checked))
         true)))))
