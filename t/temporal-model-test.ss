;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :clan/poo/object .ref)
        :std/test
        :agentic-ai-lab/modules/temporal-causality/interface)
(export temporal-model-test)

(def clock (agentic-ai-lab-temporal-clock-domain "revision-clock" 'logical-version))
(def second-clock
  (agentic-ai-lab-temporal-clock-domain "external-clock" 'logical-version))

(def (observation id domain position)
  (agentic-ai-lab-temporal-model-observation
   id domain position (string-append id "/ledger") 'observed))

(def (candidate id cause effect)
  (agentic-ai-lab-temporal-hypothesis id cause effect '()))

(def (two-explanations name domain-b position-b complete?)
  (agentic-ai-lab-temporal-model
   name (list clock second-clock)
   (list (observation "source-a" "revision-clock" 1)
         (observation "source-b" domain-b position-b)
         (observation "result" "revision-clock" 3))
   (list (candidate "via-a" "source-a" "result")
         (candidate "via-b" "source-b" "result"))
   complete?))

(def temporal-model-test
  (test-suite "open temporal model"
    (yuanxu-test-case "medication vocabulary admits two candidate explanations"
      (let* ((domain (agentic-ai-lab-temporal-clock-domain
                      "care-sequence" 'logical-version))
             (model
              (agentic-ai-lab-temporal-model
               "medication-analysis" (list domain)
               (list (observation "prescription" "care-sequence" 1)
                     (observation "review" "care-sequence" 2)
                     (observation "administration" "care-sequence" 3))
               (list (candidate "via-prescription"
                                "prescription" "administration")
                     (candidate "via-review" "review" "administration"))
               #t))
             (query (agentic-ai-lab-temporal-query
                     "why-administration" "via-prescription" 2))
             (receipt (agentic-ai-lab-temporal-model-classify model query)))
        (check (agentic-ai-lab-temporal-model? model) => #t)
        (check (agentic-ai-lab-temporal-model-receipt? receipt) => #t)
        (check (.ref receipt 'classification) => 'possible)
        (check (.ref receipt 'admissible-hypothesis-ids)
               => '("via-prescription" "via-review"))
        (check (.ref receipt 'exhausted?) => #t)
        (check (.ref receipt 'assumption) => 'exclusive-explanations)))

    (yuanxu-test-case "new evidence refutes one candidate and changes identity"
      (let* ((before (two-explanations "build-flow"
                                       "revision-clock" 2 #t))
             (after (two-explanations "build-flow"
                                      "revision-clock" 4 #t))
             (query (agentic-ai-lab-temporal-query "why-result" "via-a" 2))
             (receipt (agentic-ai-lab-temporal-model-classify after query)))
        (check (equal? (.ref before 'semantic-digest)
                       (.ref after 'semantic-digest)) => #f)
        (check (.ref receipt 'classification) => 'necessary)
        (check (.ref receipt 'refuted-hypothesis-ids) => '("via-b"))
        (check (.ref receipt 'model-digest)
               => (.ref after 'semantic-digest))))

    (yuanxu-test-case "overlapping mechanisms do not imply exclusive necessity"
      (let* ((domains (list clock))
             (observations
              (list (observation "source-a" "revision-clock" 1)
                    (observation "source-b" "revision-clock" 4)
                    (observation "result" "revision-clock" 3)))
             (hypotheses
              (list (candidate "via-a" "source-a" "result")
                    (candidate "via-b" "source-b" "result")))
             (exclusive
              (agentic-ai-lab-temporal-model
               "same-vocabulary" domains observations hypotheses #t))
             (overlapping
              (agentic-ai-lab-temporal-overlapping-model
               "same-vocabulary" domains observations hypotheses #t))
             (receipt
              (agentic-ai-lab-temporal-model-classify
               overlapping (agentic-ai-lab-temporal-query "why" "via-a" #f))))
        (check (.ref receipt 'assumption) => 'overlapping-mechanisms)
        (check (.ref receipt 'admissible-hypothesis-ids) => '("via-a"))
        (check (.ref receipt 'refuted-hypothesis-ids) => '("via-b"))
        (check (.ref receipt 'classification) => 'possible)
        (check (equal? (.ref exclusive 'semantic-digest)
                       (.ref overlapping 'semantic-digest)) => #f)
        (check (.ref (agentic-ai-lab-temporal-model-replay overlapping)
                     'semantic-digest)
               => (.ref overlapping 'semantic-digest))
        (let (forged
              (agentic-ai-lab-temporal-model-value
               "same-vocabulary" (.ref exclusive 'semantic-digest)
               (.ref overlapping 'domains) (.ref overlapping 'observations)
               (.ref overlapping 'hypotheses)
               #t 'overlapping-mechanisms))
          (check (agentic-ai-lab-temporal-model? forged) => #t)
          (check-exception (agentic-ai-lab-temporal-model-replay forged) true)
          (check-exception
           (agentic-ai-lab-temporal-model-classify
            forged (agentic-ai-lab-temporal-query "why" "via-a" #f)) true))
        (check (.ref (agentic-ai-lab-temporal-model-classify
                      exclusive (agentic-ai-lab-temporal-query "why" "via-a" #f))
                     'classification) => 'necessary)))

    (yuanxu-test-case "coexisting mechanisms remain possible together"
      (let* ((model
              (agentic-ai-lab-temporal-overlapping-model
               "coexisting" (list clock)
               (list (observation "source-a" "revision-clock" 1)
                     (observation "source-b" "revision-clock" 2)
                     (observation "result" "revision-clock" 3))
               (list (candidate "via-a" "source-a" "result")
                     (candidate "via-b" "source-b" "result")) #t))
             (receipt
              (agentic-ai-lab-temporal-model-classify
               model (agentic-ai-lab-temporal-query "why" "via-a" #f))))
        (check (.ref receipt 'admissible-hypothesis-ids)
               => '("via-a" "via-b"))
        (check (.ref receipt 'classification) => 'possible)))

    (yuanxu-test-case "software release vocabulary uses the same POO API"
      (let* ((domain (agentic-ai-lab-temporal-clock-domain
                      "build-sequence" 'logical-version))
             (model
              (agentic-ai-lab-temporal-model
               "release-analysis" (list domain)
               (list (observation "commit" "build-sequence" 1)
                     (observation "canary" "build-sequence" 2)
                     (observation "deploy" "build-sequence" 3)
                     (observation "verification" "build-sequence" 4))
               (list
                (agentic-ai-lab-temporal-hypothesis
                 "via-canary" "canary" "deploy"
                 (list (agentic-ai-lab-temporal-constraint
                        "commit-before-canary" 'before "commit" "canary")))
                (candidate "via-verification" "verification" "deploy"))
               #t))
             (receipt
              (agentic-ai-lab-temporal-model-classify
               model (agentic-ai-lab-temporal-query "release-why" "via-canary" 2))))
        (check (.ref receipt 'classification) => 'necessary)
        (check (.ref receipt 'refuted-hypothesis-ids)
               => '("via-verification"))))

    (yuanxu-test-case "incomparable clocks and bounds preserve unknown frontier"
      (let* ((model (two-explanations "build-flow"
                                      "external-clock" 2 #t))
             (full (agentic-ai-lab-temporal-model-classify
                    model (agentic-ai-lab-temporal-query "full" "via-a" 2)))
             (bounded (agentic-ai-lab-temporal-model-classify
                       model (agentic-ai-lab-temporal-query "bounded" "via-b" 1))))
        (check (.ref full 'classification) => 'possible)
        (check (.ref full 'unknown-hypothesis-ids) => '("via-b"))
        (check (.ref bounded 'classification) => 'unknown)
        (check (.ref bounded 'unexplored-hypothesis-ids) => '("via-b"))
        (check (.ref bounded 'exhausted?) => #f)))

    (yuanxu-test-case "input order does not change identity or bounded traversal"
      (let* ((observations
              (list (observation "source-a" "revision-clock" 1)
                    (observation "source-b" "revision-clock" 2)
                    (observation "result" "revision-clock" 3)))
             (hypotheses
              (list (candidate "via-a" "source-a" "result")
                    (candidate "via-b" "source-b" "result")))
             (forward (agentic-ai-lab-temporal-model
                       "stable" (list clock) observations hypotheses #t))
             (reverse-input (agentic-ai-lab-temporal-model
                             "stable" (list clock) (reverse observations)
                             (reverse hypotheses) #t))
             (query (agentic-ai-lab-temporal-query "bounded" "via-b" 1)))
        (check (.ref forward 'semantic-digest)
               => (.ref reverse-input 'semantic-digest))
        (check (.ref (agentic-ai-lab-temporal-model-classify forward query)
                     'unexplored-hypothesis-ids)
               => (.ref (agentic-ai-lab-temporal-model-classify reverse-input query)
                        'unexplored-hypothesis-ids))))

    (yuanxu-test-case "incomplete family cannot imply necessity"
      (let* ((model (two-explanations "build-flow"
                                      "revision-clock" 4 #f))
             (receipt (agentic-ai-lab-temporal-model-classify
                       model (agentic-ai-lab-temporal-query "open" "via-a" 2))))
        (check (.ref receipt 'classification) => 'possible)
        (check (.ref receipt 'family-complete?) => #f)))

    (yuanxu-test-case "unbounded query exhausts the finite family"
      (let* ((model (two-explanations "unbounded" "revision-clock" 4 #t))
             (receipt (agentic-ai-lab-temporal-model-classify
                       model (agentic-ai-lab-temporal-query "all" "via-a" #f))))
        (check (.ref receipt 'classification) => 'necessary)
        (check (.ref receipt 'exhausted?) => #t)
        (check (.ref receipt 'unexplored-hypothesis-ids) => '())))

    (yuanxu-test-case "new clock roles are POO data, not core branches"
      (let ((domain (agentic-ai-lab-temporal-clock-domain
                     "satellite-revision" 'satellite-epoch)))
        (check (agentic-ai-lab-temporal-clock-domain? domain) => #t)))

    (yuanxu-test-case "missing observations remain unresolved"
      (let* ((model
              (agentic-ai-lab-temporal-model
               "partial" (list clock)
               (list (observation "result" "revision-clock" 3))
               (list (candidate "unseen-cause" "missing" "result")) #t))
             (receipt (agentic-ai-lab-temporal-model-classify
                       model (agentic-ai-lab-temporal-query
                              "partial-why" "unseen-cause" 1))))
        (check (.ref receipt 'classification) => 'unknown)
        (check (.ref receipt 'unknown-hypothesis-ids)
               => '("unseen-cause"))))

    (yuanxu-test-case "an explicit inconsistent constraint refutes its candidate"
      (let* ((model
              (agentic-ai-lab-temporal-model
               "constrained" (list clock)
               (list (observation "source" "revision-clock" 1)
                     (observation "result" "revision-clock" 3))
               (list
                (agentic-ai-lab-temporal-hypothesis
                 "candidate" "source" "result"
                 (list (agentic-ai-lab-temporal-constraint
                        "result-before-source" 'before "result" "source"))))
               #t))
             (receipt (agentic-ai-lab-temporal-model-classify
                       model (agentic-ai-lab-temporal-query "why" "candidate" 1))))
        (check (.ref receipt 'classification) => 'refuted)
        (check (.ref receipt 'refuted-hypothesis-ids)
               => '("candidate"))))

    (yuanxu-test-case "empty candidate family is invalid"
      (check-exception
       (agentic-ai-lab-temporal-model "empty" (list clock) '() '() #t)
       true))

    (yuanxu-test-case "duplicate candidate identities are invalid"
      (check-exception
       (agentic-ai-lab-temporal-model
        "duplicate" (list clock) '()
        (list (candidate "same" "a" "result")
              (candidate "same" "b" "result")) #t)
       true))))
