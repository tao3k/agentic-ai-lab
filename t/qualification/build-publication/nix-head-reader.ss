;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Independent installed-Gerbil process; no issuer or plan object is inherited.
(import (only-in :std/encoding/json read-json)
        (only-in :std/list/walist waref))
(def (main profile)
  (def plan (call-with-input-file (path-expand "plan.json" profile) read-json))
  (write (list (waref plan "postgresql" #f) (waref plan "gitea" #f)))
  (newline))
