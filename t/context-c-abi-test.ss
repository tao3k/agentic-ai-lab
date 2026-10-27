;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Real C facade -> exported Scheme entry -> native owner -> Session CAS.
(import (only-in :std/test test-suite)
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :agentic-ai-lab/t/qualification/context-temporal/c-abi-caller c-roundtrip)
        (only-in :clan/poo/object .ref)
        (only-in :agentic-ai-lab/modules/ai-agentic-context/runtime-service
                 context-service-close!)
        :agentic-ai-lab/modules/workflow/runtime/semantic
        :agentic-ai-lab/modules/workflow/runtime/context-lifecycle
        :agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
        :agentic-ai-lab/modules/temporal-causality/runtime/policy-clock
        :agentic-ai-lab/t/context-service-test
        (only-in :agentic-ai-lab/t/qualification/context-temporal/evaluator/fixtures
                 push-join!))
(export context-c-abi-probe context-c-abi-test)
(def (context-c-abi-probe path mode)
  (let* ((value (service-fixture path)) (restart? (equal? mode "restart")))
    (dynamic-wind
      void
      (lambda ()
        ;; Independent Session endpoints retire before the Context/VM close.
        (unless restart?
          (policy-clock-call! (.ref value 'clock)
            (lambda (_) (push-join! (.ref value 'fixture) "session-b"))))
        (semantic-context-install! (.ref value 'service))
        (let (status (c-roundtrip (if restart? 1 0) (service-fixture-grant-digest value)))
          (unless (= status 0) (error "Real C lifecycle caller failed" status)))
        ;; Check C-owned shutdown BEFORE fallback cleanup, so cleanup cannot
        ;; turn a missing drain into a successful qualification.
        (unless (journal-closed? (.ref value 'journal))
          (error "C close left its journal open"))
        (displayln "CONTEXT-C public-facade=actual source=original terminal-C=1 retry=historical replacement=refused old-result=refused journal=closed restart=" restart?)
        ;; Only the official Harness emits test success markers. This remains
        ;; the existing argument-driven diagnostic replay entry as well.
        (void))
      (lambda ()
        ;; The Suite owns acquisition even if the C counterexample fails early.
        ;; Public close is idempotent and joins the Actor before temp removal.
        (context-service-close! (.ref value 'service))))))

;; A source-discovered Suite imports its compiled FFI owner, then executes the
;; original C checks. C close is terminal for this facade/VM, so the one Case
;; never pretends that a second open in the same process is a fresh restart.
(def context-c-abi-test
  (test-suite "C facade executes native Context and independent Session CAS"
    (yuanxu-test-case "C result publication and revocation retain original evidence"
      (call-with-temporary-directory "context-c-abi-"
        (lambda (directory)
          (context-c-abi-probe (path-expand "context.sqlite" directory) "run"))))))
