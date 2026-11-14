;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .def .get)
        (only-in "./types.ss" DeveloperScopeContract)
        (only-in :tao3k/agentic-ai-lab/modules/workflow/scenario/configuration/presentation-config
                 agenticAiLabUserConfigPresentation)
        (only-in :tao3k/agentic-ai-lab/modules/workflow/scenario/configuration/declaration-case
                 agenticAiLabRootDeveloperDeclarationCase))
(export Developer.)
(.def (Developer. @ (.get DeveloperScopeContract proto) config)
  preview: (agenticAiLabUserConfigPresentation config
             '(surface profile flow-mode loop-strategy sandbox-policy sandbox-backends mode-lock))
  declaration: (agenticAiLabRootDeveloperDeclarationCase config))
