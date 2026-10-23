;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: engine-neutral Proof value kinds and closed shape contracts.
;;; Invariant: proof evidence is inert; admission never executes a prover or
;;; grants runtime/action authority.
(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :clan/poo/mop define-type Type. element?)
        (only-in :std/list/list every))

(export +agentic-ai-lab-proof-artifact-kind+
        +agentic-ai-lab-proof-receipt-kind+
        +agentic-ai-lab-proof-impact-binding-kind+
        +agentic-ai-lab-proof-refinement-binding-kind+
        +agentic-ai-lab-proof-assurance-kind+
        +agentic-ai-lab-proof-module-kind+
        AgenticAILabProofArtifact
        AgenticAILabProofReceipt
        AgenticAILabProofImpactBinding
        AgenticAILabProofRefinementBinding
        AgenticAILabProofAssurance
        AgenticAILabProofModule
        agentic-ai-lab-proof-text?
        agentic-ai-lab-proof-digest?
        agentic-ai-lab-proof-artifact?
        agentic-ai-lab-proof-receipt?
        agentic-ai-lab-proof-impact-binding?
        agentic-ai-lab-proof-refinement-binding?
        agentic-ai-lab-proof-assurance?
        agentic-ai-lab-proof-module?)

(def +agentic-ai-lab-proof-artifact-kind+ 'agentic-ai-lab.proof-artifact.v1)
(def +agentic-ai-lab-proof-receipt-kind+ 'agentic-ai-lab.proof-receipt.v1)
(def +agentic-ai-lab-proof-impact-binding-kind+ 'agentic-ai-lab.proof-impact-binding.v1)
(def +agentic-ai-lab-proof-refinement-binding-kind+
  'agentic-ai-lab.proof-refinement-binding.v1)
(def +agentic-ai-lab-proof-assurance-kind+ 'agentic-ai-lab.proof-assurance.v1)
(def +agentic-ai-lab-proof-module-kind+ 'agentic-ai-lab.proof-module.v1)

(def (agentic-ai-lab-proof-text? value)
  (and (string? value) (> (string-length value) 0)))

(def (agentic-ai-lab-proof-digest? value)
  (and (string? value)
       (= (string-length value) 71)
       (string=? (substring value 0 7) "sha256:")))

(def (proof-has-slots? value slots)
  (and (object? value)
       (every (lambda (slot) (.slot? value slot)) slots)))

(def (proof-kind? value kind slots)
  (and (proof-has-slots? value (cons 'kind slots))
       (eq? (.ref value 'kind) kind)))

(def (proof-artifact-shape? value)
  (and (proof-kind?
        value +agentic-ai-lab-proof-artifact-kind+
        '(identity engine language path content-digest declarations metadata
          runtime-executed?))
       (agentic-ai-lab-proof-text? (.ref value 'identity))
       (symbol? (.ref value 'engine))
       (symbol? (.ref value 'language))
       (agentic-ai-lab-proof-text? (.ref value 'path))
       (agentic-ai-lab-proof-digest? (.ref value 'content-digest))
       (list? (.ref value 'declarations))
       (every symbol? (.ref value 'declarations))
       (object? (.ref value 'metadata))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabProofArtifact @ Type.)
  .element?: proof-artifact-shape?)

(def (proof-receipt-shape? value)
  (and (proof-kind?
        value +agentic-ai-lab-proof-receipt-kind+
        '(identity artifact-identity artifact-content-digest engine
          certifications evidence-digest admitted? runtime-executed?))
       (agentic-ai-lab-proof-text? (.ref value 'identity))
       (agentic-ai-lab-proof-text? (.ref value 'artifact-identity))
       (agentic-ai-lab-proof-digest? (.ref value 'artifact-content-digest))
       (symbol? (.ref value 'engine))
       (list? (.ref value 'certifications))
       (every symbol? (.ref value 'certifications))
       (agentic-ai-lab-proof-digest? (.ref value 'evidence-digest))
       (boolean? (.ref value 'admitted?))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabProofReceipt @ Type.)
  .element?: proof-receipt-shape?)

(def (proof-impact-binding-shape? value)
  (and (proof-kind?
        value +agentic-ai-lab-proof-impact-binding-kind+
        '(identity upstream-artifact-identity upstream-content-digest
          downstream-artifact-identity downstream-content-digest impact-map
          stale-downstream-policy runtime-executed?))
       (every
        (lambda (slot) (agentic-ai-lab-proof-text? (.ref value slot)))
        '(identity upstream-artifact-identity downstream-artifact-identity))
       (agentic-ai-lab-proof-digest? (.ref value 'upstream-content-digest))
       (agentic-ai-lab-proof-digest? (.ref value 'downstream-content-digest))
       (object? (.ref value 'impact-map))
       (eq? (.ref value 'stale-downstream-policy) 'reject)
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabProofImpactBinding @ Type.)
  .element?: proof-impact-binding-shape?)

(def (proof-refinement-binding-shape? value)
  (and (proof-kind?
        value +agentic-ai-lab-proof-refinement-binding-kind+
        '(identity upstream-artifact-identity upstream-content-digest
          downstream-artifact-identity downstream-content-digest
          receipt-identity impact-binding admitted? runtime-executed?))
       (every
        (lambda (slot) (agentic-ai-lab-proof-text? (.ref value slot)))
        '(identity upstream-artifact-identity downstream-artifact-identity
          receipt-identity))
       (agentic-ai-lab-proof-digest? (.ref value 'upstream-content-digest))
       (agentic-ai-lab-proof-digest? (.ref value 'downstream-content-digest))
       (element? AgenticAILabProofImpactBinding (.ref value 'impact-binding))
       (boolean? (.ref value 'admitted?))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabProofRefinementBinding @ Type.)
  .element?: proof-refinement-binding-shape?)

(def (proof-assurance-shape? value)
  (and (proof-kind?
        value +agentic-ai-lab-proof-assurance-kind+
        '(identity artifacts receipts refinements artifact-index receipt-index
          current? admitted? assurance-digest runtime-executed?))
       (agentic-ai-lab-proof-text? (.ref value 'identity))
       (list? (.ref value 'artifacts))
       (every (lambda (item) (element? AgenticAILabProofArtifact item))
              (.ref value 'artifacts))
       (list? (.ref value 'receipts))
       (every (lambda (item) (element? AgenticAILabProofReceipt item))
              (.ref value 'receipts))
       (list? (.ref value 'refinements))
       (every (lambda (item) (element? AgenticAILabProofRefinementBinding item))
              (.ref value 'refinements))
       (hash-table? (.ref value 'artifact-index))
       (hash-table? (.ref value 'receipt-index))
       (boolean? (.ref value 'current?))
       (boolean? (.ref value 'admitted?))
       (eq? (.ref value 'admitted?) (.ref value 'current?))
       (agentic-ai-lab-proof-digest? (.ref value 'assurance-digest))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabProofAssurance @ Type.)
  .element?: proof-assurance-shape?)

(def (proof-module-shape? value)
  (and (proof-kind?
        value +agentic-ai-lab-proof-module-kind+
        '(identity required-slots optional-slots providers .admit-assurance))
       (agentic-ai-lab-proof-text? (.ref value 'identity))
       (list? (.ref value 'required-slots))
       (pair? (.ref value 'required-slots))
       (every symbol? (.ref value 'required-slots))
       (list? (.ref value 'optional-slots))
       (every symbol? (.ref value 'optional-slots))
       (object? (.ref value 'providers))
       (procedure? (.ref value '.admit-assurance))))

(define-type (AgenticAILabProofModule @ Type.)
  .element?: proof-module-shape?)

(def (agentic-ai-lab-proof-artifact? value)
  (element? AgenticAILabProofArtifact value))
(def (agentic-ai-lab-proof-receipt? value)
  (element? AgenticAILabProofReceipt value))
(def (agentic-ai-lab-proof-impact-binding? value)
  (element? AgenticAILabProofImpactBinding value))
(def (agentic-ai-lab-proof-refinement-binding? value)
  (element? AgenticAILabProofRefinementBinding value))
(def (agentic-ai-lab-proof-assurance? value)
  (element? AgenticAILabProofAssurance value))
(def (agentic-ai-lab-proof-module? value)
  (element? AgenticAILabProofModule value))
