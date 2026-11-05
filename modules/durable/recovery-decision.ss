;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .o .ref .slot?) "objects.ss")
(export DurableRecoveryPolicy. durable-recovery-decision)

(def (known-outcome? value)
  (memq value '(succeeded failed)))

;;; The caller admits and scopes the snapshot before calling the kernel.
;;; Observations are for the original effect. Guards come from their owners.
(def (durable-recovery-decision config evidence)
  (let* ((attempt-id (.ref evidence 'attempt))
         (effect-id (.ref evidence 'effect))
         (cut-id (.ref evidence 'cut))
         (policy-id (.ref config 'revision))
         (binding-matches (eq? #t (.ref evidence 'binding-matches?)))
         (permission (eq? #t (.ref evidence 'current-permission?)))
         (repeat-safe (eq? #t (.ref evidence 'repeat-safe?)))
         (recorded (let (value (.ref evidence 'recorded-outcome))
                     (if (known-outcome? value) value 'unknown)))
         (observations (if (.slot? evidence 'outcome-observations)
                         (.ref evidence 'outcome-observations)
                         '()))
         (has-observations (pair? observations))
         (interpret-outcome (.ref config 'outcome-interpreter))
         (propose-retry (.ref config 'retry-policy))
         (interpreted-value
           (if (and (not (known-outcome? recorded)) binding-matches has-observations)
             (let (value (interpret-outcome
                          (.o attempt: attempt-id effect: effect-id cut: cut-id
                              outcome-observations: observations)))
               (if (known-outcome? value) value 'unknown))
             'unknown))
         (outcome-value (if (known-outcome? recorded) recorded interpreted-value))
         (proposal
           (and binding-matches
                (not (eq? outcome-value 'succeeded))
                (eq? #t (propose-retry
                         (.o attempt: attempt-id effect: effect-id cut: cut-id
                             current-permission?: permission repeat-safe?: repeat-safe)
                         outcome-value))))
         (eligible (and proposal permission repeat-safe)))
    (.o attempt: attempt-id effect: effect-id
        policy-revision: policy-id evidence-cut: cut-id
        recorded-outcome: recorded outcome: outcome-value
        basis: (.o binding-matches?: binding-matches
                   current-permission?: permission repeat-safe?: repeat-safe
                   has-observations?: has-observations interpretation: interpreted-value)
        retry-proposed?: proposal retry-eligible?: eligible)))
