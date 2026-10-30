;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: workflow CI/CD dependency graphs report topology only.
;;; Invariant: tests inspect graph diagnostics without scheduling work.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 test-suite
                 check-equal?
                 )
        :agentic-ai-lab/modules/workflow/interface)

(export workflow-cicd-dependency-graph-test)

;;; Graph projections are plain alists so diagnostics can cross module and
;;; runtime boundaries without requiring POO object access in downstream tools.
;; : (-> Alist Symbol Value)
(def (cicd-graph-test-alist-ref entries key)
  (let (entry (assoc key entries))
    (if entry (cdr entry) #f)))

;;; Minimal checks isolate graph topology from sandbox profile resolution; the
;;; command is inert intent data and is never executed by these tests.
;; : (-> Symbol [Symbol] YuanxuCicdCheck)
(def (cicd-graph-test-check name dependency-refs)
  (yuanxu-cicd-check
   name
   'ci/check
   '("true")
   '()
   '()
   '()
   '()
   '()
   '(read :lines)
   'manifest-handoff
   (list (cons 'dependency-refs dependency-refs))))

;;; The suite keeps invalid graph shapes out of the broad check-map projection
;;; test so topology failures remain easy to diagnose and extend.
;; : TestSuite
(def workflow-cicd-dependency-graph-test
  (test-suite "workflow cicd dependency graph"
    (yuanxu-test-case "reports topology diagnostics without scheduling"
      (let* ((valid-graph
              (yuanxu-cicd-check-map->dependency-graph
               (yuanxu-cicd-check-map
                'valid
                (list (cicd-graph-test-check 'build '())
                      (cicd-graph-test-check 'test '(build))))))
             (duplicate-graph
              (yuanxu-cicd-check-map->dependency-graph
               (yuanxu-cicd-check-map
                'duplicate
                (list (cicd-graph-test-check 'build '())
                      (cicd-graph-test-check 'build '())))))
             (unresolved-graph
              (yuanxu-cicd-check-map->dependency-graph
               (yuanxu-cicd-check-map
                'unresolved
                (list (cicd-graph-test-check 'test '(missing))))))
             (cycle-graph
              (yuanxu-cicd-check-map->dependency-graph
               (yuanxu-cicd-check-map
                'cycle
                (list (cicd-graph-test-check 'build '(test))
                      (cicd-graph-test-check 'test '(build)))))))
        (check-equal? (cicd-graph-test-alist-ref valid-graph
                                                 'order-policy)
                      'declaration-topological-report)
        (check-equal? (cicd-graph-test-alist-ref valid-graph 'ready-order)
                      '(build test))
        (check-equal? (cicd-graph-test-alist-ref valid-graph
                                                 'unordered-nodes)
                      '())
        (check-equal? (cicd-graph-test-alist-ref valid-graph
                                                 'blocked-order?)
                      #f)
        (check-equal? (cicd-graph-test-alist-ref valid-graph 'valid?)
                      #t)
        (check-equal? (cicd-graph-test-alist-ref duplicate-graph
                                                 'duplicate-nodes)
                      '(build))
        (check-equal? (cicd-graph-test-alist-ref duplicate-graph
                                                 'diagnostics)
                      '(duplicate-nodes))
        (check-equal? (cicd-graph-test-alist-ref duplicate-graph
                                                 'ready-order)
                      '())
        (check-equal? (cicd-graph-test-alist-ref duplicate-graph
                                                 'unordered-nodes)
                      '(build build))
        (check-equal? (cicd-graph-test-alist-ref duplicate-graph
                                                 'blocked-order?)
                      #t)
        (check-equal? (cicd-graph-test-alist-ref duplicate-graph 'valid?)
                      #f)
        (check-equal? (cicd-graph-test-alist-ref unresolved-graph
                                                 'unresolved-dependency-refs)
                      '(missing))
        (check-equal? (cicd-graph-test-alist-ref unresolved-graph
                                                 'diagnostics)
                      '(unresolved-dependency-refs))
        (check-equal? (cicd-graph-test-alist-ref unresolved-graph
                                                 'ready-order)
                      '())
        (check-equal? (cicd-graph-test-alist-ref unresolved-graph
                                                 'unordered-nodes)
                      '(test))
        (check-equal? (cicd-graph-test-alist-ref unresolved-graph
                                                 'blocked-order?)
                      #t)
        (check-equal? (cicd-graph-test-alist-ref unresolved-graph 'valid?)
                      #f)
        (check-equal? (cicd-graph-test-alist-ref cycle-graph 'cycle-nodes)
                      '(build test))
        (check-equal? (cicd-graph-test-alist-ref cycle-graph 'diagnostics)
                      '(cycle-detected))
        (check-equal? (cicd-graph-test-alist-ref cycle-graph 'ready-order)
                      '())
        (check-equal? (cicd-graph-test-alist-ref cycle-graph
                                                 'unordered-nodes)
                      '(build test))
        (check-equal? (cicd-graph-test-alist-ref cycle-graph
                                                 'blocked-order?)
                      #t)
        (check-equal? (cicd-graph-test-alist-ref cycle-graph 'valid?)
                      #f)
        (check-equal? (cicd-graph-test-alist-ref cycle-graph
                                                 'runtime-executed)
                      #f)))))
