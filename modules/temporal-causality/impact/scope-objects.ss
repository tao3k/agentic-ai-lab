;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .o)
        (only-in :clan/poo/mop validate)
        (only-in :agentic-ai-lab/modules/temporal-causality/impact/scope-types
                 AgenticAILabTemporalImpactScope
                 AgenticAILabTemporalImpactScopeAudit))
(export agentic-ai-lab-temporal-impact-scope-value
        agentic-ai-lab-temporal-impact-scope-audit-value)

(def (agentic-ai-lab-temporal-impact-scope-value
      identity-value digest-value intervention-value subject-value cut-value
      projection-value domain-value onset-value end-value target-value
      protected-value)
  (validate AgenticAILabTemporalImpactScope
    (.o kind: 'agentic-ai-lab.temporal-causality.impact-scope
        identity: identity-value semantic-digest: digest-value
        intervention-identity: intervention-value
        subject-identity: subject-value source-cut-digest: cut-value
        source-projection-digest: projection-value
        time-domain-identity: domain-value onset: onset-value end: end-value
        direct-target-outcomes: target-value
        protected-outcomes: protected-value)))

(def (agentic-ai-lab-temporal-impact-scope-audit-value
      identity-value digest-value scope-value candidate-value baseline-value
      outcomes-value audits-value prefix-value protected-value status-value)
  (validate AgenticAILabTemporalImpactScopeAudit
    (.o kind: 'agentic-ai-lab.temporal-causality.impact-scope-audit
        identity: identity-value semantic-digest: digest-value
        scope-digest: scope-value
        candidate-scenario-identity: candidate-value
        baseline-scenario-identity: baseline-value
        audited-outcomes: outcomes-value window-audits: audits-value
        prefix-status: prefix-value protected-status: protected-value
        status: status-value
        causal-impact-admitted?: #f runtime-executed?: #f)))
