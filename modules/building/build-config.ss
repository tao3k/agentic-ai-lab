;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: extensible POO configuration for build-projection observation.
;;; Callers derive named policies with `.def`; ambient environment variables do
;;; not participate in policy composition.

(import (only-in :clan/poo/object .def))

(export poo-flow-build-observability-policy-prototype
        poo-flow-default-build-observability-policy)

(.def poo-flow-build-observability-policy-prototype
  id: 'build-projection/package
  profile: 'package
  enabled?: #t
  ;; The default policy reports measured cardinality without inventing a
  ;; machine-independent package-size limit.  A project or CI profile that has
  ;; a measured baseline derives this object with `.def` and supplies its own
  ;; positive budget and admission action.
  target-budget: #f
  target-budget-action: 'observe
  projection-budget-ms: #f
  projection-budget-action: 'observe
  emit-executor-handoff?: #t)

(.def (poo-flow-default-build-observability-policy
       @ poo-flow-build-observability-policy-prototype)
  id: 'build-projection/package)
