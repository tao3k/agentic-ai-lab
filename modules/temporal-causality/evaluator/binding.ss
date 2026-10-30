;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Public POO facade. Verified intermediates remain inside the private kernel.
(import (prefix-in "private/binding-kernel.ss" kernel.))
(export agentic-ai-lab-temporal-proof-source-binding agentic-ai-lab-temporal-proof-support
        agentic-ai-lab-temporal-proof-support-replay)

;;; Keep the established runtime bindings for already compiled consumers.
(def agentic-ai-lab-temporal-proof-source-binding kernel.agentic-ai-lab-temporal-proof-source-binding)
(def agentic-ai-lab-temporal-proof-support kernel.agentic-ai-lab-temporal-proof-support)
(def agentic-ai-lab-temporal-proof-support-replay kernel.agentic-ai-lab-temporal-proof-support-replay)
