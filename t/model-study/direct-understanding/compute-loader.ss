;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Explicit entrypoint for trusted frozen fixtures; model outputs are data.
(displayln "MODULE-OK trusted-fixture-loader") (force-output)
(export main)
(def (main script)
  (displayln "LOAD-TRUSTED-FIXTURE " script) (force-output)
  (load script))
