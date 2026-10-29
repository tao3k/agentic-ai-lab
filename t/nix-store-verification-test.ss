;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Current native store verification, never a cached registration claim.
(import :std/test
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :yuanxu/module-system/source/admission current-module-source-observer)
        (only-in :std/source this-source-file)
        (only-in :clan/poo/object .call)
        (only-in :clan/poo/io module-action)
        (only-in "./qualification/nix/programs.ss" nix-publication-programs)
        (only-in :agentic-ai-lab/modules/nix/func
                 agentic-ai-lab-nix-verify-store current-nix-process-observer))
(export nix-store-verification-test)

;; Core qualification helpers live in their issued support publication, not the
;; production library. Resolve the native action only inside that admitted scope.
(def programs
  (nix-publication-programs (path-expand ".." (path-directory (this-source-file)))))
(def verify-store
  (module-action "yuanxu/t/qualification/build-publication/store"
                 'yuanxu/t/qualification/build-publication/store#store-verify))

(def nix-store-verification-test
  (test-suite "Each approval boundary verifies native registered contents"
    (yuanxu-test-case "Core recovery repeats fresh native verification without duplicate processes"
      (def root (getenv "AGENTIC_AI_LAB_OPENTOFU_TEST_INPUTS"))
      (def calls '())
      (def previous (current-module-source-observer))
      (parameterize ((current-module-source-observer
                      (lambda (event amount)
                        ;; Observe this boundary without swallowing the native
                        ;; Case observer's real source/admission progress.
                        (when previous (previous event amount))
                        (when (and (pair? event) (eq? (car event) 'native-store-process))
                          (set! calls (cons (cadr event) calls))))))
        (.call programs .with-imports
          (lambda ()
            (verify-store (list root))
            (verify-store (list root)))))
      (check-equal? (reverse calls)
        (list (list "nix-store" "--store" "daemon" "--verify-path" root)
              (list "nix-store" "--store" "daemon" "--verify-path" root))))
    (yuanxu-test-case "independent calls both perform cryptographic verification"
      (def root (getenv "AGENTIC_AI_LAB_OPENTOFU_TEST_INPUTS"))
      (def calls '())
      (parameterize ((current-nix-process-observer
                      (lambda (argv) (set! calls (cons argv calls)))))
        (agentic-ai-lab-nix-verify-store "nix-store" root)
        (agentic-ai-lab-nix-verify-store "nix-store" root))
      (check-equal? (reverse calls)
                    (list (list "nix-store" "--verify-path" root)
                          (list "nix-store" "--verify-path" root))))
    (yuanxu-test-case "native refusal cannot become successful approval"
      ;; An existing real store path does not override a verifier's refusal.
      (check-exception
       (agentic-ai-lab-nix-verify-store "/usr/bin/false"
         (getenv "AGENTIC_AI_LAB_OPENTOFU_TEST_INPUTS"))
       error?))
    (yuanxu-test-case "an absent store object is refused"
      (check-exception
       (agentic-ai-lab-nix-verify-store "nix-store"
         "/nix/store/00000000000000000000000000000000-context-ci-absent")
       error?))))
