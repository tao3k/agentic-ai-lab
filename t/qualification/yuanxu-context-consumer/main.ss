;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in "./init.ss" yuanxu-context-consumer.init.exports)
        (only-in :clan/poo/object .get))
(export selected-context)
(def (selected-context)
  (def leaf (.get yuanxu-context-consumer.init.exports Lab ai-agentic-context))
  ;; The Build-enabled leaf also carries metadata. Demand the business slot
  ;; inside the caller's measurement and preserve the exported leaf identity.
  (.get leaf profile)
  leaf)
