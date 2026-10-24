;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :clan/poo/object .ref)
        :std/test
        :agentic-ai-lab/modules/temporal-causality/time/interface
        :agentic-ai-lab/modules/temporal-causality/trajectory/interface)
(export temporal-trajectory-test)

(def (point id domain coordinate value)
  (agentic-ai-lab-temporal-trajectory-sample
   (agentic-ai-lab-temporal-instant id domain coordinate "source-1" 'observed)
   value))

(def (series samples)
  (agentic-ai-lab-temporal-trajectory-series
   "series-1" "subject-1" "scenario-1" "outcome-1" "unit-1"
   "cut-1" "projection-1" 'observed samples))

(def (version id cut projection samples)
  (agentic-ai-lab-temporal-trajectory-series
   id "subject-1" "scenario-1" "outcome-1" "unit-1"
   cut projection 'observed samples))

(def temporal-trajectory-test
  (test-suite "trajectory module is independent and canonical"
    (yuanxu-test-case "canonical ordering and strict clock domain"
      (let ((a (point "instant-a" "clock-1" 0 1))
            (b (point "instant-b" "clock-1" 3 7)))
        (check (.ref (series (list b a)) 'semantic-digest)
               => (.ref (series (list a b)) 'semantic-digest))
        (check-exception
         (series (list a (point "instant-c" "clock-2" 3 7))) true)
        (check-exception
         (series (list a (point "instant-a" "clock-1" 3 7))) true)))

    (yuanxu-test-case "late correction produces a bounded coordinate delta"
      (let* ((old (version "v1" "cut-1" "projection-1"
                           (list (point "a" "clock-1" 0 1)
                                 (point "b" "clock-1" 2 3)
                                 (point "c" "clock-1" 5 8))))
             (new (version "v2" "cut-2" "projection-2"
                           (list (point "a" "clock-1" 0 1)
                                 (point "d" "clock-1" 3 4)
                                 (point "c" "clock-1" 5 9))))
             (delta (agentic-ai-lab-temporal-trajectory-delta "delta" old new)))
        (check (.ref delta 'added-coordinates) => '(3))
        (check (.ref delta 'removed-coordinates) => '(2))
        (check (.ref delta 'changed-coordinates) => '(5))
        (check (.ref delta 'status) => 'sample-and-scope-change)
        (check (.ref (.ref delta 'previous-series) 'semantic-digest)
               => (.ref old 'semantic-digest))
        (check-exception
         (agentic-ai-lab-temporal-trajectory-delta
          "reused-identity" old
          (version "v1" "cut-2" "projection-2"
                   (list (point "a" "clock-1" 0 1)
                         (point "b" "clock-1" 2 3)
                         (point "c" "clock-1" 5 8)))) true)))

    (yuanxu-test-case "identity-only and projection-only changes stay distinct"
      (let* ((samples (list (point "a" "clock-1" 0 1)
                            (point "b" "clock-1" 2 3)))
             (old (version "v1" "cut-1" "projection-1" samples)))
        (check (.ref (agentic-ai-lab-temporal-trajectory-delta
                      "same" old old) 'status) => 'unchanged)
        (check (.ref (agentic-ai-lab-temporal-trajectory-delta
                      "identity" old
                      (version "v2" "cut-1" "projection-1" samples))
                     'status) => 'identity-only)
        (check (.ref (agentic-ai-lab-temporal-trajectory-delta
                      "projection" old
                      (version "v2" "cut-1" "projection-2" samples))
                     'status) => 'scope-change)))))
