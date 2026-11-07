;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; External qualification only: replay the pinned HL7 FHIR Validator and
;;; compare the decoded JSON evidence.  Normal Lambda tests remain inert.
(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        (only-in :gerbil/runtime/gambit getenv)
        (only-in :std/crypto/digest sha256)
        (only-in :std/misc/ports read-all-as-u8vector)
        (only-in :std/misc/process run-process)
        (only-in :std/encoding/hex hex-encode)
        (only-in :std/encoding/json JSONReadOptions string->json))

(export healthcare-fhir-reference-validator-replay-test)

(def expected-validator-digest
  "0e53ab1d1a6f1e35f505255c0b8ce10a35fcf27e6e96b503640f784cd07e5ad6")

(def fixture-root
  "packages/lambda-episteme/t/healthcare/standards/fixtures")

(def expected-output-path
  (string-append
   fixture-root
   "/au-core-patient-validator-6.9.12-operation-outcomes.json"))

(def (file-sha256 path)
  (hex-encode
   (sha256 (call-with-input-file path read-all-as-u8vector))))

(def (read-json path)
  (string->json (read-file-string path)
                (JSONReadOptions object-as-hash: #t)))

(def (canonical-json value)
  (cond
   ((hash-table? value)
    (map (lambda (entry)
           (cons (car entry) (canonical-json (cdr entry))))
         (list-sort
          (lambda (left right) (string<? (car left) (car right)))
          (hash->list value))))
   ((list? value) (map canonical-json value))
   (else value)))

(def (stream-process-output port)
  (let loop ((line (read-line port)))
    (unless (eof-object? line)
      (displayln line)
      (force-output)
      (loop (read-line port)))))

(def (qualification-output-path)
  (path-expand
   (string-append "agentic-ai-lab-fhir-validator-6.9.12-"
                  (number->string (current-jiffy)) ".json")
   (getenv "TMPDIR" "/tmp")))

(def healthcare-fhir-reference-validator-replay-test
  (test-suite "Healthcare FHIR reference validator replay"
    (yuanxu-test-case "pinned Validator reproduces the retained OperationOutcome Bundle"
      (let* ((jar (getenv "FHIR_VALIDATOR_JAR" #f))
             (output-path (qualification-output-path))
             (exit-status 0))
        (check (and jar (file-exists? jar)) => #t)
        (check (file-sha256 jar) => expected-validator-digest)
        (displayln "[fhir-validator-qualification] phase=replay-start version=6.9.12")
        (force-output)
        (run-process
         (list
          "java" "-jar" jar
          (string-append fixture-root "/au-core-patient-valid.json")
          (string-append fixture-root "/au-core-patient-data-absent.json")
          (string-append fixture-root "/au-core-patient-invalid.json")
          (string-append fixture-root "/au-core-patient-xor-conflict.json")
          "-version" "4.0.1"
          "-ig" "hl7.fhir.au.core#1.0.0"
          "-profile"
          "http://hl7.org.au/fhir/core/StructureDefinition/au-core-patient"
          "-tx" "n/a"
          "-output" output-path)
         stderr-redirection: #t
         coprocess: stream-process-output
         check-status:
         (lambda (status _)
           (set! exit-status status)))
        (displayln "[fhir-validator-qualification] phase=replay-complete exit-status="
                   exit-status)
        (force-output)
        (check exit-status => 0)
        ;; The validator may serialize object members in a different order.
        ;; Decoded JSON equality retains every OperationOutcome field while
        ;; avoiding a false byte-order requirement.
        (check
         (equal? (canonical-json (read-json output-path))
                 (canonical-json (read-json expected-output-path)))
         => #t)))))
