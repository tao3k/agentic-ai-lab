;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;; Use the official Gerbil package script API. Installation, recursive
;; dependencies, tags and runtime builds remain Gerbil-owned. Editor TAGS generation
;; is separate tooling: it is not part of compilation or dependency admission.
(import (only-in :gerbil/tools/gxpkg
          pkg-install pkg-update pkg-root-dir with-pkg-build-env)
        (only-in :std/error Error-irritants)
        (only-in :std/list/list find)
        (only-in :std/misc/process process-error? run-process run-process/batch))
(export main)

(def (git-revision? revision)
  (and (string? revision) (= (string-length revision) 40)
       (andmap (lambda (ch) (or (char<=? #\0 ch #\9) (char<=? #\a ch #\f)))
               (string->list revision))))

(def (missing-pinned-tree? failure directory revision)
  (and (git-revision? revision)
       (process-error? failure)
       (match (Error-irritants failure)
         (["git" _ settings]
          (and (equal? (pgetq arguments: settings) (list "checkout" "-q" revision))
               (equal? (pgetq directory: settings) directory)
               (let (missing? #f)
                 (run-process (list "git" "cat-file" "-e" (string-append revision "^{tree}"))
                   directory: directory stderr-redirection: #t
                   check-status: (lambda (status _) (set! missing? (not (zero? status)))))
                 missing?)))
         (else #f))))

(def (install-pinned operation dependency directory revision)
  (try (operation dependency)
    (catch (failure)
      (unless (missing-pinned-tree? failure directory revision)
        (raise failure))
      ;; A normal clone only fetches objects reachable from advertised refs.
      ;; Update binds the exact tag after a failed clone left the default branch
      ;; checked out. Install must see that binding before resolving its tag.
      (run-process/batch (list "git" "fetch" "--no-tags" "origin" revision)
        directory: directory)
      (pkg-update dependency)
      (unless (eq? operation pkg-update)
        (operation dependency)))))

(def (prepare-pinned-source dependency package directory revision)
  (unless (file-exists? directory)
    (create-directory* (path-directory directory))
    (run-process/batch
      (list "git" "clone" "--no-checkout" (string-append "https://" package ".git") directory)))
  (run-process/batch (list "git" "fetch" "--no-tags" "origin" revision) directory: directory)
  ;; A prefetched clone still names its default branch. Bind the declared
  ;; revision through gxpkg before deps --install chooses an existing tag.
  ;; pkg-update binds sources without recursively installing or compiling.
  (unless (pkg-update dependency)
    (error "cannot bind pinned Gerbil package source" dependency)))

(def (install-dependency! dependency)
  (def parts (string-split dependency #\@))
  (def directory (path-expand (car parts) (pkg-root-dir)))
  (def revision (and (pair? (cdr parts)) (cadr parts)))
  (when (file-exists? directory)
    (install-pinned pkg-update dependency directory revision))
  (install-pinned pkg-install dependency directory revision))

(def (orgize-scheme-rust-dependency directory)
  ;; Orgize's native build imports Scheme Rust for its ABI check. Its Cargo
  ;; lock owns this revision, just as the Bazel producer's input does.
  (def package "github.com/tao3k/gerbil-scheme-rust")
  (def prefix (string-append "source = \"git+https://" package "?"))
  (def revisions
    (call-with-input-file (path-expand "Cargo.lock" directory)
      (lambda (port)
        (let loop ((revisions '()))
          (let (line (read-line port))
            (cond
             ((eof-object? line) revisions)
             ((string-prefix? prefix line)
              (def source (cadr (string-split line #\")))
              (def parts (string-split source #\#))
              (unless (and (= (length parts) 2) (git-revision? (cadr parts)))
                (error "Orgize has an invalid Scheme Rust git source" line))
              (loop (if (member (cadr parts) revisions) revisions (cons (cadr parts) revisions))))
             (else (loop revisions))))))))
  (unless (= (length revisions) 1)
    (error "Orgize must lock one Scheme Rust revision" revisions))
  (string-append package "@" (car revisions)))

(def (prepare-orgize-build! dependency package directory revision)
  (if (file-exists? directory)
    (install-pinned pkg-update dependency directory revision)
    (prepare-pinned-source dependency package directory revision))
  (def metadata (call-with-input-file (path-expand "gerbil.pkg" directory) read))
  (def parser
    (find (lambda (entry) (string-prefix? "github.com/tao3k/gerbil-parser@" entry))
          (pgetq depend: metadata '())))
  (unless parser (error "Orgize must pin its Parser dependency" directory))
  (install-dependency! parser)
  (install-dependency! (orgize-scheme-rust-dependency directory)))

(def (main . arguments)
  (unless (or (null? arguments) (equal? arguments '("--fetch-only")))
    (error "usage: runtime-dependencies.ss [--fetch-only]" arguments))
  (def properties (call-with-input-file "gerbil.pkg" read))
  (def dependencies (pgetq depend: properties '()))
  (unless (and (list? dependencies) (andmap string? dependencies))
    (error "expected runtime package dependency strings" "gerbil.pkg"))
  (with-pkg-build-env
    (for-each
      (lambda (dependency)
        (let* ((parts (string-split dependency #\@))
               (package (car parts))
               (directory (path-expand package (pkg-root-dir)))
               (revision (and (pair? (cdr parts)) (cadr parts))))
          (cond
           ((pair? arguments)
            (when revision (prepare-pinned-source dependency package directory revision)))
           ((equal? package "github.com/tao3k/orgize")
            (prepare-orgize-build! dependency package directory revision)
            (install-pinned pkg-install dependency directory revision))
           (else (install-dependency! dependency)))))
      dependencies)))
