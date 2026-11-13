;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; The compiled entry uses the identical operations and assertions as gxi.
(import :tao3k/agentic-ai-lab/t/context-actor-cost-test)
(export main)
(def (main directory) (actor-cost-probe directory))
