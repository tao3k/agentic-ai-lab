;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Rule assertions consume the published Module, never include its implementation.
(import (only-in :clan/poo/object .get)
        (only-in "../../../../init.ss" tao3k/agentic-ai-lab.init.exports))
(include "../../../harness/d2-reader-review-cases.ss")
(export d2-reader-rules-test)
(def Scope (.get tao3k/agentic-ai-lab.init.exports modules d2))
(def d2-reader-rules-test
  (d2-reader-review-cases (.get Scope review) (.get Scope prototypes Question)))
