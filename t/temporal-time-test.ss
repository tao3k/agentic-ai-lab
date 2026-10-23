;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :clan/poo/object .ref)
        :std/test
        (only-in :agentic-ai-lab/modules/temporal-causality/time/watermark-objects
                 agentic-ai-lab-temporal-watermark-value)
        :agentic-ai-lab/modules/temporal-causality/time/interface)
(export temporal-time-test)

(def (instant id domain coordinate modality)
  (agentic-ai-lab-temporal-instant id domain coordinate "ledger" modality))

(def (extent identity-value start-value end-value)
  (agentic-ai-lab-temporal-interval
   identity-value
   (instant (string-append identity-value "-start") "event"
            start-value 'observed)
   (instant (string-append identity-value "-end") "event"
            end-value 'observed)
   #t #f))

(def (bounded identity-value role-value domain-value lower-value upper-value)
  (agentic-ai-lab-temporal-bounded-observation
   identity-value role-value "clock-source"
   (instant (string-append identity-value "-lower") domain-value
            lower-value 'observed)
   (instant (string-append identity-value "-upper") domain-value
            upper-value 'observed)
   (- upper-value lower-value)
   (instant (string-append identity-value "-acquired") "ingress"
            30 'observed)
   "clock-receipt" #f "attempt" "time.v1"))

(def temporal-time-test
  (test-suite "temporal type algebra"
    (yuanxu-test-case "clock domains and modality preserve partial order"
      (check (agentic-ai-lab-temporal-compare
              (instant "a" "event" 1 'observed)
              (instant "b" "event" 2 'observed)) => 'before)
      (check (agentic-ai-lab-temporal-compare
              (instant "a" "event" 1 'observed)
              (instant "b" "ingest" 2 'observed)) => 'incomparable)
      (check (agentic-ai-lab-temporal-compare
              (instant "a" "event" 1 'declared)
              (instant "b" "event" 2 'observed)) => 'unknown)
      (check (agentic-ai-lab-temporal-compare
              (instant "a" "event" 1 'corrected)
              (instant "b" "event" 2 'observed)) => 'unknown))
    (yuanxu-test-case "interval endpoint openness is explicit"
      (let ((span
             (agentic-ai-lab-temporal-interval
              "window" (instant "start" "event" 1 'observed)
              (instant "end" "event" 3 'observed) #t #f)))
        (check (agentic-ai-lab-temporal-interval? span) => #t)
        (check (agentic-ai-lab-temporal-interval-contains?
                span (instant "at-start" "event" 1 'observed)) => #t)
        (check (agentic-ai-lab-temporal-interval-contains?
                span (instant "at-end" "event" 3 'observed)) => #f)
        (check (agentic-ai-lab-temporal-interval-contains?
                span (instant "other" "ingest" 2 'observed))
               => 'incomparable)))
    (yuanxu-test-case "event, ingress and processing axes remain distinct"
      (let ((axes (agentic-ai-lab-temporal-axes
                   "event-1" (instant "event" "device" 1 'observed)
                   (instant "ingress" "server" 8 'observed) #f)))
        (check (agentic-ai-lab-temporal-axes? axes) => #t)))
    (yuanxu-test-case "Allen endpoint relations are exhaustive on proper extents"
      (for-each
       (lambda (row)
         (check
          (agentic-ai-lab-temporal-interval-extent-relation
           (extent "left" (list-ref row 0) (list-ref row 1))
           (extent "right" (list-ref row 2) (list-ref row 3)))
          => (list-ref row 4)))
       '((1 2 4 5 before)
         (1 3 3 5 meets)
         (1 4 3 6 overlaps)
         (1 6 3 6 finished-by)
         (1 8 3 6 contains)
         (1 4 1 6 starts)
         (1 6 1 6 equal)
         (1 8 1 6 started-by)
         (5 7 1 3 after)
         (3 5 1 3 met-by)
         (3 5 1 7 during)
         (3 7 1 7 finishes)
         (3 7 1 5 overlapped-by)))
      (check (agentic-ai-lab-temporal-interval-extent-relation
              (extent "point" 2 2) (extent "proper" 1 3))
             => 'degenerate)
      (check (agentic-ai-lab-temporal-interval-extent-relation
              (extent "event" 1 3)
              (agentic-ai-lab-temporal-interval
               "foreign" (instant "foreign-start" "ingress" 2 'observed)
               (instant "foreign-end" "ingress" 4 'observed) #t #f))
             => 'incomparable)
      (check (agentic-ai-lab-temporal-interval-extent-relation
              (extent "event" 1 3)
              (agentic-ai-lab-temporal-interval
               "declared" (instant "declared-start" "event" 2 'declared)
               (instant "declared-end" "event" 4 'observed) #t #f))
             => 'unknown))
    (yuanxu-test-case "uncertain observations preserve boundary ambiguity"
      (let* ((observation
              (agentic-ai-lab-temporal-bounded-observation
               "reading" 'wall "clock-source"
               (instant "lower" "source-clock" 8 'observed)
               (instant "upper" "source-clock" 12 'observed)
               4 (instant "acquired" "ingress-clock" 20 'observed)
               "receipt" #f "attempt" "time.v1"))
             (later
              (agentic-ai-lab-temporal-bounded-observation
               "later" 'wall "clock-source"
               (instant "later-lower" "source-clock" 13 'observed)
               (instant "later-upper" "source-clock" 15 'observed)
               2 (instant "later-acquired" "ingress-clock" 21 'observed)
               "later-receipt" #f "attempt" "time.v1")))
        (check (agentic-ai-lab-temporal-bounded-observation? observation) => #t)
        (check (equal? (.ref observation 'semantic-digest)
                       (.ref (agentic-ai-lab-temporal-bounded-observation-replay observation)
                             'semantic-digest)) => #t)
        (check (agentic-ai-lab-temporal-bounded-observation-boundary
                observation (instant "threshold" "source-clock" 10 'observed))
               => 'unknown)
        (check (agentic-ai-lab-temporal-bounded-observation-boundary
                observation (instant "future" "source-clock" 13 'observed))
               => 'before)
        (check (agentic-ai-lab-temporal-bounded-observation-boundary
                observation (instant "foreign" "ingress-clock" 10 'observed))
               => 'incomparable)
        (check (agentic-ai-lab-temporal-bounded-observation-compare observation later)
               => 'before)
        (check (agentic-ai-lab-temporal-bounded-observation-compare later observation)
               => 'after)))
    (yuanxu-test-case "observation excludes declared endpoints and inverted bounds"
      (check-exception
       (agentic-ai-lab-temporal-bounded-observation
        "declared" 'wall "source"
        (instant "lower" "clock" 1 'declared)
        (instant "upper" "clock" 2 'observed)
        1 (instant "acquired" "ingress" 3 'observed)
        "receipt" #f "attempt" "time.v1") true)
      (check-exception
       (agentic-ai-lab-temporal-bounded-observation
        "inverted" 'wall "source"
        (instant "lower" "clock" 3 'observed)
        (instant "upper" "clock" 2 'observed)
        1 (instant "acquired" "ingress" 4 'observed)
        "receipt" #f "attempt" "time.v1") true))
    (yuanxu-test-case "elapsed bounds require ordered monotonic observations"
      (let* ((start (bounded "start" 'monotonic "worker-clock" 2 4))
             (end (bounded "end" 'monotonic "worker-clock" 9 12))
             (duration (agentic-ai-lab-temporal-monotonic-duration
                        "work" start end)))
        (check (agentic-ai-lab-temporal-duration-assessment? duration) => #t)
        (check (.ref duration 'status) => 'bounded)
        (check (.ref duration 'minimum) => 5)
        (check (.ref duration 'maximum) => 10)
        (check (equal? (.ref duration 'semantic-digest)
                       (.ref (agentic-ai-lab-temporal-duration-assessment-replay
                              duration start end) 'semantic-digest)) => #t)
        (check (.ref (agentic-ai-lab-temporal-monotonic-duration
                      "overlap" start
                      (bounded "overlap-end" 'monotonic "worker-clock" 3 8))
                     'status) => 'unknown)
        (check (.ref (agentic-ai-lab-temporal-monotonic-duration
                      "reversed" start
                      (bounded "before-start" 'monotonic "worker-clock" 0 1))
                     'status) => 'reversed)
        (check (.ref (agentic-ai-lab-temporal-monotonic-duration
                      "foreign" start
                      (bounded "other-clock" 'monotonic "other-clock" 9 12))
                     'status) => 'incomparable)
        (check (.ref (agentic-ai-lab-temporal-monotonic-duration
                      "wall" start
                      (bounded "wall-end" 'wall-clock "worker-clock" 9 12))
                     'status) => 'unsupported-clock)))
    (yuanxu-test-case "watermark preserves scope and uncertainty"
      (let* ((observation
              (agentic-ai-lab-temporal-bounded-observation
               "watermark-time" 'logical "stream-clock"
               (instant "wm-lower" "event" 10 'observed)
               (instant "wm-upper" "event" 12 'observed)
               2 (instant "wm-acquired" "ingress" 30 'observed)
               "time-receipt" #f "attempt" "time.v1"))
             (watermark
              (agentic-ai-lab-temporal-watermark
               "wm-1" "stream" "partition-1" 0 50 observation
               "issuer" "coverage-receipt" "late-policy" "watermark-receipt")))
        (check (agentic-ai-lab-temporal-watermark? watermark) => #t)
        (check (equal? (.ref watermark 'semantic-digest)
                       (.ref (agentic-ai-lab-temporal-watermark-replay watermark)
                             'semantic-digest)) => #t)
        (check (agentic-ai-lab-temporal-watermark-cut-claim
                watermark "stream" "partition-1" 20
                (instant "cut-9" "event" 9 'observed))
               => 'coverage-claimed)
        (check (agentic-ai-lab-temporal-watermark-cut-claim
                watermark "stream" "partition-1" 20
                (instant "cut-11" "event" 11 'observed))
               => 'unknown)
        (check (agentic-ai-lab-temporal-watermark-cut-claim
                watermark "stream" "partition-1" 20
                (instant "cut-13" "event" 13 'observed))
               => 'not-covered)
        (check (agentic-ai-lab-temporal-watermark-cut-claim
                watermark "stream" "partition-2" 20
                (instant "cut-9-other" "event" 9 'observed))
               => 'outside-scope)
        (check (agentic-ai-lab-temporal-watermark-cut-claim
                watermark "stream" "partition-1" 51
                (instant "cut-9-outside" "event" 9 'observed))
               => 'outside-scope)
        (check (agentic-ai-lab-temporal-watermark-cut-claim
                watermark "stream" "partition-1" 20
                (instant "cut-9-foreign" "ingress" 9 'observed))
               => 'incomparable)
        (let (forged
              (agentic-ai-lab-temporal-watermark-value
               "wm-1" "sha256:wrong" "stream" "partition-1" 0 50
               observation "issuer" "coverage-receipt" "late-policy"
               "watermark-receipt"))
          (check-exception
           (agentic-ai-lab-temporal-watermark-cut-claim
            forged "stream" "partition-1" 20
            (instant "cut-forged" "event" 9 'observed)) true))))))
