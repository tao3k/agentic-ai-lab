;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Inert Context prototypes and the Memory Feature refinement.
(import (only-in :clan/poo/object .def .o)
        (only-in "funs-features.ss" ContextCoreProfile context-profile-from-feature-ids)
        "types.ss")
(export AiAgenticContextTemporalPolicy. AiAgenticContextOrgAnchor. AiAgenticContextOrgProperty.
        AiAgenticContextGovernanceGraph. AiAgenticContextOrgElementGraph.
        AiAgenticContextProgressiveRuleConfig. AiAgenticContextAgentAffinity.
        AiAgenticContextSubtreeProposal. AiAgenticContextSubtreeCommitReceipt.
        AiAgenticContextEndorsementReceipt. AiAgenticContextRestrictionEnvelope.
        AiAgenticContextOmittedAlternativesReceipt. AiAgenticContextEpistemicProjection.
        AiAgenticContextDeclassificationCert. AiAgenticContextConsolidationReceipt.
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

(.def AiAgenticContextOrgProperty.
  (kind 'agentic-ai-lab.ai-agentic-context.org-property.v1)
  (container-kind #f) (container-start #f) (container-end #f) (drawer-end #f)
  (key #f) (key-start #f) (key-end #f)
  (value #f) (value-start #f) (value-end #f))

(.def AiAgenticContextTemporalPolicy.
  (kind 'agentic-ai-lab.ai-agentic-context.temporal-policy.v1)
  (identity #f) (revision #f) (window #f) (clock-role #f) (purposes '()) (semantic-digest #f))

(.def AiAgenticContextGovernanceGraph.
  (kind 'agentic-ai-lab.ai-agentic-context.governance-graph.v1)
  (identity 'context-governance) (semantic-revision #f)
  (element-space #f) (graph #f) (source-digests '()) (element-identities '())
  (complete? #t) (source-authenticated? #f) (action-authorized? #f))

(.def AiAgenticContextOrgElementGraph.
  (kind 'agentic-ai-lab.ai-agentic-context.org-element-graph.v1)
  (identity 'context-org-elements) (semantic-revision #f)
  (element-space #f) (graph #f) (source-digests '()) (source-texts '())
  (element-identities '()) (complete? #t)
  (source-authenticated? #f) (action-authorized? #f))

(.def AiAgenticContextProgressiveRuleConfig.
  (kind 'agentic-ai-lab.ai-agentic-context.progressive-rule-config.v1)
  (split-line-watermark 1000)
  (default-focus-depth 2)
  (require-sod-reviewer? #f)
  (fold-thinking-by-default? #t)
  (allow-agent-drill-down? #t))

(.def AiAgenticContextAgentAffinity.
  (kind 'agentic-ai-lab.ai-agentic-context.agent-affinity.v1)
  (agent-id #f) (project-id #f) (task-id #f)
  (anchor-identity #f) (property-id #f) (source-id #f)
  (container-start 0) (container-end 0)
  (score-bps 0) (reasons '()) (write-eligible? #f) (action-authorized? #f))

(.def AiAgenticContextSubtreeProposal.
  (kind 'agentic-ai-lab.ai-agentic-context.subtree-proposal.v1)
  (source-id #f) (base-generation #f) (target-property-id #f)
  (agent-id #f) (task-id #f) (session-id #f)
  (expected-subtree-digest #f) (replacement-body "")
  (nonce #f) (lease-id #f))

(.def AiAgenticContextSubtreeCommitReceipt.
  (kind 'agentic-ai-lab.ai-agentic-context.subtree-commit-receipt.v1)
  (accepted? #f) (reason 'uninitialized)
  (source-id #f) (committed-generation #f) (target-property-id #f)
  (agent-id #f) (before-subtree-digest #f) (after-subtree-digest #f)
  (rebased? #f) (mediation-state #f) (mediation-receipt #f) (next-source-cut #f))

(.def AiAgenticContextEndorsementReceipt.
  (kind 'agentic-ai-lab.ai-agentic-context.endorsement-receipt.v1)
  (content-digest #f) (bound-cut #f) (proposer #f) (endorser #f)
  (target-role 'observed-fact) (semantic-digest #f))

(.def AiAgenticContextRestrictionEnvelope.
  (kind 'agentic-ai-lab.ai-agentic-context.restriction-envelope.v1)
  (domain #f) (readers '()) (destinations '()) (capabilities '())
  (lease-start 0) (lease-end 0) (trust-ceiling 'observed-fact)
  (obligations '()) (semantic-digest #f))

(.def AiAgenticContextOmittedAlternativesReceipt.
  (kind 'agentic-ai-lab.ai-agentic-context.omitted-alternatives-receipt.v1)
  (inquiry-id #f) (omitted-hypotheses '()) (claims-exhaustive? #f) (semantic-digest #f))

(.def AiAgenticContextEpistemicProjection.
  (kind 'agentic-ai-lab.ai-agentic-context.epistemic-projection.v1)
  (admitted? #f) (status 'uninitialized) (inquiry-id #f)
  (budget 0) (total-cost 0) (selected-hypotheses '()) (retained-defeaters '())
  (restriction-digest #f) (omission-receipt #f) (claims-exhaustive? #f)
  (action-authorized? #f))

(.def AiAgenticContextDeclassificationCert.
  (kind 'agentic-ai-lab.ai-agentic-context.declassification-cert.v1)
  (source-repo #f) (target-repo #f) (bound-source-cut #f) (bound-target-cut #f)
  (raw-digest #f) (redacted-digest #f) (preserves-defeaters? #t)
  (proposer #f) (declassifier #f) (recipient #f)
  (origin-role 'observed-fact) (recipient-role 'observed-fact)
  (semantic-digest #f))

(.def AiAgenticContextConsolidationReceipt.
  (kind 'agentic-ai-lab.ai-agentic-context.consolidation-receipt.v1)
  (admitted? #f) (reason 'uninitialized) (insight-id #f)
  (proposer #f) (evidence-owner #f) (approver #f)
  (outcome-receipt-digest #f) (cited-premises '()) (defeat-conditions '())
  (raw-cost 0) (quotient-cost 0) (audit-hook-id #f) (watermark-covered? #f)
  (org-promoted? #f) (semantic-digest #f) (action-authorized? #f))
