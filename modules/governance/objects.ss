;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO-native Governance values and default method slots.
;;; Invariant: the root Profile is abstract and an assessment is never authority.
(import (only-in :clan/poo/object .o .ref)
        (only-in :clan/poo/mop validate)
        (only-in :std/list/list filter)
        (only-in :agentic-ai-lab/modules/governance/types
                 agentic-ai-lab-governance-profile-kind
                 agentic-ai-lab-governance-source-kind
                 agentic-ai-lab-governance-precondition-kind
                 agentic-ai-lab-governance-threat-kind
                 agentic-ai-lab-governance-threat-model-kind
                 agentic-ai-lab-governance-assessment-kind
                 AgenticAILabGovernanceSource
                 AgenticAILabGovernancePrecondition
                 AgenticAILabGovernanceThreat
                 AgenticAILabGovernanceThreatModel
                 AgenticAILabGovernanceAssessment
                 agentic-ai-lab-governance-assess-threats))

(export AgenticAILabGovernanceProfile.
        AgenticAILabGovernanceThreatModel.
        agentic-ai-lab-governance-source
        agentic-ai-lab-governance-precondition
        agentic-ai-lab-governance-threat
        agentic-ai-lab-governance-threat-model
        agentic-ai-lab-governance-threat-blocking?
        agentic-ai-lab-governance-assessment-value
        agentic-ai-lab-governance-assessment)

(def (agentic-ai-lab-governance-assessment-value
      profile model unresolved-threat-values context-value)
  (validate
   AgenticAILabGovernanceAssessment
   (.o kind: agentic-ai-lab-governance-assessment-kind
       profile-identity: (.ref profile 'identity)
       model-identity: (.ref model 'identity)
       assessed-threats: (.ref model 'threats)
       unresolved-threats: unresolved-threat-values
       handoff-ready?: (null? unresolved-threat-values)
       runtime-executed?: #f
       context: context-value)))

(def (agentic-ai-lab-governance-threat-blocking? threat)
  (and (memq (.ref threat 'severity) '(high critical))
       (memq (.ref threat 'phase) '(exposed realized))
       #t))

(def (agentic-ai-lab-governance-default-assessment model profile context-value)
  (let* ((threats (.ref model 'threats))
         (unresolved
          (map (lambda (threat) (.ref threat 'identity))
               (filter agentic-ai-lab-governance-threat-blocking? threats))))
    (agentic-ai-lab-governance-assessment-value
     profile model unresolved context-value)))

(def AgenticAILabGovernanceThreatModel.
  (.o (:: self)
      kind: agentic-ai-lab-governance-threat-model-kind
      identity: "agentic-ai-lab/governance/threat-model/empty"
      threats: '()
      .assess-threats:
      (lambda (profile context)
        (agentic-ai-lab-governance-default-assessment self profile context))))

(def AgenticAILabGovernanceProfile.
  (.o (:: self)
      kind: agentic-ai-lab-governance-profile-kind
      identity: #f
      revision: #f
      owner: #f
      ontology: (.o)
      policies: (.o)
      source-assets: '()
      threat-model: AgenticAILabGovernanceThreatModel.
      .assess-governance:
      (lambda (context)
        (agentic-ai-lab-governance-assess-threats threat-model self context))))

(def (agentic-ai-lab-governance-source identity-value path-value language-value)
  (validate
   AgenticAILabGovernanceSource
   (.o kind: agentic-ai-lab-governance-source-kind
       governance-kind: agentic-ai-lab-governance-source-kind
       identity: identity-value
       path: path-value
       language: language-value)))

(def (agentic-ai-lab-governance-precondition identity-value observed-value
                                       evidence-value)
  (validate
   AgenticAILabGovernancePrecondition
   (.o kind: agentic-ai-lab-governance-precondition-kind
       identity: identity-value
       observed?: (if observed-value #t #f)
       evidence: evidence-value)))

(def (agentic-ai-lab-governance-threat identity-value severity-value phase-value
                                 precondition-values
                                 mitigations: (mitigation-values '())
                                 acceptance-authority:
                                 (acceptance-authority-value #f))
  (validate
   AgenticAILabGovernanceThreat
   (.o kind: agentic-ai-lab-governance-threat-kind
       identity: identity-value
       severity: severity-value
       phase: phase-value
       preconditions: precondition-values
       mitigations: mitigation-values
       acceptance-authority: acceptance-authority-value)))

(def (agentic-ai-lab-governance-threat-model identity-value threat-values)
  (validate
   AgenticAILabGovernanceThreatModel
   (.o (:: @ AgenticAILabGovernanceThreatModel.)
       identity: identity-value
       threats: threat-values)))

(def (agentic-ai-lab-governance-assessment profile context)
  (agentic-ai-lab-governance-assess-threats
   (.ref profile 'threat-model) profile context))
