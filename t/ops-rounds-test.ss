;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test :clan/poo/object "./qualification/opentofu/opentofu-rounds.ss"
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :std/source this-source-file)
        (only-in "../init.ss" agentic-ai-lab.init.exports)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :agentic-ai-lab/modules/nix/objects NixSource.))
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
          (def log (path-expand "round.log" root))
          (def fixture (path-expand "fixture.ss" root))
          (def (write-log suffix (files (list fixture)))
            (call-with-output-file (list path: log truncate: #t)
              (lambda (port)
                (display "MODULE-OK " port)
                (display fixture port)
                (newline port)
                (display "HARNESS-OK " port)
                (write files port)
                (newline port)
                (display suffix port)
                (display "OK\n" port))))
          (write-log "")
          (check-equal? (assert-control (.o status: 0) log fixture) 0)
          (check-exception (assert-control (.o status: 7) log fixture) error?)
          (write-log "ERROR CHECK failed\n")
          (check-exception (assert-control (.o status: 0) log fixture) error?)
          (write-log "ERROR MODULE imported.ss\n")
          (check-exception (assert-control (.o status: 0) log fixture) error?)
          ;; Exact native Harness ownership matters even with a successful
          ;; target Module marker; another file's completion is insufficient.
          (write-log "" (list (path-expand "other.ss" root)))
          (check-exception (assert-control (.o status: 0) log fixture) error?)
          (check-equal? (file-exists? log) #t))))
    (yuanxu-test-case "summary inputs come from the native test publication"
      (def tests
        (.call (.get agentic-ai-lab.init.exports tests) .for-files
          (list (this-source-file))))
      (check-equal? (.ref/cached (.get tests source) 'selected-graph) #f)
      (def build (.get tests build))
      ((.get build admit-current))
      (def observations (publication-observations tests build))
      (check-equal? (and (assoc (path-normalize (this-source-file)) observations) #t) #t)
      (check-equal? (length (snapshots observations)) (length observations))
      ;; Summarizing a test publication must not activate business Modules.
      (check-equal? (.ref/cached (.get tests source) 'selected-graph) #f))

    (yuanxu-test-case "summaries retain original observations and ignore unobserved files"
      (call-with-temporary-directory "ops-source-observations"
        (lambda (root)
          (def provider (path-expand "providers.nix" root))
          (def policy (path-expand "policy.nix" root))
          (def unrelated (path-expand "unselected.nix" root))
          (def (write-text path text)
            (call-with-output-file (list path: path truncate: #t) (cut display text <>)))
          (write-text provider "{ aws = 1; }")
          (write-text policy "{ allowed = true; }")
          ;; Use original native Source observations. This test owns only its
          ;; explicit Fixture, and does not scan Core or invent import edges.
          (def observations
            (append (.get (.cc NixSource. expression: provider) source-inputs)
                    (.get (.cc NixSource. expression: policy) source-inputs)))
          (def before (snapshots observations))
          (check-equal? (map car before) (list policy provider))
          (check-equal? (snapshots (reverse observations)) before)
          (write-text unrelated "{ notSelected = true; }")
          (check-equal? (snapshots observations) before)
          (dynamic-wind
            (lambda () (write-text policy "{ allowed = false; }"))
            (lambda () (check-exception (snapshots observations) error?))
            (lambda () (write-text policy "{ allowed = true; }")))
          (check-equal? (snapshots observations) before))))))
