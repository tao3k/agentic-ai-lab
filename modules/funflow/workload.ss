;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: immutable Scenario multiplicity and workload values.
;;; Invariant: ordinal lookup follows ordered launch ranges.

(import (only-in :clan/poo/object .o .ref)
        (only-in :std/list/list fold)
        (only-in :clan/poo/type validate)
        (only-in :clan/poo/number IntegerRange UInt))

(export scenario-multiplicity
        scenario-launch-range
        scenario-multiplicities->launch-ranges
        scenario-workload
        scenario-workload/ref)

(def PositiveCount (IntegerRange min: 1))

(def (scenario-multiplicity composition count)
  (validate PositiveCount count)
  (.o kind: 'yuanxu.funflow.scenario.multiplicity.v1
      (composition) (count)))

(def (scenario-launch-range composition start count)
  (validate UInt start)
  (validate PositiveCount count)
  (.o kind: 'yuanxu.funflow.scenario.launch-range.v1
      (composition) (start) (count)
      end: (+ start count)))

(def (scenario-multiplicities->launch-ranges multiplicities)
  (unless (and (list? multiplicities) (pair? multiplicities))
    (error "Funflow composition workload requires at least one multiplicity"))
  (let* ((state
          (fold
           (lambda (multiplicity state)
             (unless (eq? (.ref multiplicity 'kind)
                          'yuanxu.funflow.scenario.multiplicity.v1)
               (error "Funflow composition workload requires multiplicity objects"
                      multiplicity))
             (let* ((start (car state))
                    (ranges (cdr state))
                    (count (validate PositiveCount (.ref multiplicity 'count)))
                    (launch-range
                     (scenario-launch-range
                      (.ref multiplicity 'composition)
                      start
                      count)))
               (cons (+ start count)
                     (cons launch-range ranges))))
           (cons 0 '())
           multiplicities))
         (ranges (cdr state)))
    (list->vector (reverse ranges))))

(def (scenario-workload multiplicities)
  (let* ((launch-ranges-value
          (scenario-multiplicities->launch-ranges multiplicities))
         (last-range
          (vector-ref launch-ranges-value
                      (- (vector-length launch-ranges-value) 1)))
         (total-count-value (.ref last-range 'end)))
    (.o (kind 'yuanxu.funflow.scenario.workload.v1)
        (launch-ranges launch-ranges-value)
        (total-count total-count-value))))

;; : (-> ScenarioLaunchRange Integer Integer
;;       ScenarioInstanceRef)
(def (scenario-instance-ref launch-range ordinal start)
  (let ((composition-value (.ref launch-range 'composition))
        (launch-range-value launch-range)
        (ordinal-value ordinal)
        (local-ordinal-value (- ordinal start)))
    (.o (kind 'yuanxu.funflow.scenario.instance-ref.v1)
        (composition composition-value)
        (launch-range launch-range-value)
        (ordinal ordinal-value)
        (local-ordinal local-ordinal-value))))

;; Binary search remains a bounded lookup over the immutable range vector; the
;; recursive helper makes its search boundary explicit instead of accumulating
;; a list transform in the public workload accessor.
;; : (-> Vector Integer Integer Integer ScenarioInstanceRef)
(def (scenario-launch-range-ref launch-ranges ordinal low high)
  (let* ((middle (quotient (+ low high) 2))
         (launch-range (vector-ref launch-ranges middle))
         (start (.ref launch-range 'start))
         (end (.ref launch-range 'end)))
    (cond
     ((< ordinal start)
      (scenario-launch-range-ref
       launch-ranges ordinal low (- middle 1)))
     ((>= ordinal end)
      (scenario-launch-range-ref
       launch-ranges ordinal (+ middle 1) high))
     (else
      (scenario-instance-ref launch-range ordinal start)))))

(def (scenario-workload/ref workload ordinal)
  (let ((total-count (.ref workload 'total-count))
        (launch-ranges (.ref workload 'launch-ranges)))
    (unless (and (integer? ordinal)
                 (>= ordinal 0)
                 (< ordinal total-count))
      (error "Funflow composition workload ordinal is out of range"
             ordinal
             total-count))
    (scenario-launch-range-ref
     launch-ranges ordinal 0 (- (vector-length launch-ranges) 1))))
