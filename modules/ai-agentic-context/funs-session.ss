;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Context produces the independent Session input proposal; Session never parses Org.
;;; The producer receipt reference must be resolved by a Host before publication.
(import (only-in :clan/poo/object .o .ref)
        (only-in :agentic-ai-lab/modules/session/objects-attempt SessionInputRef. SessionTask.)
        (only-in :agentic-ai-lab/modules/query/gql agentic-ai-lab-query->gql)
        "funs-scope.ss" "funs-projection.ss" "funs-anchors.ss")
(export agentic-ai-lab-ai-agentic-context-session-input agentic-ai-lab-ai-agentic-context-session-task)
(def (agentic-ai-lab-ai-agentic-context-session-input source projection expected-scope receipt-reference)
  (unless (and (string? receipt-reference) (< 0 (string-length receipt-reference) 257))
    (error "Session input requires a producer receipt reference"))
  (let* ((verified (agentic-ai-lab-ai-agentic-context-org-replay source projection expected-scope))
         (scope-value (.ref verified 'scope))
         (identity-value (string-copy (.ref verified 'semantic-digest)))
         (scope-digest-value (string-copy (.ref scope-value 'semantic-digest)))
         (source-value (string-copy (.ref verified 'source-digest)))
         (query-value (agentic-ai-lab-ai-agentic-context-digest
                        (agentic-ai-lab-query->gql (.ref (.ref verified 'observation) 'query))))
         (restriction-value (string-copy (.ref (.ref verified 'restriction) 'semantic-digest)))
         (profile-value (agentic-ai-lab-ai-agentic-context-digest (.ref verified 'feature-ids)))
         (receipt-value (string-copy receipt-reference))
         (input-digest-value (agentic-ai-lab-ai-agentic-context-digest
           (list 'context-session-input-v1 "agentic-ai-lab/ai-agentic-context" "org-projection-v1"
                 identity-value scope-digest-value source-value query-value restriction-value
                 profile-value receipt-value (.ref scope-value 'session) (.ref scope-value 'turn)))))
    (unless (string? (.ref scope-value 'session))
      (error "Context Session input requires an exact Session and Turn scope"))
    (.o (:: @ SessionInputRef. SessionTask.) producer: "agentic-ai-lab/ai-agentic-context"
        contract: "org-projection-v1" identity: identity-value digest: input-digest-value
        scope-digest: scope-digest-value source-vector-digest: source-value
        query-digest: query-value restriction-digest: restriction-value
        profile-digest: profile-value receipt-ref: receipt-value
        consumer-session: (string-copy (.ref scope-value 'session))
        consumer-turn: (.ref scope-value 'turn) complete?: #t)))

(def (agentic-ai-lab-ai-agentic-context-session-task source projection scope receipt-reference task-revision-value ids)
  (unless (and (exact-integer? task-revision-value) (<= 0 task-revision-value 65535)) (error "Invalid Task revision"))
  (let* ((anchors-value (agentic-ai-lab-ai-agentic-context-org-anchors source projection scope ids))
         (input-value (agentic-ai-lab-ai-agentic-context-session-input source projection scope receipt-reference))
         (task-value (string-copy (.ref (agentic-ai-lab-ai-agentic-context-scope-admit scope) 'task)))
         (refs-value (map (lambda (anchor) (string-copy (.ref anchor 'semantic-digest))) anchors-value)))
    (.o (:: @ SessionTask.) identity: task-value revision: task-revision-value input: input-value
        anchor-refs: refs-value anchor-bindings: anchors-value)))
