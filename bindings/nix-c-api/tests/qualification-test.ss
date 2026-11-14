;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test "./cases.ss" "../session.ss")
(export qualification-test)
(def qualification-test
  (nix-api-suite call-with-nix-session session-query session-calls))
