;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Optional Yuanxu Feature refinement for `(graph-engine +sqlite-turso)`.
;;; Never loaded unless explicitly selected by a Marlin/runtime host.

(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :clan/poo/type Type. define-type)
        (only-in "./adapter.ss"
                 plan-turso-substrate-envelope
                 durable-trunk-open
                 durable-trunk-close!
                 durable-trunk-execute-handoff!
                 durable-trunk-execute-marlin-dispatch!
                 durable-trunk-commit-step!
                 durable-trunk-recover))

(export GraphEngineSqliteTursoExports
        GraphEngineSqliteTursoContract
        EnableGraphEngineSqliteTurso)

(def GraphEngineSqliteTursoExports
  (.o bind-these: #f
      substrate: 'sqlite-turso
      plan-envelope: plan-turso-substrate-envelope
      open: durable-trunk-open
      close!: durable-trunk-close!
      execute-handoff!: durable-trunk-execute-handoff!
      execute-marlin-dispatch!: durable-trunk-execute-marlin-dispatch!
      commit-step!: durable-trunk-commit-step!
      recover: durable-trunk-recover))

(define-type (GraphEngineSqliteTursoContract @ Type.)
  identity: 'graph-engine/sqlite-turso-feature
  .element?: (lambda (scope)
    (and (object? scope)
         (.slot? scope 'sqlite-turso)
         (object? (.ref scope 'sqlite-turso)))))

(def (EnableGraphEngineSqliteTurso inherited)
  (.o (:: self inherited)
      sqlite-turso: GraphEngineSqliteTursoExports))
