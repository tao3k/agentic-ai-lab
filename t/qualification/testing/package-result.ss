;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; ASP owns discovery and batching; this checks its existing completion wire.
(import (only-in :clan/poo/object .get)
        (only-in :std/text/pregexp pregexp-match)
        (only-in :yuanxu/observability/testing-script admit-testing-process-result))
(export admit-package-batches)
(def (admit-package-batches result)
  (admit-testing-process-result result '("dev/unit-tests.ss"))
  (def lines (string-split (.get result output) #\newline))
  (def discoveries
    (filter-map
      (cut pregexp-match "^\\[asp-testing\\] phase=discovery-complete .* fileCount=([0-9]+)$" <>)
      lines))
  (unless (pair? discoveries)
    (error "package discovery completion is missing" (.get result output)))
  (def count (cadar discoveries))
  (def (require-line line)
    (unless (member line lines)
      (error "package batch receipt is missing" line (.get result output))))
  (require-line (string-append "[asp-testing] phase=all-batches-complete fileCount=" count))
  (def prefix "[asp-testing] phase=batch-start fileCount=1 firstFile=")
  (for-each
    (lambda (line)
      (when (string-prefix? prefix line)
        (require-line
          (string-append "MODULE-OK " (substring line (string-length prefix) (string-length line))))))
    lines)
  (unless (any (cut string-prefix? "HARNESS-OK" <>) lines)
    (error "package native harness completion is missing" (.get result output)))
  result)
