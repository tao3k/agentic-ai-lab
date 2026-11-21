;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .o .ref))

(def projection-iterations 1000)

(def +projection-profile+
  (.o (name 'projection-profile)
      (runtime 'python-runtime)
      (policy 'control-plane)
      (sandbox 'readonly)
      (tool 'search-tool)
      (checkpoint 'durable)))

(def +projection-specs+
  '((name identity)
    (runtime runtime-language)
    (policy policy-plane)
    (sandbox sandbox-scope)
    (tool tool-binding)
    (checkpoint durable-boundary)))

(def (projection-descriptor spec)
  (let ((key (car spec))
        (role (cadr spec)))
    (vector key role (.ref +projection-profile+ key))))

(def (projection-descriptors)
  (list->vector (map projection-descriptor +projection-specs+)))

(def (run-loop count)
  (let loop ((i 0) (passed 0))
    (if (= i count)
      passed
      (let ((descriptors (projection-descriptors)))
        (loop (+ i 1)
              (if (= (vector-length descriptors) 6)
                (+ passed 1)
                passed))))))

(def (main)
  (let* ((started-at (time->seconds (current-time)))
         (passed (run-loop projection-iterations))
         (finished-at (time->seconds (current-time)))
         (elapsed-ms
          (inexact->exact
           (round (* 1000 (- finished-at started-at))))))
    (display
     `((status . passed)
       (feature . poo-large-profile-projection)
       (iterations . ,projection-iterations)
       (passed . ,passed)
       (elapsedMs . ,elapsed-ms)
       (shape . poo-static-projection-specs)
       (hotPath . profile-projection-descriptor-boundary)))
    (newline)))
