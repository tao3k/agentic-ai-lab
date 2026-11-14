;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;; Scenario defaults are ordinary values. Explicit service JSON wins, including
;; null; a missing client port remains absent and follows the final database.
(export Config)
(.def Config
  postgresql: (.o settings: (.o port: 5432))
  gitea: (.o database: (.o)))
