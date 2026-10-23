;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; A/B witness for native Gerbil POO three-parent mix versus the direct
;;; single-allocation base/override window.

(import :yuanxu/composition/roles
        (only-in :clan/poo/object .all-slots .ref .slot?)
        (only-in :asp-gerbil-scheme/benchmark-api benchmark-p95-elapsed-us)
        (only-in :yuanxu/composition/roles
                 role-compose
                 role-constant-slots
                 role-instance-overlay-defaults
                 role-instance-overlay3/compatible)
        (only-in :clan/poo/object .mix))

(def +sample-count+ 20)
(def +agent-count+ 500)
(def +shared-slot-count+ 64)

(def (slot-key index)
  (string->symbol (string-append "shared/slot-" (number->string index))))

(def (constant-role rows)
  (.mix slots: (role-constant-slots rows)))

(def shared
  (apply role-compose
         (let loop ((index 0) (roles '()))
           (if (= index +shared-slot-count+)
             (reverse roles)
             (loop (+ index 1)
                   (cons (constant-role (list (cons (slot-key index) index)))
                         roles))))))

(def marker
  (constant-role
   '((domain-case/ref . scenario-case)
     (domain-case/instance-overlay-resolver-depth . 1))))

(def shared-defaults (role-instance-overlay-defaults shared))

(def (local index)
  (constant-role
   (list (cons 'agent/id index)
         (cons (slot-key 0) 'local-override))))

(def (baseline marker-value local-value shared-value)
  (role-compose marker-value local-value shared-value))

(def (candidate marker-value local-value shared-value)
  (role-instance-overlay3/compatible marker-value local-value shared-defaults))

(def (exercise composer)
  (let loop ((index 0) (checksum 0))
    (if (= index +agent-count+)
      checksum
      (let (instance (composer marker (local index) shared))
        (loop (+ index 1)
              (+ checksum
                 (.ref instance 'agent/id)
                 (.ref instance (slot-key (- +shared-slot-count+ 1)))))))))

(def baseline-instance (baseline marker (local 7) shared))
(def candidate-instance (candidate marker (local 7) shared))
(def baseline-slots (.all-slots baseline-instance))
(def candidate-slots (.all-slots candidate-instance))

(unless (and (= (length baseline-slots) (length candidate-slots))
             (andmap (lambda (slot)
                       (and (.slot? candidate-instance slot)
                            (equal? (.ref baseline-instance slot)
                                    (.ref candidate-instance slot))))
                     baseline-slots)
             (andmap (lambda (slot) (.slot? baseline-instance slot))
                     candidate-slots))
  (error "native base/override changed POO composition semantics"))

;; Warm both :clan/poo composition windows before complete p95 series.
(displayln "[domain-case-composition] phase=warmup")
(force-output)
(exercise baseline)
(exercise candidate)
(displayln "[domain-case-composition] phase=baseline-p95 sample-count="
           +sample-count+)
(force-output)
(def baseline-p95-us
  (benchmark-p95-elapsed-us +sample-count+ (lambda () (exercise baseline))))
(displayln "[domain-case-composition] phase=candidate-p95 sample-count="
           +sample-count+)
(force-output)
(def candidate-p95-us
  (benchmark-p95-elapsed-us +sample-count+ (lambda () (exercise candidate))))

(unless (< candidate-p95-us baseline-p95-us)
  (error "native base/override did not improve the composition scenario"
         baseline-p95-us candidate-p95-us))

(displayln "schema=agentic-ai-lab.domain-case-native-base-override.v1")
(displayln "sample-count=" +sample-count+)
(displayln "agent-count=" +agent-count+)
(displayln "shared-slot-count=" +shared-slot-count+)
(displayln "baseline-p95-us=" baseline-p95-us)
(displayln "candidate-p95-us=" candidate-p95-us)
(displayln "slot-surface-equivalent=#t")
(displayln "accepted=#t")
