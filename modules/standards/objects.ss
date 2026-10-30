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
        (only-in :yuanxu/object-family/syntax
                 defpoo-object-family)
        (only-in :yuanxu/utilities/functional yuanxu-all?)
        "types.ss")

(export agentic-ai-lab-standard-feature-module
        agentic-ai-lab-standard-governance-binding
        agentic-ai-lab-standard-governance-interface
        agentic-ai-lab-standard-governance-write
        agentic-ai-lab-standard-governance-validate
        agentic-ai-lab-standard-family
        agentic-ai-lab-standard-artifact-ref
        agentic-ai-lab-standard-artifact-source
        agentic-ai-lab-standard-artifact
        agentic-ai-lab-standard-edition-ref
        agentic-ai-lab-standard-constraint-profile
        agentic-ai-lab-standard-catalog
        agentic-ai-lab-standard-budget
        agentic-ai-lab-standard-bundle
        agentic-ai-lab-standard-failure
        agentic-ai-lab-standard-catalog-receipt
        agentic-ai-lab-standard-resolution-receipt
        agentic-ai-lab-standard-profile-composition-receipt
        agentic-ai-lab-standard-load-receipt
        agentic-ai-lab-standard-materialization-receipt
        agentic-ai-lab-standard-validation-closure
        agentic-ai-lab-standard-validation-closure-receipt
        agentic-ai-lab-standard-conformance-receipt
        agentic-ai-lab-standard-case-admission-receipt
        agentic-ai-lab-standard-reference-observation
        agentic-ai-lab-standard-comparison-receipt
        agentic-ai-lab-standard-family-identity
        agentic-ai-lab-standard-artifact-ref-identity
        agentic-ai-lab-standard-artifact-ref-dependencies
        agentic-ai-lab-standard-artifact-ref-size-bytes
        agentic-ai-lab-standard-edition-ref-identity
        agentic-ai-lab-standard-edition-ref-dependencies
        agentic-ai-lab-standard-edition-ref-artifacts
        agentic-ai-lab-standard-edition-ref-root-artifacts
        agentic-ai-lab-standard-constraint-profile-identity
        agentic-ai-lab-standard-constraint-profile-base-editions
        agentic-ai-lab-standard-catalog-edition-count
        agentic-ai-lab-standard-bundle-closure-digest
        agentic-ai-lab-standard-resolution-receipt-valid?
        agentic-ai-lab-standard-resolution-receipt-bundle
        agentic-ai-lab-standard-resolution-receipt-failures
        agentic-ai-lab-standard-profile-composition-receipt-valid?
        agentic-ai-lab-standard-materialization-receipt-valid?
        agentic-ai-lab-standard-materialization-receipt-artifact
        agentic-ai-lab-standard-conformance-receipt-valid?
        agentic-ai-lab-standard-comparison-receipt-valid?)

(def (governance-digest value)
  (string-append
   "sha256:"
   (hex-encode
    (sha256 (string->utf8
             (call-with-output-string (lambda (port) (write value port))))))))

(def (agentic-ai-lab-standard-governance-binding
      slot-value owner-value evidence-kind-value content-digest-value
      status-value authority-bearing-value payload-value)
  (validate
   AgenticAILabStandardGovernanceBinding
   (.o kind: +agentic-ai-lab-standard-governance-binding-kind+
       slot: slot-value owner: owner-value evidence-kind: evidence-kind-value
       content-digest: content-digest-value status: status-value
       authority-bearing?: authority-bearing-value payload: payload-value
       runtime-executed?: #f)))

(def (agentic-ai-lab-standard-governance-write interface-value binding-value)
  (unless (and (agentic-ai-lab-standard-governance-interface? interface-value)
               (agentic-ai-lab-standard-governance-binding? binding-value))
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
    (agentic-ai-lab-standard-governance-interface
     (.ref interface-value 'identity)
     (.ref interface-value 'required-slots)
     (.ref interface-value 'optional-slots)
     (.ref interface-value 'stage-requirements)
     (.cc (.ref interface-value 'bindings) slot binding-value)
     (.ref interface-value '.validate-binding))))

(def (agentic-ai-lab-standard-governance-validate interface-value stage-value)
  (unless (agentic-ai-lab-standard-governance-interface? interface-value)
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
             (list 'agentic-ai-lab.standard-governance-receipt.v1
                   (.ref interface-value 'identity) stage-value required bound
                   missing invalid
                   (map (lambda (slot)
                          (list slot
                                (.ref (.ref bindings slot) 'content-digest)
                                (.ref (.ref bindings slot) 'status)))
                        (filter (lambda (slot) (.slot? bindings slot))
                                required))))))
      (validate
       AgenticAILabStandardGovernanceReceipt
       (.o kind: +agentic-ai-lab-standard-governance-receipt-kind+
           valid?: (and (null? missing) (null? invalid))
           interface-identity: (.ref interface-value 'identity)
           stage: stage-value required-slots: required bound-slots: bound
           missing-slots: missing invalid-status-slots: invalid
           receipt-digest: receipt-digest-value runtime-executed?: #f)))))

(def (agentic-ai-lab-standard-governance-interface
      identity-value required-slot-values optional-slot-values
      stage-requirement-values binding-values binding-validator-value)
  (letrec ((interface-value
            (.o kind: +agentic-ai-lab-standard-governance-interface-kind+
                identity: identity-value
                required-slots: required-slot-values
                optional-slots: optional-slot-values
                stage-requirements: stage-requirement-values
                bindings: binding-values
                .validate-binding: binding-validator-value
                .write-governance:
                (lambda (binding)
                  (agentic-ai-lab-standard-governance-write
                   interface-value binding))
                .validate-governance:
                (lambda (stage)
                  (agentic-ai-lab-standard-governance-validate
                   interface-value stage))
                runtime-executed?: #f)))
    (let (validated
          (validate AgenticAILabStandardGovernanceInterface interface-value))
      (for-each
       (lambda (slot)
         (unless (binding-validator-value (.ref binding-values slot))
           (error "initial Standard governance Binding violates its slot contract"
                  slot)))
       (.all-slots binding-values))
      validated)))

(def (agentic-ai-lab-standard-feature-module
      identity-value feature-kind-value extension-point-values fixture-values
      governance-value metadata-value)
  (letrec ((module-value
            (.o kind: +agentic-ai-lab-standard-feature-module-kind+
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
    (validate AgenticAILabStandardFeatureModule module-value)))

(def (agentic-ai-lab-standard-family identity-value owner-value semantic-kind-value
                               representation-values license-value
                               metadata-value)
  (validate
   AgenticAILabStandardFamily
   (.o kind: +agentic-ai-lab-standard-family-kind+
       identity: identity-value
       owner: owner-value
       semantic-kind: semantic-kind-value
       representations: representation-values
       license: license-value
       metadata: metadata-value)))

(def (agentic-ai-lab-standard-artifact-ref identity-value canonical-uri-value
                                     exact-version-value
                                     artifact-kind-value representation-value
                                     digest-value dependency-values
                                     size-bytes-value source-loader-value
                                     materializer-value
                                     metadata-value)
  (validate
   AgenticAILabStandardArtifactRef
   (.o kind: +agentic-ai-lab-standard-artifact-ref-kind+
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

(def (agentic-ai-lab-standard-artifact-source
      artifact-identity-value digest-value representation-value payload-value
      size-bytes-value metadata-value)
  (validate
   AgenticAILabStandardArtifactSource
   (.o kind: +agentic-ai-lab-standard-artifact-source-kind+
       artifact-identity: artifact-identity-value
       digest: digest-value
       representation: representation-value
       payload: payload-value
       size-bytes: size-bytes-value
       metadata: metadata-value
       runtime-executed?: #t)))

(def (agentic-ai-lab-standard-artifact identity-value digest-value
                                 representation-value payload-value
                                 metadata-value)
  (validate
   AgenticAILabStandardArtifact
   (.o kind: +agentic-ai-lab-standard-artifact-kind+
       identity: identity-value
       digest: digest-value
       representation: representation-value
       payload: payload-value
       metadata: metadata-value)))

(def (agentic-ai-lab-standard-edition-ref
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
    (unless (yuanxu-all?
             (lambda (root) (hash-key? artifact-identities root))
             root-artifact-values)
      (error "standard edition root artifact is absent from its artifact index"
             identity-value root-artifact-values)))
  (validate
   AgenticAILabStandardEditionRef
   (.o kind: +agentic-ai-lab-standard-edition-ref-kind+
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

(def (agentic-ai-lab-standard-constraint-profile
      identity-value exact-revision-value base-edition-values
      constraint-values compatibility-values artifact-dependency-values
      terminology-dependency-values provenance-value qualification-state-value)
  (validate
   AgenticAILabStandardConstraintProfile
   (.o kind: +agentic-ai-lab-standard-constraint-profile-kind+
       identity: identity-value
       exact-revision: exact-revision-value
       base-editions: base-edition-values
       constraints: constraint-values
       compatibility: compatibility-values
       artifact-dependencies: artifact-dependency-values
       terminology-dependencies: terminology-dependency-values
       provenance: provenance-value
       qualification-state: qualification-state-value)))

(def (agentic-ai-lab-standard-catalog identity-value edition-values metadata-value)
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
     AgenticAILabStandardCatalog
     (.o kind: +agentic-ai-lab-standard-catalog-kind+
         identity: identity-value
         editions: edition-values
         edition-index: edition-index-value
         canonical-version-index: canonical-version-index-value
         artifact-index: artifact-index-value
         edition-count: edition-count-value
         realized-artifact-count: 0
         runtime-executed?: #f
         metadata: metadata-value))))

(def (agentic-ai-lab-standard-budget max-editions-value max-artifacts-value
                               max-depth-value max-bytes-value
                               max-operations-value)
  (validate
   AgenticAILabStandardBudget
   (.o kind: +agentic-ai-lab-standard-budget-kind+
       max-editions: max-editions-value
       max-artifacts: max-artifacts-value
       max-depth: max-depth-value
       max-bytes: max-bytes-value
       max-operations: max-operations-value)))

(def (agentic-ai-lab-standard-bundle root-identities-value edition-values
                               edition-count-value artifact-values
                               artifact-count-value terminology-snapshot-digest-value
                               byte-count-value maximum-depth-value
                               operation-count-value
                               closure-digest-value)
  (validate
   AgenticAILabStandardBundle
   (.o kind: +agentic-ai-lab-standard-bundle-kind+
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

(def (agentic-ai-lab-standard-failure code-value subject-value detail-value path-value)
  (validate
   AgenticAILabStandardFailure
   (.o kind: +agentic-ai-lab-standard-failure-kind+
       code: code-value
       subject: subject-value
       detail: detail-value
       path: path-value)))

(def (agentic-ai-lab-standard-catalog-receipt catalog-value)
  (validate
   AgenticAILabStandardCatalogReceipt
   (.o kind: +agentic-ai-lab-standard-catalog-receipt-kind+
       catalog-identity: (.ref catalog-value 'identity)
       edition-count: (.ref catalog-value 'edition-count)
       realized-artifact-count: 0
       validation-closure-count: 0
       runtime-executed?: #f)))

(def (agentic-ai-lab-standard-resolution-receipt root-values bundle-value
                                           failure-values)
  (validate
   AgenticAILabStandardResolutionReceipt
   (.o kind: +agentic-ai-lab-standard-resolution-receipt-kind+
       valid?: (null? failure-values)
       roots: root-values
       bundle: bundle-value
       failures: failure-values
       first-failure: (and (pair? failure-values) (car failure-values))
       runtime-executed?: #f)))

(def (agentic-ai-lab-standard-profile-composition-receipt
      case-identity-value profile-values profile-identity-values
      base-edition-values constraint-values artifact-dependency-values
      terminology-dependency-values resolution-receipt-value failure-values
      composition-digest-value)
  (validate
   AgenticAILabStandardProfileCompositionReceipt
   (.o kind: +agentic-ai-lab-standard-profile-composition-receipt-kind+
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

(def (agentic-ai-lab-standard-load-receipt
      artifact-identity-value cache-key-value generation-value
      source-digest-value loaded-bytes-value outcome-value failure-values
      runtime-executed-value)
  (validate
   AgenticAILabStandardLoadReceipt
   (.o kind: +agentic-ai-lab-standard-load-receipt-kind+
       valid?: (null? failure-values)
       artifact-identity: artifact-identity-value
       cache-key: cache-key-value
       generation: generation-value
       source-digest: source-digest-value
       loaded-bytes: loaded-bytes-value
       outcome: outcome-value
       failures: failure-values
       runtime-executed?: runtime-executed-value)))

(def (agentic-ai-lab-standard-materialization-receipt
      artifact-identity-value artifact-value cache-outcome-value
      generation-value load-receipt-value failure-values load-count-value
      runtime-executed-value)
  (validate
   AgenticAILabStandardMaterializationReceipt
   (.o kind: +agentic-ai-lab-standard-materialization-receipt-kind+
       valid?: (null? failure-values)
       artifact-identity: artifact-identity-value
       artifact: artifact-value
       cache-outcome: cache-outcome-value
       generation: generation-value
       load-receipt: load-receipt-value
       failures: failure-values
       load-count: load-count-value
       runtime-executed?: runtime-executed-value)))

(def (agentic-ai-lab-standard-validation-closure
      identity-value bundle-value provider-identity-value subject-kind-value
      subject-snapshot-digest-value constraint-values validation-closure-digest-value)
  (validate
   AgenticAILabStandardValidationClosure
   (.o kind: +agentic-ai-lab-standard-validation-closure-kind+
       identity: identity-value
       bundle: bundle-value
       provider-identity: provider-identity-value
       subject-kind: subject-kind-value
       subject-snapshot-digest: subject-snapshot-digest-value
       constraints: constraint-values
       validation-closure-digest: validation-closure-digest-value
       runtime-executed?: #f)))

(def (agentic-ai-lab-standard-validation-closure-receipt
      validation-closure-value closure-digest-value terminology-snapshot-digest-value
      engine-identity-value engine-version-value unsupported-count-value
      cache-outcome-value generation-value failure-values
      runtime-executed-value)
  (validate
   AgenticAILabStandardValidationClosureReceipt
   (.o kind: +agentic-ai-lab-standard-validation-closure-receipt-kind+
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

(def (agentic-ai-lab-standard-conformance-receipt
      valid-value provider-identity-value validation-closure-digest-value
      subject-snapshot-digest-value evaluated-constraint-values
      unsupported-constraint-values failure-values conformance-digest-value)
  (validate
   AgenticAILabStandardConformanceReceipt
   (.o kind: +agentic-ai-lab-standard-conformance-receipt-kind+
       valid?: (if valid-value #t #f)
       provider-identity: provider-identity-value
       validation-closure-digest: validation-closure-digest-value
       subject-snapshot-digest: subject-snapshot-digest-value
       evaluated-constraints: evaluated-constraint-values
       unsupported-constraints: unsupported-constraint-values
       failures: failure-values
       conformance-digest: conformance-digest-value
       runtime-executed?: #t)))

(def (agentic-ai-lab-standard-case-admission-receipt
      case-identity-value conformance-digest-values evidence-digest-values
      failure-values admission-digest-value)
  (validate
   AgenticAILabStandardCaseAdmissionReceipt
   (.o kind: +agentic-ai-lab-standard-case-admission-receipt-kind+
       valid?: (null? failure-values)
       case-identity: case-identity-value
       conformance-digests: conformance-digest-values
       evidence-digests: evidence-digest-values
       failures: failure-values
       admission-digest: admission-digest-value
       runtime-executed?: #f)))

(def (agentic-ai-lab-standard-reference-observation
      validator-identity-value validator-version-value
      validator-binary-digest-value fixture-identity-value
      subject-snapshot-digest-value profile-identity-values outcome-value
      issue-values output-digest-value observation-digest-value metadata-value)
  (validate
   AgenticAILabStandardReferenceObservation
   (.o kind: +agentic-ai-lab-standard-reference-observation-kind+
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

(def (agentic-ai-lab-standard-comparison-receipt
      agreement-value provider-identity-value validator-identity-value
      validator-version-value subject-snapshot-digest-value
      profile-identity-values conformance-digest-value
      reference-observation-digest-value discrepancy-values failure-values
      comparison-digest-value)
  (validate
   AgenticAILabStandardComparisonReceipt
   (.o kind: +agentic-ai-lab-standard-comparison-receipt-kind+
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
   (agentic-ai-lab-standard-family-identity identity)
   (agentic-ai-lab-standard-artifact-ref-identity identity)
   (agentic-ai-lab-standard-artifact-ref-dependencies dependencies)
   (agentic-ai-lab-standard-artifact-ref-size-bytes size-bytes)
   (agentic-ai-lab-standard-edition-ref-identity identity)
   (agentic-ai-lab-standard-edition-ref-dependencies dependencies)
   (agentic-ai-lab-standard-edition-ref-artifacts artifacts)
   (agentic-ai-lab-standard-edition-ref-root-artifacts root-artifacts)
   (agentic-ai-lab-standard-constraint-profile-identity identity)
   (agentic-ai-lab-standard-constraint-profile-base-editions base-editions)
   (agentic-ai-lab-standard-catalog-edition-count edition-count)
   (agentic-ai-lab-standard-bundle-closure-digest closure-digest)
   (agentic-ai-lab-standard-resolution-receipt-valid? valid?)
   (agentic-ai-lab-standard-resolution-receipt-bundle bundle)
   (agentic-ai-lab-standard-resolution-receipt-failures failures)
   (agentic-ai-lab-standard-profile-composition-receipt-valid? valid?)
   (agentic-ai-lab-standard-materialization-receipt-valid? valid?)
   (agentic-ai-lab-standard-materialization-receipt-artifact artifact)
   (agentic-ai-lab-standard-conformance-receipt-valid? valid?)
   (agentic-ai-lab-standard-comparison-receipt-valid? valid?))
  (projections))
