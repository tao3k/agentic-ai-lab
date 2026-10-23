;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (rename-in (only-in :gerbil/tools/gxtest main) (main gxtest-main))
        (only-in :gerbil/runtime/init gerbil-load-expander!)
        (only-in :gerbil/expander import-module)
        "../../query-core-test.ss"
        "../../query-orgize-source-test.ss"
        "../../evidence-assessment-core-test.ss")
(export main)
;;; Statically linked owner modules; upstream gxtest still owns discovery,
;;; assertions, Case profiles, reporting and exit status.
(def (main . args)
  (def (completed-stage message)
    (when (getenv "AGENTIC_AI_LAB_TEST_PROGRESS" #f)
      (let (port (current-error-port))
        (display message port)
        (newline port)
        (force-output port))))
  (completed-stage "poo-test: static module initialization completed")
  ;; gxtest imports source modules. Match the official Gerbil main's expander
  ;; initialization before delegating discovery and execution to gxtest.
  (gerbil-load-expander!)
  (completed-stage "poo-test: official expander initialization completed")
  ;; Populate official expander contexts in bounded, observable dependency
  ;; stages. gxtest still imports the original test files and discovers suites.
  ;; Emit only after a real import completes; a stalled import still fails.
  (for-each
   (lambda (module)
     (import-module module #f #t)
     (completed-stage (string-append "poo-test: expander import completed "
                                     (symbol->string module))))
   '(:std/test :clan/poo/object
     :std/error :std/list/list-builder :std/list/list :std/list/walist
     :std/values :std/func
     :clan/poo/support/base :clan/poo/support/io :clan/poo/support/json
     :clan/poo/support/syntax :clan/poo/support/repr :clan/poo/brace
     :clan/poo/mop
     :asp-gerbil-scheme/testing-api :yuanxu/observability/testing-case
     :agentic-ai-lab/testing-api
     :gerbil-parser/src/modules/parser/graph-syntax
     :agentic-ai-lab/modules/query/interface
     :agentic-ai-lab/modules/query/orgize-source
     :agentic-ai-lab/modules/evidence-assessment/interface))
  (exit (apply gxtest-main args)))
