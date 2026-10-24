#!/usr/bin/env gxi
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :agentic-ai-lab/lambda-episteme/testing-observer
                 run-observed-test))

(let (arguments (cddr (command-line)))
  (unless (= (length arguments) 1)
    (error "usage: run-contribute-test.ss <test-file-or-directory>"))
  (run-observed-test (car arguments)))
