;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Current native store verification, never a cached registration claim.
(import :std/test
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :agentic-ai-lab/modules/nix/func
                 agentic-ai-lab-nix-verify-store current-nix-process-observer))
(export nix-store-verification-test)

(def nix-store-verification-test
  (test-suite "Each approval boundary verifies native registered contents"
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
