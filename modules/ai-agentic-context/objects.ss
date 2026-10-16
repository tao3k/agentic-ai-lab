;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Inert Context prototypes and owned Feature descriptor values.
(import (only-in :clan/poo/object .def)
        :core/feature-system/model
        "types.ss")
(export AiAgenticContextTemporalPolicy. AiAgenticContextOrgAnchor. AiAgenticContextDelta. AiAgenticContextEdit. AiAgenticContextScope. ai-agentic-context-core-feature
        ai-agentic-context-memory-feature)
(.def AiAgenticContextScope.
  (kind 'poo-flow.ai-agentic-context.scope.v1)
  (bundle #f) (organization #f) (epoch #f) (project #f) (worktree #f)
  (source-cut #f) (actor #f) (task #f) (destination #f)
  (session #f) (turn #f))
(def ai-agentic-context-core-feature
  (feature-descriptor
    (feature-descriptor-base 'ai-agentic-context/core 'ai-agentic-context)))
(def ai-agentic-context-memory-feature
  (feature-descriptor (feature-spec-compose
    (feature-descriptor-base 'ai-agentic-context/memory 'ai-agentic-context)
    (feature-required-features ai-agentic-context-core-feature))))

(.def AiAgenticContextEdit.
  (kind 'poo-flow.ai-agentic-context.edit.v1)
  (identity #f) (expected #f) (replacement #f))
(.def AiAgenticContextDelta.
  (kind 'poo-flow.ai-agentic-context.delta.v1)
  (base-digest #f) (target-digest #f) (edits '()) (order '()))

(.def AiAgenticContextOrgAnchor.
  (kind 'poo-flow.ai-agentic-context.org-anchor.v1)
  (org-id #f) (container-kind #f) (container-start #f)
  (value-start #f) (value-end #f) (source-digest #f) (parser-identity #f)
  (projection-digest #f) (scope-digest #f) (session #f) (turn #f)
  (semantic-digest #f) (source-authenticated? #f) (action-authorized? #f))

(.def AiAgenticContextTemporalPolicy.
  (kind 'poo-flow.ai-agentic-context.temporal-policy.v1)
  (identity #f) (revision #f) (window #f) (clock-role #f) (purposes '()) (semantic-digest #f))
