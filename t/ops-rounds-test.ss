;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test :clan/poo/object "./qualification/opentofu/opentofu-rounds.ss"
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case))
(export ops-rounds-test)
(def ops-rounds-test
  (test-suite "Native operational qualification summaries"
    (yuanxu-test-case "statistics retain every round and refuse different phase sets"
      (let* ((rounds (map (lambda (seconds)
                           (hash (phases (list (hash (phase "currentness") (seconds seconds)
                                                    (instantiate 1) (realize 0)
                                                    (type-reads 0) (type-compiles 0)))))) '(1. 2. 3.)))
             (result (hash-ref (aggregate rounds) 'currentness)))
        (check-equal? (hash-ref result 'samples) 3)
        (check-equal? (hash-ref (hash-ref result 'seconds) 'median) 2.)
        (check-equal? (hash-ref result 'instantiate) '(1 1 1))
        (check-exception (aggregate (cons (hash (phases '())) rounds)) error?)))
    (yuanxu-test-case "a nonzero exit or native error marker cannot become a passing receipt"
      (call-with-temporary-directory "ops-failed-control"
        (lambda (root)
          (let (log (path-expand "round.log" root))
            (def (write-log text)
              (call-with-output-file (list path: log truncate: #t) (cut display text <>)))
            (write-log "MODULE-OK fixture.ss\nHARNESS-OK fixture.ss\nOK\n")
            (check-exception (assert-control (.o status: 7) log "fixture.ss") error?)
            (write-log "MODULE-OK fixture.ss\nHARNESS-OK fixture.ss\nERROR CHECK failed\nOK\n")
            (check-exception (assert-control (.o status: 0) log "fixture.ss") error?)
            (check-equal? (file-exists? log) #t)))))
    (yuanxu-test-case "source digests are deterministic and detect indirect input edits"
      (call-with-temporary-directory "ops-source-hashes"
        (lambda (root)
          (let (source (path-expand "providers.nix" root))
            (call-with-output-file source (cut display "{ aws = 1; }" <>))
            (let (before (snapshots root))
              (check-equal? (snapshots root) before)
              (call-with-output-file (list path: source truncate: #t) (cut display "{ aws = 2; }" <>))
              (check-equal? (equal? before (snapshots root)) #f))))))))
