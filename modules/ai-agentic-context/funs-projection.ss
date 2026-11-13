;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Orgize and canonical Query own selection. This module binds scope and content.
(import (only-in :clan/poo/object .o .ref .slot? object?)
        :tao3k/agentic-ai-lab/modules/query/orgize-source
        :tao3k/agentic-ai-lab/modules/query/semantic/context-restriction
        "funs-scope.ss" "funs-features.ss")
(export agentic-ai-lab-ai-agentic-context-org-project-incremental
        agentic-ai-lab-ai-agentic-context-org-project
        agentic-ai-lab-ai-agentic-context-org-replay)
;; The private replay path may assemble from the canonical observation returned
;; by runtime Query replay in this same call. It never accepts a cached verdict
;; or an observation supplied by a public caller without replaying current bytes.
(def (project scope source restriction profile row-limit byte-limit base-source base-observation
              (replayed-observation #f))
  (unless (and (string? source) (exact-integer? row-limit) (<= 0 row-limit 256)
               (exact-integer? byte-limit) (<= 0 byte-limit 1048576))
    (error "invalid Context source or budget"))
  (when (> (u8vector-length (string->utf8 source)) byte-limit)
    (error "Context source byte budget exceeded"))
  (let* ((scope-value (agentic-ai-lab-ai-agentic-context-scope-admit scope))
         (feature-ids-value (context-profile-feature-ids profile))
         (restriction-value (agentic-ai-lab-context-restriction-compose (list restriction)))
         (observation-value
          (or replayed-observation
              (if base-observation
                (agentic-ai-lab-query-orgize-open-headlines-incremental base-source base-observation source)
                (agentic-ai-lab-query-orgize-open-headlines source))))
         (result (.ref observation-value 'result-set))
         (rows (.ref result 'rows)))
    (when (> (length rows) row-limit) (error "Context row budget exceeded; incomplete selection rejected"))
    (let* ((content-value (map (lambda (row)
                     (cons (.ref row 'identity)
                       (map (lambda (cell) (list (.ref cell 'field) (.ref cell 'value))) (.ref row 'cells)))) rows))
           (binding (list 'ai-agentic-context/org-projection-v1
             (.ref scope-value 'semantic-digest) (.ref observation-value 'parser-identity)
             (.ref observation-value 'source-sha256) (.ref (.ref observation-value 'query) 'identity)
             (.ref result 'semantic-digest) (.ref restriction-value 'semantic-digest)
             feature-ids-value row-limit byte-limit content-value))
           (fingerprint (agentic-ai-lab-ai-agentic-context-digest binding)))
      (.o kind: 'agentic-ai-lab.ai-agentic-context.org-projection.v1
          scope: scope-value observation: observation-value restriction: restriction-value
          feature-ids: feature-ids-value row-budget: row-limit byte-budget: byte-limit
          source-digest: (string-copy (.ref observation-value 'source-sha256))
          content: content-value semantic-digest: fingerprint complete?: #t
          source-authenticated?: #f action-authorized?: #f durable?: #f))))
(def (agentic-ai-lab-ai-agentic-context-org-project scope source restriction profile
                                           (row-limit 256) (byte-limit 1048576))
  (project scope source restriction profile row-limit byte-limit #f #f))
(def (agentic-ai-lab-ai-agentic-context-org-project-incremental base-source base scope source restriction profile)
  (let (verified (agentic-ai-lab-ai-agentic-context-org-replay base-source base (.ref base 'scope)))
    (project scope source restriction profile (.ref verified 'row-budget) (.ref verified 'byte-budget)
      base-source (.ref verified 'observation))))
(def (agentic-ai-lab-ai-agentic-context-org-replay source projection expected-scope)
  (unless (and (object? projection) (.slot? projection 'kind)
               (eq? (.ref projection 'kind) 'agentic-ai-lab.ai-agentic-context.org-projection.v1)
               (every (lambda (flag) (eq? (.ref projection flag) #f))
                      '(source-authenticated? action-authorized? durable?)))
    (error "invalid Context projection or claimed authority"))
  (let* ((scope-value (agentic-ai-lab-ai-agentic-context-scope-admit expected-scope))
         (stored-scope (.ref projection 'scope))
         (stored-scope-value (agentic-ai-lab-ai-agentic-context-scope-admit stored-scope))
         (ids (.ref projection 'feature-ids))
         (_ (unless (and (equal? (.ref stored-scope-value 'semantic-digest) (.ref stored-scope 'semantic-digest))
                         (equal? (.ref scope-value 'semantic-digest) (.ref stored-scope-value 'semantic-digest)))
              (error "Context scope mismatch")))
         (observed (agentic-ai-lab-query-orgize-open-headlines-replay source (.ref projection 'observation)))
         ;; `observed` is fresh, source-derived runtime Query output. Re-parsing
         ;; the same source again here discarded that verified work previously.
         (current (project scope-value source (.ref projection 'restriction)
                    (context-profile-from-feature-ids ids)
                    (.ref projection 'row-budget) (.ref projection 'byte-budget)
                    #f #f observed)))
    (unless (and (equal? (.ref current 'semantic-digest) (.ref projection 'semantic-digest))
                 (equal? (.ref current 'content) (.ref projection 'content))
                 (equal? (.ref current 'source-digest) (.ref projection 'source-digest))
                 (equal? (.ref current 'feature-ids) ids) (eq? (.ref projection 'complete?) #t))
      (error "Context projection substitution")) current))
