;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Verify the compiler's real import graph, not a maintained dependency roster.
(import (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :std/test test-suite check)
        (only-in :gerbil/expander core-import-module expander-context-id)
        (only-in :tao3k/yuanxu/module-system/building/source-closure for-each-build-module))
(export query-native-closure-test)

(def (imports-module? source identity)
  (def found? #f)
  (for-each-build-module (core-import-module source)
    (lambda (context)
      (when (eq? (expander-context-id context) identity)
        (set! found? #t))))
  found?)

(def query-native-closure-test
  (test-suite "Query and Context native capability closures"
    (yuanxu-test-case "Query binding and Context Provider use the public MOP"
      ;; The compiler follows runtime and syntax imports, including Parser.
      ;; The unified public MOP owns CLOS. Its internal imports are upstream's
      ;; responsibility; consumers must not retain the retired CLOS facade.
      (for-each
        (lambda (source)
          (check (imports-module? source 'clan/poo/mop) => #t)
          (check (imports-module? source 'clan/poo/clos) => #f))
        '(:tao3k/agentic-ai-lab/modules/query/contracts
          :tao3k/agentic-ai-lab/modules/ai-agentic-context/query-provider)))
    (yuanxu-test-case "the native closure control distinguishes public MOP imports"
      (check (imports-module? ':clan/poo/mop 'clan/poo/mop) => #t)
      (check (imports-module? ':std/list/list 'clan/poo/mop) => #f))))
