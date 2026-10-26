;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; The Just entrypoint supplies the heap fence before imports.
(import :agentic-ai-lab/t/context-policy-durable-test)
(apply policy-durable-driver (cddr (command-line)))
