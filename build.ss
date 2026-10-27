#!/usr/bin/env -S timeout --signal=TERM --kill-after=5s 900s gxi
;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Build-only watchdog for the complete cold library. Runtime test profiles
;;; retain their independent heap, total-duration and idle-duration gates.
(import (for-syntax
          (only-in :std/source this-source-file)
          (only-in :yuanxu/module-system/building/source-package register-module-build-source!)))
(begin-syntax
  (register-module-build-source! (path-directory (this-source-file)) 'agentic-ai-lab))

(import (only-in :clan/poo/object .get)
        (only-in :std/source this-source-file)
        (only-in :std/misc/process run-process)
        (only-in :yuanxu/module-system/building/script defbuild-script)
        (only-in "./init.ss" agentic-ai-lab.init.exports)
        (only-in "./build-spec.ss" agentic-ai-lab-build-spec agentic-ai-lab-public-build-roots))

;; The C caller is an AOT qualification leaf, not a production import root.
;; Declare its ordinary Gerbil target here with the other retained Suite
;; libraries. Module targets stay owned by init.exports.std-make-spec; the
;; same official Gerbil build compiles this retained Suite support.
(def native-qualification-spec
  `((gxc: "t/qualification/context-temporal/c-abi-caller"
      ;; Native std/make must observe included C/header edits too; a cached
      ;; Scheme wrapper alone cannot establish current C qualification.
      (extra-inputs: ("t/qualification/context-temporal/context-c-caller.c"
                      "bindings/runtime-c/src/semantic_host.c"
                      "bindings/runtime-c/include/agentic_ai_lab/semantic.h"))
      "-cc-options" ,(string-append
        "-I" (path-directory (this-source-file))
        " -I" (path-expand "bindings/runtime-c/include"
                  (path-directory (this-source-file))))
      ,@(cond-expand
          (darwin '("-ld-options" "-Wl,-undefined,dynamic_lookup"))
          (else '())))))

;; Native package clones acquire the declared Core gitlink before source lowering.
(def retained-spec
  (begin
    ;; Bootstrap a missing checkout only. An existing Core may contain an
    ;; intentional revision or local work and must not be reset by a build.
    (unless (file-exists? (path-expand "core/gerbil.pkg" (path-directory (this-source-file))))
      (run-process
        (list "git" "-C" (path-directory (this-source-file))
              "submodule" "update" "--init" "--depth" "1" "--" "core")
        stdin-redirection: #f stdout-redirection: #f))
    ;; Compatibility consumers may start in dev/. Retained library paths
    ;; are always resolved against this product entry, never the caller's cwd.
    (parameterize ((current-directory (path-directory (this-source-file))))
      ;; These published Suite libraries were already native targets of the
      ;; former preparation path. Declare them here for the official Gerbil build;
      ;; gerbil test still discovers/runs every Case and never reuses a verdict.
      (append native-qualification-spec
        (agentic-ai-lab-build-spec
          (append agentic-ai-lab-public-build-roots
            '("t/qualification/context-temporal/evaluator/fixtures.ss"
              "t/qualification/context-temporal/evaluator/cases-1.ss"
              "t/qualification/context-temporal/evaluator/cases-2.ss"
              "t/qualification/context-temporal/evaluator/cases-3.ss"
              "t/qualification/context-temporal/evaluator/cases-4.ss"
              "t/qualification/context-temporal/evaluator/cases-5.ss"
              "t/qualification/context-temporal/evaluator/cases-6.ss"
              "t/qualification/context-temporal/evaluator/cases-7.ss"
              "t/qualification/context-temporal/evaluator/cases-8.ss"
              "t/temporal-evaluator-test.ss"
              "t/ai-agentic-context-session-host-test.ss"
              "t/ai-agentic-context-delta-test.ss"
              "t/session-attempt-test.ss"
              "t/ai-agentic-context-org-anchors-test.ss"
              "t/query-orgize-source-test.ss")))))))

;; The selected init owns source lowering; the Gerbil owns Make and dispatch.
(def modules-spec (.get agentic-ai-lab.init.exports std-make-spec))
(defbuild-script (modules-spec retained-spec))
