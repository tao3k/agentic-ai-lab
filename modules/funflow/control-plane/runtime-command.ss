;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: public facade for runtime command invocation and descriptors.
;;; Invariant: leaf owners keep command execution separate from manifest data.

(import :tao3k/agentic-ai-lab/modules/funflow/control-plane/runtime-command-invocation
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/runtime-command-descriptor)

(export (import: :tao3k/agentic-ai-lab/modules/funflow/control-plane/runtime-command-invocation)
        (import: :tao3k/agentic-ai-lab/modules/funflow/control-plane/runtime-command-descriptor))
