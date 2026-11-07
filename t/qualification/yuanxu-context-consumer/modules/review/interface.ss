;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import "types.ss" "objects.ss")
(.def Review
  identity: 'review
  core:
  (.o requires:
      (.o Context:
          (.o module-id: 'agentic-ai-lab/modules/ai-agentic-context/interface
              refine: refine-context))
      scope-contract: ReviewScopeContract
      exports: (.o context: Context))
  features: (.o))
