;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Fixed, pre-registered model-study fixture. No model text is evaluated.
(import (only-in :gerbil-ascent/candidate/program candidate-inspect)
        (only-in :gerbil-ascent/candidate/reasoning
                 reasoning-source-snapshot reasoning-attempt
                 reasoning-receipt-status reasoning-receipt-rows
                 reasoning-receipt-candidate-digest)
        (only-in :gerbil-ascent/candidate/finite-evidence
                 candidate-finite-evidence candidate-verify-finite-evidence
                 finite-evidence-status))

(export main)

(def (emit label value)
  (display label)
  (display "\t")
  (write value)
  (newline))

(def (main . _)
  (let* ((source
          (reasoning-source-snapshot
           'study-negation-count 1
           '((edge 2 ((1 2) (2 3)))
             (blocked 2 ((1 3)))
             (weight 2 ((2 4) (3 6)))
             (root 1 ((1))))))
         (datum
          '(candidate
             (relation path 2)
             (relation allowed 2)
             (relation weighted 2)
             (relation summary 2)
             (rule (path ?x ?y) (edge ?x ?y))
             (rule (path ?x ?z) (path ?x ?y) (edge ?y ?z))
             (rule (allowed ?x ?y)
                   (path ?x ?y) (not (blocked ?x ?y)))
             (rule (weighted ?x ?v)
                   (allowed ?x ?y) (weight ?y ?w)
                   (where (even? ?w))
                   (compute ?v (+ ?w ?w)))
             (rule (summary ?r ?n)
                   (root ?r)
                   (reduce ?n (count) (weighted ?r ?v)))
             (query summary 1 ?n)
             (limits 16 64 128)))
         (receipt (reasoning-attempt source datum))
         (spec (candidate-inspect source datum))
         (digest (reasoning-receipt-candidate-digest receipt))
         (status (reasoning-receipt-status receipt))
         (rows (reasoning-receipt-rows receipt))
         (certificate
          (candidate-finite-evidence source spec digest status rows 5000)))
    (emit "status" status)
    (emit "rows" rows)
    (emit "finite-status" (finite-evidence-status certificate))
    (emit "verdict"
          (candidate-verify-finite-evidence
           source spec digest status rows certificate 5000))))
