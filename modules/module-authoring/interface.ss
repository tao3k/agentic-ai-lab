;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Product module-authoring public owner; shared mechanisms are imported from Core.
(import (only-in :clan/poo/object .def .o)
        "types.ss"
        "semantic-module.ss"
        "module-interface.ss"
        "module-source-collection.ss"
        "module-descriptor.ss"
        "module-option-projection.ss")
(export ModuleAuthoring
        (import: "types.ss")
        (import: "semantic-module.ss")
        (import: "module-interface.ss")
        (import: "module-source-collection.ss")
        (import: "module-descriptor.ss")
        (import: "module-option-projection.ss"))

(.def ModuleAuthoring
  identity: 'module-authoring
  tags: '(module-system authoring)
  core: (.o scope-contract: ModuleAuthoringScope
            exports: (.o library: 'tao3k/agentic-ai-lab/modules/module-authoring/interface
                         modules: agentic-ai-lab-modules
                         closure: agentic-ai-lab-module-closure
                         names: agentic-ai-lab-module-names
                         option-schemas: agentic-ai-lab-module-option-schemas
                         validation-receipts: agentic-ai-lab-module-validation-receipts))
  features: (.o))
