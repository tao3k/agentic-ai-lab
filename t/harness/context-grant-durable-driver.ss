;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; The Just entrypoint supplies the heap fence before imports.
(import :agentic-ai-lab/t/context-grant-durable-test)
(apply grant-durable-driver (cddr (command-line)))
