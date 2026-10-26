;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :agentic-ai-lab/t/context-c-abi-test)
(def (main path mode) (context-c-abi-probe path mode))
