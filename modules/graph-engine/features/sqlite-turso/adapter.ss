;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Optional Marlin / Turso (SQLite-compatible MVCC/WAL) Substrate Adapter for
;;; `(graph-engine +sqlite-turso)` (`modules/graph-engine/features/sqlite-turso/adapter.ss`).
;;;
;;; INVARIANT (Yuanxu INV-6 & 10.07 Runtime ABI):
;;; - Lives strictly inside the optional `+sqlite-turso` Feature and is NEVER
;;;   loaded by pure `(graph-engine)` core!
;;; - Models Turso / SQLite-compatible storage strictly as a durable runtime
;;;   substrate for AI concurrent branch writes, NEVER as a policy engine.
;;; - Executes pure `JournalHandoffIntent.` values from `journal-handoff.ss`
;;;   against the local SQLite/WAL substrate OR emits a Turso/Marlin substrate
;;;   envelope (`plan-turso-substrate-envelope`) for Marlin / `pyturso` handoff.

(import (only-in :clan/poo/object .o .ref)
        (only-in :tao3k/agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
                 journal-open
                 journal-close!
                 journal-epoch
                 journal-get
                 journal-put!
                 journal-evidence!
                 journal-receive!
                 journal-begin!
                 journal-commit!
                 journal-terminal!
                 journal-verify!)
        (only-in "../../journal-handoff.ss"
                 plan-trunk-journal-handoff
                 project-recovered-trunk-receipt))

(export plan-turso-substrate-envelope
        durable-trunk-open
        durable-trunk-close!
        durable-trunk-execute-handoff!
        durable-trunk-commit-step!
        durable-trunk-recover)

;;; Project a pure `JournalHandoffIntent.` into a Turso/Marlin durable substrate
;;; envelope suitable for `RuntimeDurableAdapter.turso_from_envelope` handoff.
(def (plan-turso-substrate-envelope intent db-uri: (db-uri "file:graph-engine-turso.db"))
  (.o bind-these: #f
      kind: 'agentic-ai-lab.graph-engine.sqlite-turso-envelope.v1
      substrate: 'sqlite-turso
      concurrency-mode: 'turso-mvcc-wal
      policy-authority: 'none
      db-uri: db-uri
      handoff-intent: intent
      runtime-executed?: #f))

(def (durable-trunk-open db-path)
  (journal-open db-path))

(def (durable-trunk-close! journal)
  (journal-close! journal))

;;; Execute a pure `JournalHandoffIntent.` at the SQLite/Turso WAL substrate boundary.
(def (durable-trunk-execute-handoff! journal intent)
  (let ((event-id (.ref intent 'event-id))
        (event-payload (.ref intent 'event-payload))
        (state-key (.ref intent 'state-key))
        (snap (.ref intent 'inert-snapshot))
        (evs (.ref intent 'immutable-evidence-records))
        (term (.ref intent 'terminal-record)))
    ;; 1. Persist immutable evidence records first (fail-closed on replacement!)
    (for-each
     (lambda (pair) (journal-evidence! journal (car pair) (cdr pair)))
     evs)
    ;; 2. Inbox admission precedes decision transaction
    (journal-receive! journal event-id event-payload)
    ;; 3. Fenced transaction writing inert trunk snapshot + optional Apex terminal
    (journal-begin! journal event-id)
    (journal-put! journal state-key snap)
    (when term
      (journal-terminal! journal term))
    (journal-commit! journal)
    (.o bind-these: #f
        committed?: #t
        substrate: 'sqlite-turso
        event-id: event-id
        journal-epoch: (journal-epoch journal)
        trunk-id: (.ref intent 'trunk-id)
        apex-status: (.ref intent 'apex-status))))

(def (durable-trunk-commit-step! journal event-id event-payload trunk)
  (durable-trunk-execute-handoff!
   journal
   (plan-trunk-journal-handoff event-id event-payload trunk)))

(def (durable-trunk-recover journal task-flow-registry: (task-flow-registry '()))
  (let* ((head-hash (journal-verify! journal))
         (snap (journal-get journal "graph-engine:trunk")))
    (project-recovered-trunk-receipt
     snap
     journal-epoch: (journal-epoch journal)
     chain-head-hash: head-hash
     task-flow-registry: task-flow-registry)))
