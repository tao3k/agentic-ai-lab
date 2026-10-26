;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Just supplies the heap fence before imports, including native SQLite.
(import :agentic-ai-lab/t/context-query-catalog-test)
(apply context-query-catalog-driver (cddr (command-line)))
