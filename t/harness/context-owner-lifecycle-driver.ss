;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; The Just entrypoint supplies the pre-import heap fence.
(import :tao3k/agentic-ai-lab/t/yanxu/modules/ai-agentic-context/context-owner-lifecycle-test)
(def (main path) (owner-lifecycle-unit path))
