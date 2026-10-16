;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Orgize owns Org Element and Contract semantics. POO Flow publishes the
;;; parser-independent POO runtime as a dependency-backed semantic boundary.
(import :orgize/languages/org/modules/org-elements/runtime-interface
        :orgize/languages/org/modules/org-contract/runtime-interface)
(export (import: :orgize/languages/org/modules/org-elements/runtime-interface)
        (import: :orgize/languages/org/modules/org-contract/runtime-interface))
