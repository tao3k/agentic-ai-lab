;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object o?/slots .o .cc)
        (only-in :clan/poo/object-contract ObjectContract.)
        (only-in :clan/poo/mop define-type Type.)
        (only-in :tao3k/yuanxu/types/ports Port valid-port?)
        (only-in :clan/poo/type List)
        (only-in :tao3k/yuanxu/types/contracts YuanxuContract.))
(export Port PostgreSQLValueContract PostgreSQLConfigContract PostgreSQLScopeContract valid-port?)
(def PostgreSQLValueContract
  (.cc ObjectContract. identity: 'postgresql/config-value
    responsibilities:
    (.o settings: (.cc ObjectContract. responsibilities: (.o port: Port))
        allowed-ports: (List Port))))
(define-type (PostgreSQLConfigContract @ YuanxuContract.)
  identity: 'postgresql/config
  value-contract: PostgreSQLValueContract)
;; Scope presence is intentionally metadata-only; it must not force payloads.
(define-type (PostgreSQLScopeContract @ Type.)
  identity: 'postgresql/scope .element?: (o?/slots '(config document)))
