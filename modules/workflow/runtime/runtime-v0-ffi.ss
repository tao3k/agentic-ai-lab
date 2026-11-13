;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Versioned C projection of Agentic AI Lab-owned Runtime v0 contract semantics.
;;; The ABI never exposes a Gerbil object: every returned payload is a copied,
;;; caller-released byte buffer owned by agentic_ai_lab_scheme_result_v1.
(import (only-in :std/ffi C-declare C-ffi-macrology def-C-type def-C-lambda)
        (only-in :std/encoding/json
                 JSONReadOptions
                 current-json-read-options
                 json->string
                 string->json)
        (only-in :clan/poo/object .ref)
        (only-in :std/hash/misc hash-key?)
        (only-in :gerbil/core call-with-output-string display-exception)
        (only-in ../contracts/runtime-v0-abi-schema
                 +agentic-ai-lab-runtime-v0-abi-schema+)
        (only-in ../contracts/protocol-person-runtime-abi
                 agentic-ai-lab-runtime-language-source-query-receipt
                 agentic-ai-lab-runtime-language-source-query-receipt-failures
                 agentic-ai-lab-runtime-language-admission-receipt
                 agentic-ai-lab-runtime-language-admission-receipt-failures
                 agentic-ai-lab-contract-artifact-projection-receipt
                 agentic-ai-lab-contract-artifact-projection-receipt-failures)
        (only-in :tao3k/agentic-ai-lab/modules/query/objects
                 agentic-ai-lab-query-execution-candidate)
        (only-in :tao3k/agentic-ai-lab/modules/query/types
                 agentic-ai-lab-query-execution-candidate?))

(export contract-abi-version
        contract-descriptor-payload
        runtime-query-execution-candidate->json
        runtime-query-execution-candidate<-json
        contract-validate-payload
        runtime-error-payload
        runtime-c-round-trip)

(def +contract-abi-version+ 1)
(def +runtime-descriptor-schema+ "agentic-ai-lab.scheme-contract-descriptor.v1")
(def +runtime-validation-schema+ "agentic-ai-lab.scheme-contract-validation.v1")
(def +runtime-error-schema+ "agentic-ai-lab.scheme-contract-error.v1")
(def +runtime-max-input-bytes+ (* 16 1024 1024))

(def (contract-abi-version) +contract-abi-version+)

(def (capability->json capability)
  (hash (name (.ref capability 'name))
        (bit (.ref capability 'bit))))

(def (contract-descriptor-payload)
  (let (schema +agentic-ai-lab-runtime-v0-abi-schema+)
    (json->string
     (hash (schema +runtime-descriptor-schema+)
           (runtimeAbiVersion +contract-abi-version+)
           (runtimeAbiMajor (.ref schema 'abi-major))
           (runtimeAbiMinor (.ref schema 'abi-minor))
           (bundleSchema (.ref schema 'bundle-schema))
           (maximumInputBytes +runtime-max-input-bytes+)
           (contracts
            [(.ref schema 'source-query-receipt-schema)
             (.ref schema 'query-execution-candidate-schema)
             (.ref schema 'runtime-admission-receipt-schema)
             (.ref schema 'contract-artifact-projection-receipt-schema)])
           (capabilities
            (list->vector
             (map capability->json (.ref schema 'capabilities))))))))

(def (runtime-error-payload exception)
  (json->string
   (hash (schema +runtime-error-schema+)
         (message
          (call-with-output-string
           (lambda (port) (display-exception exception port)))))))

(def (json-required object field)
  (if (hash-key? object field)
    (hash-get object field)
    (error "missing runtime contract field" field)))

(def (json-symbol object field)
  (string->symbol (json-required object field)))

(def (json-list object field)
  (let (value (json-required object field))
    (cond
     ((list? value) value)
     ((vector? value) (vector->list value))
     (else (error "runtime contract field must be an array" field)))))

(def (json-symbol-list object field)
  (map string->symbol (json-list object field)))

(def (runtime-identity->json value)
  (cond
   ((symbol? value) (symbol->string value))
   ((string? value) value)
   (else (error "runtime contract identity must be a symbol or string" value))))

(def (source-query-receipt<-json object)
  (agentic-ai-lab-runtime-language-source-query-receipt
   (json-required object "source-language")
   (json-required object "source-content-id")
   (json-required object "source-version")
   (json-required object "parser-id")
   (json-required object "parser-version")
   (json-required object "query-id")
   (json-required object "query-version")
   (json-list object "selected-node-identities")
   (json-symbol object "representation")
   (json-required object "provenance-root")
   (json-required object "result-digest")))

;;; This transport projection deliberately constructs the canonical Query
;;; object.  Runtime v0 owns the byte boundary; Query owns the semantic shape.
(def (runtime-query-execution-candidate->json candidate)
  (unless (agentic-ai-lab-query-execution-candidate? candidate)
    (error "invalid canonical query execution candidate" candidate))
  (json->string
   (hash (provider-identity
          (runtime-identity->json (.ref candidate 'provider-identity)))
         (query-identity
          (runtime-identity->json (.ref candidate 'query-identity)))
         (query-version (.ref candidate 'query-version))
         (semantic-revision (.ref candidate 'semantic-revision))
         (source-content-identity
          (.ref candidate 'source-content-identity))
         (parser-identity
          (runtime-identity->json (.ref candidate 'parser-identity)))
         (provenance-root (.ref candidate 'provenance-root))
         (result-digest (.ref candidate 'result-digest))
         (result-count (.ref candidate 'result-count))
         (complete (.ref candidate 'complete?)))))

(def (runtime-query-execution-candidate<-json object)
  (agentic-ai-lab-query-execution-candidate
   (json-symbol object "provider-identity")
   (json-symbol object "query-identity")
   (json-required object "query-version")
   (json-required object "semantic-revision")
   (json-required object "source-content-identity")
   (json-symbol object "parser-identity")
   (json-required object "provenance-root")
   (json-required object "result-digest")
   (json-required object "result-count")
   (json-required object "complete")))

(def (admission-receipt<-json object)
  (agentic-ai-lab-runtime-language-admission-receipt
   (source-query-receipt<-json
    (json-required object "source-query-receipt"))
   (json-required object "contract-id")
   (json-required object "contract-version")
   (json-required object "adapter-id")
   (json-required object "adapter-version")
   (json-required object "target-language")
   (hash-get object "normalized-semantic-digest")
   (json-symbol object "admission-outcome")
   (json-symbol-list object "failure-codes")))

(def (artifact-projection-receipt<-json object)
  (agentic-ai-lab-contract-artifact-projection-receipt
   (json-required object "projection-id")
   (json-required object "contract-id")
   (json-required object "contract-version")
   (json-required object "source-contract-digest")
   (json-required object "projector-id")
   (json-required object "projector-version")
   (json-symbol object "artifact-kind")
   (json-required object "artifact-id")
   (json-required object "output-digest")))

(def (validation-result contract failures)
  (json->string
   (hash (schema +runtime-validation-schema+)
         (contract contract)
         (valid (null? failures))
         (failures (list->vector (map symbol->string failures))))))

(def (contract-validate-payload contract payload)
  (when (> (string-length payload) +runtime-max-input-bytes+)
    (error "runtime contract payload exceeds maximum input bytes"
           (string-length payload) +runtime-max-input-bytes+))
  (let (object
        (parameterize ((current-json-read-options
                        (JSONReadOptions object-as-hash: #t)))
          (string->json payload)))
    (cond
     ((string=? contract "source-query-receipt")
      (validation-result
       contract
       (agentic-ai-lab-runtime-language-source-query-receipt-failures
        (source-query-receipt<-json object))))
     ((string=? contract "query-execution-candidate")
      (let (candidate (runtime-query-execution-candidate<-json object))
        (unless (agentic-ai-lab-query-execution-candidate? candidate)
          (error "invalid canonical query execution candidate" candidate))
        (validation-result contract '())))
     ((string=? contract "language-admission-receipt")
      (validation-result
       contract
       (agentic-ai-lab-runtime-language-admission-receipt-failures
        (admission-receipt<-json object))))
     ((string=? contract "artifact-projection-receipt")
      (validation-result
       contract
       (agentic-ai-lab-contract-artifact-projection-receipt-failures
        (artifact-projection-receipt<-json object))))
     (else (error "unsupported runtime contract" contract)))))

(C-ffi-macrology)

(C-declare #<<END-C
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  int32_t status;
  uint8_t *payload;
  size_t length;
} agentic_ai_lab_scheme_result_v1;

void agentic_ai_lab_scheme_result_v1_init(agentic_ai_lab_scheme_result_v1 *result) {
  if (result == NULL) return;
  result->status = 0;
  result->payload = NULL;
  result->length = 0;
}

void agentic_ai_lab_scheme_result_v1_release(agentic_ai_lab_scheme_result_v1 *result) {
  if (result == NULL) return;
  free(result->payload);
  result->status = 0;
  result->payload = NULL;
  result->length = 0;
}

uint32_t agentic_ai_lab_scheme_contract_abi_version(void);
int32_t agentic_ai_lab_scheme_contract_descriptor(agentic_ai_lab_scheme_result_v1 *result);
int32_t agentic_ai_lab_scheme_contract_validate(char *contract,
                                        char *payload,
                                        agentic_ai_lab_scheme_result_v1 *result);

static int agentic_ai_lab_runtime_c_round_trip(void) {
  static const char source_query[] =
    "{\"source-language\":\"scheme\",\"source-content-id\":\"sha256:source\","
    "\"source-version\":\"1\",\"parser-id\":\"gerbil-parser\","
    "\"parser-version\":\"1\",\"query-id\":\"q1\",\"query-version\":\"1\","
    "\"selected-node-identities\":[\"node-1\"],\"representation\":\"ast-data\","
    "\"provenance-root\":\"sha256:provenance\",\"result-digest\":\"sha256:result\"}";
  static const char query_execution_candidate[] =
    "{\"provider-identity\":\"mrr\",\"query-identity\":\"q1\","
    "\"query-version\":\"1\",\"semantic-revision\":\"revision-1\","
    "\"source-content-identity\":\"sha256:source\","
    "\"parser-identity\":\"gerbil-parser\","
    "\"provenance-root\":\"sha256:provenance\","
    "\"result-digest\":\"sha256:result\",\"result-count\":1,"
    "\"complete\":true}";
  agentic_ai_lab_scheme_result_v1 result;

  if (agentic_ai_lab_scheme_contract_abi_version() != 1u) return 1;
  agentic_ai_lab_scheme_result_v1_init(&result);
  if (agentic_ai_lab_scheme_contract_descriptor(&result) != 0 || result.status != 0 ||
      result.payload == NULL || result.length == 0 ||
      strstr((const char *)result.payload,
             "agentic-ai-lab.scheme-contract-descriptor.v1") == NULL)
    return 2;
  agentic_ai_lab_scheme_result_v1_release(&result);
  if (result.payload != NULL || result.length != 0 || result.status != 0)
    return 3;

  if (agentic_ai_lab_scheme_contract_validate("source-query-receipt", (char *)source_query,
                                      &result) != 0 ||
      result.status != 0 || result.payload == NULL ||
      strstr((const char *)result.payload, "\"valid\":true") == NULL) {
    agentic_ai_lab_scheme_result_v1_release(&result);
    return 4;
  }
  agentic_ai_lab_scheme_result_v1_release(&result);
  if (agentic_ai_lab_scheme_contract_validate("query-execution-candidate",
                                      (char *)query_execution_candidate,
                                      &result) != 0 ||
      result.status != 0 || result.payload == NULL ||
      strstr((const char *)result.payload, "\"valid\":true") == NULL) {
    agentic_ai_lab_scheme_result_v1_release(&result);
    return 5;
  }
  agentic_ai_lab_scheme_result_v1_release(&result);
  if (agentic_ai_lab_scheme_contract_validate("unknown", "{}", &result) != -1 ||
      result.status != -1 || result.payload == NULL ||
      strstr((const char *)result.payload,
             "agentic-ai-lab.scheme-contract-error.v1") == NULL) {
    agentic_ai_lab_scheme_result_v1_release(&result);
    return 6;
  }
  agentic_ai_lab_scheme_result_v1_release(&result);
  return 0;
}
END-C
  )

(def-C-type agentic_ai_lab_scheme_result_v1 "agentic_ai_lab_scheme_result_v1")
(def-C-type agentic_ai_lab_scheme_result_v1-borrowed-ptr*
  (pointer agentic_ai_lab_scheme_result_v1
           (agentic_ai_lab_scheme_result_v1-borrowed-ptr*)))

(def-C-lambda agentic_ai_lab_scheme_result_v1-status
  (agentic_ai_lab_scheme_result_v1-borrowed-ptr*) int32
  "___return (___arg1->status);")
(def-C-lambda agentic_ai_lab_scheme_result_v1-status-set!
  (agentic_ai_lab_scheme_result_v1-borrowed-ptr* int32) void
  "___arg1->status = ___arg2; ___return;")

(def-C-lambda agentic-ai-lab-scheme-result-v1-set-bytes!
    (agentic_ai_lab_scheme_result_v1-borrowed-ptr* scheme-object) void
    #<<END-C
free(___arg1->payload);
___arg1->payload = NULL;
___arg1->length = U8_LEN(___arg2);
if (___arg1->length > 0) {
  ___arg1->payload = (uint8_t *)malloc(___arg1->length + 1u);
  if (___arg1->payload == NULL) {
    ___arg1->length = 0;
    ___arg1->status = -1;
    ___return;
  }
  memcpy(___arg1->payload, U8_DATA(___arg2), ___arg1->length);
  ___arg1->payload[___arg1->length] = 0;
}
___return;
END-C
    )

(def-C-lambda runtime-c-round-trip () int
    "agentic_ai_lab_runtime_c_round_trip")

(begin-foreign
  (c-define (agentic-ai-lab-scheme-contract-abi-version)
    () unsigned-int32 "agentic_ai_lab_scheme_contract_abi_version" "extern"
    (tao3k/agentic-ai-lab/modules/workflow/runtime/runtime-v0-ffi#contract-abi-version))

  (c-define (agentic-ai-lab-scheme-contract-descriptor result)
    (agentic_ai_lab_scheme_result_v1-borrowed-ptr*) int32
    "agentic_ai_lab_scheme_contract_descriptor" "extern"
    (with-exception-catcher
     (lambda (exception)
       (tao3k/agentic-ai-lab/modules/workflow/runtime/runtime-v0-ffi#agentic_ai_lab_scheme_result_v1-status-set! result -1)
       (tao3k/agentic-ai-lab/modules/workflow/runtime/runtime-v0-ffi#agentic-ai-lab-scheme-result-v1-set-bytes!
        result (string->utf8
                (tao3k/agentic-ai-lab/modules/workflow/runtime/runtime-v0-ffi#runtime-error-payload
                 exception)))
       -1)
     (lambda ()
       (tao3k/agentic-ai-lab/modules/workflow/runtime/runtime-v0-ffi#agentic_ai_lab_scheme_result_v1-status-set! result 0)
       (tao3k/agentic-ai-lab/modules/workflow/runtime/runtime-v0-ffi#agentic-ai-lab-scheme-result-v1-set-bytes!
        result (string->utf8
                (tao3k/agentic-ai-lab/modules/workflow/runtime/runtime-v0-ffi#contract-descriptor-payload)))
       (tao3k/agentic-ai-lab/modules/workflow/runtime/runtime-v0-ffi#agentic_ai_lab_scheme_result_v1-status result))))

  (c-define (agentic-ai-lab-scheme-contract-validate contract payload result)
    (UTF-8-string UTF-8-string agentic_ai_lab_scheme_result_v1-borrowed-ptr*) int32
    "agentic_ai_lab_scheme_contract_validate" "extern"
    (with-exception-catcher
     (lambda (exception)
       (tao3k/agentic-ai-lab/modules/workflow/runtime/runtime-v0-ffi#agentic_ai_lab_scheme_result_v1-status-set! result -1)
       (tao3k/agentic-ai-lab/modules/workflow/runtime/runtime-v0-ffi#agentic-ai-lab-scheme-result-v1-set-bytes!
        result (string->utf8
                (tao3k/agentic-ai-lab/modules/workflow/runtime/runtime-v0-ffi#runtime-error-payload
                 exception)))
       -1)
     (lambda ()
       (tao3k/agentic-ai-lab/modules/workflow/runtime/runtime-v0-ffi#agentic_ai_lab_scheme_result_v1-status-set! result 0)
       (tao3k/agentic-ai-lab/modules/workflow/runtime/runtime-v0-ffi#agentic-ai-lab-scheme-result-v1-set-bytes!
        result
        (string->utf8
         (tao3k/agentic-ai-lab/modules/workflow/runtime/runtime-v0-ffi#contract-validate-payload
          contract payload)))
       (tao3k/agentic-ai-lab/modules/workflow/runtime/runtime-v0-ffi#agentic_ai_lab_scheme_result_v1-status result)))))
