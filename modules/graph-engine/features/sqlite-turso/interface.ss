;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Optional Yuanxu Feature declaration for `(graph-engine +sqlite-turso)`.
;;; Pure `(graph-engine)` core NEVER loads SQLite/Turso (Yuanxu INV-6);
;;; Turso/SQLite persistence activates ONLY at the Marlin/runtime boundary
;;; when explicitly opted in (`implied-modules: '()`).

(import (only-in :clan/poo/object .def)
        (only-in "./objects.ss"
                 EnableGraphEngineSqliteTurso
                 GraphEngineSqliteTursoContract))
(export Feature)

(.def Feature
  requires: '()
  implied-modules: '()
  refine: EnableGraphEngineSqliteTurso
  contract: GraphEngineSqliteTursoContract)
