;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import "objects.ss" "types.ss"
        (only-in :std/source this-source-file)
        (only-in :tao3k/yuanxu/configuration/json config-json-file config-defaults))
(export Document Config PostgreSQLScope)
(def Document
  (config-json-file (path-expand "postgresql.json" (path-directory (this-source-file)))))
(def Config
  (config-defaults (.o settings: (.o port: 5432) allowed-ports: '(5432))
                   (.get Document value)))

(def PostgreSQLScope
  (.o (:: @ PostgreSQL.) config: Config document: Document
      types: (.o port: Port Config: PostgreSQLConfigContract)))
