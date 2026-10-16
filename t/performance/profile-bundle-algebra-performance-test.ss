;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test test-suite check-equal?)
        (only-in :clan/poo/object .o .ref)
        (only-in :core/module-system/schema/relations poo-flow-semantic-identity)
        (only-in :core/module-system/authoring/roles poo-flow-semantic-module)
        :core/profile-composition/profile-bundle)

(export profile-bundle-algebra-performance-test)

(def +profile-bundle-performance-counts+ '(1000 5000))
(def +profile-bundle-performance-maximum-ms+ 20000)

(def (profile-bundle-performance-identity index)
  (string->symbol
   (string-append "profile-" (number->string index))))

(def (profile-bundle-performance-build-list count make-value)
  (let loop ((index 0) (out '()))
    (if (= index count)
      (reverse out)
      (loop (+ index 1) (cons (make-value index) out)))))

(def (profile-bundle-performance-case count)
  (let* ((identities
          (profile-bundle-performance-build-list
           count profile-bundle-performance-identity))
         (profiles-value
          (map (lambda (profile-identity-value)
                 (.o identity: profile-identity-value
                     name: profile-identity-value
                     runtime-executed?: #f))
               identities))
         (exports
          (map (lambda (profile-identity-value profile-value)
                 (poo-flow-profile-export
                  profile-identity-value profile-value))
               identities
               profiles-value))
         (started (current-jiffy))
         (module-value
          (poo-flow-semantic-module
           (poo-flow-semantic-identity 'performance 'profile-bundle)
           profiles: (apply poo-flow-module-profiles exports)))
         (selection
          (poo-flow-select-module-profiles
           module-value 'profile-bundle identities))
         (composed (compose profiles selection selection))
         (elapsed-ms
          (quotient
           (* (- (current-jiffy) started) 1000)
           (jiffies-per-second))))
    (displayln
     "[poo-flow-benchmark] profile-bundle count=" count
     " elapsedMs=" elapsed-ms
     " maxMs=" +profile-bundle-performance-maximum-ms+
     " indexedExports=" count
     " composedProfiles=" (length (.ref composed 'profiles)))
    (force-output)
    (check-equal? (length (.ref composed 'profiles)) count)
    (check-equal? (length (.ref composed 'selection-proofs)) count)
    (check-equal? (length (.ref composed 'module-bindings)) 1)
    (check-equal? (<= elapsed-ms +profile-bundle-performance-maximum-ms+) #t)))

(def profile-bundle-algebra-performance-test
  (test-suite
   "ProfileBundle indexed selection and idempotent composition performance"
   (poo-flow-test-case "1000 and 5000 Profile values stay within the hard gate"
     (for-each profile-bundle-performance-case
               +profile-bundle-performance-counts+))))
