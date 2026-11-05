;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .get)
        (only-in "../../init.ss" agentic-ai-lab.init.exports))
(export main)
(def (main . arguments)
  (apply (.get agentic-ai-lab.init.exports modules durable workspace-recovery-host) arguments))
