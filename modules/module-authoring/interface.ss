;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Product module-authoring public owner; shared mechanisms are imported from Core.
(import "semantic-module.ss" "module-interface.ss" "module-source-collection.ss")
(export (import: "semantic-module.ss")
        (import: "module-interface.ss")
        (import: "module-source-collection.ss"))
