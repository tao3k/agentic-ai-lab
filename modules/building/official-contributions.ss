;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: checked-out official contribution source collections.
;;; Invariant: Git submodule gitlinks own revisions and .gitmodules owns URLs;
;;; this module only exposes the packages root for identity-driven discovery.

(import (only-in :agentic-ai-lab/modules/module-authoring/source-policy AgenticAILabModuleStylePolicy)
        :yuanxu/module-system/source/collection
        :agentic-ai-lab/modules/module-authoring/module-source-collection)

(export agentic-ai-lab-official-contribution-sources
        agentic-ai-lab-official-contribution-load-path)

(def agentic-ai-lab-official-contribution-sources
  (list
   (make-yuanxu-contribution-root-module-source
    'agentic-ai-lab-official-contributions "packages"
    style-policy: AgenticAILabModuleStylePolicy)))

(def agentic-ai-lab-official-contribution-load-path
  (extend-yuanxu-module-load-path
   agentic-ai-lab-default-module-load-path
   'agentic-ai-lab-with-official-contributions
   agentic-ai-lab-official-contribution-sources))
