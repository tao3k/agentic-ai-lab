;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :agentic-ai-lab/t/context-durable-owner
        (only-in :std/text/pregexp pregexp-match))
(with-catch
  (lambda (e)
    (let (message (call-with-output-string (lambda (p) (display-exception e p))))
      (if (and (getenv "CONTEXT_EXPECT_OWNER_FENCE" #f)
               (pregexp-match "Durable owner epoch superseded" message))
        (begin (displayln "DURABLE-FENCED stale-owner-native-decision-refused=#t") (exit 0))
        (raise e))))
  (lambda () (apply durable-driver (cddr (command-line)))))
