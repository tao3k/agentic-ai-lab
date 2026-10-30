;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Product source policy only. Core owns inert inspection and receipt projection.
(import (only-in :clan/poo/object .o)
        (only-in :yuanxu/module-system/authoring/import-policy SourceInspectionPolicy.)
        (only-in :yuanxu/module-system/source/collection yuanxu-default-module-style-policy))
(export AgenticAILabSourcePolicy AgenticAILabModuleStylePolicy)
(def AgenticAILabSourcePolicy
  (.o (:: @ SourceInspectionPolicy.)
      aggregate-imports:
      '(:yuanxu/modules/funflow/control-plane/api
        :agentic-ai-lab/modules/workflow/scenario/configuration/interface
        :yuanxu/feature-system/interface)
      package-prefix: ":agentic-ai-lab/"
      source-roots: '("./src/" "src/" "./modules/" "modules/")
      forbidden-projections: '(yuanxu-module-source-collection-interfaces all-gerbil-modules modules)))

(def AgenticAILabModuleStylePolicy
  (.o (:: @ yuanxu-default-module-style-policy)
      source-policy: AgenticAILabSourcePolicy))
