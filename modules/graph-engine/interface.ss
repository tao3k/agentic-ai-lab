;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Public GraphEngine module interface (Style 01: thin declarative POO entry).
;;; Real Turso/SQLite WAL execution lives in optional Feature `+sqlite-turso`.

(import (only-in :clan/poo/object .def .o)
        "types.ss"
        "objects.ss"
        "funs.ss")
(export GraphEngine
        (import: "types.ss")
        (import: "objects.ss")
        (import: "funs.ss"))

(.def GraphEngine
  identity: 'graph-engine
  tags: '(graph-engine control ascent-reconciler funflow-dag convergent-tree cyclic-scc)
  core: (.o (scope-contract := GraphEngineScope)
            (exports := GraphEngineExports.))
  features: '(sqlite-turso))
