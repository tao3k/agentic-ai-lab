;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: scale gate for the indexed workflow dependency graph projection.
;;; Invariant: fixtures are constructed before timing; samples measure only
;;; Scheme control-plane graph analysis and never execute workflow commands.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test check-equal? test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api benchmark-elapsed-us)
        "../support/performance"
        :agentic-ai-lab/modules/workflow/interface)

(export workflow-cicd-graph-performance-test)

(def (workflow-cicd-graph-performance-ref rows key)
  (let (entry (assoc key rows))
    (and entry (cdr entry))))

(def (workflow-cicd-graph-performance-name index)
  (string->symbol (string-append "check/" (number->string index))))

(def (workflow-cicd-graph-performance-check index)
  (let (name (workflow-cicd-graph-performance-name index))
    (yuanxu-cicd-check
     name 'ci/check '("true") '() '() '() '() '() '(read :lines)
     'manifest-handoff
     (list
      (cons 'dependency-refs
            (if (zero? index)
              '()
              (list (workflow-cicd-graph-performance-name (- index 1)))))))))

(def (workflow-cicd-graph-performance-map count)
  (yuanxu-cicd-check-map
   (string->symbol (string-append "scale/" (number->string count)))
   (agentic-ai-lab-performance-build-list
    count workflow-cicd-graph-performance-check)))

(def (workflow-cicd-graph-performance-project check-map)
  (let (graph (yuanxu-cicd-check-map->dependency-graph check-map))
    (list
     (cons 'node-count
           (length (workflow-cicd-graph-performance-ref graph 'nodes)))
     (cons 'edge-count
           (length (workflow-cicd-graph-performance-ref graph 'edges)))
     (cons 'ready-count
           (length (workflow-cicd-graph-performance-ref graph 'ready-order)))
     (cons 'valid? (workflow-cicd-graph-performance-ref graph 'valid?)))))

(def (workflow-cicd-graph-performance-median values)
  (let (ordered (list-sort < (append values '())))
    (list-ref ordered (quotient (length ordered) 2))))

;;; Alternate pair order so process scheduling and cache warmth affect both
;;; graph sizes instead of becoming a false scaling improvement.
(def (workflow-cicd-graph-performance-paired attempts small-map large-map)
  (let loop ((remaining attempts)
             (small-first? #t)
             (small-samples '())
             (large-samples '()))
    (if (zero? remaining)
      (list
       (cons 'small-samples-us (reverse small-samples))
       (cons 'large-samples-us (reverse large-samples))
       (cons 'small-median-us
             (workflow-cicd-graph-performance-median small-samples))
       (cons 'large-median-us
             (workflow-cicd-graph-performance-median large-samples)))
      (let* ((first-map (if small-first? small-map large-map))
             (second-map (if small-first? large-map small-map))
             (first-us
              (benchmark-elapsed-us
               (lambda () (workflow-cicd-graph-performance-project first-map))))
             (second-us
              (benchmark-elapsed-us
               (lambda () (workflow-cicd-graph-performance-project second-map)))))
        (loop (- remaining 1)
              (not small-first?)
              (cons (if small-first? first-us second-us) small-samples)
              (cons (if small-first? second-us first-us) large-samples))))))

(def workflow-cicd-graph-performance-test
  (test-suite
   "workflow cicd indexed graph performance"
   (yuanxu-test-case
    "2000-node chain remains bounded and scales below quadratic growth"
    (let* ((small-count 1000)
           (large-count 2000)
           (small-map (workflow-cicd-graph-performance-map small-count))
           (large-map (workflow-cicd-graph-performance-map large-count))
           (summary (workflow-cicd-graph-performance-project large-map))
           (_warm-small (workflow-cicd-graph-performance-project small-map))
           (_warm-large (workflow-cicd-graph-performance-project large-map))
           (timings
            (workflow-cicd-graph-performance-paired 5 small-map large-map))
           (small-us
            (workflow-cicd-graph-performance-ref timings 'small-median-us))
           (large-us
            (workflow-cicd-graph-performance-ref timings 'large-median-us))
           (ratio (if (zero? small-us) 0 (/ large-us small-us))))
      (display "[agentic-ai-lab-benchmark] workflow-cicd-indexed-graph ")
      (write (list (cons 'small-count small-count)
                   (cons 'large-count large-count)
                   (cons 'small-samples-us
                         (workflow-cicd-graph-performance-ref
                          timings 'small-samples-us))
                   (cons 'large-samples-us
                         (workflow-cicd-graph-performance-ref
                          timings 'large-samples-us))
                   (cons 'small-median-us small-us)
                   (cons 'large-median-us large-us)
                   (cons 'growth-ratio ratio)))
      (newline)
      (force-output)
      (check-equal?
       (workflow-cicd-graph-performance-ref summary 'node-count) large-count)
      (check-equal?
       (workflow-cicd-graph-performance-ref summary 'edge-count)
       (- large-count 1))
      (check-equal?
       (workflow-cicd-graph-performance-ref summary 'ready-count) large-count)
      (check-equal?
       (workflow-cicd-graph-performance-ref summary 'valid?) #t)
      (check-equal? (<= large-us 2000000) #t)
      (check-equal? (<= ratio 3.5) #t)))))
