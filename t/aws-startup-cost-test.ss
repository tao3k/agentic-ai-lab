;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Import controls through the existing Ops/std/test path, not a new runner.
(import :std/test :clan/poo/object
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :std/source this-source-file)
        (only-in :yuanxu/observability/testing-script testing-script-for-source)
        (only-in :yuanxu/module-system/building/test-projection module-test-file-source))
(export aws-startup-cost-test)
(def aws-startup-cost-test
  (test-suite "Cold source import controls"
    (test-case "same Ops execution, successively stronger import closure"
      (call-with-temporary-directory "aws-startup-cost"
        (lambda (root)
          (def (probe name guarded? (direct? #f) (changed-path? #f))
            (def path (path-expand (string-append name "-test.ss") root))
            (call-with-output-file (list path: path truncate: #t)
              (lambda (port)
                (display "(import :std/test" port)
                (when guarded?
                  (display " (only-in :yuanxu/observability/testing-case yuanxu-test-case)" port))
                (display ")\n(export probe)\n(def probe (test-suite \"startup\" (" port)
                (display (if guarded? "yuanxu-test-case" "test-case") port)
                (display " \"check\" (check-equal? 1 1) (check-equal? (##get-max-heap) 1073741824) (check-equal? (car (string-split (getenv \"PATH\") #\\:)) (string-append (getenv \"GERBIL_PATH\") \"/bin\")))))\n" port)))
            (def script (testing-script-for-source (module-test-file-source (list path))))
            (def actual
              (if direct?
                (if changed-path?
                  (.cc script 'environment (.o PATH: (string-append "/usr/bin:" (getenv "PATH"))))
                  script)
                (.cc script 'command
                  (append '("gerbil") (.get script runtime-options) '("env" "gerbil")
                          (.get script runtime-options) '("test") (.get script source spec)))))
            (def result (.call actual .run))
            (.get result seconds))
          (def import-probe (path-expand "imports-test.ss" root))
          (call-with-output-file import-probe
            (lambda (port)
              (for-each
                (lambda (form) (write form port) (newline port))
                '((import :std/test :gerbil/expander)
                  (export imports-test)
                  (def imports-test
                    (test-suite "incremental source imports and expansion"
                      (test-case "public expander phase controls"
                        (parameterize ((current-expander-context (make-top-context)))
                          (def (measure name thunk)
                            (def started (real-time))
                            (def result (thunk))
                            (displayln "IMPORT-PHASE " name " " (- (real-time) started))
                            result)
                          (for-each
                            (lambda (module)
                              (measure module (lambda ()
                                (eval-syntax `(import ,(if (string? module)
                                                          (path-expand module) module))))))
                            '(:gerbil/core :std/test :clan/poo/object :clan/poo/mop :yuanxu/object-types/contracts
                              :yuanxu/observability/types :yuanxu/observability/funcs
                              :yuanxu/observability/slot-debug :yuanxu/observability/debug
                              :yuanxu/observability/testing-case
                              :yuanxu/modules/json-schema/contracts :agentic-ai-lab/scenarios/aws/types
                              :yuanxu/module-system/selection/init-syntax "init.ss"
                              :yuanxu/module-system/source/admission))
                          (eval-syntax
                            '(def source-counts (make-hash-table)))
                          (eval-syntax '(def guard-origins '()))
                          (eval-syntax '(def guard-counts (make-hash-table)))
                          (eval-syntax
                            '(current-module-source-observer
                               (lambda (kind amount)
                                 (hash-update! source-counts kind (cut + <> amount) 0)
                                 (when (pair? kind)
                                   (case (car kind)
                                     ((publication-guard-start)
                                      (set! guard-origins (cons (cadr kind) guard-origins))
                                      (hash-update! guard-counts (list (car guard-origins) 'calls) (cut + <> amount) 0))
                                     ((publication-guard-end) (set! guard-origins (cdr guard-origins)))
                                     ((publication-guard-run)
                                      (hash-update! guard-counts (list (car guard-origins) 'runs) (cut + <> amount) 0))
                                     ((file-read)
                                      (when (and (eq? (cadr kind) 'publication-current) (pair? guard-origins))
                                        (hash-update! guard-counts (list (car guard-origins) 'reads) (cut + <> amount) 0))))))))
                          (measure 'init-namespace (lambda () (eval-syntax '(.get agentic-ai-lab.init.exports scenarios))))
                          (measure 'test-discovery
                            (lambda () (eval-syntax '(.get agentic-ai-lab.init.exports scenarios aws tests source spec))))
                          (measure 'test-executor-import
                            (lambda () (eval-syntax '(.get agentic-ai-lab.init.exports scenarios aws tests execution))))
                          (check-equal? (eval-syntax '(.ref/cached (.get agentic-ai-lab.init.exports scenarios aws) 'scope)) #f)
                          (displayln "SOURCE-PHASE "
                            (eval-syntax '(filter (lambda (row) (symbol? (car row))) (hash->list source-counts))))
                          (displayln "PUBLICATION-GUARDS " (eval-syntax '(hash->list guard-counts)))
                          (check-equal? (eval-syntax '(null? guard-origins)) #t)
                          (eval-syntax
                            '(let ((phases (make-hash-table)) (files (make-hash-table)))
                               (for-each
                                 (lambda (row)
                                   (when (and (pair? (car row)) (eq? (caar row) 'file-read))
                                     (hash-update! phases (cadar row) (cut + <> (cdr row)) 0)
                                     (hash-update! files (caddar row) (cut + <> (cdr row)) 0)))
                                 (hash->list source-counts))
                               (displayln "SOURCE-STAGES " (hash->list phases))
                               (for-each
                                 (lambda (row)
                                   (displayln "SOURCE-FILE " (car row) " reads=" (cdr row)
                                     " stages="
                                     (filter-map
                                       (lambda (entry)
                                         (and (pair? (car entry))
                                              (eq? (caar entry) 'file-read)
                                              (equal? (caddar entry) (car row))
                                              (cons (cadar entry) (cdr entry))))
                                       (hash->list source-counts))))
                                 (let loop ((rows (list-sort (lambda (a b) (> (cdr a) (cdr b))) (hash->list files)))
                                            (remaining 10))
                                   (if (or (null? rows) (zero? remaining)) '()
                                     (cons (car rows) (loop (cdr rows) (- remaining 1))))))))
                          (eval-syntax '(current-module-source-observer #f))
                          (eval-syntax '(.def Base instance_type: "t3.small"))
                          (def expanded
                            (measure 'profile-expand
                              (lambda () (core-expand
                                '(.def (Profile @ Base) instance_type: "t3.medium")))))
                          (def compiled
                            (measure 'profile-compile
                              (lambda () ((current-expander-compile) expanded))))
                          (measure 'profile-eval
                            (lambda () ((current-expander-eval) compiled)))
                          (check-equal? (eval-syntax '(.get Profile instance_type)) "t3.medium")
                          (measure 'case-expand
                            (lambda () (core-expand
                              '(yuanxu-test-case "guarded" (check-equal? 1 1)))))
                          (measure 'cached-import
                            (lambda () (eval-syntax '(import :yuanxu/observability/testing-case))))))))))))
          (def imports
            (.call (testing-script-for-source (module-test-file-source (list import-probe))) .run))
          (display (.get imports output))
          (def plain (probe "plain" #f))
          (def direct (probe "plain" #f #t))
          (def restored (probe "plain" #f #t #t))
          (def guarded (probe "guarded" #t))
          (def aws-source
            (module-test-file-source
              (list (path-expand "../scenarios/aws/tests/atomic-test.ss"
                      (path-directory (this-source-file))))))
          (def aws (.get (.call (testing-script-for-source aws-source) .run) seconds))
          (displayln "Startup Ops seconds: std/test=" plain " direct=" direct " restored=" restored
                     " guarded=" guarded " AWS=" aws))))))
