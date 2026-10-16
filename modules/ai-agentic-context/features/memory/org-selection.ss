;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; POO Flow selects through Orgize's Scheme POO query runtime. Orgize owns
;;; parsing, Element facts, query meaning and memory headline projection.
;;; The caller owns authentication of the graph against its source cut.

(import (only-in :clan/poo/object .o .ref object?)
        :poo-flow/modules/session/objects
        (only-in :poo-flow/modules/query/semantic/orgize-interface
                 org-element-graph-view?
                 org-element-graph-id-of
                 org-named-element-query?
                 org-named-element-query-id
                 org-named-element-query-query
                 make-org-element-query-context
                 org-element-select))

(export poo-flow-memory-org-select
        poo-flow-memory-org-selection?)

(def (poo-flow-memory-org-nonempty-string? value)
  (and (string? value) (> (string-length value) 0)))

(def (poo-flow-memory-org-record-id? value)
  (and (integer? value) (>= value 0)))

;;; The result is a source-scoped proposal, not a parser, memory snapshot,
;;; semantic admission, or published head. The host must attest that graph
;;; and named-query came from the declared current Orgize/source revision.
(def (poo-flow-memory-org-select project-id
                                 worktree-id
                                 source-path
                                 source-cut-digest
                                 bytes-sha256
                                 graph
                                 named-query
                                 scope-record-id)
  (poo-flow-session-require "Org selection requires project and WorkTree ids"
                            (and (poo-flow-memory-org-nonempty-string? project-id)
                                 (poo-flow-memory-org-nonempty-string? worktree-id))
                            (list project-id worktree-id))
  (poo-flow-session-require "Org selection requires source identity"
                            (and (poo-flow-memory-org-nonempty-string? source-path)
                                 (poo-flow-memory-org-nonempty-string?
                                  source-cut-digest)
                                 (poo-flow-memory-org-nonempty-string?
                                  bytes-sha256))
                            (list source-path source-cut-digest bytes-sha256))
  (poo-flow-session-require "Org selection requires an Orgize graph view"
                            (org-element-graph-view? graph)
                            graph)
  (poo-flow-session-require "Org selection requires an Orgize named query"
                            (org-named-element-query? named-query)
                            named-query)
  (poo-flow-session-require "Org selection requires an Element scope id"
                            (poo-flow-memory-org-record-id? scope-record-id)
                            scope-record-id)
  (let* ((context (make-org-element-query-context graph))
         (records (org-element-select
                   (org-named-element-query-query named-query)
                   context scope-record-id (list scope-record-id)))
         (id-of (org-element-graph-id-of graph))
         (ids (map id-of records)))
    (poo-flow-session-require "Org selection exceeds the candidate bound"
                              (<= (length ids) 4096)
                              (length ids))
    (poo-flow-session-require "Orgize selection returned invalid Element ids"
                              (poo-flow-session-every?
                               poo-flow-memory-org-record-id? ids)
                              ids)
    (let ((project-value project-id)
          (worktree-value worktree-id)
          (path-value source-path)
          (cut-value source-cut-digest)
          (bytes-value bytes-sha256)
          (query-value (org-named-element-query-id named-query))
          (scope-value scope-record-id)
          (candidate-values ids))
      (.o (kind 'poo-flow.memory-core.org-selection)
          (schema 'poo-flow.modules.memory-core.org-selection.v1)
          (project-id project-value)
          (worktree-id worktree-value)
          (source-path path-value)
          (source-cut-digest cut-value)
          (bytes-sha256 bytes-value)
          (query-id query-value)
          (scope-record-id scope-value)
          (candidate-record-ids candidate-values)
          (orgize-evaluated? #t)
          (semantic-admitted? #f)
          (memory-published? #f)))))

(def (poo-flow-memory-org-selection? value)
  (and (object? value)
       (eq? (.ref value 'kind) 'poo-flow.memory-core.org-selection)))
