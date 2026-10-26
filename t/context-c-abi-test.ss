;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Real C facade -> exported Scheme entry -> native owner -> Session CAS.
(import :std/ffi
        (only-in :clan/poo/object .ref)
        :agentic-ai-lab/modules/workflow/runtime/semantic
        :agentic-ai-lab/modules/workflow/runtime/context-lifecycle
        :agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
        :agentic-ai-lab/modules/temporal-causality/runtime/policy-clock
        :agentic-ai-lab/t/context-service-test
        (only-in :agentic-ai-lab/t/temporal-evaluator-test push-join! clock-check-originals!))
(export context-c-abi-probe)
(C-declare "#include \"t/qualification/context-temporal/context-c-caller.c\"")
(def-C-lambda c-roundtrip (int UTF-8-string) int "context_c_roundtrip")
(def (context-c-abi-probe path mode)
  (let* ((value (service-fixture path)) (restart? (equal? mode "restart")))
    ;; Independent Session endpoints retire before the Context/VM close.
    (unless restart?
      (policy-clock-call! (.ref value 'clock)
        (lambda (_) (push-join! (.ref value 'fixture) "session-b"))))
    (semantic-context-install! (.ref value 'service))
    (let (status (c-roundtrip (if restart? 1 0) (service-fixture-grant-digest value)))
      (unless (= status 0) (error "Real C lifecycle caller failed" status)))
    (unless (journal-closed? (.ref value 'journal)) (error "C close left its journal open"))
    (displayln "CONTEXT-C public-facade=actual source=original terminal-C=1 retry=historical replacement=refused old-result=refused journal=closed restart=" restart?)
    (displayln "MODULE-OK t/context-c-abi-test.ss")
    (displayln "HARNESS-OK context-c-abi")
    (displayln "OK")))
