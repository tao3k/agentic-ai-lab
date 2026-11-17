;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :handoff
        (rename-in :gerbil/tools/gxtest (main run-gerbil-tests)))

(let (result (apply run-gerbil-tests (cddr (command-line))))
  (when (and (zero? result) (equal? (getenv "LAB_TERMINAL_CLEANUP" "") "terminal"))
    (unless (= (arm-terminal-cleanup!) 1)
      (error "macOS terminal cleanup handoff is unavailable"))
    (displayln "LAB-TERMINAL-CLEANUP-ARMED")
    (force-output))
  (exit result))
