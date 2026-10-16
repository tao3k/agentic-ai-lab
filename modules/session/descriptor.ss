;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Inert descriptor owned by the independent Session Module.
(import (only-in :clan/poo/object .o)
        (only-in :poo-flow/modules/module-authoring/module-interface poo-flow-module-interface)
        (only-in :poo-flow/modules/module-authoring/module-descriptor pooFlowModules))
(export +poo-flow-session-default-flags+ poo-flow-session-module)
(def +poo-flow-session-default-flags+
  '(+lineage +placement +handoff +graph +transform +doctor))
(def (poo-flow-session-module)
  (pooFlowModules
    (poo-flow-module-interface 'session (.o) '())
    (.o id: 'session group: 'session
        flags: +poo-flow-session-default-flags+)))
