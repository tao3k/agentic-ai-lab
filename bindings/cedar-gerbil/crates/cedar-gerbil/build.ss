#!/usr/bin/env gxi
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Canonical compiler owner for the downstream native conformance program.
(import (only-in :asp-gerbil-scheme/building-api
                 asp-gerbil-scheme-package-spec!
                 asp-gerbil-scheme-library-package-prototype)
        (only-in "./scheme/conformance-build-runtime"
                 cedar-conformance-build!))

;; This is a bounded native projection of the parent Agentic AI Lab package, not a
;; new package or source-catalog authority. Dependencies come from the parent
;; gerbil.pkg, including ASP's declarative build API.
(asp-gerbil-scheme-package-spec!
 (cedar-conformance-package @ asp-gerbil-scheme-library-package-prototype)
 (spec cedar-conformance-spec)
 (modules ["yuanxu/object-family/syntax.ss"
           "modules/authorization/providers/cedar/objects.ss"
           "bindings/cedar-gerbil/crates/cedar-gerbil/scheme/conformance.ss"]))

;; : (-> Path Void)
(def (main output-dir)
  (cedar-conformance-build! (cedar-conformance-spec) output-dir))
