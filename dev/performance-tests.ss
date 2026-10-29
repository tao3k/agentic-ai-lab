#!/usr/bin/env gxi
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Performance selection reuses ASP; init Test objects own native execution.

(import (only-in :asp-gerbil-scheme/testing-runner-api
                 testing-interface-test-files)
        (only-in :std/list/list filter)
        (only-in :clan/poo/object .def .get .call .o)
        (only-in :std/source this-source-file)
        (only-in "../init.ss" agentic-ai-lab.init.exports)
        (only-in "../build-spec.ss" agentic-ai-lab-test-demand)
        ;; Development policy is source-owned; it is not a published package library.
        (only-in "./testing-api.ss"
                 +agentic-ai-lab-testing-interface+))

;;; Wall-clock Scenario gates use one fresh native Test process at a time.
;;; The existing Testing Interface supplies discovery; Core's inherited POO
;;; Case Profile supplies the same declared worker and Case resource policy.
(def +agentic-ai-lab-performance-test-files+
  (filter
   (lambda (path)
     (or (string-prefix? "./t/performance/" path)
         (string-prefix?
          "./t/module-system-poo-performance-test-support/"
          path)))
   ;; Official dev builds start in dev/. Discovery remains rooted in this
   ;; source's declaring product instead of depending on the caller's cwd.
   (parameterize ((current-directory
                    (path-expand ".." (path-directory (this-source-file)))))
     (testing-interface-test-files
      +agentic-ai-lab-testing-interface+
      "dev/performance-tests.ss"))))

(export main agentic-ai-lab-performance-test-demand)

(def (agentic-ai-lab-performance-test-demand exports
          (files +agentic-ai-lab-performance-test-files+))
  ;; These are the actual development declaration and selection owners.
  (agentic-ai-lab-test-demand exports files
    '("dev/build.ss" "dev/performance-tests.ss")))

(def (main . requested)
  ;; Focused diagnosis selects from the same published inventory. The default
  ;; remains the complete queue, and preparation still owns its full demand.
  (def requests (filter (lambda (file) (not (string-empty? file))) requested))
  (def (canonical-file file) (path-normalize (path-expand file)))
  (for-each
    (lambda (file)
      (unless (any (lambda (known) (equal? (canonical-file file) (canonical-file known)))
                   +agentic-ai-lab-performance-test-files+)
        (error "performance input is outside the published inventory" file)))
    requests)
  (def files
    (if (null? requests)
      +agentic-ai-lab-performance-test-files+
      (filter (lambda (known)
                (any (lambda (file) (equal? (canonical-file file) (canonical-file known))) requests))
              +agentic-ai-lab-performance-test-files+)))
  (displayln "[poo-performance-testing] phase=entry-ready fileCount=" (length files)
             " inventoryCount=" (length +agentic-ai-lab-performance-test-files+))
  (force-output)
  (def failed '())
  ;; Preserve the complete serial queue even after refusal. Core owns all
  ;; preparation admission, child commands, resource fences and result checks.
  (for-each
   (lambda (file)
     (with-exception-catcher
      (lambda (failure)
        (set! failed (cons file failed))
        (displayln "[poo-performance-testing] phase=file-failed file=" file)
        (force-output)
        (display-exception failure (current-error-port))
        (force-output (current-error-port))
        (force-output))
      (lambda ()
        (def demand
          (agentic-ai-lab-performance-test-demand agentic-ai-lab.init.exports (list file)))
        (.def (Test @ (.get demand execution))
          profile: =>.+ (.o emit?: #t))
        (displayln "[poo-performance-testing] phase=file-start file=" file)
        (force-output)
        (display (.get (.call Test .run) output))
        (displayln "[poo-performance-testing] phase=file-complete file=" file)
        (force-output))))
   files)
  (unless (null? failed)
    (error "native performance tests failed" (reverse failed))))
