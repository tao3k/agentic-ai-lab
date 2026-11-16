;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :std/misc/process run-process)
        (only-in :clan/poo/object .get .call)
        (only-in :std/source this-source-file)
        (only-in :tao3k/yuanxu/module-system/source/directory module-directory-context)
        (only-in :tao3k/yuanxu/module-system/building/test-projection admit-module-test-layout!)
        (only-in "../../init.ss" tao3k/agentic-ai-lab.init.exports))
(export main default-test-files admit-lab-test-layout!)

(def (admit-lab-test-layout!)
  (def init (path-normalize (path-expand "../../init.ss" (path-directory (this-source-file)))))
  (def context
    (module-directory-context init
      (lambda (_) (error "test roster must leave publications cold"))
      publication-prepares-source?: #t))
  (def tests
    (.call (.get tao3k/agentic-ai-lab.init.exports tests qualification)
      .select (.get context loader-roots)))
  (def files (.get tests spec))
  ((.get tests admit-current))
  (admit-module-test-layout! context files
    require-owner-tests?: #t
    independent-directories:
    '("contribution" "fixtures" "harness" "integration" "library" "model-study"
      "module-system-poo-performance-test-support" "performance" "qualification"
      "research" "scenarios" "support")))

(def (default-test-files)
  (def root (path-normalize (current-directory)))
  (def (local-path file)
    (unless (string-prefix? root file)
      (error "Loader published a test outside Lab" file))
    (substring file (string-length root) (string-length file)))
  (def (directory-tests dir)
    (map (lambda (name) (string-append dir "/" name))
         (filter (cut string-suffix? "-test.ss" <>) (directory-files dir))))
  (def (grouped-tests dir)
    (foldr append '()
      (map (lambda (group) (directory-tests (path-expand group dir)))
           (list-sort string<? (directory-files dir)))))
  (append (list-sort string<? (map local-path (admit-lab-test-layout!)))
          (list-sort string<? (map local-path (grouped-tests (path-expand "t/library" root))))
          (list-sort string<? (map local-path (grouped-tests (path-expand "t/integration/lab" root))))
          (list-sort string<? (directory-tests "t/integration/nix"))
          (list-sort string<? (directory-tests "t/integration/testing"))))

(def (independent-test? file)
  (member file '("t/library/session/session-independent-test.ss"
                 "t/yanxu/modules/services/opentofu/deployment-test.ss")))

(def (test-batches files)
  ;; Gerbil imports the entire batch before running its Harness.
  (let loop ((remaining files) (batch '()) (size 0) (batches '()))
    (match remaining
      ([] (reverse (if (null? batch) batches (cons (reverse batch) batches))))
      ([file . rest]
       (cond
         ((independent-test? file)
          (loop rest '() 0 (cons [file] (if (null? batch) batches (cons (reverse batch) batches)))))
         ((and (pair? batch)
               (or (= size 8)
                   (not (equal? (path-directory file) (path-directory (car batch))))))
          (loop remaining '() 0 (cons (reverse batch) batches)))
         (else
          (loop rest (cons file batch) (1+ size) batches)))))))

(def (run-batch vm file-budget files)
  (displayln "LAB-TEST-BATCH " (string-join files " "))
  (force-output)
  (def test-command ["gerbil" vm "test" . files])
  (def command
    (if (and (independent-test? (car files))
             (not (cond-expand
                    (darwin (equal? (getenv "LAB_MACOS_QUALIFICATION_TIMING" #f) "1"))
                    (else #f))))
      ["timeout" "--signal=TERM" "--kill-after=5s" file-budget . test-command]
      test-command))
  (def expected (filter (cut string-suffix? "-test.ss" <>) files))
  (def harness-receipt (string-append "HARNESS-OK " (object->string files)))
  (def status #f)
  (def module-ok? #f)
  (def harness-ok? #f)
  (def final-ok? #f)
  (def failed? #f)
  (run-process command stdin-redirection: #f stderr-redirection: #t
    check-status: (lambda (result _) (set! status result))
    coprocess:
    (lambda (port)
      (let next ((line (read-line port)))
        (unless (eof-object? line)
          (displayln line)
          (force-output)
          (cond
            ((string-prefix? "MODULE-OK " line)
             (set! module-ok? #t)
             (set! expected (filter (lambda (file) (not (string=? line (string-append "MODULE-OK " file)))) expected)))
            ((string=? harness-receipt line) (set! harness-ok? #t))
            ((and harness-ok? (string=? line "OK")) (set! final-ok? #t))
            ((or (ormap (lambda (marker) (string-prefix? marker line))
                        '("ERROR CASE" "ERROR CHECK" "ERROR HARNESS" "ERROR MODULE"))
                 (string-contains line "Heap overflow")
                 (string-contains line "Stack overflow"))
             (set! failed? #t)))
          (next (read-line port))))))
  (def ok? (and (eqv? status 0) module-ok? harness-ok? final-ok? (null? expected) (not failed?)))
  (unless ok?
    (displayln "LAB-TEST-BATCH-FAILED status=" status " missing-module-receipts=" expected)
    (force-output))
  ok?)

(def (main vm file-budget . paths)
  (def files (if (null? paths) (default-test-files) paths))
  (def failed? #f)
  (for-each (lambda (batch)
              (unless (run-batch vm file-budget batch) (set! failed? #t)))
            (test-batches files))
  (when failed? (exit 1)))
