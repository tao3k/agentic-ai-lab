;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .o .alist))

;;; Scenario expected: POO remains primary, but the hot loop works over a
;;; single boundary snapshot and cached scalar.

(def +report-profile+
  (.o (field-0 0)
      (field-1 1)
      (field-2 2)
      (field-3 3)
      (field-4 4)
      (field-5 5)))

(def (build-report-profile)
  +report-profile+)

(def (sum-report-profile profile)
  (let loop ((rest (.alist profile)) (total 0))
    (if (null? rest)
      total
      (loop (cdr rest) (+ total (cdar rest))))))

(def (score-report rounds)
  (let ((step (sum-report-profile (build-report-profile))))
    (let loop ((i 0) (total 0))
      (if (= i rounds)
        total
        (loop (+ i 1) (+ total step))))))
