;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        (only-in :std/misc/ports read-all-as-string)
        (only-in :std/string/path path-expand)
        (only-in :clan/poo/object .ref)
        (only-in :agentic-ai-lab/lambda-episteme/modules/healthcare/standards/fhir/config
                 FHIRValidationCapabilities)
        (only-in :agentic-ai-lab/lambda-episteme/modules/healthcare/standards/fhir/source
                 agentic-ai-lab-fhir-json-constraints
                 agentic-ai-lab-fhir-json-ref
                 agentic-ai-lab-fhir-load-fixed-source
                 agentic-ai-lab-fhir-parse-json-structure-definition)
        (only-in :agentic-ai-lab/lambda-episteme/modules/healthcare/standards/fhir/sources
                 +agentic-ai-lab-fhir-au-core-patient-source-identity+)
        (only-in :gerbil-parser/languages/fhirpath/v2.0.0/parser
                 +fhirpath-antlr4-digest+
                 +fhirpath-standard-version+
                 parse-fhirpath-v2)
        (only-in :gerbil-parser/src/runtime/artifact
                 parse-artifact-ref parse-artifact-roundtrip
                 parse-artifact-success? parse-artifact-valid?))

(export healthcare-fhirpath-parser-receipt-test)

(def fixture-root
  (path-expand
   "languages/fhirpath/v2.0.0/corpus/au-core-patient"
   (getenv "GERBIL_PARSER_DIR" "../gerbil-parser")))

(def fixture-paths
  (map (lambda (name) (string-append fixture-root "/" name))
       '("au-core-pat-01.fhirpath"
         "au-core-pat-02.fhirpath"
         "au-core-pat-03.fhirpath")))

(def (without-trailing-newline value)
  (let (length (string-length value))
    (if (and (> length 0)
             (char=? (string-ref value (- length 1)) #\newline))
      (substring value 0 (- length 1))
      value)))

(def healthcare-fhirpath-parser-receipt-test
  (test-suite "Healthcare FHIRPath syntax receipt qualification"
    (yuanxu-test-case "parser-owned syntax receipts bind the Lambda capability"
      (let* ((capability (.ref FHIRValidationCapabilities 'fhirpath-syntax))
             (evidence (.ref capability 'evidence-digests)))
        (check (.ref capability 'state) => 'syntax-qualified)
        (check (.ref capability 'owner) => "gerbil-parser")
        (check +fhirpath-standard-version+ => "2.0.0")
        (check (car evidence) => +fhirpath-antlr4-digest+)
        (for-each
         (lambda (path)
           (let* ((source (call-with-input-file path read-all-as-string))
                  (artifact (parse-fhirpath-v2 source)))
             (check (parse-artifact-success? artifact) => #t)
             (check (parse-artifact-valid? artifact) => #t)
             (check (parse-artifact-roundtrip artifact) => source)
             (check (parse-artifact-ref artifact 'grammarDigest)
                    => (cadr evidence))))
         fixture-paths)))
    (yuanxu-test-case "syntax fixtures are exact expressions from the locked AU source"
      (let-values (((_entry _receipt bytes)
                    (agentic-ai-lab-fhir-load-fixed-source
                     +agentic-ai-lab-fhir-au-core-patient-source-identity+)))
        (let* ((decoded (agentic-ai-lab-fhir-parse-json-structure-definition bytes))
               (official
                (filter-map
                 (lambda (constraint)
                   (and (member (agentic-ai-lab-fhir-json-ref constraint "key")
                                '("au-core-pat-01"
                                  "au-core-pat-02"
                                  "au-core-pat-03"))
                        (agentic-ai-lab-fhir-json-ref constraint "expression")))
                 (agentic-ai-lab-fhir-json-constraints decoded)))
               (retained
                (map (lambda (path)
                       (without-trailing-newline
                        (call-with-input-file path read-all-as-string)))
                     fixture-paths)))
          (check retained => official))))
    (yuanxu-test-case "syntax qualification does not widen evaluator authority"
      (check (.ref (.ref FHIRValidationCapabilities 'general-fhirpath) 'state)
             => 'not-evaluated))))
