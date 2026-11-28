;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :std/test
        (only-in :clan/poo/object .get)
        (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :tao3k/agentic-ai-lab/t/yanxu/interface Lab))

(export session-module-test)

(def session-module-test
  (test-suite "Session Yuanxu module publication"
    (yuanxu-test-case "loads through Lab init module namespace"
      (def scope (.get Lab session))
      (check-equal? (.get scope library)
                    'tao3k/agentic-ai-lab/modules/session/interface)
      (check (list? (.get scope bundles)) => #t))))
