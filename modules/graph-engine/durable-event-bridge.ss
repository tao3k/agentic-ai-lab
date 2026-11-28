;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Durable Work Journal -> Post-ReAct `ObligationGraph` Event Bridge
;;; (`modules/loop-engine/durable-event-bridge.ss`):
;;; Projects pure `modules/durable/work/` snapshots & journal events onto the
;;; Post-ReAct ASCENT Obligation-Fixpoint Reconciler (`obligation-graph.ss` +
;;; `ascent-reconciler.ss` + `synthesis-oracle.ss`).
;;;
;;; Directly closes real Codex (#34043, #54855) resume-deadlock & unclosed-
;;; subagent hang failure modes: every unclosed crash attempt or open blocker
;;; detour projects as an explicit `active-defeater` on the root obligation,
;;; preventing silent infinite waiting or premature archive.

(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :std/list/list filter)
        "obligation-graph.ss")

(export work-snapshot->obligation-graph
        durable-journal-event->obligation-event)

(def (opt-ref obj key default)
  (if (and (object? obj) (.slot? obj key))
    (.ref obj key)
    default))

(def (as-string v)
  (cond
   ((string? v) v)
   ((symbol? v) (symbol->string v))
   ((number? v) (number->string v))
   (else "unknown")))

;;; Projects a Durable Work snapshot + journal state into a Post-ReAct
;;; `ObligationGraph` ready for `ascent-reconcile-frontier` /
;;; `reconcile-to-fixed-point` / `reconcile-event-stream`.
(def (work-snapshot->obligation-graph
      snapshot
      journal-state
      det-tasks: (det-tasks '())
      synthesis-holes: (synthesis-holes '())
      hypotheses: (hypotheses '())
      cut: (cut 1))
  (let* ((task-id (as-string (opt-ref snapshot 'task-id "work-task")))
         (root-id (as-string (opt-ref snapshot 'root-id task-id)))
         (root-title (as-string (opt-ref snapshot 'root-title task-id)))
         (root-done? (eq? (opt-ref snapshot 'root-status 'todo) 'done))
         (open-blockers (opt-ref snapshot 'open-blocker-detours '()))
         (unsat-invs (opt-ref snapshot 'unsatisfied-invariants '()))
         (unclosed-attempts (opt-ref journal-state 'unclosed-attempts '()))
         (cedar-live? (opt-ref journal-state 'cedar-grant-live? #t))
         (mcp-ok? (opt-ref journal-state 'mcp-manifest-healthy? #t))
         ;; Unclosed attempts & open blockers become explicit active defeaters on root
         ;; (directly prevents Codex #34043 / #54855 silent resume deadlocks!)
         (attempt-defeaters
          (map (lambda (aid) (string-append "unclosed-attempt:" (as-string aid)))
               unclosed-attempts))
         (blocker-defeaters
          (map (lambda (b)
                 (string-append "open-blocker:"
                                (as-string (if (object? b) (opt-ref b 'detour-id b) b))))
               open-blockers))
         (inv-defeaters
          (map (lambda (inv)
                 (string-append "unsatisfied-invariant:"
                                (as-string (if (object? inv) (opt-ref inv 'id inv) inv))))
               unsat-invs))
         (all-root-defeaters (append attempt-defeaters blocker-defeaters inv-defeaters))
         ;; Project DAG nodes into child obligations
         (dag-nodes (opt-ref snapshot 'dag-nodes '()))
         (node-obs
          (map (lambda (n)
                 (let* ((nid (as-string (if (object? n) (opt-ref n 'id (opt-ref n 'node-id "node")) n)))
                        (deps (if (object? n) (map as-string (opt-ref n 'deps '())) '()))
                        (ev-id (string-append "ev:node:" nid)))
                   (make-obligation
                    nid
                    title: (string-append "Work node " nid)
                    required-evidence-ids: (list ev-id)
                    depends-on: deps
                    premise-ids: (list (string-append "premise:" nid)))))
               dag-nodes))
         (node-ids (map (lambda (o) (.ref o 'obligation-id)) node-obs))
         ;; Completed DAG nodes / root become verified live EvidenceFacts
         (completed-node-ids (opt-ref journal-state 'completed-node-ids '()))
         (completed-evs
          (map (lambda (nid)
                 (make-evidence-fact
                  (string-append "ev:node:" (as-string nid))
                  'completed
                  cut: cut
                  premise-ids: (list (string-append "premise:" (as-string nid)))))
               completed-node-ids))
         (root-ev-id (string-append "ev:root:" root-id))
         (initial-evs
          (if root-done?
            (append completed-evs (list (make-evidence-fact root-ev-id 'root-done cut: cut)))
            completed-evs))
         (root-ob
          (make-obligation
           root-id
           title: root-title
           required-evidence-ids: (if (null? node-ids) (list root-ev-id) '())
           depends-on: node-ids
           active-defeaters: all-root-defeaters
           premise-ids: (list (string-append "premise:" root-id)))))
    (make-obligation-graph
     task-id
     cut: cut
     obligations: (append node-obs (list root-ob))
     hypotheses: hypotheses
     evidence: initial-evs
     det-tasks: det-tasks
     synthesis-holes: synthesis-holes
     cedar-grant-live?: cedar-live?
     mcp-manifest-healthy?: mcp-ok?)))

;;; Translates Durable Work / Journal domain events into Post-ReAct
;;; `ObligationGraph` events for `reconcile-event-stream`.
(def (durable-journal-event->obligation-event work-event)
  (case (.ref work-event 'work-event-kind)
    ((work-attempt-interrupted)
     (.o (event-kind := 'defeater-discovered)
         (obligation-id := (as-string (.ref work-event 'root-id)))
         (defeater-id := (string-append "unclosed-attempt:" (as-string (.ref work-event 'attempt-id))))))
    ((work-attempt-recovered)
     (.o (event-kind := 'human-approved)
         (resolve-defeater-id := (string-append "unclosed-attempt:" (as-string (.ref work-event 'attempt-id))))))
    ((work-premise-changed)
     (.o (event-kind := 'premise-retracted)
         (premise-id := (as-string (.ref work-event 'premise-id)))))
    ((work-evidence-verified)
     (.o (event-kind := 'evidence-arrived)
         (evidence := (.ref work-event 'evidence))))
    ((work-cedar-revoked) (.o (event-kind := 'cedar-revoked)))
    ((work-cedar-restored) (.o (event-kind := 'cedar-restored)))
    ((work-mcp-mutated) (.o (event-kind := 'mcp-manifest-mutated)))
    ((work-human-approved)
     (.o (event-kind := 'human-approved)
         (resolve-defeater-id := (opt-ref work-event 'resolve-defeater-id #f))))
    (else (error "Unknown durable work event kind" (.ref work-event 'work-event-kind)))))
