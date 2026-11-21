;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .o .ref object<-alist))

;;; Scenario input: rejected construction shape.
;;; It rebuilds the POO object from an alist inside the loop and reads slots
;;; repeatedly after construction.

(def +report-profile-alist+
  '((name . construction-profile)
    (weight . 7)
    (scale . 11)
    (policy . runtime-poo)
    (runtime . control-plane)))

(def (build-report-profile)
  (object<-alist +report-profile-alist+))

(def (score-report rounds)
  (let loop ((i 0) (total 0))
    (if (= i rounds)
      total
      (let ((profile (build-report-profile)))
        (loop (+ i 1)
              (+ total
                 (.ref profile 'weight)
                 (.ref profile 'scale)))))))
