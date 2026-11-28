;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Product building public owner; shared mechanisms are imported from Core.
(import (only-in :clan/poo/object .def .o)
        "types.ss" "build-config.ss" "build-projection.ss" "official-contributions.ss")
(export Building
        (import: "types.ss")
        (import: "build-config.ss")
        (import: "build-projection.ss")
        (import: "official-contributions.ss"))

(.def Building
  identity: 'building
  tags: '(building module-system)
  core: (.o scope-contract: BuildingScope
            exports: (.o library: 'tao3k/agentic-ai-lab/modules/building/interface))
  features: (.o))
