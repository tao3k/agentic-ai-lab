;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Inert descriptor owned by the independent Session Module.
(import (only-in :clan/poo/object .o)
        (only-in :agentic-ai-lab/modules/module-authoring/module-interface yuanxu-module-interface)
        (only-in :agentic-ai-lab/modules/module-authoring/module-descriptor agenticAiLabModules))
(export +agentic-ai-lab-session-default-flags+ agentic-ai-lab-session-module)
(def +agentic-ai-lab-session-default-flags+
  '(+lineage +placement +handoff +graph +transform +doctor))
(def (agentic-ai-lab-session-module)
  (agenticAiLabModules
    (yuanxu-module-interface 'session (.o) '())
    (.o id: 'session group: 'session
        flags: +agentic-ai-lab-session-default-flags+)))
