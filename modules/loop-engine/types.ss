;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-engine contracts, result types, and runtime vocabulary.

(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :clan/poo/type define-type Type.)
        "contract.ss"
        "kind-contract.ss"
        "result-contract.ss"
        "proof-abi.ss"
        "runtime-vocabulary.ss")

(export LoopEngineScope
        (import: "contract.ss")
        (import: "kind-contract.ss")
        (import: "result-contract.ss")
        (import: "proof-abi.ss")
        (import: "runtime-vocabulary.ss"))

(define-type (LoopEngineScope @ Type.)
  identity: 'loop-engine/scope
  .element?: (lambda (value)
               (and (object? value)
                    (.slot? value 'library)
                    (eq? (.ref value 'library) 'tao3k/agentic-ai-lab/modules/loop-engine/interface))))
