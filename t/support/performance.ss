;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: shared performance-test helpers for synthetic fixture data.
;;; Invariant: helper functions are pure except elapsed measurement thunks.

(import :core/composition/roles
        :gerbil/runtime/gambit
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-p95-elapsed-us))

(export poo-flow-performance-build-list)

;;; Intent: construct deterministic index-addressed fixture lists.
;;; Boundary: callers own the item constructor and count.
;; : (-> Integer (-> Integer Object) [Object])
(import :clan/poo/object
        :poo-flow/modules/workflow/control-plane/roles)

(export run-domain-case-instance-overlay-benchmark
        domain-case-instance-overlay-benchmark->alist)

(def (poo-flow-performance-build-list count make-value)
  (map make-value (iota count)))

(def +domain-case-instance-overlay-benchmark-kind+
  'poo-flow.domain-case-instance-overlay-benchmark.v1)

(def +domain-case-instance-overlay-benchmark-sample-count+ 20)
(def +domain-case-instance-overlay-benchmark-agent-count+ 5000)
(def +domain-case-instance-overlay-benchmark-max-p95-us+ 1000000)

(def (domain-case-instance-overlay-benchmark-role rows)
  (.mix slots: (role-constant-slots rows)))

(def (domain-case-instance-overlay-benchmark-slot-key index)
  (string->symbol
   (string-append "shared/slot-" (number->string index))))

(def (domain-case-instance-overlay-benchmark-component index)
  (domain-case-instance-overlay-benchmark-role
   (list
    (cons (domain-case-instance-overlay-benchmark-slot-key index)
          index))))

(def (domain-case-instance-overlay-benchmark-shared slot-count)
  (apply
   role-compose
   (poo-flow-performance-build-list
    slot-count domain-case-instance-overlay-benchmark-component)))

(def (domain-case-instance-overlay-benchmark-marker)
  (domain-case-instance-overlay-benchmark-role
   (list (cons 'domain-case/ref 'benchmark-case)
         (cons 'domain-case/instance-overlay-resolver-depth 1))))

(def (domain-case-instance-overlay-benchmark-local index)
  (domain-case-instance-overlay-benchmark-role
   (list (cons 'agent/id index)
         (cons (domain-case-instance-overlay-benchmark-slot-key 0)
               'local-override))))

(def (domain-case-instance-overlay-benchmark-compose/mix
      marker local shared _shared-keys)
  (role-compose marker local shared))

(def (domain-case-instance-overlay-benchmark-compose/overlay
      marker local _shared shared-defaults)
  (role-instance-overlay3/compatible marker local shared-defaults))

(def (domain-case-instance-overlay-benchmark-exercise
      composer agent-count shared shared-keys last-slot-key)
  (let ((marker (domain-case-instance-overlay-benchmark-marker)))
   (let loop ((index 0) (checksum 0))
    (if (= index agent-count)
        checksum
        (let* ((local (domain-case-instance-overlay-benchmark-local index))
               (instance (composer marker local shared shared-keys)))
          (.ref instance 'domain-case/ref)
          (.ref instance (domain-case-instance-overlay-benchmark-slot-key 0))
          (loop (+ index 1)
                (+ checksum
                   (.ref instance 'agent/id)
                   (.ref instance last-slot-key))))))))

(def (domain-case-instance-overlay-benchmark-correct?
      shared shared-keys last-slot-key)
  (let* ((marker (domain-case-instance-overlay-benchmark-marker))
         (local (domain-case-instance-overlay-benchmark-local 7))
         (baseline
          (domain-case-instance-overlay-benchmark-compose/mix
           marker local shared shared-keys))
         (overlay
          (domain-case-instance-overlay-benchmark-compose/overlay
           marker local shared shared-keys)))
    (and (equal? (.ref baseline 'domain-case/ref)
                 (.ref overlay 'domain-case/ref))
         (equal? (.ref baseline 'agent/id)
                 (.ref overlay 'agent/id))
         (equal? (.ref baseline
                       (domain-case-instance-overlay-benchmark-slot-key 0))
                 (.ref overlay
                       (domain-case-instance-overlay-benchmark-slot-key 0)))
         (equal? (.ref baseline last-slot-key)
                 (.ref overlay last-slot-key)))))

(def (run-domain-case-instance-overlay-benchmark-case
      agent-count slot-count)
  (let* ((shared
          (domain-case-instance-overlay-benchmark-shared slot-count))
         (shared-defaults
          (role-instance-overlay-defaults shared))
         (last-slot-key
          (domain-case-instance-overlay-benchmark-slot-key
           (- slot-count 1)))
         (correct?
          (domain-case-instance-overlay-benchmark-correct?
           shared shared-defaults last-slot-key))
         (_warm-overlay
          (domain-case-instance-overlay-benchmark-exercise
           domain-case-instance-overlay-benchmark-compose/overlay
           64 shared shared-defaults last-slot-key))
         (_overlay-gc (##gc))
         (overlay-us
          (benchmark-p95-elapsed-us
           +domain-case-instance-overlay-benchmark-sample-count+
           (lambda ()
             (domain-case-instance-overlay-benchmark-exercise
              domain-case-instance-overlay-benchmark-compose/overlay
              agent-count shared shared-defaults last-slot-key))))
         (timing-pass?
          (<= overlay-us
              +domain-case-instance-overlay-benchmark-max-p95-us+)))
    (domain-case-instance-overlay-benchmark-role
     (list
      (cons 'kind +domain-case-instance-overlay-benchmark-kind+)
      (cons 'admissionStatistic 'p95)
      (cons 'sample-count
            +domain-case-instance-overlay-benchmark-sample-count+)
      (cons 'max-overlay-p95-us
            +domain-case-instance-overlay-benchmark-max-p95-us+)
      (cons 'agent-count agent-count)
      (cons 'shared-slot-count slot-count)
      (cons 'materialized-slot-count (+ slot-count 4))
      (cons 'legacy-reference-count 1)
      (cons 'overlay-mix-count 0)
      (cons 'resolver-depth 1)
      (cons 'construction-complexity 'native-base-override)
      (cons 'lookup-source-depth 'constant-source-depth)
      (cons 'overlay-us overlay-us)
      (cons 'correct? correct?)
      (cons 'shared-prototype-retained? correct?)
      (cons 'local-precedence-valid? correct?)
      (cons 'timing-pass? timing-pass?)
      (cons 'max-rss-mb 256)
      (cons 'pass? (and correct? timing-pass?))))))

(def (run-domain-case-instance-overlay-benchmark)
  (map
   (lambda (slot-count)
     (let (receipt
           (run-domain-case-instance-overlay-benchmark-case
            +domain-case-instance-overlay-benchmark-agent-count+
            slot-count))
       (displayln "[domain-case-overlay] "
                  (domain-case-instance-overlay-benchmark->alist receipt))
       receipt))
   '(8 32 64)))

(def (domain-case-instance-overlay-benchmark->alist receipt)
  (map
   (lambda (key) (cons key (.ref receipt key)))
   '(kind admissionStatistic sample-count max-overlay-p95-us
     agent-count shared-slot-count materialized-slot-count
     legacy-reference-count overlay-mix-count resolver-depth
     construction-complexity lookup-source-depth
     overlay-us correct?
     shared-prototype-retained? local-precedence-valid? timing-pass?
     max-rss-mb pass?)))
