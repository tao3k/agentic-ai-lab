;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test (only-in :clan/poo/object .ref)
        :core/object-family/role-syntax
        :poo-flow/modules/search-engine/interface)
(export search-attempt-test)
(def stage (poo-flow-search-stage 'a 'acquire '() 'source 'candidates
                                   poo-flow-search-acquisition-role))
(def (initial) (poo-flow-search-attempt-state stage "generation" "config" "cut"))
(def target-stage (poo-flow-search-stage 'c 'merge '() 'candidates 'candidates poo-flow-search-refinement-role))
(def (downstream) (poo-flow-search-attempt-state target-stage "generation" "config" "cut"))
(def (rejected? thunk)
  (with-catch (lambda (_) #t) (lambda () (thunk) #f)))
(def search-attempt-test
  (test-suite "Search temporal attempt admission"
    (test-case "current attempt settles exactly once"
      (let* ((issued (poo-flow-search-attempt-issue (initial)))
             (state (.ref issued 'state)) (request (.ref issued 'request))
             (done (poo-flow-search-attempt-settle state request)))
        (check (.ref done 'active) => #f)
        (check (rejected? (lambda () (poo-flow-search-attempt-settle done request))) => #t)
        (check (rejected? (lambda () (poo-flow-search-attempt-issue state))) => #t)))
    (test-case "all original identity fields are admitted"
      (let* ((issued (poo-flow-search-attempt-issue (initial)))
             (state (.ref issued 'state)) (request (.ref issued 'request)))
        (for-each
         (lambda (wrong)
           (check (rejected? (lambda () (poo-flow-search-attempt-settle state wrong))) => #t))
         (list
          (poo-core-role-object (slots ((stage (poo-flow-search-stage 'b 'acquire '() 'source 'candidates poo-flow-search-acquisition-role)))) (supers request))
          (poo-core-role-object (slots ((attempt 99))) (supers request))
          (poo-core-role-object (slots ((revision 1))) (supers request))
          (poo-core-role-object (slots ((source-cut "foreign"))) (supers request))
          (poo-core-role-object (slots ((generation "foreign"))) (supers request))
          (poo-core-role-object (slots ((configuration "foreign"))) (supers request))))))
    (test-case "revision fences old work even with an unchanged cut"
      (let* ((issued (poo-flow-search-attempt-issue (initial)))
             (old (.ref issued 'request))
             (revised (poo-flow-search-attempt-revise (.ref issued 'state) "cut"))
             (again (poo-flow-search-attempt-issue revised))
             (state (.ref again 'state)))
        (check (.ref (.ref again 'request) 'attempt) => 1)
        (check (.ref state 'revision) => 1)
        (check (rejected? (lambda () (poo-flow-search-attempt-settle state old))) => #t)
        (check (.ref (poo-flow-search-attempt-settle state (.ref again 'request)) 'active) => #f)))
    (test-case "retirement rejects issue completion and revision"
      (let* ((issued (poo-flow-search-attempt-issue (initial)))
             (request (.ref issued 'request))
             (state (poo-flow-search-attempt-retire (.ref issued 'state))))
        (check (.ref (poo-flow-search-attempt-retire state) 'retired?) => #t)
        (check (rejected? (lambda () (poo-flow-search-attempt-issue state))) => #t)
        (check (rejected? (lambda () (poo-flow-search-attempt-settle state request))) => #t)
        (check (rejected? (lambda () (poo-flow-search-attempt-revise state "new"))) => #t)))
    (test-case "request source proposals do not mutate the retained scope"
      (let* ((issued (poo-flow-search-attempt-issue (initial)))
             (state (.ref issued 'state)) (request (.ref issued 'request)))
        (string-set! (.ref request 'source-cut) 0 #\x)
        (check (.ref state 'source-cut) => "cut")
        (check (rejected? (lambda () (poo-flow-search-attempt-settle state request))) => #t)))
    (test-case "fan-in waits for every exact predecessor completion"
      (let* ((a (poo-flow-search-attempt-issue (initial)))
             (b-stage (poo-flow-search-stage 'b 'acquire '() 'source 'candidates poo-flow-search-acquisition-role))
             (b (poo-flow-search-attempt-issue
                 (poo-flow-search-attempt-state b-stage "generation" "config" "cut")))
             (target (downstream))
             (required (list (.ref a 'request) (.ref b 'request)))
             (done-a (poo-flow-search-attempt-complete (.ref a 'state) (.ref a 'request)))
             (done-b (poo-flow-search-attempt-complete (.ref b 'state) (.ref b 'request))))
        (check (poo-flow-search-attempt-ready? target '() '()) => #t)
        (check (rejected? (lambda () (poo-flow-search-attempt-issue-ready target required (list done-a done-a)))) => #t)
        (check (poo-flow-search-attempt-ready? target required (list done-a done-b)) => #t)
        (check (.ref (.ref (poo-flow-search-attempt-issue-ready target required (list done-a done-b)) 'request) 'attempt) => 0)))
    (test-case "revision and execution scope isolate predecessor evidence"
      (let* ((a (poo-flow-search-attempt-issue (initial)))
             (old (poo-flow-search-attempt-complete (.ref a 'state) (.ref a 'request)))
             (revised (poo-flow-search-attempt-revise (.ref old 'state) "cut"))
             (fresh (poo-flow-search-attempt-issue revised))
             (required (list (.ref fresh 'request)))
             (done (poo-flow-search-attempt-complete (.ref fresh 'state) (.ref fresh 'request))))
        (check (poo-flow-search-attempt-ready? (downstream) required (list old)) => #f)
        (check (poo-flow-search-attempt-ready? (downstream) required (list done)) => #t)
        (check (poo-flow-search-attempt-ready? (poo-flow-search-attempt-state stage "other-generation" "config" "cut") required (list done)) => #f)
        (check (poo-flow-search-attempt-ready? (poo-flow-search-attempt-state stage "generation" "other-config" "cut") required (list done)) => #f)))
    (test-case "completion admission and ordinary issue guards remain mandatory"
      (let* ((a (poo-flow-search-attempt-issue (initial)))
             (request (.ref a 'request))
             (done (poo-flow-search-attempt-complete (.ref a 'state) request))
             (issued (poo-flow-search-attempt-issue-ready (downstream) (list request) (list done)))
             (foreign (poo-core-role-object (slots ((attempt 9))) (supers request))))
        (check (rejected? (lambda () (poo-flow-search-attempt-complete (.ref a 'state) foreign))) => #t)
        (check (rejected? (lambda () (poo-flow-search-attempt-complete (.ref done 'state) request))) => #t)
        (check (rejected? (lambda () (poo-flow-search-attempt-issue-ready (.ref issued 'state) (list request) (list done)))) => #t)
        (check (rejected? (lambda () (poo-flow-search-attempt-issue-ready (poo-flow-search-attempt-retire (downstream)) '() '()))) => #t)))))
