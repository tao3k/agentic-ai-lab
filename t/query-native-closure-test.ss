;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Verify the compiler's real import graph, not a maintained dependency roster.
(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :std/test test-suite check)
        (only-in :gerbil/expander core-import-module expander-context-id)
        (only-in :yuanxu/module-system/building/source-closure for-each-build-module))
(export query-native-closure-test)

(def (imports-aggregate-clos? source)
  (def found? #f)
  (for-each-build-module (core-import-module source)
    (lambda (context)
      (when (eq? (expander-context-id context) 'yuanxu/poo-clos/interface)
        (set! found? #t))))
  found?)

(def query-native-closure-test
  (test-suite "Query and Context native capability closures"
    (yuanxu-test-case "Query binding and Context Provider retain bounded CLOS owners"
      ;; The compiler follows runtime and syntax imports, including Parser.
      ;; A source-only grep would miss the transitive aggregate dependency.
      (check (imports-aggregate-clos? ':agentic-ai-lab/modules/query/contracts) => #f)
      (check (imports-aggregate-clos? ':agentic-ai-lab/modules/ai-agentic-context/query-provider) => #f))
    (yuanxu-test-case "the native closure control detects an aggregate import"
      ;; Keep the full facade available for consumers that actually need it.
      (check (imports-aggregate-clos? ':yuanxu/poo-clos/interface) => #t))))
