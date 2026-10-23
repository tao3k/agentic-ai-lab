;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Qualification of the existing init-owned AWS integration endpoint.
(import :std/test :yuanxu/object-syntax/path-slots
        (only-in :clan/poo/object .get .call .ref/cached)
        (only-in :std/io/tempfile make-temporary-file-name clear-temporary-file!)
        (only-in :yuanxu/observability/testing-fixture with-yuanxu-fixture)
        (only-in "../init.ss" agentic-ai-lab.init.exports))
(export aws-context-publication-test)
;; The surviving parent owns the worker's temporary directory, so an Ops
;; deadline can still release it when the worker cannot unwind its own fixture.
(.def Workspace
  .acquire: (lambda ()
              (let (root (make-temporary-file-name "aws-worker-"))
                (create-directory root) root))
  .release: (lambda (root)
              (clear-temporary-file! root)
              ;; Runs after a successful worker or a refused/timed-out worker.
              (check-equal? (file-exists? root) #f)))
(def aws-context-publication-test
  (test-suite "AWS tests are owned by the selected module namespace"
    (test-case "one init projection runs the real Schema transition with observation off and on"
      (with-yuanxu-fixture (workspace Workspace)
        (def module (.get agentic-ai-lab.init.exports scenarios aws))
        (check-equal? (.ref/cached module 'scope) #f)
        (check-equal? (map path-strip-directory (.get (.call (.get agentic-ai-lab.init.exports tests) .select '(aws)) spec)) '("atomic-test.ss"))
        ;; Test-source discovery must not resolve the root configuration Graph.
        ;; Explicit Graph identity is qualified separately by the source-admission
        ;; suite; demanding it here would expand every unrelated root before .run.
        (check-equal? (.ref/cached (.get module tests) 'selected-graph) #f)
        (check-equal? (.ref/cached (.get module tests source) 'selected-graph) #f)
        (check-equal? (.ref/cached (.get module tests) 'qualification) #f)
        (def tests (.get module tests qualification))
        (check-equal? (.ref/cached tests 'selected-graph) #f)
        (check-equal? (eq? (.call tests .select '(aws)) tests) #t)
        (def guard (.get tests admit-current))
        (def source (.get tests source))
        ;; The original default policy stays off. Only the workspace changes,
        ;; so the surviving parent can clean up a terminated worker as well.
        (.def (Default @ tests)
          execution.environment.TMPDIR: workspace)
        (check-equal? (.get Default execution profile emit?) #f)
        (check-equal? (eq? (.get Default source) source) #t)
        (check-equal? (eq? (.get Default execution source) source) #t)
        (check-equal? (eq? (.get Default admit-current) guard) #t)
        (def ordinary (.call Default .run))
        (check-equal? (and (string-contains (.get ordinary output) "test-work case=") #t) #f)
        (check-equal? (directory-files workspace) '())

        (.def (Observed @ tests)
          execution.profile.emit?: #t
          execution.environment.TMPDIR: workspace)
        (check-equal? (eq? (.get Observed source) source) #t)
        (check-equal? (eq? (.get Observed execution source) source) #t)
        (check-equal? (eq? (.get Observed admit-current) guard) #t)
        (check-equal? (.get tests execution profile emit?) #f)
        (def result (.call Observed .run))
        (check-equal? (and (string-contains (.get result output) "test-work case=") #t) #t)
        (for-each
          (lambda (counter)
            (check-equal? (and (string-contains (.get result output) counter) #t) #t))
          '("(publication-fault-boundary . 3)" "(publication-fault-refused . 3)"))
        (check-equal? (directory-files workspace) '())
        (check-equal? (.get tests execution profile emit?) #f)
        (check-equal? (.ref/cached module 'scope) #f)))))
