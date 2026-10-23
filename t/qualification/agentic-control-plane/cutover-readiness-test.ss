;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        :clan/poo/object
        :agentic-ai-lab/modules/workflow/qualification/cutover-readiness)


(def accepted-symbol-receipt
  (.o (kind 'agentic-ai-lab.runtime-symbol-manifest-receipt.v1) (accepted? #t)))
(def accepted-version-receipt
  (.o (kind 'agentic-ai-lab.release-version-matrix-receipt.v1) (accepted? #t)))
(def accepted-guards
  (list (agentic-ai-lab-cutover-legacy-guard
         'python-no-ctypes #t "python-public-surface-test")
        (agentic-ai-lab-cutover-legacy-guard
         'agent-sandbox-zero-consumer #t "ledger-133-owner-audit")))
(def external-blocker
  (agentic-ai-lab-cutover-external-blocker
   'asp-provider 'missing-asp-source-index-token-owner-v1 #f))

(def (input . rest)
  (let ((source-revision (if (pair? rest) (car rest) "revision"))
        (symbol-revision (if (> (length rest) 1) (cadr rest) "revision"))
        (version-revision (if (> (length rest) 2) (caddr rest) "revision"))
        (symbol-receipt (if (> (length rest) 3) (list-ref rest 3)
                            accepted-symbol-receipt))
        (version-receipt (if (> (length rest) 4) (list-ref rest 4)
                             accepted-version-receipt))
        (guards (if (> (length rest) 5) (list-ref rest 5) accepted-guards))
        (blocker (if (> (length rest) 6) (list-ref rest 6) external-blocker))
        (decision? (if (> (length rest) 7) (list-ref rest 7) #t))
        (frozen? (if (> (length rest) 8) (list-ref rest 8) #f))
        (deletion? (if (> (length rest) 9) (list-ref rest 9) #f)))
    (agentic-ai-lab-cutover-readiness-input
     source-revision "ac10-revision" "ac10-manifest-digest"
     symbol-revision symbol-receipt version-revision version-receipt
     guards blocker decision? frozen? deletion?)))

(def cutover-readiness-test
  (test-suite "AC-11 cutover readiness preflight"
    (yuanxu-test-case "qualified evidence is ready only for release decision"
      (let (receipt (agentic-ai-lab-cutover-readiness-verify (input)))
        (check (.ref receipt 'ready?) => #t)
        (check (.ref receipt 'decision-required?) => #t)
        (check (.ref receipt 'abi-v1-frozen?) => #f)
        (check (.ref receipt 'deletion-authorized?) => #f)))
    (yuanxu-test-case "revision mismatch fails closed"
      (let (receipt
            (agentic-ai-lab-cutover-readiness-verify
             (input "revision" "stale-symbol" "stale-version")))
        (check (.ref receipt 'ready?) => #f)
        (check (.ref receipt 'diagnostics)
               => '(symbol-revision-mismatch version-revision-mismatch))))
    (yuanxu-test-case "failed symbol, version, or legacy evidence fails closed"
      (let* ((failed (.o (kind 'failed) (accepted? #f)))
             (failed-guards
              (list (agentic-ai-lab-cutover-legacy-guard
                     'python-no-ctypes #f "failed")))
             (receipt
              (agentic-ai-lab-cutover-readiness-verify
               (input "revision" "revision" "revision"
                      failed failed failed-guards))))
        (check (.ref receipt 'ready?) => #f)
        (check (.ref receipt 'diagnostics)
               => '(runtime-symbol-surface-rejected
                    release-version-matrix-rejected
                    legacy-guard-rejected))))
    (yuanxu-test-case "missing external blocker classification fails closed"
      (let (receipt
            (agentic-ai-lab-cutover-readiness-verify
             (input "revision" "revision" "revision"
                    accepted-symbol-receipt accepted-version-receipt
                    accepted-guards
                    (agentic-ai-lab-cutover-external-blocker
                     'agentic-ai-lab 'unknown #t))))
        (check (.ref receipt 'ready?) => #f)
        (check (.ref receipt 'diagnostics)
               => '(external-blocker-unclassified))))
    (yuanxu-test-case "decision, freeze, and deletion escalation is rejected"
      (let (receipt
            (agentic-ai-lab-cutover-readiness-verify
             (input "revision" "revision" "revision"
                    accepted-symbol-receipt accepted-version-receipt
                    accepted-guards external-blocker #f #t #t)))
        (check (.ref receipt 'ready?) => #f)
        (check (.ref receipt 'diagnostics)
               => '(release-decision-bypassed implicit-abi-v1-freeze
                    deletion-without-release-decision))))))
