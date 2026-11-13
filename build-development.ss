#!/usr/bin/env gxi
;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (for-syntax
          (only-in :std/source this-source-file)
          (only-in :tao3k/yuanxu/module-system/building/source-package register-module-build-source!)))
(begin-syntax
  (register-module-build-source! (path-directory (this-source-file)) 'agentic-ai-lab))

(import (only-in :clan/poo/object .get .call)
        (only-in :gerbil/expander module-context-path)
        (only-in :tao3k/yuanxu/module-system/source/admission
                 call-with-module-source-read-cache
                 module-source-admit-current! module-source-read
                 module-compiler-interface-source)
        (only-in :tao3k/yuanxu/module-system/source/preparation
                 yuanxu-prepare-module-retained-source)
        (only-in :std/source this-source-file)
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :std/misc/process run-process)
        (only-in :std/build-script defbuild-script)
        (only-in :tao3k/yuanxu/module-system/building/build-projection yuanxu-project-source-spec)
        (only-in :tao3k/yuanxu/module-system/building/products
                 current-build-module-roots current-build-source-directory)
        (only-in "./build-spec.ss" agentic-ai-lab-build-spec))

;; Runtime package clones acquire the declared Core gitlink before source lowering.
(def (ensure-core-source!)
  ;; An existing Core may contain local work and must not be reset by a build.
  (unless (file-exists? (path-expand "core/gerbil.pkg" (path-directory (this-source-file))))
    (run-process
      (list "git" "-C" (path-directory (this-source-file))
            "submodule" "update" "--init" "--depth" "1" "--" "core")
      stdin-redirection: #f stdout-redirection: #f)))

;; Expand the native library closure in a process that exits before Make.
;; Its only handoff is the target list and Yuanxu's actual source observations.
(def (write-library-specification output)
  (def input-paths (load-path))
  (def observed (make-hash-table))
  (def (remember! input)
    (let (path (car input))
      (when (and (hash-key? observed path)
                 (not (equal? (hash-ref observed path) (cdr input))))
        (error "Lab library input changed during specification" path))
      (hash-put! observed path (cdr input))))
  (def (observe-context context)
    (let (path (module-context-path context))
      (when (and (string? path) (not (hash-key? observed path)))
        (call-with-module-source-read-cache
          (lambda ()
            (let (input
                   (if (equal? (path-extension path) ".ssi")
                     (module-compiler-interface-source path)
                     (yuanxu-prepare-module-retained-source path void)))
              (for-each remember! (.get input source-inputs))))))))
  (def spec
    (begin
      (for-each
        (lambda (file)
          (let (path (path-expand file (current-directory)))
            (remember! (cons path (module-source-read path)))))
        '("build-development.ss" "build-spec.ss" "gerbil.pkg"))
      (agentic-ai-lab-build-spec observe-context: observe-context)))
  (def inputs (hash->list observed))
  (unless (equal? input-paths (load-path))
    (error "Lab library specification changed its import path"))
  (admit-library-inputs! inputs)
  (call-with-output-file output
    (lambda (port)
      (write (list input-paths spec (length inputs)) port) (newline port)
      (for-each (lambda (input) (write input port) (newline port)) inputs))))

(def (admit-library-inputs! inputs)
  (call-with-module-source-read-cache
    (lambda () (module-source-admit-current! inputs "stale Lab library specification input"))))

(def (read-library-specification path)
  (call-with-input-file path
    (lambda (port)
      (def header (read port))
      (unless (and (list? header) (= (length header) 3)
                   (equal? (car header) (load-path))
                   (list? (cadr header))
                   (exact-integer? (caddr header)) (positive? (caddr header)))
        (error "invalid Lab library specification handoff"))
      ;; Stream the observations. Retaining all source texts in Make's VM
      ;; would consume the memory released by the specification process.
      (let loop ((remaining (caddr header)))
        (unless (zero? remaining)
          (let (input (read port))
            (unless (and (pair? input) (string? (car input))
                         (or (not (cdr input)) (string? (cdr input))))
              (error "invalid Lab library specification input"))
            (module-source-admit-current! (list input) "stale Lab library specification input")
            (loop (- remaining 1)))))
      (unless (eof-object? (read port))
        (error "unexpected Lab library specification data"))
      (cadr header))))

;; The private directory carries only the current invocation's handoff.
;; The init still owns selected Module projection, Make and output checks.
(def (run-development-build args)
  (ensure-core-source!)
  (call-with-temporary-directory "lab-library-spec-"
    (lambda (directory)
      (def packet-path
        (and (not (current-build-module-roots))
             (path-expand "specification" directory)))
      (when packet-path
        (run-process (list "gxi" (this-source-file) "--library-specification" packet-path)
          directory: (path-directory (this-source-file))
          stdin-redirection: #f stdout-redirection: #f))
      (def entry-source (this-source-file))
      (def root (path-directory entry-source))
      (def retained (if packet-path (read-library-specification packet-path) '()))
      (def projection
        (yuanxu-project-source-spec (path-expand "init.ss" root) retained root entry-source))
      (def spec (.get projection spec))
      (def (run-make)
        (def (this-source-file)
          (let (directory (current-build-source-directory))
            (if directory
                (path-expand (path-strip-directory entry-source) directory)
                entry-source)))
        (defbuild-script spec)
        (apply main args))
      (begin0
        (match args
          (["clean"] (.call projection .with-clean-outputs run-make))
          (["meta"] (run-make))
          (["spec"] (run-make))
          (else (.call projection .with-compiler-inputs run-make)))
        (when packet-path (read-library-specification packet-path))))))

(def (main . args)
  (if (and (= (length args) 2) (equal? (car args) "--library-specification"))
    (write-library-specification (cadr args))
    (run-development-build args)))
