#!/usr/bin/env gxi
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Core projects selected sources; std/build-script and std/make execute.
(import (for-syntax
          (only-in :std/source this-source-file)
          (only-in :yuanxu/module-system/building/source-package register-module-build-source!)))
(begin-syntax
  (register-module-build-source! (path-directory (this-source-file)) 'agentic-ai-lab))

(import (only-in :clan/poo/object .get)
        (only-in :std/source this-source-file)
        (only-in :std/misc/process run-process)
        (only-in :yuanxu/module-system/building/script defbuild-script)
        (only-in "./init.ss" agentic-ai-lab.init.exports)
        (only-in "./build-spec.ss" agentic-ai-lab-library-spec))

(def +nono-c-include-option+
  (string-append
   "-I"
   (path-expand "bindings/nono-c" (current-directory))))

(def +nono-c-link-option+
  (cond-expand
   (darwin "-Wl,-undefined,dynamic_lookup")
   (else "-ldl")))

;;; Gambit emits a loadable bundle for begin-ffi modules on Darwin.  The
;;; process/AOT consumer supplies libc and runtime symbols at final link time.
(def +runtime-v0-native-ffi-spec+
  (cond-expand
   (darwin
    '(gxc: "modules/workflow/runtime/runtime-v0-native"
           "-ld-options" "-Wl,-undefined,dynamic_lookup"))
   (else
    '(gxc: "modules/workflow/runtime/runtime-v0-native"))))

(def +semantic-native-ffi-spec+
  (cond-expand
   (darwin '(gxc: "modules/workflow/runtime/semantic" "-ld-options" "-Wl,-undefined,dynamic_lookup"))
   (else '(gxc: "modules/workflow/runtime/semantic"))))


(def (agentic-ai-lab-spec)
  (append
    `((gxc: "modules/nono-sandbox/_nono"
            "-cc-options" ,+nono-c-include-option+
            "-ld-options" ,+nono-c-link-option+))
    (agentic-ai-lab-library-spec)
    (list +runtime-v0-native-ffi-spec+ +semantic-native-ffi-spec+)))

;; The declarative init selects the repository's declared Core submodule.
;; Native package clones do not initialize gitlinks. Git owns that acquisition;
;; the fixed gitlink is also aligned with the inherited Core package revision.
(def retained-spec
  (begin
    (run-process
      (list "git" "-C" (path-directory (this-source-file))
            "submodule" "update" "--init" "--depth" "1" "--" "core")
      stdin-redirection: #f stdout-redirection: #f)
    (agentic-ai-lab-spec)))

;; Core retains source/currentness guards; the SDK owns native dispatch.
(def modules-spec (.get agentic-ai-lab.init.exports std-make-spec))
(defbuild-script (modules-spec retained-spec))
