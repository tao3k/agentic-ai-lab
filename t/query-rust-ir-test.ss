;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test check test-suite)
        (only-in :std/misc/ports read-all-as-string)
        (only-in :agentic-ai-lab/modules/query/rust-ir
                 agentic-ai-lab-query-execution-candidate-transport-diagnostic
                 agentic-ai-lab-query-execution-candidate-transport-ir-json))

(export query-rust-ir-test)

(def query-rust-ir-test
  (test-suite
   "Query Scheme to Rust IR"

   (yuanxu-test-case "Scheme transport contract fails closed on the first missing identity"
     (check
      (agentic-ai-lab-query-execution-candidate-transport-diagnostic
       "" "query" "1" "revision" "source" "parser" "provenance"
       "digest" 0 #f)
      => "provider_identity")
     (check
      (agentic-ai-lab-query-execution-candidate-transport-diagnostic
       "provider" "query" "1" "revision" "source" "parser" "provenance"
       "digest" 0 #f)
      => ""))

   (yuanxu-test-case "checked-in Rust IR is the canonical Scheme projection"
     (check
      (agentic-ai-lab-query-execution-candidate-transport-ir-json)
      =>
      (call-with-input-file
       "bindings/rust-ir/query-execution-candidate-v1.ir.json"
       read-all-as-string)))))
