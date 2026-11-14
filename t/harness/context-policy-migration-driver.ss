;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; The Just entrypoint installs the heap fence before imports.
(import :tao3k/agentic-ai-lab/t/context-policy-migration-test)
;;; Let gxi consume all arguments through its runtime main entrypoint. Loading a
;;; script for side effects leaves its artifact directory as another load input.
(def (main folder profile order) (migration-driver folder profile order))
