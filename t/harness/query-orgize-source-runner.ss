;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Use the original compiler's actual dependency order; report completed imports.
(import :gerbil/compiler/driver :gerbil/expander)
(let* ((ctx (import-module "modules/query/interface.ss"))
       (deps (gxc#find-runtime-module-deps ctx)))
  (for-each (lambda (dep)
    (let* ((id (expander-context-id dep))
           (name (if (symbol? id) (symbol->string id) id)))
      (unless (or (and (>= (string-length name) 7) (equal? (substring name 0 7) "gerbil/"))
                  (member #\~ (string->list name)))
        (let (module (string->symbol (string-append ":" name)))
          (eval `(import ,module))
          (displayln "QUERY-SOURCE-IMPORT-OK " module) (force-output))))) deps))
(import :gerbil/tools/gxtest)
(exit (gerbil/tools/gxtest#main "-v" "5" "t/query-orgize-source-test.ss"))
