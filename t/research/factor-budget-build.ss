;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :gerbil/compiler compile-exe execute-pending-compile-jobs!))
(export main)
(def (main . args)
  (compile-exe "t/research/factor-budget.ss"
    [output-dir: (path-expand "lib" (gerbil-path))
     output-file: (path-expand "bin/factor-budget" (gerbil-path))
     invoke-gsc: #t keep-scm: #t parallel: #t])
  (execute-pending-compile-jobs!)
  (displayln "FACTOR-PILOT-BUILD-OK")
  (exit 0))
