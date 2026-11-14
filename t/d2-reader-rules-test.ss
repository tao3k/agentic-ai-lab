;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
prelude: :gerbil/core
;;; A role-level rule check, distinct from the managed Module integration gate.
(include "../modules/d2/objects.ss")
(include "../modules/d2/ascent-review.ss")
(include "harness/d2-reader-review-cases.ss")
(export d2-reader-rules-test)
(def d2-reader-rules-test (d2-reader-review-cases d2-review D2Question.))
