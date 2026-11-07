;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Runtime owner for the Cargo-local Cedar conformance build projection.

(export cedar-conformance-build!)

(import (only-in :std/make make)
        (only-in :gerbil/core path-expand)
        (only-in :std/source this-source-file)
        :gerbil-scheme-rust/scheme/program-build)

;; : Path
(def +cedar-build-directory+
  (path-directory (this-source-file)))

;;; The nested build.ss owns only the declarative package projection and its
;;; script entrypoint.  This runtime boundary owns the temporary Cargo stage,
;;; Gerbil load path, std/make execution, and runtime program materialization.
;; : (-> BuildSpec Path Void)
(def (cedar-conformance-build! build-spec output-dir)
  (let* ((root (path-normalize
                (path-expand "../../../../../" +cedar-build-directory+)))
         (stage (path-expand "gerbil" output-dir))
         (library (path-expand "lib" stage)))
    (setenv "GERBIL_PATH" stage)
    (add-load-path! library)
    (make build-spec
          srcdir: root libdir: library
          build-deps: (path-expand "build-deps" output-dir)
          optimize: #t)
    (gerbil-rs-stage-program
     (path-expand "conformance.ss" +cedar-build-directory+)
     output-dir)))
