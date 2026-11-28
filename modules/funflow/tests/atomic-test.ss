;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test :tao3k/yuanxu/syntax/path-slots
        (only-in :clan/poo/object .get .call .ref/cached .def .o)
        (only-in :clan/poo/type TypeError?)
        (only-in :std/io/tempfile make-temporary-file-name clear-temporary-file!)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/job-prototypes Job. Task.)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/runtime-command-descriptor
                 runtime-command-fields->manifest)
        (only-in :tao3k/yuanxu/observability/testing-fixture yuanxu-test-fixture))
(export funflow-atomic-test)
(.def Workspace
  .acquire: (lambda () (let (directory (make-temporary-file-name "funflow-atomic-"))
                         (create-directory directory) directory))
  .release: clear-temporary-file!)
(.def (Build @ Job.)
  tasks: (.o build: (.o (:: @ Task.) command: '("printf" "build"))
             unused: (error "unselected task was forced"))
  selected: '(build))
(def funflow-atomic-test
  (test-suite "Funflow module atomic Job"
    (test-case "functional command publication projects data without running it"
      (def calls 0)
      (def envelope '((schema . yuanxu.runtime-request.v1)
                             (request-id . "public-function")))
      (def manifest
        (runtime-command-fields->manifest 'inspect "never-run"
          (lambda (actual)
            (set! calls (+ calls 1))
            (check-equal? (eq? actual envelope) #t)
            '("--preview"))
          'stdout-s-expression '() envelope))
      (check-equal? calls 1)
      (check-equal? (cdr (assq 'argv manifest)) '("never-run" "--preview"))
      (check-equal? (cdr (assq 'request-id manifest)) "public-function")
      ;; The runtime Function boundary checks input BEFORE the builder and
      ;; output BEFORE publication. A projection is not a process execution.
      (check-exception
        (runtime-command-fields->manifest 'inspect "never-run"
          (lambda (_actual) (set! calls (+ calls 1)) '("--preview"))
          'stdout-s-expression '() '((request-id . "missing-schema"))) TypeError?)
      (check-equal? calls 1)
      (check-exception
        (runtime-command-fields->manifest 'inspect "never-run" (lambda (_actual) 42)
          'stdout-s-expression '() envelope) TypeError?))
    (yuanxu-test-fixture "cached parent graph keeps child values and unused tasks lazy" (workspace Workspace)
      (def parent (.get Build graph))
      (.def (Release @ Build)
        tasks.build.command: '("printf" "release"))
      (check-equal? (.get (.call Release .run workspace) steps build output) "release")
      (check-equal? (.ref/cached (.get Release tasks) 'unused) #f)
      (check-equal? (.get Build tasks build command) '("printf" "build")))))
