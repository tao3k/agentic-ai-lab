;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object o?/slots)
        (only-in :clan/poo/mop define-type Type.))
(export ServiceScopeContract ApplicationScopeContract)
(define-type (ServiceScopeContract @ Type.)
  identity: 'application/service-scope .element?: (o?/slots '(config document types)))
(define-type (ApplicationScopeContract @ Type.)
  identity: 'application/scope .element?: (o?/slots '(Scenario types)))
