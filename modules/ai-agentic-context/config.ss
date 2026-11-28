;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .o))
(def Config (.o))

;;; Public operations are selected through this Module's init.exports scope.
(import "types.ss" "objects.ss" "funs-scope.ss" "funs-org-properties.ss"
        "funs-governance-graph.ss" "funs-org-elements-gql.ss"
        "funs-org-progressive-rules.ss" "funs-subtree-mediation.ss"
        "funs-trust-lattice.ss" "funs-epistemic-consolidation.ss"
        "funs-assembly-pipeline.ss"
        "org-contract/elements.ss")
(export Config ContextOperations)
(def ContextOperations
  (.o admit-scope: agentic-ai-lab-ai-agentic-context-scope-admit
      admission-type: AiAgenticContextAdmissionType
      scope-prototype: AiAgenticContextScope.
      scope-shape?: agentic-ai-lab-ai-agentic-context-scope-shape?
      org-source: context-org-source
      org-contract-schema-prototype: OrgContractSchema.
      org-contract-catalog: DefaultOrgContractCatalog
      contract-schema-resolver: resolve-org-contract-schema
      org-properties: agentic-ai-lab-ai-agentic-context-org-properties
      org-property-disjoint?: agentic-ai-lab-ai-agentic-context-org-property-disjoint?
      org-property-contains?: agentic-ai-lab-ai-agentic-context-org-property-contains?
      governance-graph: agentic-ai-lab-ai-agentic-context-governance-graph
      topology-entries: agentic-ai-lab-ai-agentic-context-topology-entries
      agent-affinities: agentic-ai-lab-ai-agentic-context-agent-affinities
      governance-conflicts: agentic-ai-lab-ai-agentic-context-governance-conflicts
      org-element-graph: agentic-ai-lab-ai-agentic-context-org-element-graph
      org-element->gql-query: agentic-ai-lab-ai-agentic-context-org-element->gql-query
      org-elements-select: agentic-ai-lab-ai-agentic-context-org-elements-select
      ready-task-slices: agentic-ai-lab-ai-agentic-context-ready-task-slices
      babel-upsert-results: agentic-ai-lab-ai-agentic-context-babel-upsert-results
      checklist-set: agentic-ai-lab-ai-agentic-context-checklist-set
      headline-set-todo: agentic-ai-lab-ai-agentic-context-headline-set-todo
      fission-subtree: agentic-ai-lab-ai-agentic-context-fission-subtree
      progressive-rule-config-prototype: AiAgenticContextProgressiveRuleConfig.
      parse-rule-overrides: agentic-ai-lab-ai-agentic-context-parse-rule-overrides
      ascent-progressive-plan: agentic-ai-lab-ai-agentic-context-ascent-progressive-plan
      render-progressive-org: agentic-ai-lab-ai-agentic-context-render-progressive-org
      ast-auto-repair: agentic-ai-lab-ai-agentic-context-ast-auto-repair
      repair-org: agentic-ai-lab-ai-agentic-context-repair-org
      subtree-proposal-prototype: AiAgenticContextSubtreeProposal.
      org-subtree-digest: agentic-ai-lab-ai-agentic-context-org-subtree-digest
      subtree-mediation-init: agentic-ai-lab-ai-agentic-context-subtree-mediation-init
      subtree-issue-token: agentic-ai-lab-ai-agentic-context-subtree-issue-token
      subtree-commit: agentic-ai-lab-ai-agentic-context-subtree-commit
      endorsement-receipt: agentic-ai-lab-ai-agentic-context-endorsement-receipt
      admit-trust-promotion: agentic-ai-lab-ai-agentic-context-admit-trust-promotion
      restriction-envelope: agentic-ai-lab-ai-agentic-context-restriction-envelope
      restriction-meet: agentic-ai-lab-ai-agentic-context-restriction-meet
      handoff-assess: agentic-ai-lab-ai-agentic-context-handoff-assess
      kv-prefix-admit: agentic-ai-lab-ai-agentic-context-kv-prefix-admit
      declassification-cert: agentic-ai-lab-ai-agentic-context-declassification-cert
      admit-declassification: agentic-ai-lab-ai-agentic-context-admit-declassification
      project-epistemic: agentic-ai-lab-ai-agentic-context-project-epistemic
      admit-security-branch: agentic-ai-lab-ai-agentic-context-admit-security-branch
      admit-consolidation: agentic-ai-lab-ai-agentic-context-admit-consolidation
      quotient-survives?: agentic-ai-lab-ai-agentic-context-quotient-survives?
      join-provider-receipts: agentic-ai-lab-ai-agentic-context-join-provider-receipts
      memory-candidate: agentic-ai-lab-ai-agentic-context-memory-candidate
      admit-memory-promotion: agentic-ai-lab-ai-agentic-context-admit-memory-promotion
      recall-memories: agentic-ai-lab-ai-agentic-context-recall-memories
      serialize-two-zone-prompt: agentic-ai-lab-ai-agentic-context-serialize-two-zone-prompt
      admit-confined-detour-return: agentic-ai-lab-ai-agentic-context-admit-confined-detour-return
      causal-counterfactual-audit: agentic-ai-lab-ai-agentic-context-causal-counterfactual-audit
      evaluate-stall-advisory: agentic-ai-lab-ai-agentic-context-evaluate-stall-advisory
      verify-tool-schema-pin: agentic-ai-lab-ai-agentic-context-verify-tool-schema-pin
      admit-mcp-tool-registration: agentic-ai-lab-ai-agentic-context-admit-mcp-tool-registration
      admit-camel-sensitive-sink: agentic-ai-lab-ai-agentic-context-admit-camel-sensitive-sink
      audit-tool-metadata-decision-dependence: agentic-ai-lab-ai-agentic-context-audit-tool-metadata-decision-dependence
      replay-audit-capsule: agentic-ai-lab-ai-agentic-context-replay-audit-capsule
      assemble-governed-turn: agentic-ai-lab-ai-agentic-context-assemble-governed-turn))
