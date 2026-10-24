;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        (only-in :std/misc/ports read-all-as-string)
        (only-in :clan/poo/object .ref)
        :agentic-ai-lab/modules/standards/interface
        :agentic-ai-lab/lambda-episteme/modules/healthcare/standards/interface
        :agentic-ai-lab/lambda-episteme/modules/ontology/interface
        (only-in :agentic-ai-lab/lambda-episteme/user-interface/scenarios/healthcare/cases/au-legacy-interface-fhir-migration/case
                 AULegacyInterfaceFHIRMigrationCase)
        (only-in :gerbil-parser/languages/hl7/v2-2.5.1/parser
                 parse-hl7v2)
        (only-in :gerbil-parser/languages/hl7/v2-2.5.1/projection
                 hl7v2-adt-a08-patient-projection)
        (only-in :gerbil-parser/src/runtime/artifact
                 parse-artifact-ref parse-artifact-roundtrip
                 parse-artifact-success? parse-artifact-valid?))

(export healthcare-hl7v2-parser-receipt-test)

(def fixture-path
  "packages/lambda-episteme/modules/healthcare/standards/migration/fixtures/au-adt-a08-patient.hl7")

(def migration-terminology-snapshot
  (agentic-ai-lab-standard-digest 'au-hl7v2-end-to-end-terminology))

(def (materialized-au-core-patient-constraints)
  (let* ((resolution
          (agentic-ai-lab-standard-resolve
           FHIRStandardsCatalog '("hl7.fhir.au.core@1.0.0")
           agentic-ai-lab-standard-default-budget migration-terminology-snapshot))
         (bundle (agentic-ai-lab-standard-resolution-receipt-bundle resolution))
         (context
          (agentic-ai-lab-standard-materialization-context
           "qualification/healthcare/hl7v2-migration/materialization"
           (.ref bundle 'artifacts)))
         (receipt
          (agentic-ai-lab-standard-materialize
           context +agentic-ai-lab-fhir-au-core-patient-artifact-identity+)))
    (agentic-ai-lab-fhir-au-core-patient-constraints
     (agentic-ai-lab-standard-materialization-receipt-artifact receipt))))

(def (validate-au-core-patient candidate)
  (let* ((resolution
          (agentic-ai-lab-standard-resolve
           FHIRStandardsCatalog '("hl7.fhir.au.core@1.0.0")
           agentic-ai-lab-standard-default-budget migration-terminology-snapshot))
         (bundle (agentic-ai-lab-standard-resolution-receipt-bundle resolution))
         (closure
          (agentic-ai-lab-standard-make-validation-closure
           (.ref FHIRAUCorePatientStandardProfile 'identity)
           bundle +agentic-ai-lab-fhir-provider-identity+ 'fhir-json
           (agentic-ai-lab-standard-digest candidate)
           (materialized-au-core-patient-constraints)))
         (conformance
          (healthcare-standard-validate
           FHIRValidationExecutor FHIRAUCorePatientStandardProfile
           closure candidate)))
    (values closure conformance)))

(def healthcare-hl7v2-parser-receipt-test
  (test-suite "Healthcare HL7v2 parser receipt qualification"
    (yuanxu-test-case "parser-owned projection exactly binds the Lambda migration Case"
      (let* ((source (call-with-input-file fixture-path read-all-as-string))
             (artifact (parse-hl7v2 source))
             (projection (hl7v2-adt-a08-patient-projection artifact)))
        (check (parse-artifact-success? artifact) => #t)
        (check (parse-artifact-valid? artifact) => #t)
        (check (parse-artifact-roundtrip artifact) => source)
        (check projection => AULegacyHL7v2PatientParserProjection)
        (check (parse-artifact-ref artifact 'sourceDigest)
               => (.ref AULegacyHL7v2PatientMigrationCase
                        'source-snapshot-digest))
        (check (parse-artifact-ref artifact 'grammarDigest)
               => (.ref AULegacyHL7v2PatientSubject 'parser-grammar-digest))
        (check (agentic-ai-lab-standard-digest projection)
               => (.ref AULegacyHL7v2PatientMigrationCase
                        'parser-receipt-digest))
        (check
         (agentic-ai-lab-standard-digest
          (list 'gerbil-parser-hl7v2-qualification
                (parse-artifact-ref artifact 'sourceDigest)
                (parse-artifact-ref artifact 'grammarDigest)
                (agentic-ai-lab-standard-digest projection)))
         => (.ref AULegacyHL7v2PatientMigrationCase
                  'source-qualification-digest))
        (check (.ref AULegacyHL7v2PatientMigrationCase
                     'source-qualification-state)
               => 'qualified)
        (let* ((subject
                (healthcare-hl7v2-patient-projection->subject projection))
               (candidate
                (healthcare-au-legacy-patient->fhir-candidate subject))
               (analysis (.ref AULegacyHL7v2PatientMigrationCase
                               'ai-analysis))
               (ontology-receipt
                (ontology-compose-case AULegacyInterfaceFHIRMigrationCase)))
          (check
           (map (lambda (slot) (.ref subject slot))
                '(source-interface source-message-type source-version
                  source-snapshot-digest parser-grammar-digest
                  identifier-system identifier-value family-name given-names))
           =>
           (map (lambda (slot) (.ref AULegacyHL7v2PatientSubject slot))
                '(source-interface source-message-type source-version
                  source-snapshot-digest parser-grammar-digest
                  identifier-system identifier-value family-name given-names)))
          (check candidate => AULegacyHL7v2PatientFHIRCandidate)
          (check (.ref analysis 'source-snapshot-digest)
                 => (parse-artifact-ref artifact 'sourceDigest))
          (check (.ref analysis 'ai-role) => 'advisory-only)
          (check (.ref analysis 'unmapped-required-fields) => '())
          (check (.ref ontology-receipt 'accepted?) => #t)
          (call-with-values
           (lambda () (validate-au-core-patient candidate))
           (lambda (closure conformance)
             (let (migration-receipt
                   (healthcare-standard-migration-admit
                    AULegacyHL7v2PatientMigrationCase closure conformance
                    HealthcareStandardMigrationGovernanceInterface))
               (check (.ref conformance 'valid?) => #t)
               (check (.ref migration-receipt 'valid?) => #t)
               (check (.ref migration-receipt 'ai-analysis-digest)
                      => (.ref analysis 'analysis-digest))
               (check (.ref migration-receipt 'workflow-stages)
                      => +healthcare-standard-migration-ai-workflow-stages+)))))))))
