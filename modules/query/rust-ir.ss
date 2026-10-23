;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: build-time Rust projection of the Query transport contract.
;;; The executable Scheme function is the authority; the Rust function IR is
;;; only a generated projection consumed by gerbil-scheme-rust.
(import (only-in :std/encoding/json
                 JSONReadOptions json->string string->json)
        (only-in :gerbil-parser/src/compiler/rust-pure-aot
                 define-rust-pure)
        (only-in :gerbil-parser/src/compiler/rust-syntax
                 rust-function-ir-json))

(export agentic-ai-lab-query-execution-candidate-transport-diagnostic
        agentic-ai-lab-query-execution-candidate-transport-diagnostic-rust
        agentic-ai-lab-query-execution-candidate-transport-ir-json)

;;; Rust types close two Scheme predicates before this function runs:
;;; result-count is u64 and complete? is bool.  They remain explicit inputs so
;;; the generated boundary covers the complete transport shape.
(define-rust-pure
  agentic-ai-lab-query-execution-candidate-transport-diagnostic
  agentic-ai-lab-query-execution-candidate-transport-diagnostic-rust
  ((provider-identity "&str")
   (query-identity "&str")
   (query-version "&str")
   (semantic-revision "&str")
   (source-content-identity "&str")
   (parser-identity "&str")
   (provenance-root "&str")
   (result-digest "&str")
   (_result-count "u64")
   (_complete? "bool"))
  "&'static str"
  (if (equal? provider-identity "") "provider_identity"
    (if (equal? query-identity "") "query_identity"
      (if (equal? query-version "") "query_version"
        (if (equal? semantic-revision "") "semantic_revision"
          (if (equal? source-content-identity "")
            "source_content_identity"
            (if (equal? parser-identity "") "parser_identity"
              (if (equal? provenance-root "") "provenance_root"
                (if (equal? result-digest "") "result_digest" "")))))))))

(def (agentic-ai-lab-query-execution-candidate-transport-ir-json)
  ;; Re-encode with sorted keys so the checked-in build input is byte-stable.
  (string-append
   (json->string
    (string->json
     (rust-function-ir-json
      agentic-ai-lab-query-execution-candidate-transport-diagnostic-rust)
     (JSONReadOptions object-as-hash: #t))
    sort-keys: #t)
   "\n"))
