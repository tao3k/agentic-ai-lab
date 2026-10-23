#!/usr/bin/env gxi
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :std/build-script defbuild-script)
        (only-in :std/source this-source-file)
        (only-in "../build-modules.ss" agentic-ai-lab-native-spec agentic-ai-lab-library-modules)
        (rename-in (only-in "./package.ss" agentic-ai-lab-native-spec)
                   (agentic-ai-lab-native-spec policy-native-spec))
        (only-in :asp-gerbil-scheme/src/build-api/policy-runner
                 asp-gerbil-scheme-run-selected-policy))
(export main)
(def (compile-development . args)
  (defbuild-script
   '("modules/testing/testing-extension"
     "modules/testing/source-admission"
     "modules/testing/module-system-live-case-object"
     "modules/testing/module-system-live-case"
     "modules/testing/interface"
     "testing-api"))
  (apply main args))
(def (main . args)
  (when (or (null? args) (equal? (car args) "compile"))
    (parameterize ((current-directory (path-expand ".." (path-directory (this-source-file)))))
      (def (target-name item) (if (string? item) item (cadr item)))
      (def (canonical targets)
        (list-sort (lambda (a b) (string<? (target-name a) (target-name b))) targets))
      (let ((production (agentic-ai-lab-native-spec)) (discovered (policy-native-spec)))
        (unless (equal? (canonical production) (canonical discovered))
          (error "production catalog differs from native public import closure"
                 (filter (lambda (item) (not (member item discovered))) production)
                 (filter (lambda (item) (not (member item production))) discovered))))
      (asp-gerbil-scheme-run-selected-policy
       (append agentic-ai-lab-library-modules
               '("modules/nono-sandbox/_nono.ss"
                 "modules/workflow/runtime/runtime-v0-native.ss"
                 "modules/workflow/runtime/semantic.ss")))))
  (apply compile-development args))
