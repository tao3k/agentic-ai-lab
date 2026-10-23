;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        (only-in :yuanxu/utilities/algorithms
                 yuanxu-memoize yuanxu-read-datums/append-map
                 yuanxu-scheme-datum-find
                 yuanxu-make-value-index
                 yuanxu-value-index-put! yuanxu-value-index-ref
                 yuanxu-make-frontier-state
                 yuanxu-frontier-state-ready-ids
                 yuanxu-frontier-state-complete!))

(export core-funcs-test)

(def core-funcs-test
  (test-suite "Agentic AI Lab core algorithm functions"
    (yuanxu-test-case "streaming datum projection preserves order and empty results"
      (check
       (call-with-input-string
        "(first second)\nskip\n(third)\n"
        (lambda (port)
          (yuanxu-read-datums/append-map
           (lambda (datum) (if (pair? datum) datum '()))
           port)))
       => '(first second third)))
    (yuanxu-test-case "datum search shares quote and dotted-pair semantics"
      (let (find-target
            (lambda (datum)
              (yuanxu-scheme-datum-find
               (lambda (candidate)
                 (and (symbol? candidate)
                      (eq? candidate 'target)
                      candidate))
               datum)))
        (check (find-target '#(ignored (nested target))) => 'target)
        (check (find-target '(head . target)) => 'target)
        (check (find-target '(head '(target))) => #f)))
    (yuanxu-test-case "memoization indexes keys and retains false values"
      (let* ((calls 0)
             (memoized
              (yuanxu-memoize
               (lambda (value) value)
               (lambda (_value) (set! calls (+ calls 1)) #f))))
        (check (memoized '(same key)) => #f)
        (check (memoized '(same key)) => #f)
        (check calls => 1)))
    (yuanxu-test-case "runner value indexes distinguish missing ids from false values"
      (let (index (yuanxu-make-value-index))
        (yuanxu-value-index-put! index '(node false) #f)
        (check
         (call-with-values
          (lambda () (yuanxu-value-index-ref index '(node false)))
          cons)
         => '(#t . #f))
        (check
         (call-with-values
          (lambda () (yuanxu-value-index-ref index '(node missing)))
          cons)
         => '(#f . #f))))
    (yuanxu-test-case "incremental frontiers retain canonical node order"
      (let* ((nodes '((root-a 0 ())
                      (after-a 1 (root-a))
                      (root-b 2 ())
                      (join 3 (after-a root-b))))
             (accessor-calls 0)
             (state
              (yuanxu-make-frontier-state
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
        (check (yuanxu-frontier-state-ready-ids state)
               => '(root-a root-b))
        (yuanxu-frontier-state-complete! state 'root-a)
        (check (yuanxu-frontier-state-ready-ids state)
               => '(after-a root-b))
        (yuanxu-frontier-state-complete! state 'after-a)
        (check (yuanxu-frontier-state-ready-ids state)
               => '(root-b))
        (yuanxu-frontier-state-complete! state 'root-b)
        (check (yuanxu-frontier-state-ready-ids state)
               => '(join))
        ;; Completion updates dependency counts directly; it never rescans
        ;; the source nodes through their accessors.
        (check accessor-calls => 12)))))
