;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :tao3k/yuanxu/module-system/source/declaration .def)
        (only-in "../../objects.ss" EnableMemory)
        (only-in "../../types.ss" ContextMemoryScopeContract)
        "config.ss"
        "org-selection.ss"
        "session-selection.ss")

(.def Feature
  refine: EnableMemory
  contract: ContextMemoryScopeContract)
