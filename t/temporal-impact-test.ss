;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :clan/poo/object .ref)
        :std/test
        :agentic-ai-lab/modules/temporal-causality/interface)
(export temporal-impact-test)

(def (sample id coordinate outcome)
  (agentic-ai-lab-temporal-trajectory-sample
   (agentic-ai-lab-temporal-instant id "study-time" coordinate
                             "schedule-1" 'observed)
   outcome))

(def (series id scenario modality values)
  (agentic-ai-lab-temporal-trajectory-series
   id "subject-1" scenario "outcome-1" "unit-1"
   "cut-1" "projection-1" modality values))

(def (series-for id scenario outcome modality values)
  (agentic-ai-lab-temporal-trajectory-series
   id "subject-1" scenario outcome "unit-1"
   "cut-1" "projection-1" modality values))

(def (versioned-series id scenario modality cut projection values)
  (agentic-ai-lab-temporal-trajectory-series
   id "subject-1" scenario "outcome-1" "unit-1"
   cut projection modality values))

(def temporal-impact-test
  (test-suite "exact dynamic trajectory contrasts"
    (yuanxu-test-case "irregular intervals yield exact level and rate contrasts"
      (let* ((left (series "left" "policy-a" 'observed
                           (list (sample "l5" 5 10)
                                 (sample "l0" 0 0)
                                 (sample "l2" 2 4))))
             (reordered (series "left" "policy-a" 'observed
                                (list (sample "l0" 0 0)
                                      (sample "l2" 2 4)
                                      (sample "l5" 5 10))))
             (right (series "right" "policy-b" 'observed
                            (list (sample "r0" 0 0)
                                  (sample "r2" 2 2)
                                  (sample "r5" 5 8))))
             (contrast (agentic-ai-lab-temporal-impact-contrast
                        "contrast" left right))
             (points (.ref contrast 'points)))
        (check (.ref left 'semantic-digest)
               => (.ref reordered 'semantic-digest))
        (check (map (lambda (point) (.ref point 'coordinate)) points)
               => '(0 2 5))
        (check (map (lambda (point) (.ref point 'level-delta)) points)
               => '(0 2 2))
        (check (map (lambda (point) (.ref point 'rate-delta)) points)
               => '(#f 1 0))
        (check (.ref contrast 'status) => 'descriptive-contrast)
        (check (.ref contrast 'causal-impact-admitted?) => #f)))

    (yuanxu-test-case "counterfactual values stay candidates"
      (let* ((baseline (series "baseline" "actual" 'observed
                               (list (sample "a0" 0 1)
                                     (sample "a2" 2 3))))
             (alternative (series "alternative" "proposal" 'counterfactual
                                  (list (sample "b0" 0 2)
                                        (sample "b2" 2 4))))
             (contrast (agentic-ai-lab-temporal-impact-contrast
                        "candidate" alternative baseline)))
        (check (.ref contrast 'status) => 'candidate-contrast)
        (check (map (lambda (point) (.ref point 'level-delta))
                    (.ref contrast 'points)) => '(1 1))
        (check (.ref (cadr (.ref contrast 'points)) 'rate-delta) => 0)
        (check (.ref contrast 'causal-impact-admitted?) => #f)))

    (yuanxu-test-case "intervention window audits prefix and exact irregular area"
      (let* ((baseline (series "baseline-window" "actual" 'observed
                               (list (sample "b0" 0 0)
                                     (sample "b2" 2 2)
                                     (sample "b5" 5 8))))
             (candidate (series "candidate-window" "policy-a" 'counterfactual
                                (list (sample "c0" 0 0)
                                      (sample "c2" 2 4)
                                      (sample "c5" 5 10))))
             (onset (agentic-ai-lab-temporal-instant
                     "onset-2" "study-time" 2 "policy-a" 'proposed))
             (end (agentic-ai-lab-temporal-instant
                   "end-5" "study-time" 5 "policy-a" 'proposed))
             (audit (agentic-ai-lab-temporal-intervention-window-audit
                     "audit" "intervention-a" candidate baseline onset end)))
        (check (agentic-ai-lab-temporal-intervention-window-audit? audit) => #t)
        (check (.ref audit 'prefix-status) => 'consistent)
        (check (.ref audit 'prefix-observed-count) => 1)
        (check (.ref audit 'cumulative-delta) => 6)
        (check (.ref audit 'mean-delta) => 2)
        (check (.ref audit 'causal-impact-admitted?) => #f)
        (check (.ref (agentic-ai-lab-temporal-intervention-window-audit
                      "audit-diverged" "intervention-a"
                      (series "diverged" "policy-a" 'counterfactual
                              (list (sample "d0" 0 1)
                                    (sample "d2" 2 4)
                                    (sample "d5" 5 10)))
                      baseline onset end)
                     'prefix-status) => 'diverged)
        (check-exception
         (agentic-ai-lab-temporal-intervention-window-audit
          "audit-off-grid" "intervention-a" candidate baseline
          (agentic-ai-lab-temporal-instant
           "onset-3" "study-time" 3 "policy-a" 'proposed)
          end) true)
        (check-exception
         (agentic-ai-lab-temporal-intervention-window-audit
          "audit-unobserved-baseline" "intervention-a" baseline candidate
          onset end) true)))

    (yuanxu-test-case "scoped candidate audit checks declared negative controls"
      (let* ((onset (agentic-ai-lab-temporal-instant
                     "onset-2" "study-time" 2 "policy-a" 'proposed))
             (end (agentic-ai-lab-temporal-instant
                   "end-5" "study-time" 5 "policy-a" 'proposed))
             (scope (agentic-ai-lab-temporal-impact-scope
                     "scope" "intervention-a" "subject-1" "cut-1"
                     "projection-1" onset end '("outcome-1") '("outcome-2")))
             (baseline-target
              (series-for "bt" "actual" "outcome-1" 'observed
                          (list (sample "b0" 0 0) (sample "b2" 2 2)
                                (sample "b5" 5 8))))
             (candidate-target
              (series-for "ct" "proposal" "outcome-1" 'counterfactual
                          (list (sample "c0" 0 0) (sample "c2" 2 4)
                                (sample "c5" 5 10))))
             (baseline-control
              (series-for "bc" "actual" "outcome-2" 'observed
                          (list (sample "n0" 0 5) (sample "n2" 2 6)
                                (sample "n5" 5 7))))
             (candidate-control
              (series-for "cc" "proposal" "outcome-2" 'counterfactual
                          (list (sample "m0" 0 5) (sample "m2" 2 6)
                                (sample "m5" 5 7))))
             (audit
              (agentic-ai-lab-temporal-impact-scope-audit
               "scope-audit" scope
               (list candidate-control candidate-target)
               (list baseline-target baseline-control))))
        (check (.ref audit 'audited-outcomes) => '("outcome-1" "outcome-2"))
        (check (.ref audit 'status) => 'consistent-with-declaration)
        (check (.ref audit 'prefix-status) => 'consistent)
        (check (.ref audit 'protected-status) => 'consistent)
        (check (.ref audit 'causal-impact-admitted?) => #f)
        (check
         (.ref
          (agentic-ai-lab-temporal-impact-scope-audit
           "unprotected-descendant" scope
           (list candidate-target candidate-control
                 (series-for "descendant-c" "proposal" "outcome-3"
                             'counterfactual
                             (list (sample "dc0" 0 1)
                                   (sample "dc2" 2 5)
                                   (sample "dc5" 5 9))))
           (list baseline-target baseline-control
                 (series-for "descendant-b" "actual" "outcome-3"
                             'observed
                             (list (sample "db0" 0 1)
                                   (sample "db2" 2 3)
                                   (sample "db5" 5 7)))))
          'status) => 'consistent-with-declaration)
        (check (.ref (agentic-ai-lab-temporal-impact-scope-audit
                      "violation" scope
                      (list candidate-target
                            (series-for "changed" "proposal" "outcome-2"
                                        'counterfactual
                                        (list (sample "m0" 0 5)
                                              (sample "m2" 2 6)
                                              (sample "m5" 5 9))))
                      (list baseline-target baseline-control))
                     'status) => 'violated)
        (check-exception
         (agentic-ai-lab-temporal-impact-scope-audit
          "missing-control" scope (list candidate-target)
          (list baseline-target)) true)
        (check-exception
         (agentic-ai-lab-temporal-impact-scope-audit
          "same-scenario" scope
          (list (series-for "same-ct" "actual" "outcome-1"
                            'counterfactual
                            (list (sample "c0" 0 0) (sample "c2" 2 4)
                                  (sample "c5" 5 10)))
                (series-for "same-cc" "actual" "outcome-2"
                            'counterfactual
                            (list (sample "m0" 0 5) (sample "m2" 2 6)
                                  (sample "m5" 5 7))))
          (list baseline-target baseline-control)) true)
        (check-exception
         (agentic-ai-lab-temporal-impact-scope
          "overlap" "intervention-a" "subject-1" "cut-1"
          "projection-1" onset end '("outcome-1") '("outcome-1")) true)))

    (yuanxu-test-case "revised trajectories reissue or block Impact"
      (let* ((old-left
              (versioned-series "left-v1" "proposal" 'counterfactual
                                "cut-1" "projection-1"
                                (list (sample "l0" 0 0)
                                      (sample "l2" 2 4))))
             (old-right
              (versioned-series "right-v1" "actual" 'observed
                                "cut-1" "projection-1"
                                (list (sample "r0" 0 0)
                                      (sample "r2" 2 2))))
             (new-left
              (versioned-series "left-v2" "proposal" 'counterfactual
                                "cut-2" "projection-2"
                                (list (sample "l0" 0 0)
                                      (sample "l2" 2 5))))
             (new-right
              (versioned-series "right-v2" "actual" 'observed
                                "cut-2" "projection-2"
                                (list (sample "r0" 0 0)
                                      (sample "r2" 2 2))))
             (old (agentic-ai-lab-temporal-impact-contrast
                   "old-impact" old-left old-right))
             (left-delta (agentic-ai-lab-temporal-trajectory-delta
                          "left-delta" old-left new-left))
             (right-delta (agentic-ai-lab-temporal-trajectory-delta
                           "right-delta" old-right new-right))
             (refresh (agentic-ai-lab-temporal-impact-refresh
                       "refresh" old left-delta right-delta)))
        (check (.ref refresh 'action) => 'recomputed)
        (check (.ref refresh 'reason) => 'source-version)
        (check (.ref (.ref refresh 'previous-contrast) 'semantic-digest)
               => (.ref old 'semantic-digest))
        (check (map (lambda (point) (.ref point 'level-delta))
                    (.ref (.ref refresh 'revised-contrast) 'points))
               => '(0 3))
        (check (.ref (agentic-ai-lab-temporal-impact-refresh
                      "reuse" old
                      (agentic-ai-lab-temporal-trajectory-delta
                       "same-left" old-left old-left)
                      (agentic-ai-lab-temporal-trajectory-delta
                       "same-right" old-right old-right))
                     'action) => 'reused)
        (check
         (.ref
          (agentic-ai-lab-temporal-impact-refresh
           "scope-only" old
           (agentic-ai-lab-temporal-trajectory-delta
            "left-scope" old-left
            (versioned-series "left-scope-v2" "proposal" 'counterfactual
                              "cut-2" "projection-2"
                              (list (sample "l0" 0 0)
                                    (sample "l2" 2 4))))
           (agentic-ai-lab-temporal-trajectory-delta
            "right-scope" old-right new-right))
          'action) => 'recomputed)
        (let (blocked
              (agentic-ai-lab-temporal-impact-refresh
               "blocked" old left-delta
               (agentic-ai-lab-temporal-trajectory-delta
                "mismatched-right" old-right
                (versioned-series "right-v3" "actual" 'observed
                                  "cut-3" "projection-2"
                                  (list (sample "r0" 0 0)
                                        (sample "r2" 2 2))))))
          (check (.ref blocked 'action) => 'blocked)
          (check (.ref blocked 'reason) => 'scope-mismatch)
          (check (.ref blocked 'revised-contrast) => #f))
        (check (.ref (agentic-ai-lab-temporal-impact-refresh
                      "bad-grid" old left-delta
                      (agentic-ai-lab-temporal-trajectory-delta
                       "shifted-right" old-right
                       (versioned-series "right-v4" "actual" 'observed
                                         "cut-2" "projection-2"
                                         (list (sample "r0" 0 0)
                                               (sample "r3" 3 2)))))
                     'reason) => 'grid-mismatch)))

    (yuanxu-test-case "grid and evidence-scope mismatch fail closed"
      (let ((left (series "left" "a" 'observed
                          (list (sample "a0" 0 1) (sample "a2" 2 3)))))
        (check-exception
         (agentic-ai-lab-temporal-impact-contrast
          "bad-grid" left
          (series "right" "b" 'observed
                  (list (sample "b0" 0 1) (sample "b3" 3 3)))) true)
        (check-exception
         (agentic-ai-lab-temporal-impact-contrast
          "bad-cut" left
          (agentic-ai-lab-temporal-trajectory-series
           "right" "subject-1" "b" "outcome-1" "unit-1"
           "cut-2" "projection-1" 'observed
           (list (sample "b0" 0 1) (sample "b2" 2 3)))) true)
        (check-exception
         (series "duplicate" "b" 'observed
                 (list (sample "a" 0 1) (sample "b" 0 2))) true)
        (check-exception
         (agentic-ai-lab-temporal-impact-contrast
          "forged" left
          (agentic-ai-lab-temporal-trajectory-series-value
           "right" "sha256:wrong" "subject-1" "b" "outcome-1"
           "unit-1" "cut-1" "projection-1" "study-time" 'observed
           (list (sample "b0" 0 1) (sample "b2" 2 3)))) true)
        (check-exception
         (sample "inexact" 1 1.5) true)))))
