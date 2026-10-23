#!/usr/bin/env gxi
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Native performance entrypoint using the same ASP scheduler as unit tests.

(import (only-in :asp-gerbil-scheme/testing-runner-api
                 testing-interface-test-files)
        (only-in :asp-gerbil-scheme/testing-api
                 +testing-serial-resource-profile+
                 testing-test-selector
                 testing-interface-map-profile
                 testing-interface-run-test-files!)
        (only-in :std/list/list filter foldl)
        (only-in :agentic-ai-lab/dev/testing-api
                 +agentic-ai-lab-testing-interface+))

;;; Scenario end-to-end benchmarks admit on wall-clock p95, so every file in
;;; the performance lane needs an uncontended process.  This is a test-owned
;;; POO declaration; non-benchmark support files still use ASP's native core
;;; capacity, while CPU-time micro-kernels can later opt out through a distinct
;;; lane.
(def +agentic-ai-lab-performance-serial-test-fragments+
  '("./t/performance/"
    "module-system-poo-performance-test-support/objects-test.ss"))

(def +agentic-ai-lab-performance-testing-interface+
  (foldl
   (lambda (fragment testing)
     (testing-interface-map-profile
      testing
      (testing-test-selector 'contains fragment)
      +testing-serial-resource-profile+))
   +agentic-ai-lab-testing-interface+
   +agentic-ai-lab-performance-serial-test-fragments+))

(def +agentic-ai-lab-performance-test-files+
  (filter
   (lambda (path)
     (or (string-prefix? "./t/performance/" path)
         (string-prefix?
          "./t/module-system-poo-performance-test-support/"
          path)))
   (testing-interface-test-files
    +agentic-ai-lab-performance-testing-interface+
    "dev/performance-tests.ss")))

(displayln "[poo-performance-testing] phase=entry-ready")
(force-output)
(testing-interface-run-test-files!
 +agentic-ai-lab-performance-testing-interface+
 +agentic-ai-lab-performance-test-files+)
