;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :std/test
        (only-in :clan/poo/object .get)
        (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :tao3k/agentic-ai-lab/t/yanxu/interface Lab))

(export loop-engine-module-test)

(def loop-engine-module-test
  (test-suite "LoopEngine Yuanxu module publication"
    (yuanxu-test-case "loads through Lab init module namespace"
      (def scope (.get Lab loop-engine))
      (check-equal? (.get scope library)
                    'tao3k/agentic-ai-lab/modules/loop-engine/interface)
      (check (procedure? (.get scope strategy-plan?)) => #t))))
