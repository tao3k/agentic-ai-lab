;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Session-owned pure policy gate for an Orgize Scheme selection.
;;; Neither a query result nor this intent admits MRR semantics or publishes
;;; a Memory head. Current source and grant facts come from the host. The
;;; supplied graph is not yet bound to parser-owned source bytes, so policy
;;; eligibility must not be mistaken for source-admission eligibility.

(import (only-in :clan/poo/object .o .ref object?)
        :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/session/transform-support/memory-intent
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/objects-core
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/org-selection)

(export agentic-ai-lab-session-org-memory-selection-context
        agentic-ai-lab-session-org-memory-selection-context?
        agentic-ai-lab-session-org-memory-selection-intent
        agentic-ai-lab-session-org-memory-selection-intent?
        agentic-ai-lab-session-org-memory-selection-intent-policy-eligible?
        agentic-ai-lab-session-org-memory-selection-intent-eligible?
        agentic-ai-lab-session-org-memory-selection-intent-diagnostics)

(def (agentic-ai-lab-session-org-nonempty-string? value)
  (and (string? value) (> (string-length value) 0)))

(def (agentic-ai-lab-session-org-memory-selection-context project-id
                                                    worktree-id
                                                    current-cut-digest
                                                    current-bytes-sha256
                                                    allowed-query-id
                                                    expected-head-revision
                                                    current-head-revision
                                                    read-granted?
                                                    session-active?)
  (agentic-ai-lab-session-require "selection context requires project and WorkTree ids"
                            (and (agentic-ai-lab-session-org-nonempty-string? project-id)
                                 (agentic-ai-lab-session-org-nonempty-string? worktree-id))
                            (list project-id worktree-id))
  (agentic-ai-lab-session-require "selection context requires source and query ids"
                            (and (agentic-ai-lab-session-org-nonempty-string?
                                  current-cut-digest)
                                 (agentic-ai-lab-session-org-nonempty-string?
                                  current-bytes-sha256)
                                 (agentic-ai-lab-session-org-nonempty-string?
                                  allowed-query-id))
                            (list current-cut-digest current-bytes-sha256
                                  allowed-query-id))
  (agentic-ai-lab-session-require "head revisions must be nonnegative integers"
                            (and (integer? expected-head-revision)
                                 (>= expected-head-revision 0)
                                 (integer? current-head-revision)
                                 (>= current-head-revision 0))
                            (list expected-head-revision current-head-revision))
  (agentic-ai-lab-session-require "grant and Session state must be booleans"
                            (and (boolean? read-granted?)
                                 (boolean? session-active?))
                            (list read-granted? session-active?))
  (let ((project-value project-id)
        (worktree-value worktree-id)
        (cut-value current-cut-digest)
        (bytes-value current-bytes-sha256)
        (query-value allowed-query-id)
        (expected-value expected-head-revision)
        (current-value current-head-revision)
        (grant-value read-granted?)
        (active-value session-active?))
    (.o (kind 'agentic-ai-lab.session.org-memory-selection-context)
        (project-id project-value)
        (worktree-id worktree-value)
        (current-cut-digest cut-value)
        (current-bytes-sha256 bytes-value)
        (allowed-query-id query-value)
        (expected-head-revision expected-value)
        (current-head-revision current-value)
        (read-granted? grant-value)
        (session-active? active-value))))

(def (agentic-ai-lab-session-org-memory-selection-context? value)
  (and (object? value)
       (eq? (.ref value 'kind) 'agentic-ai-lab.session.org-memory-selection-context)))

(def (agentic-ai-lab-session-org-memory-selection-diagnostics selection intent store context)
  (filter
   (lambda (diagnostic) diagnostic)
   (list
    (and (not (and (equal? (.ref selection 'project-id)
                           (.ref context 'project-id))
                   (equal? (.ref selection 'worktree-id)
                           (.ref context 'worktree-id))))
         'foreign-scope)
    (and (not (equal? (.ref selection 'source-cut-digest)
                      (.ref context 'current-cut-digest)))
         'stale-source-cut)
    (and (not (equal? (.ref selection 'bytes-sha256)
                      (.ref context 'current-bytes-sha256)))
         'stale-org-bytes)
    (and (not (equal? (.ref selection 'query-id)
                      (.ref context 'allowed-query-id)))
         'query-not-granted)
    (and (not (and (equal? (agentic-ai-lab-session-memory-intent-store-ref intent)
                           (agentic-ai-lab-memory-store-spec-ref store))
                   (member (agentic-ai-lab-session-memory-intent-scope intent)
                           (agentic-ai-lab-memory-store-spec-scopes store))
                   (member (agentic-ai-lab-session-memory-intent-commit-policy intent)
                           (agentic-ai-lab-memory-store-spec-commit-policies store))))
         'memory-policy-denied)
    (and (not (.ref context 'read-granted?)) 'read-not-granted)
    (and (not (.ref context 'session-active?)) 'session-inactive)
    (and (not (= (.ref context 'expected-head-revision)
                 (.ref context 'current-head-revision)))
         'stale-memory-head)
    (and (null? (.ref selection 'candidate-record-ids)) 'no-candidate))))

(def (agentic-ai-lab-session-org-memory-selection-intent selection intent store session context)
  (agentic-ai-lab-session-require "Org selection requires an Orgize Scheme selection"
                            (agentic-ai-lab-memory-org-selection? selection)
                            selection)
  (agentic-ai-lab-session-require "Org selection requires a Session memory intent"
                            (agentic-ai-lab-session-memory-intent? intent)
                            intent)
  (agentic-ai-lab-session-require "Org selection requires a Memory store spec"
                            (agentic-ai-lab-memory-store-spec? store)
                            store)
  (agentic-ai-lab-session-require "Org selection requires a Session"
                            (agentic-ai-lab-session? session)
                            session)
  (agentic-ai-lab-session-require "Org selection requires current host context"
                            (agentic-ai-lab-session-org-memory-selection-context? context)
                            context)
  (let ((policy-diagnostic-values
         (agentic-ai-lab-session-org-memory-selection-diagnostics
          selection intent store context))
        (session-value (agentic-ai-lab-session-id session))
        (selection-value selection)
        (intent-value intent)
        (head-value (.ref context 'expected-head-revision)))
    (.o (kind 'agentic-ai-lab.session.org-memory-selection-intent)
        (schema 'agentic-ai-lab.modules.session.org-memory-selection.v1)
        (session-id session-value)
        (org-selection selection-value)
        (memory-intent intent-value)
        (expected-head-revision head-value)
        (policy-eligible? (null? policy-diagnostic-values))
        (eligible? #f)
        (diagnostics (append policy-diagnostic-values
                             '(unverified-source-graph)))
        (semantic-admitted? #f)
        (memory-published? #f))))

(def (agentic-ai-lab-session-org-memory-selection-intent? value)
  (and (object? value)
       (eq? (.ref value 'kind) 'agentic-ai-lab.session.org-memory-selection-intent)))

(def (agentic-ai-lab-session-org-memory-selection-intent-eligible? value)
  (.ref value 'eligible?))

(def (agentic-ai-lab-session-org-memory-selection-intent-policy-eligible? value)
  (.ref value 'policy-eligible?))

(def (agentic-ai-lab-session-org-memory-selection-intent-diagnostics value)
  (.ref value 'diagnostics))
