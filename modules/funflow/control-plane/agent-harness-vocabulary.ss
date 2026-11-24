;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: inert agent harness/runtime vocabulary.
;;; Invariant: vocabulary constants do not import harness object families.

(export +yuanxu-agent-operation-kinds+
        +yuanxu-runtime-snapshot-statuses+
        yuanxu-agent-operation-kind?
        yuanxu-runtime-snapshot-status?)

;;; Operation kind names are stable user/agent-facing vocabulary. Runtime
;;; adapters may lower them differently, but projections keep these symbols.
;; : [AgentOperationKind]
(def +yuanxu-agent-operation-kinds+
  '(prompt skill task shell fs-read fs-write compact governor-judge human-audit))

;;; Snapshots are shallow UI/CLI projections over richer receipts and runtime
;;; objects. They are not the canonical execution state.
;; : [RuntimeSnapshotStatus]
(def +yuanxu-runtime-snapshot-statuses+
  '(idle admitted connecting running blocked waiting-human completed errored disconnected))

;; : (-> Symbol Boolean)
(def (yuanxu-agent-operation-kind? kind)
  (and (member kind +yuanxu-agent-operation-kinds+) #t))

;; : (-> Symbol Boolean)
(def (yuanxu-runtime-snapshot-status? status)
  (and (member status +yuanxu-runtime-snapshot-statuses+) #t))
