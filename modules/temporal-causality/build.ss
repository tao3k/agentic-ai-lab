;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .def .o))

;; The platform clock is a native library, compiled by its owning Module.
;; It must not be evaluated while publishing the pure Temporal scope.
(.def Build
  ffi: '("runtime/monotonic-clock")
  defbuild-script: (.o spec: '("runtime/durable-journal")))
