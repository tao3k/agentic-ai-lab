;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Interpret the shared parser-owned property projection; no line parser or caller graph.
;;; Initial anchors are document IDs and IDs of selected ordinary headlines.
(import (only-in :clan/poo/object .o .ref)
        (only-in :std/list/list every delete-duplicates/hash find)
        (only-in :tao3k/agentic-ai-lab/modules/query/semantic/orgize-source-interface
                 org-source-headline-parser-identity)
        "types.ss" "objects.ss" "funs-org-properties.ss" "funs-projection.ss" "funs-scope.ss")
(export agentic-ai-lab-ai-agentic-context-org-anchors
        agentic-ai-lab-ai-agentic-context-org-anchors-replay)

(def (id-properties source)
  (let* ((properties (filter (cut agentic-ai-lab-ai-agentic-context-org-property-key? <> "ID")
                             (agentic-ai-lab-ai-agentic-context-org-properties source)))
         (ids (map (cut .ref <> 'value) properties)))
    (when (> (length properties) 256) (error "Org anchor capacity exceeded"))
    (unless (every string? ids) (error "Empty Org property ID"))
    (unless (every (lambda (id) (<= (string-length id) 256)) ids)
      (error "Org property ID exceeds bound"))
    (unless (= (length ids) (length (delete-duplicates/hash ids)))
      (error "Ambiguous duplicate Org property ID"))
    properties))

(def (agentic-ai-lab-ai-agentic-context-org-anchors source projection expected-scope ids)
  (unless (and (list? ids) (<= 1 (length ids) 32)
               (every (lambda (id) (and (string? id) (< 0 (string-length id) 257))) ids)
               (= (length ids) (length (delete-duplicates/hash ids))))
    (error "Org anchor request requires unique bounded IDs"))
  (let* ((verified (agentic-ai-lab-ai-agentic-context-org-replay source projection expected-scope))
         (scope (.ref verified 'scope))
         (properties (id-properties source))
         (rows (.ref (.ref (.ref verified 'observation) 'result-set) 'rows))
         (starts (map (lambda (row)
                        (.ref (find (lambda (cell) (eq? (.ref cell 'field) 'byte-start))
                                    (.ref row 'cells))
                              'value))
                      rows))
         (source-digest (string-copy (.ref verified 'source-digest)))
         (projection-digest (string-copy (.ref verified 'semantic-digest)))
         (scope-digest (string-copy (.ref scope 'semantic-digest)))
         (session (let (s (.ref scope 'session))
                    (unless (string? s) (error "Org Session anchor requires exact Session/Turn"))
                    (string-copy s)))
         (turn (.ref scope 'turn))
         (parser-identity org-source-headline-parser-identity))
    (map (lambda (requested-id)
           (let (prop (or (find (lambda (p) (equal? (.ref p 'value) requested-id)) properties)
                          (error "Unknown Org property ID" requested-id)))
             (unless (or (eq? (.ref prop 'container-kind) 'OrgFile)
                         (member (.ref prop 'container-start) starts))
               (error "Org anchor is outside selected headline Context" requested-id))
             (let* ((org-id (string-copy (.ref prop 'value)))
                    (container-kind (.ref prop 'container-kind))
                    (container-start (.ref prop 'container-start))
                    (value-start (.ref prop 'value-start))
                    (value-end (.ref prop 'value-end))
                    (semantic-digest
                     (agentic-ai-lab-ai-agentic-context-digest
                      (list 'org-property-anchor-v1 org-id container-kind container-start
                            value-start value-end source-digest parser-identity
                            projection-digest scope-digest session turn))))
               (.o (:: @ AiAgenticContextOrgAnchor.)
                   org-id container-kind container-start value-start value-end
                   source-digest parser-identity projection-digest scope-digest
                   session turn semantic-digest))))
         ids)))

(def (agentic-ai-lab-ai-agentic-context-org-anchors-replay source projection scope anchors)
  (unless (and (list? anchors) (every agentic-ai-lab-ai-agentic-context-org-anchor-shape? anchors))
    (error "Invalid Context Org anchor proposal"))
  (let (fresh (agentic-ai-lab-ai-agentic-context-org-anchors
               source projection scope (map (cut .ref <> 'org-id) anchors)))
    (unless (every (lambda (pair)
                     (every (lambda (key) (equal? (.ref (car pair) key) (.ref (cdr pair) key)))
                            '(kind org-id container-kind container-start value-start value-end
                              source-digest parser-identity projection-digest scope-digest
                              session turn semantic-digest source-authenticated? action-authorized?)))
                   (map cons anchors fresh))
      (error "Org anchor substitution"))
    fresh))
