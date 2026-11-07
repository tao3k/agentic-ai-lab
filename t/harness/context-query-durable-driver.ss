;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; The Just entrypoint applies its heap fence before these imports.
(import :agentic-ai-lab/t/context-query-durable-test)
(apply query-durable-driver (cddr (command-line)))
