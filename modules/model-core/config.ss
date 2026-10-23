;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: declares the default model catalog and selection policy objects.
;;; Invariant: configuration is inert data; provider invocation remains runtime-owned.
(export agentic-ai-lab-model-core-fast-text-model
        agentic-ai-lab-model-core-tool-json-model
        agentic-ai-lab-model-core-default-catalog
        agentic-ai-lab-model-core-default-selection-policy)

(import :agentic-ai-lab/modules/model-core/objects)

(def agentic-ai-lab-model-core-fast-text-model
  (agentic-ai-lab-model-spec
   'fast-text
   'runtime-local
   "local-fast-text"
   '(chat text)
   '(text)
   32768
   4096
   "runtime-model-adapter"
   'model-complete
   'python-runtime
   '((profile . default-fast))))

(def agentic-ai-lab-model-core-tool-json-model
  (agentic-ai-lab-model-spec
   'tool-json
   'runtime-local
   "local-tool-json"
   '(chat text json tool-calling)
   '(text json)
   65536
   8192
   "runtime-model-adapter"
   'model-complete
   'python-runtime
   '((profile . default-tool-json))))

(def agentic-ai-lab-model-core-default-catalog
  (agentic-ai-lab-model-catalog
   'model-core-default
   (list agentic-ai-lab-model-core-fast-text-model
         agentic-ai-lab-model-core-tool-json-model)
   '((owner . model-core)
     (projection . runtime-facing))))

(def agentic-ai-lab-model-core-default-selection-policy
  (agentic-ai-lab-model-selection-policy
   'default-tool-aware
   '(tool-json fast-text)
   'fast-text
   '(chat text)
   'first-compatible
   '((max-cost-tier . default)
     (latency-class . interactive))
   '((owner . model-core)
     (policy . default))))
