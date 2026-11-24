;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: ModuleAuthoring Yuanxu module scope type.
(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :clan/poo/type define-type Type.))
(export ModuleAuthoringScope)

(define-type (ModuleAuthoringScope @ Type.)
  identity: 'module-authoring/scope
  .element?: (lambda (value)
               (and (object? value)
                    (.slot? value 'modules) (procedure? (.ref value 'modules))
                    (.slot? value 'closure) (procedure? (.ref value 'closure))
                    (.slot? value 'names) (procedure? (.ref value 'names)))))
