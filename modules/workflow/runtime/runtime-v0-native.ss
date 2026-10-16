;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Versioned C projection of POO Flow-owned Runtime v0 contract semantics.
;;; The ABI never exposes a Gerbil object: every returned payload is a copied,
;;; caller-released byte buffer owned by poo_flow_scheme_result_v1.
(import (only-in :std/ffi C-declare C-ffi-macrology def-C-type def-C-lambda)
        (only-in :std/encoding/json
                 JSONReadOptions
                 current-json-read-options
                 json->string
                 string->json)
        (only-in :clan/poo/object .ref)
        (only-in :std/hash/misc hash-key?)
        (only-in :gerbil/core call-with-output-string display-exception)
        (only-in ../contract/runtime-v0-abi-schema
                 +poo-flow-runtime-v0-abi-schema+)
        (only-in ../contract/protocol-person-runtime-abi
                 poo-flow-runtime-language-source-query-receipt
                 poo-flow-runtime-language-source-query-receipt-failures
                 poo-flow-runtime-language-admission-receipt
                 poo-flow-runtime-language-admission-receipt-failures
                 poo-flow-contract-artifact-projection-receipt
                 poo-flow-contract-artifact-projection-receipt-failures)
        (only-in :poo-flow/modules/query/objects
                 poo-flow-query-execution-candidate)
        (only-in :poo-flow/modules/query/types
                 poo-flow-query-execution-candidate?))

(export native-abi-version
        native-descriptor-payload
        native-query-execution-candidate->json
        native-query-execution-candidate<-json
        native-validate-payload
        native-error-payload
        native-c-round-trip)

(def +native-abi-version+ 1)
(def +native-descriptor-schema+ "poo-flow.scheme-native-descriptor.v1")
(def +native-validation-schema+ "poo-flow.scheme-native-validation.v1")
(def +native-error-schema+ "poo-flow.scheme-native-error.v1")
(def +native-max-input-bytes+ (* 16 1024 1024))

(def (native-abi-version) +native-abi-version+)

(def (capability->json capability)
  (hash (name (.ref capability 'name))
        (bit (.ref capability 'bit))))

(def (native-descriptor-payload)
  (let (schema +poo-flow-runtime-v0-abi-schema+)
    (json->string
     (hash (schema +native-descriptor-schema+)
           (nativeAbiVersion +native-abi-version+)
           (runtimeAbiMajor (.ref schema 'abi-major))
           (runtimeAbiMinor (.ref schema 'abi-minor))
           (bundleSchema (.ref schema 'bundle-schema))
           (maximumInputBytes +native-max-input-bytes+)
           (contracts
            [(.ref schema 'source-query-receipt-schema)
             (.ref schema 'query-execution-candidate-schema)
             (.ref schema 'runtime-admission-receipt-schema)
             (.ref schema 'contract-artifact-projection-receipt-schema)])
           (capabilities
            (list->vector
             (map capability->json (.ref schema 'capabilities))))))))

(def (native-error-payload exception)
  (json->string
   (hash (schema +native-error-schema+)
         (message
          (call-with-output-string
           (lambda (port) (display-exception exception port)))))))

(def (json-required object field)
  (if (hash-key? object field)
    (hash-get object field)
    (error "missing native contract field" field)))

(def (json-symbol object field)
  (string->symbol (json-required object field)))

(def (json-list object field)
  (let (value (json-required object field))
    (cond
     ((list? value) value)
     ((vector? value) (vector->list value))
     (else (error "native contract field must be an array" field)))))

(def (json-symbol-list object field)
  (map string->symbol (json-list object field)))

(def (native-identity->json value)
  (cond
   ((symbol? value) (symbol->string value))
   ((string? value) value)
   (else (error "native contract identity must be a symbol or string" value))))

(def (source-query-receipt<-json object)
  (poo-flow-runtime-language-source-query-receipt
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
(def (native-query-execution-candidate->json candidate)
  (unless (poo-flow-query-execution-candidate? candidate)
    (error "invalid canonical query execution candidate" candidate))
  (json->string
   (hash (provider-identity
          (native-identity->json (.ref candidate 'provider-identity)))
         (query-identity
          (native-identity->json (.ref candidate 'query-identity)))
         (query-version (.ref candidate 'query-version))
         (semantic-revision (.ref candidate 'semantic-revision))
         (source-content-identity
          (.ref candidate 'source-content-identity))
         (parser-identity
          (native-identity->json (.ref candidate 'parser-identity)))
         (provenance-root (.ref candidate 'provenance-root))
         (result-digest (.ref candidate 'result-digest))
         (result-count (.ref candidate 'result-count))
         (complete (.ref candidate 'complete?)))))

(def (native-query-execution-candidate<-json object)
  (poo-flow-query-execution-candidate
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
  (poo-flow-runtime-language-admission-receipt
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
  (poo-flow-contract-artifact-projection-receipt
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
   (hash (schema +native-validation-schema+)
         (contract contract)
         (valid (null? failures))
         (failures (list->vector (map symbol->string failures))))))

(def (native-validate-payload contract payload)
  (when (> (string-length payload) +native-max-input-bytes+)
    (error "native contract payload exceeds maximum input bytes"
           (string-length payload) +native-max-input-bytes+))
  (let (object
        (parameterize ((current-json-read-options
                        (JSONReadOptions object-as-hash: #t)))
          (string->json payload)))
    (cond
     ((string=? contract "source-query-receipt")
      (validation-result
       contract
       (poo-flow-runtime-language-source-query-receipt-failures
        (source-query-receipt<-json object))))
     ((string=? contract "query-execution-candidate")
      (let (candidate (native-query-execution-candidate<-json object))
        (unless (poo-flow-query-execution-candidate? candidate)
          (error "invalid canonical query execution candidate" candidate))
        (validation-result contract '())))
     ((string=? contract "language-admission-receipt")
      (validation-result
       contract
       (poo-flow-runtime-language-admission-receipt-failures
        (admission-receipt<-json object))))
     ((string=? contract "artifact-projection-receipt")
      (validation-result
       contract
       (poo-flow-contract-artifact-projection-receipt-failures
        (artifact-projection-receipt<-json object))))
     (else (error "unsupported native contract" contract)))))

(C-ffi-macrology)

(C-declare #<<END-C
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  int32_t status;
  uint8_t *payload;
  size_t length;
} poo_flow_scheme_result_v1;

void poo_flow_scheme_result_v1_init(poo_flow_scheme_result_v1 *result) {
  if (result == NULL) return;
  result->status = 0;
  result->payload = NULL;
  result->length = 0;
}

void poo_flow_scheme_result_v1_release(poo_flow_scheme_result_v1 *result) {
  if (result == NULL) return;
  free(result->payload);
  result->status = 0;
  result->payload = NULL;
  result->length = 0;
}

uint32_t poo_flow_scheme_native_abi_version(void);
int32_t poo_flow_scheme_native_descriptor(poo_flow_scheme_result_v1 *result);
int32_t poo_flow_scheme_native_validate(char *contract,
                                        char *payload,
                                        poo_flow_scheme_result_v1 *result);

static int poo_flow_native_c_round_trip(void) {
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
  poo_flow_scheme_result_v1 result;

  if (poo_flow_scheme_native_abi_version() != 1u) return 1;
  poo_flow_scheme_result_v1_init(&result);
  if (poo_flow_scheme_native_descriptor(&result) != 0 || result.status != 0 ||
      result.payload == NULL || result.length == 0 ||
      strstr((const char *)result.payload,
             "poo-flow.scheme-native-descriptor.v1") == NULL)
    return 2;
  poo_flow_scheme_result_v1_release(&result);
  if (result.payload != NULL || result.length != 0 || result.status != 0)
    return 3;

  if (poo_flow_scheme_native_validate("source-query-receipt", (char *)source_query,
                                      &result) != 0 ||
      result.status != 0 || result.payload == NULL ||
      strstr((const char *)result.payload, "\"valid\":true") == NULL) {
    poo_flow_scheme_result_v1_release(&result);
    return 4;
  }
  poo_flow_scheme_result_v1_release(&result);
  if (poo_flow_scheme_native_validate("query-execution-candidate",
                                      (char *)query_execution_candidate,
                                      &result) != 0 ||
      result.status != 0 || result.payload == NULL ||
      strstr((const char *)result.payload, "\"valid\":true") == NULL) {
    poo_flow_scheme_result_v1_release(&result);
    return 5;
  }
  poo_flow_scheme_result_v1_release(&result);
  if (poo_flow_scheme_native_validate("unknown", "{}", &result) != -1 ||
      result.status != -1 || result.payload == NULL ||
      strstr((const char *)result.payload,
             "poo-flow.scheme-native-error.v1") == NULL) {
    poo_flow_scheme_result_v1_release(&result);
    return 6;
  }
  poo_flow_scheme_result_v1_release(&result);
  return 0;
}
END-C
  )

(def-C-type poo_flow_scheme_result_v1 "poo_flow_scheme_result_v1")
(def-C-type poo_flow_scheme_result_v1-borrowed-ptr*
  (pointer poo_flow_scheme_result_v1
           (poo_flow_scheme_result_v1-borrowed-ptr*)))

(def-C-lambda poo_flow_scheme_result_v1-status
  (poo_flow_scheme_result_v1-borrowed-ptr*) int32
  "___return (___arg1->status);")
(def-C-lambda poo_flow_scheme_result_v1-status-set!
  (poo_flow_scheme_result_v1-borrowed-ptr* int32) void
  "___arg1->status = ___arg2; ___return;")

(def-C-lambda poo-flow-scheme-result-v1-set-bytes!
    (poo_flow_scheme_result_v1-borrowed-ptr* scheme-object) void
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

(def-C-lambda native-c-round-trip () int
    "poo_flow_native_c_round_trip")

(begin-foreign
  (c-define (poo-flow-scheme-native-abi-version)
    () unsigned-int32 "poo_flow_scheme_native_abi_version" "extern"
    (poo-flow/src/ffi/runtime-v0-native#native-abi-version))

  (c-define (poo-flow-scheme-native-descriptor result)
    (poo_flow_scheme_result_v1-borrowed-ptr*) int32
    "poo_flow_scheme_native_descriptor" "extern"
    (with-exception-catcher
     (lambda (exception)
       (poo-flow/src/ffi/runtime-v0-native#poo_flow_scheme_result_v1-status-set! result -1)
       (poo-flow/src/ffi/runtime-v0-native#poo-flow-scheme-result-v1-set-bytes!
        result (string->utf8
                (poo-flow/src/ffi/runtime-v0-native#native-error-payload
                 exception)))
       -1)
     (lambda ()
       (poo-flow/src/ffi/runtime-v0-native#poo_flow_scheme_result_v1-status-set! result 0)
       (poo-flow/src/ffi/runtime-v0-native#poo-flow-scheme-result-v1-set-bytes!
        result (string->utf8
                (poo-flow/src/ffi/runtime-v0-native#native-descriptor-payload)))
       (poo-flow/src/ffi/runtime-v0-native#poo_flow_scheme_result_v1-status result))))

  (c-define (poo-flow-scheme-native-validate contract payload result)
    (UTF-8-string UTF-8-string poo_flow_scheme_result_v1-borrowed-ptr*) int32
    "poo_flow_scheme_native_validate" "extern"
    (with-exception-catcher
     (lambda (exception)
       (poo-flow/src/ffi/runtime-v0-native#poo_flow_scheme_result_v1-status-set! result -1)
       (poo-flow/src/ffi/runtime-v0-native#poo-flow-scheme-result-v1-set-bytes!
        result (string->utf8
                (poo-flow/src/ffi/runtime-v0-native#native-error-payload
                 exception)))
       -1)
     (lambda ()
       (poo-flow/src/ffi/runtime-v0-native#poo_flow_scheme_result_v1-status-set! result 0)
       (poo-flow/src/ffi/runtime-v0-native#poo-flow-scheme-result-v1-set-bytes!
        result
        (string->utf8
         (poo-flow/src/ffi/runtime-v0-native#native-validate-payload
          contract payload)))
       (poo-flow/src/ffi/runtime-v0-native#poo_flow_scheme_result_v1-status result)))))
