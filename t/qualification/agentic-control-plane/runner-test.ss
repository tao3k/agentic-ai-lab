;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         :std/test
        :clan/poo/object
        :poo-flow/modules/workflow/qualification/runner)

(def registry (poo-flow-agentic-control-plane-gate-registry))

(def (accepted-receipt gate-id revision)
  (poo-flow-qualification-gate-receipt
   (find-gate gate-id registry)
   revision
   #t
   (list (cons 'kind 'gerbil-bazel.action-receipt.v1)
         (cons 'gate-id gate-id))))

(def runner-test
  (test-suite "AC-10 S4 cross-language qualification receipts"
    (poo-flow-test-case "registry declares exact release owners and installed gates"
      (check (map (lambda (gate) (.ref gate 'gate-id)) registry)
             => +poo-flow-ac10-release-gates+)
      (check (map (lambda (id)
                    (.ref (find-gate id registry) 'installed-consumer?))
                  '(runtime-v0-installed-consumer proof-case-installed-consumer
                    python-proof-installed-wheel lean-ffi-smoke))
             => '(#t #t #t #t)))

    (poo-flow-test-case "focused mode verifies upstream build evidence"
      (let* ((receipt
              (accepted-receipt 'scheme-canonical-fixture "revision"))
             (run
              (poo-flow-qualification-run-receipt
               'focused "revision" (list receipt)))
             (verified (poo-flow-qualification-verify-run registry run)))
        (check (map (lambda (entry) (.ref entry 'gate-id))
                    (.ref run 'gate-receipts))
               => '(scheme-canonical-fixture))
        (check (.ref run 'accepted?) => #t)
        (check (.ref verified 'accepted?) => #t)
        (check (.ref receipt 'evidence)
               => '((kind . gerbil-bazel.action-receipt.v1)
                    (gate-id . scheme-canonical-fixture)))))

    (poo-flow-test-case "missing and stale release receipts fail closed"
      (let* ((focused
              (poo-flow-qualification-run-receipt
               'focused
               "revision"
               (list
                (accepted-receipt
                 'scheme-canonical-fixture "revision"))))
             (fake-release
              (object<-alist
               (list (cons 'kind 'poo-flow.qualification-run-receipt.v1)
                     (cons 'mode 'release)
                     (cons 'source-revision "other-revision")
                     (cons 'gate-receipts (.ref focused 'gate-receipts))
                     (cons 'accepted? #f))))
             (verified
              (poo-flow-qualification-verify-run registry fake-release)))
        (check (.ref verified 'accepted?) => #f)
        (let (codes (map (lambda (entry) (cdr (assq 'code entry)))
                         (.ref verified 'diagnostics)))
          (check (car codes) => 'stale-source-revision)
          (check (length codes) => (length +poo-flow-ac10-release-gates+)))))))
