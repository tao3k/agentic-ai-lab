;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :clan/poo/mop Type. define-type))
(export NonoSandboxScope)

(define-type (NonoSandboxScope @ Type.)
  identity: 'nono-sandbox/scope
  .element?: (lambda (scope)
    (and (object? scope)
         (.slot? scope 'profile-config)
         (procedure? (.ref scope 'profile-config)))))
