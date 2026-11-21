;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; The service declaration boundary is a closed, extensible POO Type.
(import :clan/poo/object
        (only-in :clan/poo/object-contract ObjectContract.))
(export Services)

;; A service becomes legal by contributing a typed responsibility. Deriving
;; this Type never creates another registry or grants unknown fields a fallback.
(.def (Services @ ObjectContract.)
  identity: 'Services
  responsibilities: (.o))
