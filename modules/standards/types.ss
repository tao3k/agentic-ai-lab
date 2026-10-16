;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: domain-neutral Standards value kinds and closed shape contracts.
;;; Invariant: these predicates inspect inert values and never resolve, load,
;;; parse, validate, or execute a concrete industry standard.
(import (only-in :clan/poo/object .all-slots .ref .slot? object?)
        (only-in :clan/poo/mop define-type Type. element?)
        (only-in :core/utilities/functional
                 poo-flow-all? poo-flow-any? poo-flow-list-of?))

(export +poo-flow-standard-family-kind+
        +poo-flow-standard-failure-codes+
        +poo-flow-standard-artifact-ref-kind+
        +poo-flow-standard-artifact-source-kind+
        +poo-flow-standard-artifact-kind+
        +poo-flow-standard-edition-ref-kind+
        +poo-flow-standard-constraint-profile-kind+
        +poo-flow-standard-catalog-kind+
        +poo-flow-standard-budget-kind+
        +poo-flow-standard-bundle-kind+
        +poo-flow-standard-failure-kind+
        +poo-flow-standard-catalog-receipt-kind+
        +poo-flow-standard-resolution-receipt-kind+
        +poo-flow-standard-profile-composition-receipt-kind+
        +poo-flow-standard-load-receipt-kind+
        +poo-flow-standard-materialization-receipt-kind+
        +poo-flow-standard-validation-closure-kind+
        +poo-flow-standard-validation-closure-receipt-kind+
        +poo-flow-standard-conformance-receipt-kind+
        +poo-flow-standard-case-admission-receipt-kind+
        +poo-flow-standard-reference-observation-kind+
        +poo-flow-standard-comparison-receipt-kind+
        +poo-flow-standards-module-kind+
        +poo-flow-standard-feature-module-kind+
        +poo-flow-standard-governance-binding-kind+
        +poo-flow-standard-governance-interface-kind+
        +poo-flow-standard-governance-receipt-kind+
        +poo-flow-standard-validation-provider-kind+
        +poo-flow-standard-materialization-context-kind+
        PooFlowStandardFamily
        PooFlowStandardArtifactRef
        PooFlowStandardArtifactSource
        PooFlowStandardArtifact
        PooFlowStandardEditionRef
        PooFlowStandardConstraintProfile
        PooFlowStandardCatalog
        PooFlowStandardBudget
        PooFlowStandardBundle
        PooFlowStandardFailure
        PooFlowStandardCatalogReceipt
        PooFlowStandardResolutionReceipt
        PooFlowStandardProfileCompositionReceipt
        PooFlowStandardLoadReceipt
        PooFlowStandardMaterializationReceipt
        PooFlowStandardValidationClosure
        PooFlowStandardValidationClosureReceipt
        PooFlowStandardConformanceReceipt
        PooFlowStandardCaseAdmissionReceipt
        PooFlowStandardReferenceObservation
        PooFlowStandardComparisonReceipt
        PooFlowStandardsModule
        PooFlowStandardFeatureModule
        PooFlowStandardGovernanceBinding
        PooFlowStandardGovernanceInterface
        PooFlowStandardGovernanceReceipt
        PooFlowStandardValidationProvider
        PooFlowStandardMaterializationContext
        poo-flow-standard-text?
        poo-flow-standard-digest?
        poo-flow-standard-family?
        poo-flow-standard-artifact-ref?
        poo-flow-standard-artifact-source?
        poo-flow-standard-artifact?
        poo-flow-standard-edition-ref?
        poo-flow-standard-constraint-profile?
        poo-flow-standard-catalog?
        poo-flow-standard-budget?
        poo-flow-standard-bundle?
        poo-flow-standard-failure?
        poo-flow-standard-catalog-receipt?
        poo-flow-standard-resolution-receipt?
        poo-flow-standard-profile-composition-receipt?
        poo-flow-standard-load-receipt?
        poo-flow-standard-materialization-receipt?
        poo-flow-standard-validation-closure?
        poo-flow-standard-validation-closure-receipt?
        poo-flow-standard-conformance-receipt?
        poo-flow-standard-case-admission-receipt?
        poo-flow-standard-reference-observation?
        poo-flow-standard-comparison-receipt?
        poo-flow-standards-module?
        poo-flow-standard-feature-module?
        poo-flow-standard-governance-binding?
        poo-flow-standard-governance-interface?
        poo-flow-standard-governance-receipt?
        poo-flow-standard-validation-provider?
        poo-flow-standard-materialization-context?)

(def +poo-flow-standard-family-kind+ 'poo-flow.standard-family.v1)
(def +poo-flow-standard-artifact-ref-kind+ 'poo-flow.standard-artifact-ref.v1)
(def +poo-flow-standard-artifact-source-kind+
  'poo-flow.standard-artifact-source.v1)
(def +poo-flow-standard-artifact-kind+ 'poo-flow.standard-artifact.v1)
(def +poo-flow-standard-edition-ref-kind+ 'poo-flow.standard-edition-ref.v1)
(def +poo-flow-standard-constraint-profile-kind+
  'poo-flow.standard-constraint-profile.v1)
(def +poo-flow-standard-catalog-kind+ 'poo-flow.standard-catalog.v1)
(def +poo-flow-standard-budget-kind+ 'poo-flow.standard-budget.v1)
(def +poo-flow-standard-bundle-kind+ 'poo-flow.standard-bundle.v1)
(def +poo-flow-standard-failure-kind+ 'poo-flow.standard-failure.v1)
(def +poo-flow-standard-catalog-receipt-kind+
  'poo-flow.standard-catalog-receipt.v1)
(def +poo-flow-standard-resolution-receipt-kind+
  'poo-flow.standard-resolution-receipt.v1)
(def +poo-flow-standard-profile-composition-receipt-kind+
  'poo-flow.standard-profile-composition-receipt.v1)
(def +poo-flow-standard-load-receipt-kind+
  'poo-flow.standard-load-receipt.v1)
(def +poo-flow-standard-materialization-receipt-kind+
  'poo-flow.standard-materialization-receipt.v1)
(def +poo-flow-standard-validation-closure-kind+
  'poo-flow.standard-validation-closure.v1)
(def +poo-flow-standard-validation-closure-receipt-kind+
  'poo-flow.standard-validation-closure-receipt.v1)
(def +poo-flow-standard-conformance-receipt-kind+
  'poo-flow.standard-conformance-receipt.v1)
(def +poo-flow-standard-case-admission-receipt-kind+
  'poo-flow.standard-case-admission-receipt.v1)
(def +poo-flow-standard-reference-observation-kind+
  'poo-flow.standard-reference-observation.v1)
(def +poo-flow-standard-comparison-receipt-kind+
  'poo-flow.standard-comparison-receipt.v1)
(def +poo-flow-standards-module-kind+
  'poo-flow.standards-module.v1)
(def +poo-flow-standard-feature-module-kind+
  'poo-flow.standard-feature-module.v1)
(def +poo-flow-standard-governance-binding-kind+
  'poo-flow.standard-governance-binding.v1)
(def +poo-flow-standard-governance-interface-kind+
  'poo-flow.standard-governance-interface.v1)
(def +poo-flow-standard-governance-receipt-kind+
  'poo-flow.standard-governance-receipt.v1)
(def +poo-flow-standard-validation-provider-kind+
  'poo-flow.standard-validation-provider.v1)
(def +poo-flow-standard-materialization-context-kind+
  'poo-flow.standard-materialization-context.v1)

(def +poo-flow-standard-failure-codes+
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

(def (poo-flow-standard-text? value)
  (and (string? value) (> (string-length value) 0)))

(def (poo-flow-standard-digest? value)
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
       (poo-flow-all? (lambda (slot) (.slot? value slot)) slots)))

(def (standard-kind? value kind slots)
  (and (standard-has-slots? value (cons 'kind slots))
       (eq? (.ref value 'kind) kind)))

(def (standard-text-list? value)
  (poo-flow-list-of? poo-flow-standard-text? value))

(def (standard-symbol-list? value)
  (poo-flow-list-of? symbol? value))

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

(def (poo-flow-standard-family-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-family-kind+
        '(identity owner semantic-kind representations license metadata))
       (poo-flow-standard-text? (.ref value 'identity))
       (poo-flow-standard-text? (.ref value 'owner))
       (symbol? (.ref value 'semantic-kind))
       (pair? (.ref value 'representations))
       (standard-symbol-list? (.ref value 'representations))
       (poo-flow-standard-text? (.ref value 'license))
       (list? (.ref value 'metadata))))

(define-type (PooFlowStandardFamily @ Type.)
  .element?: poo-flow-standard-family-shape?)

(def (poo-flow-standard-artifact-ref-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-artifact-ref-kind+
        '(identity canonical-uri exact-version artifact-kind representation
          digest generation cache-key dependencies size-bytes source-loader
          materializer metadata))
       (poo-flow-standard-text? (.ref value 'identity))
       (poo-flow-standard-text? (.ref value 'canonical-uri))
       (poo-flow-standard-text? (.ref value 'exact-version))
       (symbol? (.ref value 'artifact-kind))
       (symbol? (.ref value 'representation))
       (poo-flow-standard-digest? (.ref value 'digest))
       (poo-flow-standard-digest? (.ref value 'generation))
       (poo-flow-standard-text? (.ref value 'cache-key))
       (standard-text-list? (.ref value 'dependencies))
       (standard-natural? (.ref value 'size-bytes))
       (procedure? (.ref value 'source-loader))
       (procedure? (.ref value 'materializer))
       (list? (.ref value 'metadata))))

(define-type (PooFlowStandardArtifactRef @ Type.)
  .element?: poo-flow-standard-artifact-ref-shape?)

(def (poo-flow-standard-artifact-source-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-artifact-source-kind+
        '(artifact-identity digest representation payload size-bytes metadata
          runtime-executed?))
       (poo-flow-standard-text? (.ref value 'artifact-identity))
       (poo-flow-standard-digest? (.ref value 'digest))
       (symbol? (.ref value 'representation))
       (standard-natural? (.ref value 'size-bytes))
       (list? (.ref value 'metadata))
       (eq? (.ref value 'runtime-executed?) #t)))

(define-type (PooFlowStandardArtifactSource @ Type.)
  .element?: poo-flow-standard-artifact-source-shape?)

(def (poo-flow-standard-artifact-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-artifact-kind+
        '(identity digest representation payload metadata))
       (poo-flow-standard-text? (.ref value 'identity))
       (poo-flow-standard-digest? (.ref value 'digest))
       (symbol? (.ref value 'representation))
       (list? (.ref value 'metadata))))

(define-type (PooFlowStandardArtifact @ Type.)
  .element?: poo-flow-standard-artifact-shape?)

(def (poo-flow-standard-edition-ref-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-edition-ref-kind+
        '(identity family canonical-uri version specification-release
          jurisdiction digest source-ref dependencies artifacts root-artifacts
          status validity metadata))
       (poo-flow-standard-text? (.ref value 'identity))
       (element? PooFlowStandardFamily (.ref value 'family))
       (poo-flow-standard-text? (.ref value 'canonical-uri))
       (poo-flow-standard-text? (.ref value 'version))
       (poo-flow-standard-text? (.ref value 'specification-release))
       (symbol? (.ref value 'jurisdiction))
       (poo-flow-standard-digest? (.ref value 'digest))
       (standard-text-list? (.ref value 'dependencies))
       (poo-flow-list-of? poo-flow-standard-artifact-ref?
                          (.ref value 'artifacts))
       (standard-text-list? (.ref value 'root-artifacts))
       (symbol? (.ref value 'status))
       (list? (.ref value 'validity))
       (list? (.ref value 'metadata))))

(define-type (PooFlowStandardEditionRef @ Type.)
  .element?: poo-flow-standard-edition-ref-shape?)

(def (poo-flow-standard-constraint-profile-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-constraint-profile-kind+
        '(identity exact-revision base-editions constraints compatibility
          artifact-dependencies terminology-dependencies provenance
          qualification-state))
       (poo-flow-standard-text? (.ref value 'identity))
       (poo-flow-standard-text? (.ref value 'exact-revision))
       (pair? (.ref value 'base-editions))
       (standard-text-list? (.ref value 'base-editions))
       (list? (.ref value 'constraints))
       (list? (.ref value 'compatibility))
       (standard-text-list? (.ref value 'artifact-dependencies))
       (standard-text-list? (.ref value 'terminology-dependencies))
       (list? (.ref value 'provenance))
       (symbol? (.ref value 'qualification-state))))

(define-type (PooFlowStandardConstraintProfile @ Type.)
  .element?: poo-flow-standard-constraint-profile-shape?)

(def (poo-flow-standard-catalog-shape? value)
  (and (standard-kind?
       value +poo-flow-standard-catalog-kind+
        '(identity editions edition-index canonical-version-index artifact-index edition-count
          realized-artifact-count runtime-executed? metadata))
       (poo-flow-standard-text? (.ref value 'identity))
       (standard-list-of-count?
        poo-flow-standard-edition-ref?
        (.ref value 'editions)
        (.ref value 'edition-count))
       (hash-table? (.ref value 'edition-index))
       (hash-table? (.ref value 'canonical-version-index))
       (hash-table? (.ref value 'artifact-index))
       (= (.ref value 'realized-artifact-count) 0)
       (eq? (.ref value 'runtime-executed?) #f)
       (list? (.ref value 'metadata))))

(define-type (PooFlowStandardCatalog @ Type.)
  .element?: poo-flow-standard-catalog-shape?)

(def (poo-flow-standard-budget-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-budget-kind+
        '(max-editions max-artifacts max-depth max-bytes max-operations))
       (standard-positive? (.ref value 'max-editions))
       (standard-positive? (.ref value 'max-artifacts))
       (standard-positive? (.ref value 'max-depth))
       (standard-positive? (.ref value 'max-bytes))
       (standard-positive? (.ref value 'max-operations))))

(define-type (PooFlowStandardBudget @ Type.)
  .element?: poo-flow-standard-budget-shape?)

(def (poo-flow-standard-bundle-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-bundle-kind+
        '(root-identities editions artifacts terminology-snapshot-digest
          edition-count artifact-count byte-count maximum-depth operation-count
          closure-digest generation runtime-executed?))
       (standard-text-list? (.ref value 'root-identities))
       (standard-list-of-count?
        poo-flow-standard-edition-ref?
        (.ref value 'editions)
        (.ref value 'edition-count))
       (standard-list-of-count?
        poo-flow-standard-artifact-ref?
        (.ref value 'artifacts)
        (.ref value 'artifact-count))
       (poo-flow-standard-digest?
        (.ref value 'terminology-snapshot-digest))
       (standard-natural? (.ref value 'byte-count))
       (standard-natural? (.ref value 'maximum-depth))
       (standard-natural? (.ref value 'operation-count))
       (poo-flow-standard-digest? (.ref value 'closure-digest))
       (poo-flow-standard-digest? (.ref value 'generation))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (PooFlowStandardBundle @ Type.)
  .element?: poo-flow-standard-bundle-shape?)

(def (poo-flow-standard-failure-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-failure-kind+ '(code subject detail path))
       (memq (.ref value 'code) +poo-flow-standard-failure-codes+)
       (list? (.ref value 'path))))

(define-type (PooFlowStandardFailure @ Type.)
  .element?: poo-flow-standard-failure-shape?)

(def (poo-flow-standard-catalog-receipt-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-catalog-receipt-kind+
        '(catalog-identity edition-count realized-artifact-count
          validation-closure-count runtime-executed?))
       (poo-flow-standard-text? (.ref value 'catalog-identity))
       (standard-natural? (.ref value 'edition-count))
       (= (.ref value 'realized-artifact-count) 0)
       (= (.ref value 'validation-closure-count) 0)
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (PooFlowStandardCatalogReceipt @ Type.)
  .element?: poo-flow-standard-catalog-receipt-shape?)

(def (poo-flow-standard-resolution-receipt-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-resolution-receipt-kind+
        '(valid? roots bundle failures first-failure runtime-executed?))
       (boolean? (.ref value 'valid?))
       (standard-text-list? (.ref value 'roots))
       (or (not (.ref value 'bundle))
           (poo-flow-standard-bundle? (.ref value 'bundle)))
       (poo-flow-list-of? poo-flow-standard-failure?
                          (.ref value 'failures))
       (eq? (.ref value 'valid?) (null? (.ref value 'failures)))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (PooFlowStandardResolutionReceipt @ Type.)
  .element?: poo-flow-standard-resolution-receipt-shape?)

(def (poo-flow-standard-profile-composition-receipt-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-profile-composition-receipt-kind+
        '(valid? case-identity profiles profile-identities base-editions
          constraints constraint-count artifact-dependencies
          terminology-dependencies resolution-receipt failures
          composition-digest runtime-executed?))
       (boolean? (.ref value 'valid?))
       (poo-flow-standard-text? (.ref value 'case-identity))
       (poo-flow-list-of? poo-flow-standard-constraint-profile?
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
           (poo-flow-standard-resolution-receipt?
            (.ref value 'resolution-receipt)))
       (poo-flow-list-of? poo-flow-standard-failure? (.ref value 'failures))
       (eq? (.ref value 'valid?) (null? (.ref value 'failures)))
       (poo-flow-standard-digest? (.ref value 'composition-digest))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (PooFlowStandardProfileCompositionReceipt @ Type.)
  .element?: poo-flow-standard-profile-composition-receipt-shape?)

(def (poo-flow-standard-load-receipt-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-load-receipt-kind+
        '(valid? artifact-identity cache-key generation source-digest
          loaded-bytes outcome failures runtime-executed?))
       (boolean? (.ref value 'valid?))
       (poo-flow-standard-text? (.ref value 'artifact-identity))
       (poo-flow-standard-text? (.ref value 'cache-key))
       (poo-flow-standard-digest? (.ref value 'generation))
       (poo-flow-standard-digest? (.ref value 'source-digest))
       (standard-natural? (.ref value 'loaded-bytes))
       (symbol? (.ref value 'outcome))
       (poo-flow-list-of? poo-flow-standard-failure? (.ref value 'failures))
       (eq? (.ref value 'valid?) (null? (.ref value 'failures)))
       (boolean? (.ref value 'runtime-executed?))))

(define-type (PooFlowStandardLoadReceipt @ Type.)
  .element?: poo-flow-standard-load-receipt-shape?)

(def (poo-flow-standard-materialization-receipt-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-materialization-receipt-kind+
        '(valid? artifact-identity artifact cache-outcome generation
          load-receipt failures load-count runtime-executed?))
       (boolean? (.ref value 'valid?))
       (poo-flow-standard-text? (.ref value 'artifact-identity))
       (or (not (.ref value 'artifact))
           (poo-flow-standard-artifact? (.ref value 'artifact)))
       (symbol? (.ref value 'cache-outcome))
       (poo-flow-standard-digest? (.ref value 'generation))
       (or (not (.ref value 'load-receipt))
           (poo-flow-standard-load-receipt? (.ref value 'load-receipt)))
       (poo-flow-list-of? poo-flow-standard-failure?
                          (.ref value 'failures))
       (standard-natural? (.ref value 'load-count))
       (boolean? (.ref value 'runtime-executed?))))

(define-type (PooFlowStandardMaterializationReceipt @ Type.)
  .element?: poo-flow-standard-materialization-receipt-shape?)

(def (poo-flow-standard-validation-closure-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-validation-closure-kind+
        '(identity bundle provider-identity subject-kind subject-snapshot-digest
          constraints validation-closure-digest runtime-executed?))
       (poo-flow-standard-text? (.ref value 'identity))
       (poo-flow-standard-bundle? (.ref value 'bundle))
       (poo-flow-standard-text? (.ref value 'provider-identity))
       (symbol? (.ref value 'subject-kind))
       (poo-flow-standard-digest? (.ref value 'subject-snapshot-digest))
       (list? (.ref value 'constraints))
       (poo-flow-standard-digest? (.ref value 'validation-closure-digest))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (PooFlowStandardValidationClosure @ Type.)
  .element?: poo-flow-standard-validation-closure-shape?)

(def (poo-flow-standard-validation-closure-receipt-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-validation-closure-receipt-kind+
        '(valid? validation-closure validation-closure-digest closure-digest terminology-snapshot-digest
          engine-identity engine-version constraint-count unsupported-count
          cache-outcome generation failures runtime-executed?))
       (boolean? (.ref value 'valid?))
       (or (not (.ref value 'validation-closure))
           (poo-flow-standard-validation-closure? (.ref value 'validation-closure)))
       (poo-flow-standard-digest? (.ref value 'validation-closure-digest))
       (poo-flow-standard-digest? (.ref value 'closure-digest))
       (poo-flow-standard-digest? (.ref value 'terminology-snapshot-digest))
       (poo-flow-standard-text? (.ref value 'engine-identity))
       (poo-flow-standard-text? (.ref value 'engine-version))
       (standard-natural? (.ref value 'constraint-count))
       (standard-natural? (.ref value 'unsupported-count))
       (symbol? (.ref value 'cache-outcome))
       (poo-flow-standard-digest? (.ref value 'generation))
       (poo-flow-list-of? poo-flow-standard-failure? (.ref value 'failures))
       (eq? (.ref value 'valid?) (null? (.ref value 'failures)))
       (boolean? (.ref value 'runtime-executed?))))

(define-type (PooFlowStandardValidationClosureReceipt @ Type.)
  .element?: poo-flow-standard-validation-closure-receipt-shape?)

(def (poo-flow-standard-conformance-receipt-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-conformance-receipt-kind+
        '(valid? provider-identity validation-closure-digest subject-snapshot-digest
          evaluated-constraints unsupported-constraints failures
          conformance-digest runtime-executed?))
       (boolean? (.ref value 'valid?))
       (poo-flow-standard-text? (.ref value 'provider-identity))
       (poo-flow-standard-digest? (.ref value 'validation-closure-digest))
       (poo-flow-standard-digest? (.ref value 'subject-snapshot-digest))
       (standard-text-list? (.ref value 'evaluated-constraints))
       (standard-text-list? (.ref value 'unsupported-constraints))
       (poo-flow-list-of? poo-flow-standard-failure?
                          (.ref value 'failures))
       (poo-flow-standard-digest? (.ref value 'conformance-digest))
       (eq? (.ref value 'runtime-executed?) #t)))

(define-type (PooFlowStandardConformanceReceipt @ Type.)
  .element?: poo-flow-standard-conformance-receipt-shape?)

(def (poo-flow-standard-case-admission-receipt-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-case-admission-receipt-kind+
        '(valid? case-identity conformance-digests evidence-digests failures
          admission-digest runtime-executed?))
       (boolean? (.ref value 'valid?))
       (poo-flow-standard-text? (.ref value 'case-identity))
       (poo-flow-list-of? poo-flow-standard-digest?
                          (.ref value 'conformance-digests))
       (poo-flow-list-of? poo-flow-standard-digest?
                          (.ref value 'evidence-digests))
       (poo-flow-list-of? poo-flow-standard-failure? (.ref value 'failures))
       (eq? (.ref value 'valid?) (null? (.ref value 'failures)))
       (poo-flow-standard-digest? (.ref value 'admission-digest))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (PooFlowStandardCaseAdmissionReceipt @ Type.)
  .element?: poo-flow-standard-case-admission-receipt-shape?)

(def (poo-flow-standard-reference-observation-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-reference-observation-kind+
        '(validator-identity validator-version validator-binary-digest
          fixture-identity subject-snapshot-digest profile-identities outcome
          issues output-digest observation-digest runtime-executed? metadata))
       (poo-flow-standard-text? (.ref value 'validator-identity))
       (poo-flow-standard-text? (.ref value 'validator-version))
       (poo-flow-standard-digest? (.ref value 'validator-binary-digest))
       (poo-flow-standard-text? (.ref value 'fixture-identity))
       (poo-flow-standard-digest? (.ref value 'subject-snapshot-digest))
       (standard-text-list? (.ref value 'profile-identities))
       (memq (.ref value 'outcome) '(valid invalid not-evaluated))
       (standard-text-list? (.ref value 'issues))
       (poo-flow-standard-digest? (.ref value 'output-digest))
       (poo-flow-standard-digest? (.ref value 'observation-digest))
       (eq? (.ref value 'runtime-executed?) #t)
       (list? (.ref value 'metadata))))

(define-type (PooFlowStandardReferenceObservation @ Type.)
  .element?: poo-flow-standard-reference-observation-shape?)

(def (poo-flow-standard-comparison-receipt-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-comparison-receipt-kind+
        '(valid? agreement? provider-identity validator-identity
          validator-version subject-snapshot-digest profile-identities
          conformance-digest reference-observation-digest discrepancies
          failures comparison-digest runtime-executed?))
       (boolean? (.ref value 'valid?))
       (boolean? (.ref value 'agreement?))
       (poo-flow-standard-text? (.ref value 'provider-identity))
       (poo-flow-standard-text? (.ref value 'validator-identity))
       (poo-flow-standard-text? (.ref value 'validator-version))
       (poo-flow-standard-digest? (.ref value 'subject-snapshot-digest))
       (standard-text-list? (.ref value 'profile-identities))
       (poo-flow-standard-digest? (.ref value 'conformance-digest))
       (poo-flow-standard-digest? (.ref value 'reference-observation-digest))
       (standard-symbol-list? (.ref value 'discrepancies))
       (poo-flow-list-of? poo-flow-standard-failure? (.ref value 'failures))
       (eq? (.ref value 'valid?) (null? (.ref value 'failures)))
       (eq? (.ref value 'agreement?) (null? (.ref value 'discrepancies)))
       (poo-flow-standard-digest? (.ref value 'comparison-digest))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (PooFlowStandardComparisonReceipt @ Type.)
  .element?: poo-flow-standard-comparison-receipt-shape?)

(def +poo-flow-standard-governance-statuses+
  '(declared qualified admitted rejected revoked))

(def (poo-flow-standard-governance-binding-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-governance-binding-kind+
        '(slot owner evidence-kind content-digest status authority-bearing?
          payload runtime-executed?))
       (symbol? (.ref value 'slot))
       (poo-flow-standard-text? (.ref value 'owner))
       (symbol? (.ref value 'evidence-kind))
       (poo-flow-standard-digest? (.ref value 'content-digest))
       (memq (.ref value 'status) +poo-flow-standard-governance-statuses+)
       (boolean? (.ref value 'authority-bearing?))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (PooFlowStandardGovernanceBinding @ Type.)
  .element?: poo-flow-standard-governance-binding-shape?)

(def (standard-governance-requirements? value)
  (and (object? value)
       (poo-flow-all?
        (lambda (stage)
          (let (requirements (.ref value stage))
            (and (object? requirements)
                 (poo-flow-all?
                  (lambda (slot)
                    (let (statuses (.ref requirements slot))
                      (and (pair? statuses)
                           (poo-flow-all?
                            (lambda (status)
                              (memq status
                                    +poo-flow-standard-governance-statuses+))
                            statuses))))
                  (.all-slots requirements)))))
        (.all-slots value))))

(def (standard-governance-bindings? value)
  (and (object? value)
       (poo-flow-all?
        (lambda (slot)
          (let (binding (.ref value slot))
            (and (poo-flow-standard-governance-binding? binding)
                 (eq? (.ref binding 'slot) slot))))
        (.all-slots value))))

(def (poo-flow-standard-governance-interface-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-governance-interface-kind+
        '(identity required-slots optional-slots stage-requirements bindings
          .validate-binding .write-governance .validate-governance
          runtime-executed?))
       (poo-flow-standard-text? (.ref value 'identity))
       (standard-symbol-list? (.ref value 'required-slots))
       (standard-symbol-list? (.ref value 'optional-slots))
       (not (poo-flow-any?
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

(define-type (PooFlowStandardGovernanceInterface @ Type.)
  .element?: poo-flow-standard-governance-interface-shape?)

(def (poo-flow-standard-governance-receipt-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-governance-receipt-kind+
        '(valid? interface-identity stage required-slots bound-slots
          missing-slots invalid-status-slots receipt-digest
          runtime-executed?))
       (boolean? (.ref value 'valid?))
       (poo-flow-standard-text? (.ref value 'interface-identity))
       (symbol? (.ref value 'stage))
       (standard-symbol-list? (.ref value 'required-slots))
       (standard-symbol-list? (.ref value 'bound-slots))
       (standard-symbol-list? (.ref value 'missing-slots))
       (standard-symbol-list? (.ref value 'invalid-status-slots))
       (eq? (.ref value 'valid?)
            (and (null? (.ref value 'missing-slots))
                 (null? (.ref value 'invalid-status-slots))))
       (poo-flow-standard-digest? (.ref value 'receipt-digest))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (PooFlowStandardGovernanceReceipt @ Type.)
  .element?: poo-flow-standard-governance-receipt-shape?)

(def (poo-flow-standard-feature-module-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-feature-module-kind+
        '(identity feature-kind extension-points fixtures governance
          .write-governance .validate-governance metadata))
       (poo-flow-standard-text? (.ref value 'identity))
       (symbol? (.ref value 'feature-kind))
       (standard-symbol-list? (.ref value 'extension-points))
       (object? (.ref value 'fixtures))
       (poo-flow-standard-governance-interface? (.ref value 'governance))
       (procedure? (.ref value '.write-governance))
       (procedure? (.ref value '.validate-governance))
       (list? (.ref value 'metadata))))

(define-type (PooFlowStandardFeatureModule @ Type.)
  .element?: poo-flow-standard-feature-module-shape?)

(def (poo-flow-standards-module-shape? value)
  (and (standard-kind?
        value +poo-flow-standards-module-kind+
        '(identity catalog budget providers features .resolve
          .materialization-context .make-validation-closure))
       (poo-flow-standard-text? (.ref value 'identity))
       (poo-flow-standard-catalog? (.ref value 'catalog))
       (poo-flow-standard-budget? (.ref value 'budget))
       (object? (.ref value 'providers))
       (object? (.ref value 'features))
       (procedure? (.ref value '.resolve))
       (procedure? (.ref value '.materialization-context))
       (procedure? (.ref value '.make-validation-closure))))

(define-type (PooFlowStandardsModule @ Type.)
  .element?: poo-flow-standards-module-shape?)

(def (poo-flow-standard-validation-provider-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-validation-provider-kind+
        '(identity supported-families .validate-standard))
       (poo-flow-standard-text? (.ref value 'identity))
       (standard-text-list? (.ref value 'supported-families))
       (procedure? (.ref value '.validate-standard))))

(define-type (PooFlowStandardValidationProvider @ Type.)
  .element?: poo-flow-standard-validation-provider-shape?)

(def (poo-flow-standard-materialization-context-shape? value)
  (and (standard-kind?
        value +poo-flow-standard-materialization-context-kind+
        '(identity load-source materialize evict! stats))
       (poo-flow-standard-text? (.ref value 'identity))
       (procedure? (.ref value 'load-source))
       (procedure? (.ref value 'materialize))
       (procedure? (.ref value 'evict!))
       (procedure? (.ref value 'stats))))

(define-type (PooFlowStandardMaterializationContext @ Type.)
  .element?: poo-flow-standard-materialization-context-shape?)

(def (poo-flow-standard-family? value)
  (element? PooFlowStandardFamily value))
(def (poo-flow-standard-artifact-ref? value)
  (element? PooFlowStandardArtifactRef value))
(def (poo-flow-standard-artifact-source? value)
  (element? PooFlowStandardArtifactSource value))
(def (poo-flow-standard-artifact? value)
  (element? PooFlowStandardArtifact value))
(def (poo-flow-standard-edition-ref? value)
  (element? PooFlowStandardEditionRef value))
(def (poo-flow-standard-constraint-profile? value)
  (element? PooFlowStandardConstraintProfile value))
(def (poo-flow-standard-catalog? value)
  (element? PooFlowStandardCatalog value))
(def (poo-flow-standard-budget? value)
  (element? PooFlowStandardBudget value))
(def (poo-flow-standard-bundle? value)
  (element? PooFlowStandardBundle value))
(def (poo-flow-standard-failure? value)
  (element? PooFlowStandardFailure value))
(def (poo-flow-standard-catalog-receipt? value)
  (element? PooFlowStandardCatalogReceipt value))
(def (poo-flow-standard-resolution-receipt? value)
  (element? PooFlowStandardResolutionReceipt value))
(def (poo-flow-standard-profile-composition-receipt? value)
  (element? PooFlowStandardProfileCompositionReceipt value))
(def (poo-flow-standard-load-receipt? value)
  (element? PooFlowStandardLoadReceipt value))
(def (poo-flow-standard-materialization-receipt? value)
  (element? PooFlowStandardMaterializationReceipt value))
(def (poo-flow-standard-validation-closure? value)
  (element? PooFlowStandardValidationClosure value))
(def (poo-flow-standard-validation-closure-receipt? value)
  (element? PooFlowStandardValidationClosureReceipt value))
(def (poo-flow-standard-conformance-receipt? value)
  (element? PooFlowStandardConformanceReceipt value))
(def (poo-flow-standard-case-admission-receipt? value)
  (element? PooFlowStandardCaseAdmissionReceipt value))
(def (poo-flow-standard-reference-observation? value)
  (element? PooFlowStandardReferenceObservation value))
(def (poo-flow-standard-comparison-receipt? value)
  (element? PooFlowStandardComparisonReceipt value))
(def (poo-flow-standards-module? value)
  (element? PooFlowStandardsModule value))
(def (poo-flow-standard-feature-module? value)
  (element? PooFlowStandardFeatureModule value))
(def (poo-flow-standard-governance-binding? value)
  (element? PooFlowStandardGovernanceBinding value))
(def (poo-flow-standard-governance-interface? value)
  (element? PooFlowStandardGovernanceInterface value))
(def (poo-flow-standard-governance-receipt? value)
  (element? PooFlowStandardGovernanceReceipt value))
(def (poo-flow-standard-validation-provider? value)
  (element? PooFlowStandardValidationProvider value))
(def (poo-flow-standard-materialization-context? value)
  (element? PooFlowStandardMaterializationContext value))
