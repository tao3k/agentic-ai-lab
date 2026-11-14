;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Inert Context prototypes and the Memory Feature refinement.
(import (only-in :clan/poo/object .def .o)
        (only-in "funs-features.ss" ContextCoreProfile context-profile-from-feature-ids)
        "types.ss")
(export AiAgenticContextTemporalPolicy. AiAgenticContextOrgAnchor.
        AiAgenticContextDelta. AiAgenticContextEdit. AiAgenticContextScope.
        ContextCoreProfile EnableMemory)

(def (EnableMemory scope)
  (.o (:: self scope)
    profile: (context-profile-from-feature-ids '(ai-agentic-context/core ai-agentic-context/memory))))

(.def AiAgenticContextScope.
  (kind 'agentic-ai-lab.ai-agentic-context.scope.v1)
  (bundle #f) (organization #f) (epoch #f) (project #f) (worktree #f)
  (source-cut #f) (actor #f) (task #f) (destination #f)
  (session #f) (turn #f))

(.def AiAgenticContextEdit.
  (kind 'agentic-ai-lab.ai-agentic-context.edit.v1)
  (identity #f) (expected #f) (replacement #f))
(.def AiAgenticContextDelta.
  (kind 'agentic-ai-lab.ai-agentic-context.delta.v1)
  (base-digest #f) (target-digest #f) (edits '()) (order '()))

(.def AiAgenticContextOrgAnchor.
  (kind 'agentic-ai-lab.ai-agentic-context.org-anchor.v1)
  (org-id #f) (container-kind #f) (container-start #f)
  (value-start #f) (value-end #f) (source-digest #f) (parser-identity #f)
  (projection-digest #f) (scope-digest #f) (session #f) (turn #f)
  (semantic-digest #f) (source-authenticated? #f) (action-authorized? #f))

(.def AiAgenticContextTemporalPolicy.
  (kind 'agentic-ai-lab.ai-agentic-context.temporal-policy.v1)
  (identity #f) (revision #f) (window #f) (clock-role #f) (purposes '()) (semantic-digest #f))
