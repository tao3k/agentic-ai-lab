;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;; Use the official Gerbil package script API. Installation, recursive
;; dependencies, tags and runtime builds remain Gerbil-owned. Editor TAGS generation
;; is separate tooling: it is not part of compilation or dependency admission.
(import (only-in :gerbil/tools/gxpkg
          pkg-install pkg-update pkg-root-dir with-pkg-build-env)
        (only-in :std/error Error-irritants)
        (only-in :std/misc/process process-error? run-process run-process/batch))
(export main)

(def (missing-pinned-tree? failure directory revision)
  (and (string? revision)
       (= (string-length revision) 40)
       (andmap (lambda (ch) (or (char<=? #\0 ch #\9) (char<=? #\a ch #\f)))
               (string->list revision))
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

(def (prepare-pinned-source package directory revision)
  (unless (file-exists? directory)
    (create-directory* (path-directory directory))
    (run-process/batch
      (list "git" "clone" "--no-checkout" (string-append "https://" package ".git") directory)))
  ;; Leave checkout, tag binding, recursive dependencies and builds to gxpkg.
  (run-process/batch (list "git" "fetch" "--no-tags" "origin" revision) directory: directory))

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
               (directory (path-expand (car parts) (pkg-root-dir)))
               (revision (and (pair? (cdr parts)) (cadr parts))))
          ;; Call the native APIs directly: v0.19's deps --update forwards the
          ;; tagged spelling to a directory lookup after updating it.
          (if (pair? arguments)
            (when revision (prepare-pinned-source (car parts) directory revision))
            (begin
              (when (file-exists? directory)
                (install-pinned pkg-update dependency directory revision))
              (install-pinned pkg-install dependency directory revision)))))
      dependencies)))
