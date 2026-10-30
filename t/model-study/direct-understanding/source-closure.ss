;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :gerbil/compiler/driver :gerbil/expander :std/encoding/json)
(displayln "MODULE-OK :gerbil/compiler/driver") (force-output)
(let* ((ctx (import-module ':gerbil-ascent/program/scheme-language))
       (deps (gxc#find-runtime-module-deps ctx)))
  (displayln (json->string
    (map (lambda (dep) (symbol->string (expander-context-id dep)))
         (append deps (list ctx))))))
(displayln "HARNESS-OK source-closure") (displayln "OK") (force-output)
