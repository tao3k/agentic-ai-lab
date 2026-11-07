;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :clan/poo/mop define-type Type. element?)
        (only-in :std/list/list every))
(export PooFlowEvidenceRetrieval PooFlowEvidenceUse PooFlowEvidenceAssessment
        PooFlowEvidenceDependency PooFlowEvidenceLineage
        PooFlowEvidenceUseAudit PooFlowEvidenceImpactFrontier
        agentic-ai-lab-evidence-retrieval? agentic-ai-lab-evidence-use?
        agentic-ai-lab-evidence-assessment?
        agentic-ai-lab-evidence-dependency? agentic-ai-lab-evidence-lineage?
        agentic-ai-lab-evidence-use-audit? agentic-ai-lab-evidence-impact-frontier?)

(def (text? value) (and (string? value) (> (string-length value) 0)))
(def (texts? value) (and (list? value) (every text? value)))
(def (slots? value names)
  (and (object? value) (every (lambda (name) (.slot? value name)) names)))
(def (common? value tag names)
  (and (slots? value (append '(kind identity semantic-digest) names))
       (eq? (.ref value 'kind) tag)
       (every text? (map (lambda (name) (.ref value name))
                         (append '(identity semantic-digest) names)))))

(def (retrieval-shape? value)
  (common? value 'poo-flow.temporal-causality.evidence-retrieval
           '(query-identity evidence-identity source-digest)))
(define-type (PooFlowEvidenceRetrieval @ Type.)
  .element?: retrieval-shape?)
(def (agentic-ai-lab-evidence-retrieval? value)
  (element? PooFlowEvidenceRetrieval value))

(def (use-shape? value)
  (and (common? value 'poo-flow.temporal-causality.evidence-use
                '(evidence-identity claim-identity source-digest
                                      claim-digest))))
(define-type (PooFlowEvidenceUse @ Type.)
  .element?: use-shape?)
(def (agentic-ai-lab-evidence-use? value)
  (element? PooFlowEvidenceUse value))

(def (assessment-shape? value)
  (and (common? value 'poo-flow.temporal-causality.evidence-assessment
                '(use-identity use-digest assessor-identity method-identity
                               basis-digest))
       (slots? value '(verdict))
       (memq (.ref value 'verdict) '(supports refutes uncertain))))
(define-type (PooFlowEvidenceAssessment @ Type.)
  .element?: assessment-shape?)
(def (agentic-ai-lab-evidence-assessment? value)
  (element? PooFlowEvidenceAssessment value))

(def (dependency-shape? value)
  (common? value 'poo-flow.temporal-causality.evidence-dependency
           '(source-claim-identity dependent-claim-identity)))
(define-type (PooFlowEvidenceDependency @ Type.)
  .element?: dependency-shape?)
(def (agentic-ai-lab-evidence-dependency? value)
  (element? PooFlowEvidenceDependency value))

(def (lineage-shape? value)
  (and (common? value 'poo-flow.temporal-causality.evidence-lineage '())
       (slots? value '(retrievals uses assessments dependencies))
       (list? (.ref value 'retrievals))
       (list? (.ref value 'uses))
       (list? (.ref value 'assessments))
       (list? (.ref value 'dependencies))
       (every agentic-ai-lab-evidence-retrieval? (.ref value 'retrievals))
       (every agentic-ai-lab-evidence-use? (.ref value 'uses))
       (every agentic-ai-lab-evidence-assessment? (.ref value 'assessments))
       (every agentic-ai-lab-evidence-dependency? (.ref value 'dependencies))))
(define-type (PooFlowEvidenceLineage @ Type.)
  .element?: lineage-shape?)
(def (agentic-ai-lab-evidence-lineage? value)
  (element? PooFlowEvidenceLineage value))

(def (audit-shape? value)
  (and (common? value 'poo-flow.temporal-causality.evidence-use-audit
                '(lineage-digest))
       (slots? value '(retrieved-unused-evidence cited-unretrieved-evidence
                       unreviewed-use-identities supported-use-identities
                       refuted-use-identities uncertain-use-identities
                       contested-use-identities status))
       (every texts?
              (map (lambda (name) (.ref value name))
                   '(retrieved-unused-evidence cited-unretrieved-evidence
                     unreviewed-use-identities supported-use-identities
                     refuted-use-identities uncertain-use-identities
                     contested-use-identities)))
       (memq (.ref value 'status) '(declared-reviewed needs-review))))
(define-type (PooFlowEvidenceUseAudit @ Type.)
  .element?: audit-shape?)
(def (agentic-ai-lab-evidence-use-audit? value)
  (element? PooFlowEvidenceUseAudit value))

(def (frontier-shape? value)
  (and (common? value 'poo-flow.temporal-causality.evidence-impact-frontier
                '(lineage-digest))
       (slots? value '(seed-evidence-identities reachable-claim-identities
                       actual-impact-admitted?))
       (texts? (.ref value 'seed-evidence-identities))
       (texts? (.ref value 'reachable-claim-identities))
       (eq? (.ref value 'actual-impact-admitted?) #f)))
(define-type (PooFlowEvidenceImpactFrontier @ Type.)
  .element?: frontier-shape?)
(def (agentic-ai-lab-evidence-impact-frontier? value)
  (element? PooFlowEvidenceImpactFrontier value))
