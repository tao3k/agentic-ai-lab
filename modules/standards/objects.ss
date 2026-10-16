;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO-native Standard values and immutable constructors.
;;; Invariant: construction performs no source loading or validation execution.
(import (only-in :clan/poo/object .all-slots .cc .o .ref .slot?)
        (only-in :clan/poo/mop validate)
        (only-in :std/crypto/digest sha256)
        (only-in :std/hash/misc hash-key? hash-put!)
        (only-in :std/list/list filter)
        (only-in :std/encoding/hex hex-encode)
        (only-in :core/object-family/syntax
                 defpoo-object-family)
        (only-in :core/utilities/functional poo-flow-all?)
        "types.ss")

(export poo-flow-standard-feature-module
        poo-flow-standard-governance-binding
        poo-flow-standard-governance-interface
        poo-flow-standard-governance-write
        poo-flow-standard-governance-validate
        poo-flow-standard-family
        poo-flow-standard-artifact-ref
        poo-flow-standard-artifact-source
        poo-flow-standard-artifact
        poo-flow-standard-edition-ref
        poo-flow-standard-constraint-profile
        poo-flow-standard-catalog
        poo-flow-standard-budget
        poo-flow-standard-bundle
        poo-flow-standard-failure
        poo-flow-standard-catalog-receipt
        poo-flow-standard-resolution-receipt
        poo-flow-standard-profile-composition-receipt
        poo-flow-standard-load-receipt
        poo-flow-standard-materialization-receipt
        poo-flow-standard-validation-closure
        poo-flow-standard-validation-closure-receipt
        poo-flow-standard-conformance-receipt
        poo-flow-standard-case-admission-receipt
        poo-flow-standard-reference-observation
        poo-flow-standard-comparison-receipt
        poo-flow-standard-family-identity
        poo-flow-standard-artifact-ref-identity
        poo-flow-standard-artifact-ref-dependencies
        poo-flow-standard-artifact-ref-size-bytes
        poo-flow-standard-edition-ref-identity
        poo-flow-standard-edition-ref-dependencies
        poo-flow-standard-edition-ref-artifacts
        poo-flow-standard-edition-ref-root-artifacts
        poo-flow-standard-constraint-profile-identity
        poo-flow-standard-constraint-profile-base-editions
        poo-flow-standard-catalog-edition-count
        poo-flow-standard-bundle-closure-digest
        poo-flow-standard-resolution-receipt-valid?
        poo-flow-standard-resolution-receipt-bundle
        poo-flow-standard-resolution-receipt-failures
        poo-flow-standard-profile-composition-receipt-valid?
        poo-flow-standard-materialization-receipt-valid?
        poo-flow-standard-materialization-receipt-artifact
        poo-flow-standard-conformance-receipt-valid?
        poo-flow-standard-comparison-receipt-valid?)

(def (governance-digest value)
  (string-append
   "sha256:"
   (hex-encode
    (sha256 (string->utf8
             (call-with-output-string (lambda (port) (write value port))))))))

(def (poo-flow-standard-governance-binding
      slot-value owner-value evidence-kind-value content-digest-value
      status-value authority-bearing-value payload-value)
  (validate
   PooFlowStandardGovernanceBinding
   (.o kind: +poo-flow-standard-governance-binding-kind+
       slot: slot-value owner: owner-value evidence-kind: evidence-kind-value
       content-digest: content-digest-value status: status-value
       authority-bearing?: authority-bearing-value payload: payload-value
       runtime-executed?: #f)))

(def (poo-flow-standard-governance-write interface-value binding-value)
  (unless (and (poo-flow-standard-governance-interface? interface-value)
               (poo-flow-standard-governance-binding? binding-value))
    (error "Standard governance write requires a typed Interface and Binding"
           interface-value binding-value))
  (let* ((slot (.ref binding-value 'slot))
         (declared
          (append (.ref interface-value 'required-slots)
                  (.ref interface-value 'optional-slots))))
    (unless (memq slot declared)
      (error "Agent attempted to write an undeclared Standard governance slot"
             slot declared))
    (unless ((.ref interface-value '.validate-binding) binding-value)
      (error "Agent governance Binding violates the Standard slot contract"
             slot binding-value))
    (poo-flow-standard-governance-interface
     (.ref interface-value 'identity)
     (.ref interface-value 'required-slots)
     (.ref interface-value 'optional-slots)
     (.ref interface-value 'stage-requirements)
     (.cc (.ref interface-value 'bindings) slot binding-value)
     (.ref interface-value '.validate-binding))))

(def (poo-flow-standard-governance-validate interface-value stage-value)
  (unless (poo-flow-standard-governance-interface? interface-value)
    (error "invalid Standard governance Interface" interface-value))
  (let (stages (.ref interface-value 'stage-requirements))
    (unless (and (symbol? stage-value) (.slot? stages stage-value))
      (error "unknown Standard governance stage" stage-value))
    (let* ((requirements (.ref stages stage-value))
           (required (.all-slots requirements))
           (bindings (.ref interface-value 'bindings))
           (bound (.all-slots bindings))
           (missing
            (filter (lambda (slot) (not (.slot? bindings slot))) required))
           (invalid
            (filter
             (lambda (slot)
               (and (.slot? bindings slot)
                    (not (memq (.ref (.ref bindings slot) 'status)
                               (.ref requirements slot)))))
             required))
           (receipt-digest-value
            (governance-digest
             (list 'poo-flow.standard-governance-receipt.v1
                   (.ref interface-value 'identity) stage-value required bound
                   missing invalid
                   (map (lambda (slot)
                          (list slot
                                (.ref (.ref bindings slot) 'content-digest)
                                (.ref (.ref bindings slot) 'status)))
                        (filter (lambda (slot) (.slot? bindings slot))
                                required))))))
      (validate
       PooFlowStandardGovernanceReceipt
       (.o kind: +poo-flow-standard-governance-receipt-kind+
           valid?: (and (null? missing) (null? invalid))
           interface-identity: (.ref interface-value 'identity)
           stage: stage-value required-slots: required bound-slots: bound
           missing-slots: missing invalid-status-slots: invalid
           receipt-digest: receipt-digest-value runtime-executed?: #f)))))

(def (poo-flow-standard-governance-interface
      identity-value required-slot-values optional-slot-values
      stage-requirement-values binding-values binding-validator-value)
  (letrec ((interface-value
            (.o kind: +poo-flow-standard-governance-interface-kind+
                identity: identity-value
                required-slots: required-slot-values
                optional-slots: optional-slot-values
                stage-requirements: stage-requirement-values
                bindings: binding-values
                .validate-binding: binding-validator-value
                .write-governance:
                (lambda (binding)
                  (poo-flow-standard-governance-write
                   interface-value binding))
                .validate-governance:
                (lambda (stage)
                  (poo-flow-standard-governance-validate
                   interface-value stage))
                runtime-executed?: #f)))
    (let (validated
          (validate PooFlowStandardGovernanceInterface interface-value))
      (for-each
       (lambda (slot)
         (unless (binding-validator-value (.ref binding-values slot))
           (error "initial Standard governance Binding violates its slot contract"
                  slot)))
       (.all-slots binding-values))
      validated)))

(def (poo-flow-standard-feature-module
      identity-value feature-kind-value extension-point-values fixture-values
      governance-value metadata-value)
  (letrec ((module-value
            (.o kind: +poo-flow-standard-feature-module-kind+
                identity: identity-value
                feature-kind: feature-kind-value
                extension-points: extension-point-values
                fixtures: fixture-values
                governance: governance-value
                .write-governance:
                (lambda (binding)
                  (.cc module-value 'governance
                       ((.ref governance-value '.write-governance) binding)))
                .validate-governance:
                (lambda (stage)
                  ((.ref governance-value '.validate-governance) stage))
                metadata: metadata-value)))
    (validate PooFlowStandardFeatureModule module-value)))

(def (poo-flow-standard-family identity-value owner-value semantic-kind-value
                               representation-values license-value
                               metadata-value)
  (validate
   PooFlowStandardFamily
   (.o kind: +poo-flow-standard-family-kind+
       identity: identity-value
       owner: owner-value
       semantic-kind: semantic-kind-value
       representations: representation-values
       license: license-value
       metadata: metadata-value)))

(def (poo-flow-standard-artifact-ref identity-value canonical-uri-value
                                     exact-version-value
                                     artifact-kind-value representation-value
                                     digest-value dependency-values
                                     size-bytes-value source-loader-value
                                     materializer-value
                                     metadata-value)
  (validate
   PooFlowStandardArtifactRef
   (.o kind: +poo-flow-standard-artifact-ref-kind+
       identity: identity-value
       canonical-uri: canonical-uri-value
       exact-version: exact-version-value
       artifact-kind: artifact-kind-value
       representation: representation-value
       digest: digest-value
       generation: digest-value
       cache-key:
       (string-append canonical-uri-value "|" exact-version-value "|"
                      digest-value)
       dependencies: dependency-values
       size-bytes: size-bytes-value
       source-loader: source-loader-value
       materializer: materializer-value
       metadata: metadata-value)))

(def (poo-flow-standard-artifact-source
      artifact-identity-value digest-value representation-value payload-value
      size-bytes-value metadata-value)
  (validate
   PooFlowStandardArtifactSource
   (.o kind: +poo-flow-standard-artifact-source-kind+
       artifact-identity: artifact-identity-value
       digest: digest-value
       representation: representation-value
       payload: payload-value
       size-bytes: size-bytes-value
       metadata: metadata-value
       runtime-executed?: #t)))

(def (poo-flow-standard-artifact identity-value digest-value
                                 representation-value payload-value
                                 metadata-value)
  (validate
   PooFlowStandardArtifact
   (.o kind: +poo-flow-standard-artifact-kind+
       identity: identity-value
       digest: digest-value
       representation: representation-value
       payload: payload-value
       metadata: metadata-value)))

(def (poo-flow-standard-edition-ref
      identity-value family-value canonical-uri-value version-value
      specification-release-value jurisdiction-value digest-value
      source-ref-value dependency-values artifact-values root-artifact-values
      status-value validity-value metadata-value)
  ;; Build the identity set once.  Scanning ARTIFACT-VALUES independently for
  ;; every root makes edition construction O(roots * artifacts), which is
  ;; especially costly for externally published conformance packs.
  (let (artifact-identities (make-hash-table))
    (for-each
     (lambda (artifact)
       (hash-put! artifact-identities (.ref artifact 'identity) #t))
     artifact-values)
    (unless (poo-flow-all?
             (lambda (root) (hash-key? artifact-identities root))
             root-artifact-values)
      (error "standard edition root artifact is absent from its artifact index"
             identity-value root-artifact-values)))
  (validate
   PooFlowStandardEditionRef
   (.o kind: +poo-flow-standard-edition-ref-kind+
       identity: identity-value
       family: family-value
       canonical-uri: canonical-uri-value
       version: version-value
       specification-release: specification-release-value
       jurisdiction: jurisdiction-value
       digest: digest-value
       source-ref: source-ref-value
       dependencies: dependency-values
       artifacts: artifact-values
       root-artifacts: root-artifact-values
       status: status-value
       validity: validity-value
       metadata: metadata-value)))

(def (poo-flow-standard-constraint-profile
      identity-value exact-revision-value base-edition-values
      constraint-values compatibility-values artifact-dependency-values
      terminology-dependency-values provenance-value qualification-state-value)
  (validate
   PooFlowStandardConstraintProfile
   (.o kind: +poo-flow-standard-constraint-profile-kind+
       identity: identity-value
       exact-revision: exact-revision-value
       base-editions: base-edition-values
       constraints: constraint-values
       compatibility: compatibility-values
       artifact-dependencies: artifact-dependency-values
       terminology-dependencies: terminology-dependency-values
       provenance: provenance-value
       qualification-state: qualification-state-value)))

(def (poo-flow-standard-catalog identity-value edition-values metadata-value)
  (let ((edition-index-value (make-hash-table))
        (canonical-version-index-value (make-hash-table))
        (artifact-index-value (make-hash-table))
        (edition-count-value 0))
    (for-each
     (lambda (edition)
       (let (identity (.ref edition 'identity))
         ;; Edition values are always truthy POO objects, so hash-get gives a
         ;; single native lookup for duplicate detection on the 10k hot path.
         (when (hash-get edition-index-value identity)
           (error "duplicate Standard edition identity" identity))
         (hash-put! edition-index-value identity edition)
         (hash-put!
          canonical-version-index-value identity
          (string-append (.ref edition 'canonical-uri)
                         "|" (.ref edition 'version)))
         (set! edition-count-value (+ edition-count-value 1))
         (for-each
          (lambda (artifact-ref)
            (let* ((artifact-identity (.ref artifact-ref 'identity))
                   (existing (hash-get artifact-index-value artifact-identity)))
              (when (and existing
                         (not (equal? (.ref existing 'digest)
                                      (.ref artifact-ref 'digest))))
                (error "conflicting Standard artifact identity"
                       artifact-identity))
              (unless existing
                (hash-put! artifact-index-value artifact-identity artifact-ref))))
          (.ref edition 'artifacts))))
     edition-values)
    (validate
     PooFlowStandardCatalog
     (.o kind: +poo-flow-standard-catalog-kind+
         identity: identity-value
         editions: edition-values
         edition-index: edition-index-value
         canonical-version-index: canonical-version-index-value
         artifact-index: artifact-index-value
         edition-count: edition-count-value
         realized-artifact-count: 0
         runtime-executed?: #f
         metadata: metadata-value))))

(def (poo-flow-standard-budget max-editions-value max-artifacts-value
                               max-depth-value max-bytes-value
                               max-operations-value)
  (validate
   PooFlowStandardBudget
   (.o kind: +poo-flow-standard-budget-kind+
       max-editions: max-editions-value
       max-artifacts: max-artifacts-value
       max-depth: max-depth-value
       max-bytes: max-bytes-value
       max-operations: max-operations-value)))

(def (poo-flow-standard-bundle root-identities-value edition-values
                               edition-count-value artifact-values
                               artifact-count-value terminology-snapshot-digest-value
                               byte-count-value maximum-depth-value
                               operation-count-value
                               closure-digest-value)
  (validate
   PooFlowStandardBundle
   (.o kind: +poo-flow-standard-bundle-kind+
       root-identities: root-identities-value
       editions: edition-values
       artifacts: artifact-values
       terminology-snapshot-digest: terminology-snapshot-digest-value
       edition-count: edition-count-value
       artifact-count: artifact-count-value
       byte-count: byte-count-value
       maximum-depth: maximum-depth-value
       operation-count: operation-count-value
       closure-digest: closure-digest-value
       generation: closure-digest-value
       runtime-executed?: #f)))

(def (poo-flow-standard-failure code-value subject-value detail-value path-value)
  (validate
   PooFlowStandardFailure
   (.o kind: +poo-flow-standard-failure-kind+
       code: code-value
       subject: subject-value
       detail: detail-value
       path: path-value)))

(def (poo-flow-standard-catalog-receipt catalog-value)
  (validate
   PooFlowStandardCatalogReceipt
   (.o kind: +poo-flow-standard-catalog-receipt-kind+
       catalog-identity: (.ref catalog-value 'identity)
       edition-count: (.ref catalog-value 'edition-count)
       realized-artifact-count: 0
       validation-closure-count: 0
       runtime-executed?: #f)))

(def (poo-flow-standard-resolution-receipt root-values bundle-value
                                           failure-values)
  (validate
   PooFlowStandardResolutionReceipt
   (.o kind: +poo-flow-standard-resolution-receipt-kind+
       valid?: (null? failure-values)
       roots: root-values
       bundle: bundle-value
       failures: failure-values
       first-failure: (and (pair? failure-values) (car failure-values))
       runtime-executed?: #f)))

(def (poo-flow-standard-profile-composition-receipt
      case-identity-value profile-values profile-identity-values
      base-edition-values constraint-values artifact-dependency-values
      terminology-dependency-values resolution-receipt-value failure-values
      composition-digest-value)
  (validate
   PooFlowStandardProfileCompositionReceipt
   (.o kind: +poo-flow-standard-profile-composition-receipt-kind+
       valid?: (null? failure-values)
       case-identity: case-identity-value
       profiles: profile-values
       profile-identities: profile-identity-values
       base-editions: base-edition-values
       constraints: constraint-values
       constraint-count: (length constraint-values)
       artifact-dependencies: artifact-dependency-values
       terminology-dependencies: terminology-dependency-values
       resolution-receipt: resolution-receipt-value
       failures: failure-values
       composition-digest: composition-digest-value
       runtime-executed?: #f)))

(def (poo-flow-standard-load-receipt
      artifact-identity-value cache-key-value generation-value
      source-digest-value loaded-bytes-value outcome-value failure-values
      runtime-executed-value)
  (validate
   PooFlowStandardLoadReceipt
   (.o kind: +poo-flow-standard-load-receipt-kind+
       valid?: (null? failure-values)
       artifact-identity: artifact-identity-value
       cache-key: cache-key-value
       generation: generation-value
       source-digest: source-digest-value
       loaded-bytes: loaded-bytes-value
       outcome: outcome-value
       failures: failure-values
       runtime-executed?: runtime-executed-value)))

(def (poo-flow-standard-materialization-receipt
      artifact-identity-value artifact-value cache-outcome-value
      generation-value load-receipt-value failure-values load-count-value
      runtime-executed-value)
  (validate
   PooFlowStandardMaterializationReceipt
   (.o kind: +poo-flow-standard-materialization-receipt-kind+
       valid?: (null? failure-values)
       artifact-identity: artifact-identity-value
       artifact: artifact-value
       cache-outcome: cache-outcome-value
       generation: generation-value
       load-receipt: load-receipt-value
       failures: failure-values
       load-count: load-count-value
       runtime-executed?: runtime-executed-value)))

(def (poo-flow-standard-validation-closure
      identity-value bundle-value provider-identity-value subject-kind-value
      subject-snapshot-digest-value constraint-values validation-closure-digest-value)
  (validate
   PooFlowStandardValidationClosure
   (.o kind: +poo-flow-standard-validation-closure-kind+
       identity: identity-value
       bundle: bundle-value
       provider-identity: provider-identity-value
       subject-kind: subject-kind-value
       subject-snapshot-digest: subject-snapshot-digest-value
       constraints: constraint-values
       validation-closure-digest: validation-closure-digest-value
       runtime-executed?: #f)))

(def (poo-flow-standard-validation-closure-receipt
      validation-closure-value closure-digest-value terminology-snapshot-digest-value
      engine-identity-value engine-version-value unsupported-count-value
      cache-outcome-value generation-value failure-values
      runtime-executed-value)
  (validate
   PooFlowStandardValidationClosureReceipt
   (.o kind: +poo-flow-standard-validation-closure-receipt-kind+
       valid?: (null? failure-values)
       validation-closure: validation-closure-value
       validation-closure-digest: (.ref validation-closure-value 'validation-closure-digest)
       closure-digest: closure-digest-value
       terminology-snapshot-digest: terminology-snapshot-digest-value
       engine-identity: engine-identity-value
       engine-version: engine-version-value
       constraint-count: (length (.ref validation-closure-value 'constraints))
       unsupported-count: unsupported-count-value
       cache-outcome: cache-outcome-value
       generation: generation-value
       failures: failure-values
       runtime-executed?: runtime-executed-value)))

(def (poo-flow-standard-conformance-receipt
      valid-value provider-identity-value validation-closure-digest-value
      subject-snapshot-digest-value evaluated-constraint-values
      unsupported-constraint-values failure-values conformance-digest-value)
  (validate
   PooFlowStandardConformanceReceipt
   (.o kind: +poo-flow-standard-conformance-receipt-kind+
       valid?: (if valid-value #t #f)
       provider-identity: provider-identity-value
       validation-closure-digest: validation-closure-digest-value
       subject-snapshot-digest: subject-snapshot-digest-value
       evaluated-constraints: evaluated-constraint-values
       unsupported-constraints: unsupported-constraint-values
       failures: failure-values
       conformance-digest: conformance-digest-value
       runtime-executed?: #t)))

(def (poo-flow-standard-case-admission-receipt
      case-identity-value conformance-digest-values evidence-digest-values
      failure-values admission-digest-value)
  (validate
   PooFlowStandardCaseAdmissionReceipt
   (.o kind: +poo-flow-standard-case-admission-receipt-kind+
       valid?: (null? failure-values)
       case-identity: case-identity-value
       conformance-digests: conformance-digest-values
       evidence-digests: evidence-digest-values
       failures: failure-values
       admission-digest: admission-digest-value
       runtime-executed?: #f)))

(def (poo-flow-standard-reference-observation
      validator-identity-value validator-version-value
      validator-binary-digest-value fixture-identity-value
      subject-snapshot-digest-value profile-identity-values outcome-value
      issue-values output-digest-value observation-digest-value metadata-value)
  (validate
   PooFlowStandardReferenceObservation
   (.o kind: +poo-flow-standard-reference-observation-kind+
       validator-identity: validator-identity-value
       validator-version: validator-version-value
       validator-binary-digest: validator-binary-digest-value
       fixture-identity: fixture-identity-value
       subject-snapshot-digest: subject-snapshot-digest-value
       profile-identities: profile-identity-values
       outcome: outcome-value
       issues: issue-values
       output-digest: output-digest-value
       observation-digest: observation-digest-value
       runtime-executed?: #t
       metadata: metadata-value)))

(def (poo-flow-standard-comparison-receipt
      agreement-value provider-identity-value validator-identity-value
      validator-version-value subject-snapshot-digest-value
      profile-identity-values conformance-digest-value
      reference-observation-digest-value discrepancy-values failure-values
      comparison-digest-value)
  (validate
   PooFlowStandardComparisonReceipt
   (.o kind: +poo-flow-standard-comparison-receipt-kind+
       valid?: (null? failure-values)
       agreement?: (if agreement-value #t #f)
       provider-identity: provider-identity-value
       validator-identity: validator-identity-value
       validator-version: validator-version-value
       subject-snapshot-digest: subject-snapshot-digest-value
       profile-identities: profile-identity-values
       conformance-digest: conformance-digest-value
       reference-observation-digest: reference-observation-digest-value
       discrepancies: discrepancy-values
       failures: failure-values
       comparison-digest: comparison-digest-value
       runtime-executed?: #f)))

(defpoo-object-family
  (accessors
   (poo-flow-standard-family-identity identity)
   (poo-flow-standard-artifact-ref-identity identity)
   (poo-flow-standard-artifact-ref-dependencies dependencies)
   (poo-flow-standard-artifact-ref-size-bytes size-bytes)
   (poo-flow-standard-edition-ref-identity identity)
   (poo-flow-standard-edition-ref-dependencies dependencies)
   (poo-flow-standard-edition-ref-artifacts artifacts)
   (poo-flow-standard-edition-ref-root-artifacts root-artifacts)
   (poo-flow-standard-constraint-profile-identity identity)
   (poo-flow-standard-constraint-profile-base-editions base-editions)
   (poo-flow-standard-catalog-edition-count edition-count)
   (poo-flow-standard-bundle-closure-digest closure-digest)
   (poo-flow-standard-resolution-receipt-valid? valid?)
   (poo-flow-standard-resolution-receipt-bundle bundle)
   (poo-flow-standard-resolution-receipt-failures failures)
   (poo-flow-standard-profile-composition-receipt-valid? valid?)
   (poo-flow-standard-materialization-receipt-valid? valid?)
   (poo-flow-standard-materialization-receipt-artifact artifact)
   (poo-flow-standard-conformance-receipt-valid? valid?)
   (poo-flow-standard-comparison-receipt-valid? valid?))
  (projections))
