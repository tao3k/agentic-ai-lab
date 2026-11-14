;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Real compiler Fixture: inspect the VM initialized by the generated tool.
(import :std/build-script
        (only-in :gerbil/compiler/base __available-cores))
(unless (and (= __available-cores 1)
             (equal? (getenv "GERBIL_BUILD_CORES") "1")
             (member "max-heap=256M" (string-split (getenv "GAMBOPT") #\,)))
  (error "native compiler lost its admitted runtime budget" __available-cores))
(displayln "NATIVE-COMPILER-BUDGET-OK available-cores=1 max-heap=256M")
(force-output)
;; Compilation, dependency scheduling and completion remain Gerbil-owned.
(defbuild-script '("probe"))
