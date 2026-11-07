;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; The Just entrypoint supplies the pre-import heap fence.
(import :agentic-ai-lab/t/context-owner-lifecycle-test)
(def (main path) (owner-lifecycle-unit path))
