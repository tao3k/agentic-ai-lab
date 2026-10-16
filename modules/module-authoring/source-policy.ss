;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Product source policy only. Core owns inert inspection and receipt projection.
(import (only-in :clan/poo/object .o)
        (only-in :core/module-system/authoring/import-policy SourceInspectionPolicy.)
        (only-in :core/module-system/source/collection poo-flow-default-module-style-policy))
(export PooFlowSourcePolicy PooFlowModuleStylePolicy)
(def PooFlowSourcePolicy
  (.o (:: @ SourceInspectionPolicy.)
      aggregate-imports:
      '(:poo-flow/modules/workflow/control-plane/api
        :poo-flow/modules/workflow/scenario/configuration/interface
        :core/feature-system/interface)
      package-prefix: ":poo-flow/"
      source-roots: '("./src/" "src/" "./modules/" "modules/")
      forbidden-projections: '(poo-flow-module-source-collection-interfaces all-gerbil-modules modules)))

(def PooFlowModuleStylePolicy
  (.o (:: @ poo-flow-default-module-style-policy)
      source-policy: PooFlowSourcePolicy))
