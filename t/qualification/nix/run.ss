;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Product test selection, Core execution/admission protocol.
(import :clan/poo/object
        (only-in :std/source this-source-file)
        (only-in :yuanxu/observability/testing-script TestingScript.)
        (only-in :agentic-ai-lab/modules/nix/progress make-nix-test-progress-reader)
        (only-in :yuanxu/module-system/source/admission module-source-read module-source-admit-current!))
;; Resolve test inputs from the maintained product root, independent of cwd.
(def root (path-expand "../../.." (path-directory (this-source-file))))
;; Preserve the complete existing adapter selection, including recovery gates.
(def (selected? name)
  (and (string-suffix? "-test.ss" name)
    (or (any (lambda (prefix) (string-prefix? prefix name))
             '("nix-" "opentofu-" "aws-" "module-nix-" "json-schema-aws-"))
        (member name '("ops-selected-packages-test.ss" "execution-progress-test.ss"
                       "approved-build-recovery-test.ss" "build-store-recovery-test.ss")))))
;; TestingScript retains source guards, resource limits and result admission.
(def (run-file file)
  (def input (cons file (module-source-read file)))
  (.def (Test @ TestingScript.)
    source: (.o spec: (list file) source-root: root
                admit-current: (lambda () (module-source-admit-current! (list input))))
    profile: =>.+ (.o max-duration-milliseconds: 120000 max-idle-milliseconds: 60000)
    ;; Relay real fixture boundaries immediately; the existing reader still
    ;; owns Nix/progress admission and the idle watchdog sees no synthetic ticks.
    progress: (lambda ()
                (let (read-progress (make-nix-test-progress-reader))
                  (lambda (line)
                    (read-progress line)
                    (when (string-prefix? "PHASE " line)
                      (displayln line) (force-output))))))
  (displayln "TEST-START " file) (force-output)
  (display (.get (.call Test .run) output)) (force-output))
;; Run serially so per-file heap budgets never multiply without a scheduler.
(def (main . paths)
  (for-each run-file
    (if (null? paths)
      (map (cut path-expand <> (path-expand "t" root))
        (list-sort string<? (filter selected? (directory-files (path-expand "t" root)))))
      (map (cut path-expand <> root) paths))))
;; gxi invokes main after loading the script; never invoke it again here.
