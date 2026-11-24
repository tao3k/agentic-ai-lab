;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :std/test
        (only-in :clan/poo/object .get)
        (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :tao3k/agentic-ai-lab/t/yanxu/interface Lab))

(export model-core-module-test)

(def model-core-module-test
  (test-suite "ModelCore Yuanxu module publication"
    (yuanxu-test-case "loads through Lab init module namespace"
      (check-equal? (.get (.get Lab model-core) library)
                    'tao3k/agentic-ai-lab/modules/model-core/interface))))
