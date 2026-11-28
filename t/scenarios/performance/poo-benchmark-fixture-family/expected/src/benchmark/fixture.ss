;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Expected: fixture contract fields are projected once into a POO family.

(import (only-in :clan/poo/object .o .ref))

(def benchmark-fixture-family
  (.o (kind 'benchmark-fixture-family)
      (name 'benchmark-fixture-family)
      (source 'agentic-ai-lab.performance.benchmark-fixture)))

(def (benchmark-fixture feature-value rss-value metric-value unit-value target-value observed-value)
  (.o (family 'benchmark-fixture-family)
      (feature feature-value)
      (max-rss-mb rss-value)
      (memory-metric metric-value)
      (memory-unit unit-value)
      (target-total target-value)
      (observed-total observed-value)))

(def benchmark-fixture-value
  (benchmark-fixture 'poo-benchmark-fixture-family
                     512
                     'resident-set-size
                     "MB"
                     '25ms
                     '18ms))

(def (benchmark-fixture-hot-loop fixture rounds)
  (let (rss-value (.ref fixture 'max-rss-mb))
    (let loop ((round 0) (accepted 0))
      (if (>= round rounds)
        accepted
        (loop (+ round 1)
              (if (= rss-value 512) (+ accepted 1) accepted))))))
