;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: engine-neutral Governance types and open dispatch protocols.
;;; Invariant: admission and threat assessment never imply action authority.
(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :clan/poo/mop .defgeneric define-type Type. element?)
        (only-in :std/list/list every))

(export agentic-ai-lab-governance-profile-kind
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
        AgenticAILabGovernanceProfile
        agentic-ai-lab-governance-assess-threats
        agentic-ai-lab-governance-assess
        agentic-ai-lab-governance-source?
        agentic-ai-lab-governance-precondition?
        agentic-ai-lab-governance-threat?
        agentic-ai-lab-governance-threat-model?
        agentic-ai-lab-governance-assessment?
        agentic-ai-lab-governance-profile?)

(def agentic-ai-lab-governance-profile-kind 'agentic-ai-lab.governance-profile)
(def agentic-ai-lab-governance-source-kind 'agentic-ai-lab.governance-source)
(def agentic-ai-lab-governance-precondition-kind 'agentic-ai-lab.governance-precondition)
(def agentic-ai-lab-governance-threat-kind 'agentic-ai-lab.governance-threat)
(def agentic-ai-lab-governance-threat-model-kind 'agentic-ai-lab.governance-threat-model)
(def agentic-ai-lab-governance-assessment-kind 'agentic-ai-lab.governance-assessment)

;;; Threat-model and Profile specializations replace method slots through
;;; ordinary gerbil-poo inheritance; no central case statement owns extension.
(.defgeneric (agentic-ai-lab-governance-assess-threats model profile context)
  slot: .assess-threats)

(.defgeneric (agentic-ai-lab-governance-assess profile context)
  slot: .assess-governance)

(def (governance-text? value)
  (and (string? value) (> (string-length value) 0)))

(def (governance-has-slots? value slots)
  (and (object? value)
       (every (lambda (slot) (.slot? value slot)) slots)))

(def (governance-kind? value kind slots)
  (and (governance-has-slots? value (cons 'kind slots))
       (eq? (.ref value 'kind) kind)))

(def (agentic-ai-lab-governance-source-shape? value)
  (and (governance-has-slots?
        value '(kind governance-kind identity path language))
       (eq? (.ref value 'governance-kind) agentic-ai-lab-governance-source-kind)
       (governance-text? (.ref value 'identity))
       (governance-text? (.ref value 'path))
       (symbol? (.ref value 'language))))

(define-type (AgenticAILabGovernanceSource @ Type.)
  .element?: agentic-ai-lab-governance-source-shape?)

(def (agentic-ai-lab-governance-precondition-shape? value)
  (and (governance-kind?
        value agentic-ai-lab-governance-precondition-kind
        '(identity observed? evidence))
       (governance-text? (.ref value 'identity))
       (boolean? (.ref value 'observed?))
       (if (.ref value 'observed?)
         (governance-text? (.ref value 'evidence))
         (or (not (.ref value 'evidence))
             (governance-text? (.ref value 'evidence))))))

(define-type (AgenticAILabGovernancePrecondition @ Type.)
  .element?: agentic-ai-lab-governance-precondition-shape?)

(def (governance-severity? value)
  (and (memq value '(low moderate high critical)) #t))

(def (governance-threat-phase? value)
  (and (memq value '(latent exposed realized mitigated accepted)) #t))

(def (agentic-ai-lab-governance-threat-shape? value)
  (and
   (governance-kind?
    value agentic-ai-lab-governance-threat-kind
    '(identity severity phase preconditions mitigations acceptance-authority))
   (governance-text? (.ref value 'identity))
   (governance-severity? (.ref value 'severity))
   (governance-threat-phase? (.ref value 'phase))
   (list? (.ref value 'preconditions))
   (pair? (.ref value 'preconditions))
   (every (lambda (item) (element? AgenticAILabGovernancePrecondition item))
          (.ref value 'preconditions))
   (list? (.ref value 'mitigations))
   (every governance-text? (.ref value 'mitigations))
   (if (eq? (.ref value 'phase) 'mitigated)
     (pair? (.ref value 'mitigations))
     #t)
   (if (eq? (.ref value 'phase) 'accepted)
     (governance-text? (.ref value 'acceptance-authority))
     (or (not (.ref value 'acceptance-authority))
         (governance-text? (.ref value 'acceptance-authority))))))

(define-type (AgenticAILabGovernanceThreat @ Type.)
  .element?: agentic-ai-lab-governance-threat-shape?)

(def (agentic-ai-lab-governance-threat-model-shape? value)
  (and (governance-kind?
        value agentic-ai-lab-governance-threat-model-kind
        '(identity threats .assess-threats))
       (governance-text? (.ref value 'identity))
       (list? (.ref value 'threats))
       (every (lambda (item) (element? AgenticAILabGovernanceThreat item))
              (.ref value 'threats))
       (procedure? (.ref value '.assess-threats))))

(define-type (AgenticAILabGovernanceThreatModel @ Type.)
  .element?: agentic-ai-lab-governance-threat-model-shape?)

(def (agentic-ai-lab-governance-assessment-shape? value)
  (and
   (governance-kind?
    value agentic-ai-lab-governance-assessment-kind
    '(profile-identity model-identity assessed-threats unresolved-threats
      handoff-ready? runtime-executed? context))
   (governance-text? (.ref value 'profile-identity))
   (governance-text? (.ref value 'model-identity))
   (list? (.ref value 'assessed-threats))
   (every (lambda (item) (element? AgenticAILabGovernanceThreat item))
          (.ref value 'assessed-threats))
   (list? (.ref value 'unresolved-threats))
   (every governance-text? (.ref value 'unresolved-threats))
   (boolean? (.ref value 'handoff-ready?))
   (eq? (.ref value 'handoff-ready?)
        (null? (.ref value 'unresolved-threats)))
   (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabGovernanceAssessment @ Type.)
  .element?: agentic-ai-lab-governance-assessment-shape?)

(def (agentic-ai-lab-governance-profile-shape? value)
  (and
   (governance-kind?
    value agentic-ai-lab-governance-profile-kind
    '(identity revision owner ontology policies source-assets threat-model
      .assess-governance))
   (every (lambda (slot) (governance-text? (.ref value slot)))
          '(identity revision owner))
   (object? (.ref value 'ontology))
   (object? (.ref value 'policies))
   (list? (.ref value 'source-assets))
   (every (lambda (item) (element? AgenticAILabGovernanceSource item))
          (.ref value 'source-assets))
   (element? AgenticAILabGovernanceThreatModel (.ref value 'threat-model))
   (procedure? (.ref value '.assess-governance))))

(define-type (AgenticAILabGovernanceProfile @ Type.)
  .element?: agentic-ai-lab-governance-profile-shape?)

(def (agentic-ai-lab-governance-source? value)
  (element? AgenticAILabGovernanceSource value))

(def (agentic-ai-lab-governance-precondition? value)
  (element? AgenticAILabGovernancePrecondition value))

(def (agentic-ai-lab-governance-threat? value)
  (element? AgenticAILabGovernanceThreat value))

(def (agentic-ai-lab-governance-threat-model? value)
  (element? AgenticAILabGovernanceThreatModel value))

(def (agentic-ai-lab-governance-assessment? value)
  (element? AgenticAILabGovernanceAssessment value))

(def (agentic-ai-lab-governance-profile? value)
  (element? AgenticAILabGovernanceProfile value))
