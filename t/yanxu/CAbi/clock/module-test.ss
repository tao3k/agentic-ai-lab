;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :std/test
        (only-in :clan/poo/object .get object?)
        (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :tao3k/agentic-ai-lab/t/yanxu/interface Lab))

(export c-abi-clock-module-test)

(def c-abi-clock-module-test
  (test-suite "CAbi clock Yuanxu module publication"
    (yuanxu-test-case "loads through Lab init CAbi mount"
      (def scope (.get Lab c-abi-clock))
      (check (object? scope) => #t))))
