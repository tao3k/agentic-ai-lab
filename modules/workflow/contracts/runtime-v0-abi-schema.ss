;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: declares Runtime v0 ABI capability and schema descriptors.
;;; Invariant: numeric capability bits and symbolic names remain a stable bijection.
(export #t)

(import (only-in :clan/poo/object .o .ref))

(def (runtime-v0-capability name-value bit-value)
  (.o (kind 'poo-flow.runtime-v0.abi-capability.1)
      (name name-value) (bit bit-value)))

(def +poo-flow-runtime-v0-abi-schema+
  (.o (kind 'poo-flow.runtime-v0.abi-schema.1)
      (abi-major 0)
      (abi-minor 1)
      (bundle-schema "poo-flow.organization-bundle.draft.3")
      (control-packet-schema "poo-flow.runtime-v0.control-packet.1")
      (promotion-request-schema
       "poo-flow.runtime-language.promotion-request.1")
      (promotion-receipt-schema
       "poo-flow.runtime-language.promotion-receipt.1")
      (promotion-idempotency-key-schema
       "poo-flow.runtime-language.promotion-idempotency-key.1")
      (source-query-receipt-schema
       "poo-flow.runtime-language.source-query-receipt.1")
      (query-execution-candidate-schema
       "poo-flow.query.execution-candidate.1")
      (runtime-admission-receipt-schema
       "poo-flow.runtime-language.admission-receipt.1")
      (contract-artifact-projection-receipt-schema
       "poo-flow.contract.artifact-projection-receipt.1")
      (abi-v1-frozen? #f)
      (hot-layout-version 1)
      (event-header-bytes 96)
      (compact-identity-bits 128)
      (capabilities
       (list (runtime-v0-capability "CONTROL" 0)
             (runtime-v0-capability "CHECKPOINT" 1)
             (runtime-v0-capability "HOT_BATCH" 2)
             (runtime-v0-capability "BULK_BUFFER" 3)
             (runtime-v0-capability "CALLER_ARENA" 4)
             (runtime-v0-capability "PARTIAL_ACCEPTANCE" 5)
             (runtime-v0-capability "BATCHED_EVIDENCE" 6)
             (runtime-v0-capability "PROMOTION_MATERIALIZE" 7)
             (runtime-v0-capability "INJECTION_RECEIPT" 8)
             (runtime-v0-capability "ROLLBACK" 9)
             (runtime-v0-capability "EXACTLY_ONCE" 10)
             (runtime-v0-capability "LANGUAGE_QUALIFICATION" 11)
             (runtime-v0-capability "SOURCE_QUERY_DATA" 12)
             (runtime-v0-capability "CONTRACT_ADMISSION_RECEIPT" 13)
             (runtime-v0-capability "CONTRACT_ARTIFACT_PROJECTION" 14)
             (runtime-v0-capability "QUERY_EXECUTION_CANDIDATE" 15)))))

(def (emit-line port . values)
  (for-each (lambda (value) (display value port)) values)
  (newline port))

(def (poo-flow-runtime-v0-abi-schema->c-header schema)
  (let (port (open-output-string))
    (emit-line port "// SPDX-FileCopyrightText: 2026 tao3k team and Contributors")
    (emit-line port "//")
    (emit-line port "// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later")
    (newline port)
    (emit-line port "#ifndef POO_FLOW_RUNTIME_V0_CONTRACT_H")
    (emit-line port "#define POO_FLOW_RUNTIME_V0_CONTRACT_H")
    (newline port)
    (emit-line port "#include <stdint.h>")
    (newline port)
    (emit-line port "#define POO_FLOW_RUNTIME_V0_ABI_MAJOR "
               (.ref schema 'abi-major) "u")
    (emit-line port "#define POO_FLOW_RUNTIME_V0_ABI_MINOR "
               (.ref schema 'abi-minor) "u")
    (emit-line port "#define POO_FLOW_RUNTIME_V0_BUNDLE_SCHEMA \""
               (.ref schema 'bundle-schema) "\"")
    (emit-line port "#define POO_FLOW_RUNTIME_V0_CONTROL_PACKET_SCHEMA \""
               (.ref schema 'control-packet-schema) "\"")
    (emit-line port "#define POO_FLOW_RUNTIME_LANGUAGE_PROMOTION_REQUEST_SCHEMA \""
               (.ref schema 'promotion-request-schema) "\"")
    (emit-line port "#define POO_FLOW_RUNTIME_LANGUAGE_PROMOTION_RECEIPT_SCHEMA \""
               (.ref schema 'promotion-receipt-schema) "\"")
    (emit-line port "#define POO_FLOW_RUNTIME_LANGUAGE_PROMOTION_IDEMPOTENCY_KEY_SCHEMA \""
               (.ref schema 'promotion-idempotency-key-schema) "\"")
    (emit-line port "#define POO_FLOW_RUNTIME_LANGUAGE_SOURCE_QUERY_RECEIPT_SCHEMA \""
               (.ref schema 'source-query-receipt-schema) "\"")
    (emit-line port "#define POO_FLOW_QUERY_EXECUTION_CANDIDATE_SCHEMA \""
               (.ref schema 'query-execution-candidate-schema) "\"")
    (emit-line port "#define POO_FLOW_RUNTIME_LANGUAGE_ADMISSION_RECEIPT_SCHEMA \""
               (.ref schema 'runtime-admission-receipt-schema) "\"")
    (emit-line port "#define POO_FLOW_CONTRACT_ARTIFACT_PROJECTION_RECEIPT_SCHEMA \""
               (.ref schema 'contract-artifact-projection-receipt-schema) "\"")
    (emit-line port "#define POO_FLOW_RUNTIME_V0_LAYOUT_VERSION "
               (.ref schema 'hot-layout-version) "u")
    (emit-line port "#define POO_FLOW_RUNTIME_V0_EVENT_HEADER_BYTES "
               (.ref schema 'event-header-bytes) "u")
    (emit-line port "#define POO_FLOW_RUNTIME_V0_COMPACT_IDENTITY_BITS "
               (.ref schema 'compact-identity-bits) "u")
    (for-each
     (lambda (capability)
       (emit-line port "#define POO_FLOW_RUNTIME_V0_CAP_"
                  (.ref capability 'name) " (UINT64_C(1) << "
                  (.ref capability 'bit) ")"))
     (.ref schema 'capabilities))
    (newline port)
    (emit-line port "#endif")
    (get-output-string port)))

(def (poo-flow-runtime-v0-abi-schema->vector schema)
  (let (port (open-output-string))
    (emit-line port "schema=poo-flow.runtime-v0.contract-vector.1")
    (emit-line port "abi-major=" (.ref schema 'abi-major))
    (emit-line port "abi-minor=" (.ref schema 'abi-minor))
    (emit-line port "bundle-schema=" (.ref schema 'bundle-schema))
    (emit-line port "control-packet-schema="
               (.ref schema 'control-packet-schema))
    (emit-line port "promotion-request-schema="
               (.ref schema 'promotion-request-schema))
    (emit-line port "promotion-receipt-schema="
               (.ref schema 'promotion-receipt-schema))
    (emit-line port "promotion-idempotency-key-schema="
               (.ref schema 'promotion-idempotency-key-schema))
    (emit-line port "source-query-receipt-schema="
               (.ref schema 'source-query-receipt-schema))
    (emit-line port "query-execution-candidate-schema="
               (.ref schema 'query-execution-candidate-schema))
    (emit-line port "runtime-admission-receipt-schema="
               (.ref schema 'runtime-admission-receipt-schema))
    (emit-line port "contract-artifact-projection-receipt-schema="
               (.ref schema 'contract-artifact-projection-receipt-schema))
    (emit-line port "abi-v1-frozen="
               (if (.ref schema 'abi-v1-frozen?) "true" "false"))
    (emit-line port "hot-layout-version=" (.ref schema 'hot-layout-version))
    (emit-line port "event-header-bytes=" (.ref schema 'event-header-bytes))
    (emit-line port "compact-identity-bits="
               (.ref schema 'compact-identity-bits))
    (for-each
     (lambda (capability)
       (emit-line port "capability-" (.ref capability 'name) "="
                  (.ref capability 'bit)))
     (.ref schema 'capabilities))
    (get-output-string port)))

(def (poo-flow-runtime-v0-abi-schema->event-vector schema)
  (let (port (open-output-string))
    (emit-line port "schema=poo-flow.runtime-v0.native-event-vector.1")
    (emit-line port "layout-version=" (.ref schema 'hot-layout-version))
    (emit-line port "header-bytes=" (.ref schema 'event-header-bytes))
    (emit-line port "event-kind=1")
    (emit-line port "flags=0")
    (emit-line port "sequence=7")
    (emit-line port "event-id-high=1")
    (emit-line port "event-id-low=2")
    (emit-line port "correlation-id-high=3")
    (emit-line port "correlation-id-low=4")
    (emit-line port "authorization-id-high=5")
    (emit-line port "authorization-id-low=6")
    (emit-line port "payload-offset=64")
    (emit-line port "payload-length=128")
    (emit-line port "deadline-mono-ns=9000")
    (emit-line port "required-evidence-bits=3")
    (emit-line port "reserved0=0")
    (get-output-string port)))
