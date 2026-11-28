;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Public domain-neutral Standards core module interface.
(import (only-in :clan/poo/object .def .o)
        "types.ss" "objects.ss" "funs.ss" "loader.ss" "contracts.ss" "config.ss")
(export Standards
        (import: "types.ss")
        (import: "objects.ss")
        (import: "funs.ss")
        (import: "loader.ss")
        (import: "contracts.ss")
        (import: "config.ss"))

(.def Standards
  identity: 'standards
  tags: '(standards policy)
  core: (.o scope-contract: StandardsScope
            exports: (.o library: 'tao3k/agentic-ai-lab/modules/standards/interface))
  features: (.o))
