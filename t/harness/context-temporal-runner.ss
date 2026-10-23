;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Preserve completed import observations and the original installed harness.
(load "t/harness/scheme-progress.ss")
(import :gerbil/tools/gxtest)
(let (status (apply gerbil/tools/gxtest#main (append '("-v" "5") (cddr (command-line)))))
  (displayln "poo-test: gxtest returned " status)
  (force-output)
  (exit status))
