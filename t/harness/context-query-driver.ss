;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; The Just entrypoint sets the heap fence before these imports.
(import :agentic-ai-lab/t/context-query-provider-test)
(apply context-query-driver (cddr (command-line)))
