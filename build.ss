#!/usr/bin/env gxi
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Core projects selected sources; std/build-script and std/make execute.
(import (for-syntax
          (only-in :std/source this-source-file)
          (only-in :yuanxu/module-system/building/source-package register-module-build-source!)))
(begin-syntax
  (register-module-build-source! (path-directory (this-source-file)) 'poo-flow))

(import (only-in :clan/poo/object .get)
        (only-in :std/build-script defbuild-script)
        (only-in "./init.ss" poo-flow.init.exports)
        (only-in "./build-spec.ss" poo-flow-library-spec))

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


(def (poo-flow-spec)
  (append
    `((gxc: "modules/nono-sandbox/_nono"
            "-cc-options" ,+nono-c-include-option+
            "-ld-options" ,+nono-c-link-option+))
    (poo-flow-library-spec)
    (list +runtime-v0-native-ffi-spec+ +semantic-native-ffi-spec+)))

(def retained-spec (poo-flow-spec))

;; Use the admitted specification directly; std/build-script owns dispatch.
(def (package-main spec args)
  (let ()
    (defbuild-script spec)
    (apply main args)))
(def (main . args)
  ;; Package compilation returns no module-publication authority. Keep its
  ;; source guards and let the SDK reuse its own incremental output cohort.
  (if (and (pair? args) (equal? (car args) "clean"))
    ((.get poo-flow.init.exports std-make-run) retained-spec package-main args)
    (let (spec ((.get poo-flow.init.exports std-make-spec) retained-spec))
      (begin0 (package-main spec args)
        ((.get poo-flow.init.exports admit-current))))))
