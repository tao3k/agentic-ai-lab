;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Executable witness that POO CLOS projects upstream C4 without a second CPL.
(import (only-in :gerbil/runtime/gambit current-time time->seconds)
        (only-in :clan/poo/object
                 .ref .slot? compute-precedence-list!)
        (only-in :yuanxu/poo-clos/objects poo-clos-class-precedence-list)
        :yuanxu/poo-clos/classes)

(def +sample-count+ 40)

(def (name prefix index)
  (string->symbol
   (string-append prefix "-" (number->string index))))

(def (make-pedalo index)
  (let* ((boat (poo-clos-class (name "boat" index)))
         (day-boat
          (poo-clos-class (name "day-boat" index)
                          direct-superclasses: (list boat)))
         (wheel-boat
          (poo-clos-class (name "wheel-boat" index)
                          direct-superclasses: (list boat)))
         (engineless
          (poo-clos-class (name "engineless" index)
                          direct-superclasses: (list day-boat)))
         (pedal-wheel-boat
          (poo-clos-class
           (name "pedal-wheel-boat" index)
           direct-superclasses: (list engineless wheel-boat)))
         (small-multihull
          (poo-clos-class (name "small-multihull" index)
                          direct-superclasses: (list day-boat)))
         (small-catamaran
          (poo-clos-class (name "small-catamaran" index)
                          direct-superclasses: (list small-multihull))))
    (poo-clos-class
     (name "pedalo" index)
     direct-superclasses: (list pedal-wheel-boat small-catamaran))))

(def (native-class-precedence-list class-value)
  (filter-map
   (lambda (prototype)
     (and (.slot? prototype '%poo-clos-class)
          (.ref prototype '%poo-clos-class)))
   (compute-precedence-list! (.ref class-value 'instance-prototype))))

(def (same-identities? left right)
  (and (= (length left) (length right))
       (andmap eq? left right)))

(def (elapsed-ms thunk)
  (let* ((started (time->seconds (current-time)))
         (value (thunk))
         (elapsed (* 1000.0 (- (time->seconds (current-time)) started))))
    (values value elapsed)))

(def (sample thunk count)
  (let loop ((index 0) (times '()) (last #f))
    (if (= index count)
      (values last (reverse times))
      (let-values (((value elapsed) (elapsed-ms (lambda () (thunk index)))))
        (loop (+ index 1) (cons elapsed times) value)))))

(def (median values)
  (let (ordered (list-sort < values))
    (list-ref ordered (quotient (length ordered) 2))))

;; Warm the module and the upstream C4 caches before collecting the 40-sample
;; construction receipt. Each measured graph has fresh metaobject identities.
(make-pedalo -1)
(let-values (((pedalo construction-times)
              (sample (lambda (index) (make-pedalo index)) +sample-count+)))
  (let* ((projected (poo-clos-class-precedence-list pedalo))
         (native (native-class-precedence-list pedalo))
         (expected
          (list (name "pedalo" (- +sample-count+ 1))
                (name "pedal-wheel-boat" (- +sample-count+ 1))
                (name "engineless" (- +sample-count+ 1))
                (name "small-catamaran" (- +sample-count+ 1))
                (name "small-multihull" (- +sample-count+ 1))
                (name "day-boat" (- +sample-count+ 1))
                (name "wheel-boat" (- +sample-count+ 1))
                (name "boat" (- +sample-count+ 1))
                'standard-object))
         (actual (map (lambda (class-value) (.ref class-value 'identity))
                      projected)))
    (unless (same-identities? projected native)
      (error "POO CLOS precedence diverged from native prototype C4"))
    (unless (equal? actual expected)
      (error "unexpected native C4 order" actual expected))
    (let-values (((_ warm-times)
                  (sample
                   (lambda (_index)
                     (poo-clos-class-precedence-list pedalo))
                   +sample-count+)))
      (display "schema=agentic-ai-lab.poo-clos-native-c4.v1\n")
      (display "sample-count=") (display +sample-count+) (newline)
      (display "class-count=") (display (length projected)) (newline)
      (display "native-metaobject-identity=#t\n")
      (display "parallel-cpl=#f\n")
      (display "construction-p50-ms=")
      (display (median construction-times)) (newline)
      (display "warm-precedence-p50-ms=")
      (display (median warm-times)) (newline)
      (display "accepted=#t\n"))))
