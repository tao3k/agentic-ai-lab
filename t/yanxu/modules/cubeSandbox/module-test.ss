;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :std/test
        (only-in :clan/poo/object .get)
        (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :tao3k/agentic-ai-lab/t/yanxu/interface Lab))

(export cube-sandbox-module-test)

(def cube-sandbox-module-test
  (test-suite "CubeSandbox Yuanxu module publication"
    (yuanxu-test-case "loads through Lab init module namespace"
      (check-equal? (.get (.get Lab cubeSandbox) library)
                    'tao3k/agentic-ai-lab/modules/cubeSandbox/interface))))
