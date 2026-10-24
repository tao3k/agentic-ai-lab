;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object)
(export Config)
;; Selected package realization supplies this, not ordinary Profile users.
(def Config (.o provider-directory: #f))
