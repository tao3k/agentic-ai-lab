#!/usr/bin/env gxi
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Compatibility launcher only. The product init owns the Make specification,
;;; source admission and SDK dispatch; development has no parallel catalog.
(import (only-in :std/source this-source-file)
        (only-in :std/misc/process run-process))
(export main)
(def (main . arguments)
  ;; Execute the existing product entry with its own watchdog. Its main is an
  ;; SDK script entry, not a public library export to reproduce in dev/.
  (def root (path-expand ".." (path-directory (this-source-file))))
  (parameterize ((current-directory root))
    (run-process (cons (path-expand "build.ss" root) arguments)
      stdin-redirection: #f stdout-redirection: #f stderr-redirection: #f)))
