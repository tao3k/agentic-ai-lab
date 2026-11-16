;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Compile only the native dependencies of the maintained Harness inputs.
(import (only-in :std/make make)
        (only-in :std/source this-source-file)
        (only-in :clan/poo/object .get .call)
        (only-in "../init.ss" tao3k/agentic-ai-lab.init.exports)
        (only-in "./run-lab-tests.ss" default-test-files))

(def (main . files)
  (def root (path-expand ".." (path-directory (this-source-file))))
  (def tests
    (.call (.get tao3k/agentic-ai-lab.init.exports tests) .for-files
      (if (null? files) (default-test-files) files)))
  (make (.get tests std-make-spec) srcdir: root
    options: (list "-cc-options"
               (string-append "-I" root " -I" (path-expand "bindings/runtime-c/include" root)))))
