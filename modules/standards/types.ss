;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: domain-neutral Standards value kinds and closed shape contracts.
;;; Invariant: these predicates inspect inert values and never resolve, load,
;;; parse, validate, or execute a concrete industry standard.
(import (only-in :clan/poo/object .all-slots .ref .slot? object?)
        (only-in :clan/poo/mop define-type Type. element?)
        (only-in :yuanxu/utilities/functional
                 yuanxu-all? yuanxu-any? yuanxu-list-of?))

(export +agentic-ai-lab-standard-family-kind+
        +agentic-ai-lab-standard-failure-codes+
        +agentic-ai-lab-standard-artifact-ref-kind+
        +agentic-ai-lab-standard-artifact-source-kind+
        +agentic-ai-lab-standard-artifact-kind+
        +agentic-ai-lab-standard-edition-ref-kind+
        +agentic-ai-lab-standard-constraint-profile-kind+
        +agentic-ai-lab-standard-catalog-kind+
        +agentic-ai-lab-standard-budget-kind+
        +agentic-ai-lab-standard-bundle-kind+
        +agentic-ai-lab-standard-failure-kind+
        +agentic-ai-lab-standard-catalog-receipt-kind+
        +agentic-ai-lab-standard-resolution-receipt-kind+
        +agentic-ai-lab-standard-profile-composition-receipt-kind+
        +agentic-ai-lab-standard-load-receipt-kind+
        +agentic-ai-lab-standard-materialization-receipt-kind+
        +agentic-ai-lab-standard-validation-closure-kind+
        +agentic-ai-lab-standard-validation-closure-receipt-kind+
        +agentic-ai-lab-standard-conformance-receipt-kind+
        +agentic-ai-lab-standard-case-admission-receipt-kind+
        +agentic-ai-lab-standard-reference-observation-kind+
        +agentic-ai-lab-standard-comparison-receipt-kind+
        +agentic-ai-lab-standards-module-kind+
        +agentic-ai-lab-standard-feature-module-kind+
        +agentic-ai-lab-standard-governance-binding-kind+
        +agentic-ai-lab-standard-governance-interface-kind+
        +agentic-ai-lab-standard-governance-receipt-kind+
        +agentic-ai-lab-standard-validation-provider-kind+
        +agentic-ai-lab-standard-materialization-context-kind+
        AgenticAILabStandardFamily
        AgenticAILabStandardArtifactRef
        AgenticAILabStandardArtifactSource
        AgenticAILabStandardArtifact
        AgenticAILabStandardEditionRef
        AgenticAILabStandardConstraintProfile
        AgenticAILabStandardCatalog
        AgenticAILabStandardBudget
        AgenticAILabStandardBundle
        AgenticAILabStandardFailure
        AgenticAILabStandardCatalogReceipt
        AgenticAILabStandardResolutionReceipt
        AgenticAILabStandardProfileCompositionReceipt
        AgenticAILabStandardLoadReceipt
        AgenticAILabStandardMaterializationReceipt
        AgenticAILabStandardValidationClosure
        AgenticAILabStandardValidationClosureReceipt
        AgenticAILabStandardConformanceReceipt
        AgenticAILabStandardCaseAdmissionReceipt
        AgenticAILabStandardReferenceObservation
        AgenticAILabStandardComparisonReceipt
        AgenticAILabStandardsModule
        AgenticAILabStandardFeatureModule
        AgenticAILabStandardGovernanceBinding
        AgenticAILabStandardGovernanceInterface
        AgenticAILabStandardGovernanceReceipt
        AgenticAILabStandardValidationProvider
        AgenticAILabStandardMaterializationContext
        agentic-ai-lab-standard-text?
        agentic-ai-lab-standard-digest?
        agentic-ai-lab-standard-family?
        agentic-ai-lab-standard-artifact-ref?
        agentic-ai-lab-standard-artifact-source?
        agentic-ai-lab-standard-artifact?
        agentic-ai-lab-standard-edition-ref?
        agentic-ai-lab-standard-constraint-profile?
        agentic-ai-lab-standard-catalog?
        agentic-ai-lab-standard-budget?
        agentic-ai-lab-standard-bundle?
        agentic-ai-lab-standard-failure?
        agentic-ai-lab-standard-catalog-receipt?
        agentic-ai-lab-standard-resolution-receipt?
        agentic-ai-lab-standard-profile-composition-receipt?
        agentic-ai-lab-standard-load-receipt?
        agentic-ai-lab-standard-materialization-receipt?
        agentic-ai-lab-standard-validation-closure?
        agentic-ai-lab-standard-validation-closure-receipt?
        agentic-ai-lab-standard-conformance-receipt?
        agentic-ai-lab-standard-case-admission-receipt?
        agentic-ai-lab-standard-reference-observation?
        agentic-ai-lab-standard-comparison-receipt?
        agentic-ai-lab-standards-module?
        agentic-ai-lab-standard-feature-module?
        agentic-ai-lab-standard-governance-binding?
        agentic-ai-lab-standard-governance-interface?
        agentic-ai-lab-standard-governance-receipt?
        agentic-ai-lab-standard-validation-provider?
        agentic-ai-lab-standard-materialization-context?)

(def +agentic-ai-lab-standard-family-kind+ 'agentic-ai-lab.standard-family.v1)
(def +agentic-ai-lab-standard-artifact-ref-kind+ 'agentic-ai-lab.standard-artifact-ref.v1)
(def +agentic-ai-lab-standard-artifact-source-kind+
  'agentic-ai-lab.standard-artifact-source.v1)
(def +agentic-ai-lab-standard-artifact-kind+ 'agentic-ai-lab.standard-artifact.v1)
(def +agentic-ai-lab-standard-edition-ref-kind+ 'agentic-ai-lab.standard-edition-ref.v1)
(def +agentic-ai-lab-standard-constraint-profile-kind+
  'agentic-ai-lab.standard-constraint-profile.v1)
(def +agentic-ai-lab-standard-catalog-kind+ 'agentic-ai-lab.standard-catalog.v1)
(def +agentic-ai-lab-standard-budget-kind+ 'agentic-ai-lab.standard-budget.v1)
(def +agentic-ai-lab-standard-bundle-kind+ 'agentic-ai-lab.standard-bundle.v1)
(def +agentic-ai-lab-standard-failure-kind+ 'agentic-ai-lab.standard-failure.v1)
(def +agentic-ai-lab-standard-catalog-receipt-kind+
  'agentic-ai-lab.standard-catalog-receipt.v1)
(def +agentic-ai-lab-standard-resolution-receipt-kind+
  'agentic-ai-lab.standard-resolution-receipt.v1)
(def +agentic-ai-lab-standard-profile-composition-receipt-kind+
  'agentic-ai-lab.standard-profile-composition-receipt.v1)
(def +agentic-ai-lab-standard-load-receipt-kind+
  'agentic-ai-lab.standard-load-receipt.v1)
(def +agentic-ai-lab-standard-materialization-receipt-kind+
  'agentic-ai-lab.standard-materialization-receipt.v1)
(def +agentic-ai-lab-standard-validation-closure-kind+
  'agentic-ai-lab.standard-validation-closure.v1)
(def +agentic-ai-lab-standard-validation-closure-receipt-kind+
  'agentic-ai-lab.standard-validation-closure-receipt.v1)
(def +agentic-ai-lab-standard-conformance-receipt-kind+
  'agentic-ai-lab.standard-conformance-receipt.v1)
(def +agentic-ai-lab-standard-case-admission-receipt-kind+
  'agentic-ai-lab.standard-case-admission-receipt.v1)
(def +agentic-ai-lab-standard-reference-observation-kind+
  'agentic-ai-lab.standard-reference-observation.v1)
(def +agentic-ai-lab-standard-comparison-receipt-kind+
  'agentic-ai-lab.standard-comparison-receipt.v1)
(def +agentic-ai-lab-standards-module-kind+
  'agentic-ai-lab.standards-module.v1)
(def +agentic-ai-lab-standard-feature-module-kind+
  'agentic-ai-lab.standard-feature-module.v1)
(def +agentic-ai-lab-standard-governance-binding-kind+
  'agentic-ai-lab.standard-governance-binding.v1)
(def +agentic-ai-lab-standard-governance-interface-kind+
  'agentic-ai-lab.standard-governance-interface.v1)
(def +agentic-ai-lab-standard-governance-receipt-kind+
  'agentic-ai-lab.standard-governance-receipt.v1)
(def +agentic-ai-lab-standard-validation-provider-kind+
  'agentic-ai-lab.standard-validation-provider.v1)
(def +agentic-ai-lab-standard-materialization-context-kind+
  'agentic-ai-lab.standard-materialization-context.v1)

(def +agentic-ai-lab-standard-failure-codes+
  '(standard-not-found
    standard-version-unresolved
    standard-identity-conflict
    standard-profile-revision-conflict
    standard-source-digest-mismatch
    standard-dependency-missing
    standard-dependency-cycle
    standard-lazy-reentry
    standard-refinement-base-rejected
    standard-budget-exceeded
    standard-load-failed
    standard-artifact-invalid
    standard-constraint-unsupported
    standard-terminology-not-evaluated
    standard-validation-failed
    standard-receipt-stale
    standard-receipt-revoked
    standard-comparison-validation-closure-mismatch
    standard-comparison-profile-mismatch
    standard-comparison-provider-mismatch
    standard-comparison-subject-mismatch
    standard-reference-validator-disagreement
    standard-reference-validator-not-evaluated))

(def (agentic-ai-lab-standard-text? value)
  (and (string? value) (> (string-length value) 0)))

(def (agentic-ai-lab-standard-digest? value)
  (and (string? value)
       (= (string-length value) 71)
       (string=? (substring value 0 7) "sha256:")
       (let loop ((index 7))
         (or (= index 71)
             (let (character (string-ref value index))
               (and (or (char<=? #\0 character #\9)
                        (char<=? #\a character #\f))
                    (loop (+ index 1))))))))

(def (standard-natural? value)
  (and (exact-integer? value) (>= value 0)))

(def (standard-positive? value)
  (and (standard-natural? value) (> value 0)))

(def (standard-has-slots? value slots)
  (and (object? value)
       (yuanxu-all? (lambda (slot) (.slot? value slot)) slots)))

(def (standard-kind? value kind slots)
  (and (standard-has-slots? value (cons 'kind slots))
       (eq? (.ref value 'kind) kind)))

(def (standard-text-list? value)
  (yuanxu-list-of? agentic-ai-lab-standard-text? value))

(def (standard-symbol-list? value)
  (yuanxu-list-of? symbol? value))

;;; Validate list elements and the declared cardinality in one traversal.
;;; Large Standard catalogs must not rescan the same spine merely to compare
;;; a cached count with `length`.
(def (standard-list-of-count? predicate value expected-count)
  (and (standard-natural? expected-count)
       (let loop ((rest value) (count 0))
         (cond
          ((pair? rest)
           (and (< count expected-count)
                (predicate (car rest))
                (loop (cdr rest) (+ count 1))))
          ((null? rest) (= count expected-count))
          (else #f)))))

(def (agentic-ai-lab-standard-family-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-family-kind+
        '(identity owner semantic-kind representations license metadata))
       (agentic-ai-lab-standard-text? (.ref value 'identity))
       (agentic-ai-lab-standard-text? (.ref value 'owner))
       (symbol? (.ref value 'semantic-kind))
       (pair? (.ref value 'representations))
       (standard-symbol-list? (.ref value 'representations))
       (agentic-ai-lab-standard-text? (.ref value 'license))
       (list? (.ref value 'metadata))))

(define-type (AgenticAILabStandardFamily @ Type.)
  .element?: agentic-ai-lab-standard-family-shape?)

(def (agentic-ai-lab-standard-artifact-ref-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-artifact-ref-kind+
        '(identity canonical-uri exact-version artifact-kind representation
          digest generation cache-key dependencies size-bytes source-loader
          materializer metadata))
       (agentic-ai-lab-standard-text? (.ref value 'identity))
       (agentic-ai-lab-standard-text? (.ref value 'canonical-uri))
       (agentic-ai-lab-standard-text? (.ref value 'exact-version))
       (symbol? (.ref value 'artifact-kind))
       (symbol? (.ref value 'representation))
       (agentic-ai-lab-standard-digest? (.ref value 'digest))
       (agentic-ai-lab-standard-digest? (.ref value 'generation))
       (agentic-ai-lab-standard-text? (.ref value 'cache-key))
       (standard-text-list? (.ref value 'dependencies))
       (standard-natural? (.ref value 'size-bytes))
       (procedure? (.ref value 'source-loader))
       (procedure? (.ref value 'materializer))
       (list? (.ref value 'metadata))))

(define-type (AgenticAILabStandardArtifactRef @ Type.)
  .element?: agentic-ai-lab-standard-artifact-ref-shape?)

(def (agentic-ai-lab-standard-artifact-source-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-artifact-source-kind+
        '(artifact-identity digest representation payload size-bytes metadata
          runtime-executed?))
       (agentic-ai-lab-standard-text? (.ref value 'artifact-identity))
       (agentic-ai-lab-standard-digest? (.ref value 'digest))
       (symbol? (.ref value 'representation))
       (standard-natural? (.ref value 'size-bytes))
       (list? (.ref value 'metadata))
       (eq? (.ref value 'runtime-executed?) #t)))

(define-type (AgenticAILabStandardArtifactSource @ Type.)
  .element?: agentic-ai-lab-standard-artifact-source-shape?)

(def (agentic-ai-lab-standard-artifact-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-artifact-kind+
        '(identity digest representation payload metadata))
       (agentic-ai-lab-standard-text? (.ref value 'identity))
       (agentic-ai-lab-standard-digest? (.ref value 'digest))
       (symbol? (.ref value 'representation))
       (list? (.ref value 'metadata))))

(define-type (AgenticAILabStandardArtifact @ Type.)
  .element?: agentic-ai-lab-standard-artifact-shape?)

(def (agentic-ai-lab-standard-edition-ref-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-edition-ref-kind+
        '(identity family canonical-uri version specification-release
          jurisdiction digest source-ref dependencies artifacts root-artifacts
          status validity metadata))
       (agentic-ai-lab-standard-text? (.ref value 'identity))
       (element? AgenticAILabStandardFamily (.ref value 'family))
       (agentic-ai-lab-standard-text? (.ref value 'canonical-uri))
       (agentic-ai-lab-standard-text? (.ref value 'version))
       (agentic-ai-lab-standard-text? (.ref value 'specification-release))
       (symbol? (.ref value 'jurisdiction))
       (agentic-ai-lab-standard-digest? (.ref value 'digest))
       (standard-text-list? (.ref value 'dependencies))
       (yuanxu-list-of? agentic-ai-lab-standard-artifact-ref?
                          (.ref value 'artifacts))
       (standard-text-list? (.ref value 'root-artifacts))
       (symbol? (.ref value 'status))
       (list? (.ref value 'validity))
       (list? (.ref value 'metadata))))

(define-type (AgenticAILabStandardEditionRef @ Type.)
  .element?: agentic-ai-lab-standard-edition-ref-shape?)

(def (agentic-ai-lab-standard-constraint-profile-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-constraint-profile-kind+
        '(identity exact-revision base-editions constraints compatibility
          artifact-dependencies terminology-dependencies provenance
          qualification-state))
       (agentic-ai-lab-standard-text? (.ref value 'identity))
       (agentic-ai-lab-standard-text? (.ref value 'exact-revision))
       (pair? (.ref value 'base-editions))
       (standard-text-list? (.ref value 'base-editions))
       (list? (.ref value 'constraints))
       (list? (.ref value 'compatibility))
       (standard-text-list? (.ref value 'artifact-dependencies))
       (standard-text-list? (.ref value 'terminology-dependencies))
       (list? (.ref value 'provenance))
       (symbol? (.ref value 'qualification-state))))

(define-type (AgenticAILabStandardConstraintProfile @ Type.)
  .element?: agentic-ai-lab-standard-constraint-profile-shape?)

(def (agentic-ai-lab-standard-catalog-shape? value)
  (and (standard-kind?
       value +agentic-ai-lab-standard-catalog-kind+
        '(identity editions edition-index canonical-version-index artifact-index edition-count
          realized-artifact-count runtime-executed? metadata))
       (agentic-ai-lab-standard-text? (.ref value 'identity))
       (standard-list-of-count?
        agentic-ai-lab-standard-edition-ref?
        (.ref value 'editions)
        (.ref value 'edition-count))
       (hash-table? (.ref value 'edition-index))
       (hash-table? (.ref value 'canonical-version-index))
       (hash-table? (.ref value 'artifact-index))
       (= (.ref value 'realized-artifact-count) 0)
       (eq? (.ref value 'runtime-executed?) #f)
       (list? (.ref value 'metadata))))

(define-type (AgenticAILabStandardCatalog @ Type.)
  .element?: agentic-ai-lab-standard-catalog-shape?)

(def (agentic-ai-lab-standard-budget-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-budget-kind+
        '(max-editions max-artifacts max-depth max-bytes max-operations))
       (standard-positive? (.ref value 'max-editions))
       (standard-positive? (.ref value 'max-artifacts))
       (standard-positive? (.ref value 'max-depth))
       (standard-positive? (.ref value 'max-bytes))
       (standard-positive? (.ref value 'max-operations))))

(define-type (AgenticAILabStandardBudget @ Type.)
  .element?: agentic-ai-lab-standard-budget-shape?)

(def (agentic-ai-lab-standard-bundle-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-bundle-kind+
        '(root-identities editions artifacts terminology-snapshot-digest
          edition-count artifact-count byte-count maximum-depth operation-count
          closure-digest generation runtime-executed?))
       (standard-text-list? (.ref value 'root-identities))
       (standard-list-of-count?
        agentic-ai-lab-standard-edition-ref?
        (.ref value 'editions)
        (.ref value 'edition-count))
       (standard-list-of-count?
        agentic-ai-lab-standard-artifact-ref?
        (.ref value 'artifacts)
        (.ref value 'artifact-count))
       (agentic-ai-lab-standard-digest?
        (.ref value 'terminology-snapshot-digest))
       (standard-natural? (.ref value 'byte-count))
       (standard-natural? (.ref value 'maximum-depth))
       (standard-natural? (.ref value 'operation-count))
       (agentic-ai-lab-standard-digest? (.ref value 'closure-digest))
       (agentic-ai-lab-standard-digest? (.ref value 'generation))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabStandardBundle @ Type.)
  .element?: agentic-ai-lab-standard-bundle-shape?)

(def (agentic-ai-lab-standard-failure-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-failure-kind+ '(code subject detail path))
       (memq (.ref value 'code) +agentic-ai-lab-standard-failure-codes+)
       (list? (.ref value 'path))))

(define-type (AgenticAILabStandardFailure @ Type.)
  .element?: agentic-ai-lab-standard-failure-shape?)

(def (agentic-ai-lab-standard-catalog-receipt-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-catalog-receipt-kind+
        '(catalog-identity edition-count realized-artifact-count
          validation-closure-count runtime-executed?))
       (agentic-ai-lab-standard-text? (.ref value 'catalog-identity))
       (standard-natural? (.ref value 'edition-count))
       (= (.ref value 'realized-artifact-count) 0)
       (= (.ref value 'validation-closure-count) 0)
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabStandardCatalogReceipt @ Type.)
  .element?: agentic-ai-lab-standard-catalog-receipt-shape?)

(def (agentic-ai-lab-standard-resolution-receipt-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-resolution-receipt-kind+
        '(valid? roots bundle failures first-failure runtime-executed?))
       (boolean? (.ref value 'valid?))
       (standard-text-list? (.ref value 'roots))
       (or (not (.ref value 'bundle))
           (agentic-ai-lab-standard-bundle? (.ref value 'bundle)))
       (yuanxu-list-of? agentic-ai-lab-standard-failure?
                          (.ref value 'failures))
       (eq? (.ref value 'valid?) (null? (.ref value 'failures)))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabStandardResolutionReceipt @ Type.)
  .element?: agentic-ai-lab-standard-resolution-receipt-shape?)

(def (agentic-ai-lab-standard-profile-composition-receipt-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-profile-composition-receipt-kind+
        '(valid? case-identity profiles profile-identities base-editions
          constraints constraint-count artifact-dependencies
          terminology-dependencies resolution-receipt failures
          composition-digest runtime-executed?))
       (boolean? (.ref value 'valid?))
       (agentic-ai-lab-standard-text? (.ref value 'case-identity))
       (yuanxu-list-of? agentic-ai-lab-standard-constraint-profile?
                          (.ref value 'profiles))
       (standard-text-list? (.ref value 'profile-identities))
       (standard-text-list? (.ref value 'base-editions))
       (standard-list-of-count?
        (lambda (_) #t)
        (.ref value 'constraints)
        (.ref value 'constraint-count))
       (standard-text-list? (.ref value 'artifact-dependencies))
       (standard-text-list? (.ref value 'terminology-dependencies))
       (or (not (.ref value 'resolution-receipt))
           (agentic-ai-lab-standard-resolution-receipt?
            (.ref value 'resolution-receipt)))
       (yuanxu-list-of? agentic-ai-lab-standard-failure? (.ref value 'failures))
       (eq? (.ref value 'valid?) (null? (.ref value 'failures)))
       (agentic-ai-lab-standard-digest? (.ref value 'composition-digest))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabStandardProfileCompositionReceipt @ Type.)
  .element?: agentic-ai-lab-standard-profile-composition-receipt-shape?)

(def (agentic-ai-lab-standard-load-receipt-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-load-receipt-kind+
        '(valid? artifact-identity cache-key generation source-digest
          loaded-bytes outcome failures runtime-executed?))
       (boolean? (.ref value 'valid?))
       (agentic-ai-lab-standard-text? (.ref value 'artifact-identity))
       (agentic-ai-lab-standard-text? (.ref value 'cache-key))
       (agentic-ai-lab-standard-digest? (.ref value 'generation))
       (agentic-ai-lab-standard-digest? (.ref value 'source-digest))
       (standard-natural? (.ref value 'loaded-bytes))
       (symbol? (.ref value 'outcome))
       (yuanxu-list-of? agentic-ai-lab-standard-failure? (.ref value 'failures))
       (eq? (.ref value 'valid?) (null? (.ref value 'failures)))
       (boolean? (.ref value 'runtime-executed?))))

(define-type (AgenticAILabStandardLoadReceipt @ Type.)
  .element?: agentic-ai-lab-standard-load-receipt-shape?)

(def (agentic-ai-lab-standard-materialization-receipt-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-materialization-receipt-kind+
        '(valid? artifact-identity artifact cache-outcome generation
          load-receipt failures load-count runtime-executed?))
       (boolean? (.ref value 'valid?))
       (agentic-ai-lab-standard-text? (.ref value 'artifact-identity))
       (or (not (.ref value 'artifact))
           (agentic-ai-lab-standard-artifact? (.ref value 'artifact)))
       (symbol? (.ref value 'cache-outcome))
       (agentic-ai-lab-standard-digest? (.ref value 'generation))
       (or (not (.ref value 'load-receipt))
           (agentic-ai-lab-standard-load-receipt? (.ref value 'load-receipt)))
       (yuanxu-list-of? agentic-ai-lab-standard-failure?
                          (.ref value 'failures))
       (standard-natural? (.ref value 'load-count))
       (boolean? (.ref value 'runtime-executed?))))

(define-type (AgenticAILabStandardMaterializationReceipt @ Type.)
  .element?: agentic-ai-lab-standard-materialization-receipt-shape?)

(def (agentic-ai-lab-standard-validation-closure-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-validation-closure-kind+
        '(identity bundle provider-identity subject-kind subject-snapshot-digest
          constraints validation-closure-digest runtime-executed?))
       (agentic-ai-lab-standard-text? (.ref value 'identity))
       (agentic-ai-lab-standard-bundle? (.ref value 'bundle))
       (agentic-ai-lab-standard-text? (.ref value 'provider-identity))
       (symbol? (.ref value 'subject-kind))
       (agentic-ai-lab-standard-digest? (.ref value 'subject-snapshot-digest))
       (list? (.ref value 'constraints))
       (agentic-ai-lab-standard-digest? (.ref value 'validation-closure-digest))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabStandardValidationClosure @ Type.)
  .element?: agentic-ai-lab-standard-validation-closure-shape?)

(def (agentic-ai-lab-standard-validation-closure-receipt-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-validation-closure-receipt-kind+
        '(valid? validation-closure validation-closure-digest closure-digest terminology-snapshot-digest
          engine-identity engine-version constraint-count unsupported-count
          cache-outcome generation failures runtime-executed?))
       (boolean? (.ref value 'valid?))
       (or (not (.ref value 'validation-closure))
           (agentic-ai-lab-standard-validation-closure? (.ref value 'validation-closure)))
       (agentic-ai-lab-standard-digest? (.ref value 'validation-closure-digest))
       (agentic-ai-lab-standard-digest? (.ref value 'closure-digest))
       (agentic-ai-lab-standard-digest? (.ref value 'terminology-snapshot-digest))
       (agentic-ai-lab-standard-text? (.ref value 'engine-identity))
       (agentic-ai-lab-standard-text? (.ref value 'engine-version))
       (standard-natural? (.ref value 'constraint-count))
       (standard-natural? (.ref value 'unsupported-count))
       (symbol? (.ref value 'cache-outcome))
       (agentic-ai-lab-standard-digest? (.ref value 'generation))
       (yuanxu-list-of? agentic-ai-lab-standard-failure? (.ref value 'failures))
       (eq? (.ref value 'valid?) (null? (.ref value 'failures)))
       (boolean? (.ref value 'runtime-executed?))))

(define-type (AgenticAILabStandardValidationClosureReceipt @ Type.)
  .element?: agentic-ai-lab-standard-validation-closure-receipt-shape?)

(def (agentic-ai-lab-standard-conformance-receipt-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-conformance-receipt-kind+
        '(valid? provider-identity validation-closure-digest subject-snapshot-digest
          evaluated-constraints unsupported-constraints failures
          conformance-digest runtime-executed?))
       (boolean? (.ref value 'valid?))
       (agentic-ai-lab-standard-text? (.ref value 'provider-identity))
       (agentic-ai-lab-standard-digest? (.ref value 'validation-closure-digest))
       (agentic-ai-lab-standard-digest? (.ref value 'subject-snapshot-digest))
       (standard-text-list? (.ref value 'evaluated-constraints))
       (standard-text-list? (.ref value 'unsupported-constraints))
       (yuanxu-list-of? agentic-ai-lab-standard-failure?
                          (.ref value 'failures))
       (agentic-ai-lab-standard-digest? (.ref value 'conformance-digest))
       (eq? (.ref value 'runtime-executed?) #t)))

(define-type (AgenticAILabStandardConformanceReceipt @ Type.)
  .element?: agentic-ai-lab-standard-conformance-receipt-shape?)

(def (agentic-ai-lab-standard-case-admission-receipt-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-case-admission-receipt-kind+
        '(valid? case-identity conformance-digests evidence-digests failures
          admission-digest runtime-executed?))
       (boolean? (.ref value 'valid?))
       (agentic-ai-lab-standard-text? (.ref value 'case-identity))
       (yuanxu-list-of? agentic-ai-lab-standard-digest?
                          (.ref value 'conformance-digests))
       (yuanxu-list-of? agentic-ai-lab-standard-digest?
                          (.ref value 'evidence-digests))
       (yuanxu-list-of? agentic-ai-lab-standard-failure? (.ref value 'failures))
       (eq? (.ref value 'valid?) (null? (.ref value 'failures)))
       (agentic-ai-lab-standard-digest? (.ref value 'admission-digest))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabStandardCaseAdmissionReceipt @ Type.)
  .element?: agentic-ai-lab-standard-case-admission-receipt-shape?)

(def (agentic-ai-lab-standard-reference-observation-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-reference-observation-kind+
        '(validator-identity validator-version validator-binary-digest
          fixture-identity subject-snapshot-digest profile-identities outcome
          issues output-digest observation-digest runtime-executed? metadata))
       (agentic-ai-lab-standard-text? (.ref value 'validator-identity))
       (agentic-ai-lab-standard-text? (.ref value 'validator-version))
       (agentic-ai-lab-standard-digest? (.ref value 'validator-binary-digest))
       (agentic-ai-lab-standard-text? (.ref value 'fixture-identity))
       (agentic-ai-lab-standard-digest? (.ref value 'subject-snapshot-digest))
       (standard-text-list? (.ref value 'profile-identities))
       (memq (.ref value 'outcome) '(valid invalid not-evaluated))
       (standard-text-list? (.ref value 'issues))
       (agentic-ai-lab-standard-digest? (.ref value 'output-digest))
       (agentic-ai-lab-standard-digest? (.ref value 'observation-digest))
       (eq? (.ref value 'runtime-executed?) #t)
       (list? (.ref value 'metadata))))

(define-type (AgenticAILabStandardReferenceObservation @ Type.)
  .element?: agentic-ai-lab-standard-reference-observation-shape?)

(def (agentic-ai-lab-standard-comparison-receipt-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-comparison-receipt-kind+
        '(valid? agreement? provider-identity validator-identity
          validator-version subject-snapshot-digest profile-identities
          conformance-digest reference-observation-digest discrepancies
          failures comparison-digest runtime-executed?))
       (boolean? (.ref value 'valid?))
       (boolean? (.ref value 'agreement?))
       (agentic-ai-lab-standard-text? (.ref value 'provider-identity))
       (agentic-ai-lab-standard-text? (.ref value 'validator-identity))
       (agentic-ai-lab-standard-text? (.ref value 'validator-version))
       (agentic-ai-lab-standard-digest? (.ref value 'subject-snapshot-digest))
       (standard-text-list? (.ref value 'profile-identities))
       (agentic-ai-lab-standard-digest? (.ref value 'conformance-digest))
       (agentic-ai-lab-standard-digest? (.ref value 'reference-observation-digest))
       (standard-symbol-list? (.ref value 'discrepancies))
       (yuanxu-list-of? agentic-ai-lab-standard-failure? (.ref value 'failures))
       (eq? (.ref value 'valid?) (null? (.ref value 'failures)))
       (eq? (.ref value 'agreement?) (null? (.ref value 'discrepancies)))
       (agentic-ai-lab-standard-digest? (.ref value 'comparison-digest))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabStandardComparisonReceipt @ Type.)
  .element?: agentic-ai-lab-standard-comparison-receipt-shape?)

(def +agentic-ai-lab-standard-governance-statuses+
  '(declared qualified admitted rejected revoked))

(def (agentic-ai-lab-standard-governance-binding-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-governance-binding-kind+
        '(slot owner evidence-kind content-digest status authority-bearing?
          payload runtime-executed?))
       (symbol? (.ref value 'slot))
       (agentic-ai-lab-standard-text? (.ref value 'owner))
       (symbol? (.ref value 'evidence-kind))
       (agentic-ai-lab-standard-digest? (.ref value 'content-digest))
       (memq (.ref value 'status) +agentic-ai-lab-standard-governance-statuses+)
       (boolean? (.ref value 'authority-bearing?))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabStandardGovernanceBinding @ Type.)
  .element?: agentic-ai-lab-standard-governance-binding-shape?)

(def (standard-governance-requirements? value)
  (and (object? value)
       (yuanxu-all?
        (lambda (stage)
          (let (requirements (.ref value stage))
            (and (object? requirements)
                 (yuanxu-all?
                  (lambda (slot)
                    (let (statuses (.ref requirements slot))
                      (and (pair? statuses)
                           (yuanxu-all?
                            (lambda (status)
                              (memq status
                                    +agentic-ai-lab-standard-governance-statuses+))
                            statuses))))
                  (.all-slots requirements)))))
        (.all-slots value))))

(def (standard-governance-bindings? value)
  (and (object? value)
       (yuanxu-all?
        (lambda (slot)
          (let (binding (.ref value slot))
            (and (agentic-ai-lab-standard-governance-binding? binding)
                 (eq? (.ref binding 'slot) slot))))
        (.all-slots value))))

(def (agentic-ai-lab-standard-governance-interface-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-governance-interface-kind+
        '(identity required-slots optional-slots stage-requirements bindings
          .validate-binding .write-governance .validate-governance
          runtime-executed?))
       (agentic-ai-lab-standard-text? (.ref value 'identity))
       (standard-symbol-list? (.ref value 'required-slots))
       (standard-symbol-list? (.ref value 'optional-slots))
       (not (yuanxu-any?
             (lambda (slot)
               (memq slot (.ref value 'optional-slots)))
             (.ref value 'required-slots)))
       (standard-governance-requirements?
        (.ref value 'stage-requirements))
       (standard-governance-bindings? (.ref value 'bindings))
       (procedure? (.ref value '.validate-binding))
       (procedure? (.ref value '.write-governance))
       (procedure? (.ref value '.validate-governance))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabStandardGovernanceInterface @ Type.)
  .element?: agentic-ai-lab-standard-governance-interface-shape?)

(def (agentic-ai-lab-standard-governance-receipt-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-governance-receipt-kind+
        '(valid? interface-identity stage required-slots bound-slots
          missing-slots invalid-status-slots receipt-digest
          runtime-executed?))
       (boolean? (.ref value 'valid?))
       (agentic-ai-lab-standard-text? (.ref value 'interface-identity))
       (symbol? (.ref value 'stage))
       (standard-symbol-list? (.ref value 'required-slots))
       (standard-symbol-list? (.ref value 'bound-slots))
       (standard-symbol-list? (.ref value 'missing-slots))
       (standard-symbol-list? (.ref value 'invalid-status-slots))
       (eq? (.ref value 'valid?)
            (and (null? (.ref value 'missing-slots))
                 (null? (.ref value 'invalid-status-slots))))
       (agentic-ai-lab-standard-digest? (.ref value 'receipt-digest))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabStandardGovernanceReceipt @ Type.)
  .element?: agentic-ai-lab-standard-governance-receipt-shape?)

(def (agentic-ai-lab-standard-feature-module-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-feature-module-kind+
        '(identity feature-kind extension-points fixtures governance
          .write-governance .validate-governance metadata))
       (agentic-ai-lab-standard-text? (.ref value 'identity))
       (symbol? (.ref value 'feature-kind))
       (standard-symbol-list? (.ref value 'extension-points))
       (object? (.ref value 'fixtures))
       (agentic-ai-lab-standard-governance-interface? (.ref value 'governance))
       (procedure? (.ref value '.write-governance))
       (procedure? (.ref value '.validate-governance))
       (list? (.ref value 'metadata))))

(define-type (AgenticAILabStandardFeatureModule @ Type.)
  .element?: agentic-ai-lab-standard-feature-module-shape?)

(def (agentic-ai-lab-standards-module-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standards-module-kind+
        '(identity catalog budget providers features .resolve
          .materialization-context .make-validation-closure))
       (agentic-ai-lab-standard-text? (.ref value 'identity))
       (agentic-ai-lab-standard-catalog? (.ref value 'catalog))
       (agentic-ai-lab-standard-budget? (.ref value 'budget))
       (object? (.ref value 'providers))
       (object? (.ref value 'features))
       (procedure? (.ref value '.resolve))
       (procedure? (.ref value '.materialization-context))
       (procedure? (.ref value '.make-validation-closure))))

(define-type (AgenticAILabStandardsModule @ Type.)
  .element?: agentic-ai-lab-standards-module-shape?)

(def (agentic-ai-lab-standard-validation-provider-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-validation-provider-kind+
        '(identity supported-families .validate-standard))
       (agentic-ai-lab-standard-text? (.ref value 'identity))
       (standard-text-list? (.ref value 'supported-families))
       (procedure? (.ref value '.validate-standard))))

(define-type (AgenticAILabStandardValidationProvider @ Type.)
  .element?: agentic-ai-lab-standard-validation-provider-shape?)

(def (agentic-ai-lab-standard-materialization-context-shape? value)
  (and (standard-kind?
        value +agentic-ai-lab-standard-materialization-context-kind+
        '(identity load-source materialize evict! stats))
       (agentic-ai-lab-standard-text? (.ref value 'identity))
       (procedure? (.ref value 'load-source))
       (procedure? (.ref value 'materialize))
       (procedure? (.ref value 'evict!))
       (procedure? (.ref value 'stats))))

(define-type (AgenticAILabStandardMaterializationContext @ Type.)
  .element?: agentic-ai-lab-standard-materialization-context-shape?)

(def (agentic-ai-lab-standard-family? value)
  (element? AgenticAILabStandardFamily value))
(def (agentic-ai-lab-standard-artifact-ref? value)
  (element? AgenticAILabStandardArtifactRef value))
(def (agentic-ai-lab-standard-artifact-source? value)
  (element? AgenticAILabStandardArtifactSource value))
(def (agentic-ai-lab-standard-artifact? value)
  (element? AgenticAILabStandardArtifact value))
(def (agentic-ai-lab-standard-edition-ref? value)
  (element? AgenticAILabStandardEditionRef value))
(def (agentic-ai-lab-standard-constraint-profile? value)
  (element? AgenticAILabStandardConstraintProfile value))
(def (agentic-ai-lab-standard-catalog? value)
  (element? AgenticAILabStandardCatalog value))
(def (agentic-ai-lab-standard-budget? value)
  (element? AgenticAILabStandardBudget value))
(def (agentic-ai-lab-standard-bundle? value)
  (element? AgenticAILabStandardBundle value))
(def (agentic-ai-lab-standard-failure? value)
  (element? AgenticAILabStandardFailure value))
(def (agentic-ai-lab-standard-catalog-receipt? value)
  (element? AgenticAILabStandardCatalogReceipt value))
(def (agentic-ai-lab-standard-resolution-receipt? value)
  (element? AgenticAILabStandardResolutionReceipt value))
(def (agentic-ai-lab-standard-profile-composition-receipt? value)
  (element? AgenticAILabStandardProfileCompositionReceipt value))
(def (agentic-ai-lab-standard-load-receipt? value)
  (element? AgenticAILabStandardLoadReceipt value))
(def (agentic-ai-lab-standard-materialization-receipt? value)
  (element? AgenticAILabStandardMaterializationReceipt value))
(def (agentic-ai-lab-standard-validation-closure? value)
  (element? AgenticAILabStandardValidationClosure value))
(def (agentic-ai-lab-standard-validation-closure-receipt? value)
  (element? AgenticAILabStandardValidationClosureReceipt value))
(def (agentic-ai-lab-standard-conformance-receipt? value)
  (element? AgenticAILabStandardConformanceReceipt value))
(def (agentic-ai-lab-standard-case-admission-receipt? value)
  (element? AgenticAILabStandardCaseAdmissionReceipt value))
(def (agentic-ai-lab-standard-reference-observation? value)
  (element? AgenticAILabStandardReferenceObservation value))
(def (agentic-ai-lab-standard-comparison-receipt? value)
  (element? AgenticAILabStandardComparisonReceipt value))
(def (agentic-ai-lab-standards-module? value)
  (element? AgenticAILabStandardsModule value))
(def (agentic-ai-lab-standard-feature-module? value)
  (element? AgenticAILabStandardFeatureModule value))
(def (agentic-ai-lab-standard-governance-binding? value)
  (element? AgenticAILabStandardGovernanceBinding value))
(def (agentic-ai-lab-standard-governance-interface? value)
  (element? AgenticAILabStandardGovernanceInterface value))
(def (agentic-ai-lab-standard-governance-receipt? value)
  (element? AgenticAILabStandardGovernanceReceipt value))
(def (agentic-ai-lab-standard-validation-provider? value)
  (element? AgenticAILabStandardValidationProvider value))
(def (agentic-ai-lab-standard-materialization-context? value)
  (element? AgenticAILabStandardMaterializationContext value))
