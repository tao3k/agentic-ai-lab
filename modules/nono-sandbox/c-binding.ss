;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Owner: public facade for nono-sandbox C binding contract projection.
;;; Boundary: C binding belongs to the sandbox/nono-sandbox module category.
;;; Runtime contract: manifest owners emit data; native.ss owns gated FFI probes.

(import :agentic-ai-lab/modules/nono-sandbox/c-binding-build
        :agentic-ai-lab/modules/nono-sandbox/c-binding-descriptor
        :agentic-ai-lab/modules/nono-sandbox/c-binding-runtime
        :agentic-ai-lab/modules/nono-sandbox/native)

(export (import: :agentic-ai-lab/modules/nono-sandbox/c-binding-build)
        (import: :agentic-ai-lab/modules/nono-sandbox/c-binding-descriptor)
        (import: :agentic-ai-lab/modules/nono-sandbox/c-binding-runtime)
        (import: :agentic-ai-lab/modules/nono-sandbox/native))
