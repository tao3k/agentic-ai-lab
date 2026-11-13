;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object
        (only-in "../dev/d2/init.ss" tao3k/agentic-ai-lab/dev/d2.init.exports))
(include "harness/d2-reader-review-cases.ss")
(export d2-reader-review-test)
(def Scope (.get tao3k/agentic-ai-lab/dev/d2.init.exports modules d2))
(def d2-reader-review-test
  (d2-reader-review-cases (.get Scope review) (.get Scope prototypes Question)))
