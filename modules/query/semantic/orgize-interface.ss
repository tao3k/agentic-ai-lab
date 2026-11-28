;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Orgize owns Org Element and Contract semantics. Agentic AI Lab publishes the
;;; parser-independent POO runtime as a dependency-backed semantic boundary.
(import :orgize/languages/org/modules/org-elements/value-types
        :orgize/languages/org/modules/org-elements/values
        :orgize/languages/org/modules/org-elements/query
        :orgize/languages/org/modules/org-elements/syntax
        :orgize/languages/org/modules/org-contract/value-types
        :orgize/languages/org/modules/org-contract/values
        :orgize/languages/org/modules/org-contract/evaluation
        :orgize/languages/org/modules/org-contract/syntax)
(export (import: :orgize/languages/org/modules/org-elements/value-types
                 :orgize/languages/org/modules/org-elements/values
                 :orgize/languages/org/modules/org-elements/query
                 :orgize/languages/org/modules/org-elements/syntax
                 :orgize/languages/org/modules/org-contract/value-types
                 :orgize/languages/org/modules/org-contract/values
                 :orgize/languages/org/modules/org-contract/evaluation
                 :orgize/languages/org/modules/org-contract/syntax))
