;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
prelude: :gerbil/core
;; Use the SDK's documented package script API. Installation, recursive
;; dependencies, tags and native builds remain SDK-owned. Editor TAGS generation
;; is separate tooling: it is not part of compilation or dependency admission.
(import (only-in :gerbil/tools/gxpkg pkg-install with-pkg-build-env))
(export main)
(def (main)
  (def properties (call-with-input-file "gerbil.pkg" read))
  (def dependencies (pgetq depend: properties '()))
  (unless (and (list? dependencies) (andmap string? dependencies))
    (error "expected native package dependency strings" "gerbil.pkg"))
  (with-pkg-build-env
    (for-each pkg-install dependencies)))
