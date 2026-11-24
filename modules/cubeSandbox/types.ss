;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: CubeSandbox Yuanxu module scope type.
(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :clan/poo/type define-type Type.))
(export CubeSandboxScope)

(define-type (CubeSandboxScope @ Type.)
  identity: 'cubeSandbox/scope
  .element?: (lambda (value)
               (and (object? value)
                    (.slot? value 'library)
                    (eq? (.ref value 'library) 'tao3k/agentic-ai-lab/modules/cubeSandbox/interface))))
