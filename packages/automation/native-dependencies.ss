;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;; Use the official Gerbil package script API. Installation, recursive
;; dependencies, tags and native builds remain owned by the Gerbil package manager. Editor TAGS generation
;; is separate tooling: it is not part of compilation or dependency admission.
(import (only-in :gerbil/tools/gxpkg
          pkg-install pkg-update pkg-root-dir with-pkg-build-env))
(export main)
(def (main)
  (def properties (call-with-input-file "gerbil.pkg" read))
  (def dependencies (pgetq depend: properties '()))
  (unless (and (list? dependencies) (andmap string? dependencies))
    (error "expected native package dependency strings" "gerbil.pkg"))
  (with-pkg-build-env
    (for-each
      (lambda (dependency)
        (let (package (car (string-split dependency #\@)))
          ;; Gerbil owns fetching and the exact checkout/tag transition before
          ;; installation checks. No Python prefetch manages package state.
          ;; Call the native APIs directly: v0.19's deps --update forwards the
          ;; tagged spelling to a directory lookup after updating it.
          (when (file-exists? (path-expand package (pkg-root-dir)))
            (pkg-update dependency))
          (pkg-install dependency)))
      dependencies)))
