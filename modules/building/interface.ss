;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Product building public owner; shared mechanisms are imported from Core.
(import "build-config.ss" "build-projection.ss" "official-contributions.ss")
(export (import: "build-config.ss")
        (import: "build-projection.ss")
        (import: "official-contributions.ss"))
