;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         :std/test
        (only-in :core/utilities/algorithms
                 poo-flow-memoize poo-flow-read-datums/append-map
                 poo-flow-scheme-datum-find
                 poo-flow-make-value-index
                 poo-flow-value-index-put! poo-flow-value-index-ref
                 poo-flow-make-frontier-state
                 poo-flow-frontier-state-ready-ids
                 poo-flow-frontier-state-complete!))

(export core-funcs-test)

(def core-funcs-test
  (test-suite "POO Flow core algorithm functions"
    (poo-flow-test-case "streaming datum projection preserves order and empty results"
      (check
       (call-with-input-string
        "(first second)\nskip\n(third)\n"
        (lambda (port)
          (poo-flow-read-datums/append-map
           (lambda (datum) (if (pair? datum) datum '()))
           port)))
       => '(first second third)))
    (poo-flow-test-case "datum search shares quote and dotted-pair semantics"
      (let (find-target
            (lambda (datum)
              (poo-flow-scheme-datum-find
               (lambda (candidate)
                 (and (symbol? candidate)
                      (eq? candidate 'target)
                      candidate))
               datum)))
        (check (find-target '#(ignored (nested target))) => 'target)
        (check (find-target '(head . target)) => 'target)
        (check (find-target '(head '(target))) => #f)))
    (poo-flow-test-case "memoization indexes keys and retains false values"
      (let* ((calls 0)
             (memoized
              (poo-flow-memoize
               (lambda (value) value)
               (lambda (_value) (set! calls (+ calls 1)) #f))))
        (check (memoized '(same key)) => #f)
        (check (memoized '(same key)) => #f)
        (check calls => 1)))
    (poo-flow-test-case "runner value indexes distinguish missing ids from false values"
      (let (index (poo-flow-make-value-index))
        (poo-flow-value-index-put! index '(node false) #f)
        (check
         (call-with-values
          (lambda () (poo-flow-value-index-ref index '(node false)))
          cons)
         => '(#t . #f))
        (check
         (call-with-values
          (lambda () (poo-flow-value-index-ref index '(node missing)))
          cons)
         => '(#f . #f))))
    (poo-flow-test-case "incremental frontiers retain canonical node order"
      (let* ((nodes '((root-a 0 ())
                      (after-a 1 (root-a))
                      (root-b 2 ())
                      (join 3 (after-a root-b))))
             (accessor-calls 0)
             (state
              (poo-flow-make-frontier-state
               nodes
               (lambda (node)
                 (set! accessor-calls (+ accessor-calls 1))
                 (car node))
               (lambda (node)
                 (set! accessor-calls (+ accessor-calls 1))
                 (cadr node))
               (lambda (node)
                 (set! accessor-calls (+ accessor-calls 1))
                 (caddr node)))))
        (check accessor-calls => 12)
        (check (poo-flow-frontier-state-ready-ids state)
               => '(root-a root-b))
        (poo-flow-frontier-state-complete! state 'root-a)
        (check (poo-flow-frontier-state-ready-ids state)
               => '(after-a root-b))
        (poo-flow-frontier-state-complete! state 'after-a)
        (check (poo-flow-frontier-state-ready-ids state)
               => '(root-b))
        (poo-flow-frontier-state-complete! state 'root-b)
        (check (poo-flow-frontier-state-ready-ids state)
               => '(join))
        ;; Completion updates dependency counts directly; it never rescans
        ;; the source nodes through their accessors.
        (check accessor-calls => 12)))))
