;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: inert agent harness/runtime vocabulary.
;;; Invariant: vocabulary constants do not import harness object families.

(export +poo-flow-agent-operation-kinds+
        +poo-flow-runtime-snapshot-statuses+
        poo-flow-agent-operation-kind?
        poo-flow-runtime-snapshot-status?)

;;; Operation kind names are stable user/agent-facing vocabulary. Runtime
;;; adapters may lower them differently, but projections keep these symbols.
;; : [AgentOperationKind]
(def +poo-flow-agent-operation-kinds+
  '(prompt skill task shell fs-read fs-write compact governor-judge human-audit))

;;; Snapshots are shallow UI/CLI projections over richer receipts and runtime
;;; objects. They are not the canonical execution state.
;; : [RuntimeSnapshotStatus]
(def +poo-flow-runtime-snapshot-statuses+
  '(idle admitted connecting running blocked waiting-human completed errored disconnected))

;; : (-> Symbol Boolean)
(def (poo-flow-agent-operation-kind? kind)
  (and (member kind +poo-flow-agent-operation-kinds+) #t))

;; : (-> Symbol Boolean)
(def (poo-flow-runtime-snapshot-status? status)
  (and (member status +poo-flow-runtime-snapshot-statuses+) #t))
