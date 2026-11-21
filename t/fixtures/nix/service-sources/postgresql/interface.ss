;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .def .o)
        (only-in "./types.ss" PostgreSQLScopeContract)
        (only-in "./config.ss" PostgreSQLScope))
(export PostgreSQL)

(.def PostgreSQL
  identity: 'services/postgresql
  core:
  (.o scope-contract: PostgreSQLScopeContract
      exports: PostgreSQLScope))
