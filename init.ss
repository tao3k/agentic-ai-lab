;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Product module source root. Discovery/selection stays an explicit operation.
(import (only-in :clan/poo/object .def)
        (only-in :poo-flow/modules/module-authoring/module-source-collection poo-flow-maintained-module-source))
(export PooFlowModules)

(.def (PooFlowModules @ poo-flow-maintained-module-source))
