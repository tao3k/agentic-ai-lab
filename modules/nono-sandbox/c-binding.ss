;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Owner: public facade for nono-sandbox C binding contract projection.
;;; Boundary: C binding belongs to the sandbox/nono-sandbox module category.
;;; Runtime contract: manifest owners emit data; ffi.ss owns gated FFI probes.

(import :tao3k/agentic-ai-lab/modules/nono-sandbox/c-binding-build
        :tao3k/agentic-ai-lab/modules/nono-sandbox/c-binding-descriptor
        :tao3k/agentic-ai-lab/modules/nono-sandbox/c-binding-runtime
        :tao3k/agentic-ai-lab/modules/nono-sandbox/ffi)

(export (import: :tao3k/agentic-ai-lab/modules/nono-sandbox/c-binding-build)
        (import: :tao3k/agentic-ai-lab/modules/nono-sandbox/c-binding-descriptor)
        (import: :tao3k/agentic-ai-lab/modules/nono-sandbox/c-binding-runtime)
        (import: :tao3k/agentic-ai-lab/modules/nono-sandbox/ffi))
