;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Product module-authoring public owner; shared mechanisms are imported from Core.
(import "semantic-module.ss" "module-interface.ss" "module-source-collection.ss"
        (only-in "module-descriptor.ss"
                 agentic-ai-lab-modules agentic-ai-lab-module-closure
                 agentic-ai-lab-module-names)
        (only-in "module-option-projection.ss"
                 agentic-ai-lab-module-option-schemas
                 agentic-ai-lab-module-validation-receipts))
(export agentic-ai-lab-modules agentic-ai-lab-module-closure agentic-ai-lab-module-names
        agentic-ai-lab-module-option-schemas agentic-ai-lab-module-validation-receipts
        (import: "semantic-module.ss")
        (import: "module-interface.ss")
        (import: "module-source-collection.ss"))
