;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Public engine-neutral Proof core interface.
(import (only-in :clan/poo/object .def .o)
        "types.ss" "objects.ss" "funs.ss" "config.ss")
(export Proof
        (import: "types.ss")
        (import: "objects.ss")
        (import: "funs.ss")
        (import: "config.ss"))

(.def Proof
  identity: 'proof
  tags: '(proof verification)
  core: (.o scope-contract: ProofScope
            exports: (.o library: 'tao3k/agentic-ai-lab/modules/proof/interface))
  features: (.o))
