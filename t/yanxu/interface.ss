;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Shared test dependency facade. Test ownership remains with the root Loader.
;;; These are lazy POO slots, not a second init or a separate test manifest.
(import (only-in :clan/poo/object .get .o)
        (only-in :tao3k/agentic-ai-lab/init tao3k/agentic-ai-lab.init.exports)
        (only-in :tao3k/agentic-ai-lab/modules/module-authoring/interface
          yuanxu-module-interface agentic-ai-lab-modules
          agentic-ai-lab-module-closure agentic-ai-lab-module-names
          agentic-ai-lab-module-option-schemas agentic-ai-lab-module-validation-receipts))
(export make-lab-dependencies Lab
        yuanxu-module-interface agentic-ai-lab-modules
        agentic-ai-lab-module-closure agentic-ai-lab-module-names
        agentic-ai-lab-module-option-schemas agentic-ai-lab-module-validation-receipts)

(def (make-lab-dependencies selection)
  (.o context: (.get selection modules ai-agentic-context)
      temporal: (.get selection modules temporal-causality)
      gitops: (.get selection modules gitops)
      module-authoring: (.get selection modules module-authoring)
      session: (.get selection modules session)
      loop-engine: (.get selection modules loop-engine)
      authorization: (.get selection modules authorization)
      c-abi-clock: (.get selection CAbi clock)))
(def Lab (make-lab-dependencies tao3k/agentic-ai-lab.init.exports))
