;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Public workflow module interface; all internal roles close through this file.

(import :core/modules/funflow/check-types :core/modules/funflow/check-objects "funs.ss" "config.ss")
(export (import: :core/modules/funflow/check-types)
        (import: :core/modules/funflow/check-objects)
        (import: "funs.ss")
        (import: "config.ss"))
