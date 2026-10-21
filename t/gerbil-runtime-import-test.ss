;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Runtime/tool control intentionally has no Core or POO dependency. The Just
;;; recipe fences the heap before the first native std/test import.
(import :std/test)
(export gerbil-runtime-import-test)
(def gerbil-runtime-import-test
  (test-suite "gerbil-runtime-import-test"
    (test-case "retains bindings used by dynamic module evaluation"
      (check-equal?
        (eval '(begin
                 (import :std/text/pregexp)
                 (if (pregexp-match "^native$" "native") 'imported 'failed)))
        'imported))))
