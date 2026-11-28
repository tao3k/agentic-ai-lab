;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in "../../modules/durable/workspace-recovery-host.ss"
                 durable-workspace-recovery-host))
(export main)
(def (main . arguments)
  (apply durable-workspace-recovery-host arguments))
