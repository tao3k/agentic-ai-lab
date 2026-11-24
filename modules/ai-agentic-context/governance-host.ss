;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Single-owner Org Governance coordinator bridging `context-query-host`,
;;; layered GQL `GovernanceGraph`, and `:ID:` subtree strict mediation.
(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :std/list/list every delete-duplicates/hash)
        "query-provider.ss"
        "funs-governance-graph.ss"
        "funs-subtree-mediation.ss")
(export context-governance-host
        context-governance-enroll-source!
        context-governance-live-graph
        context-governance-issue-token
        context-governance-commit-subtree!
        context-governance-mediation-state)

(defstruct gov-owner-state (owner query-host graph-id source-ids policy-digest mediation-state))

(def (text? v) (and (string? v) (< 0 (string-length v) 257)))

(def (state host)
  (unless (and (object? host) (.slot? host 'kind)
               (eq? (.ref host 'kind) 'context.governance-host.v1)
               (.slot? host 'private-runtime-state)
               (gov-owner-state? (.ref host 'private-runtime-state)))
    (error "Invalid Context Governance Host"))
  (let (s (.ref host 'private-runtime-state))
    (unless (eq? (gov-owner-state-owner s) (current-thread))
      (error "Context Governance Host requires its serialized owner thread"))
    s))

(def (context-governance-host query-host seed policy-digest
                              (source-ids '()) (graph-id 'context/governance-live)
                              (revocation-epoch 0))
  (unless (and (object? query-host) (.slot? query-host 'kind)
               (eq? (.ref query-host 'kind) 'context.query-provider-host.v1)
               (text? seed) (text? policy-digest)
               (list? source-ids) (every text? source-ids)
               (symbol? graph-id))
    (error "Invalid Context Governance Host arguments"))
  (let ((kind 'context.governance-host.v1)
        (private-runtime-state
         (make-gov-owner-state
          (current-thread)
          query-host
          graph-id
          (delete-duplicates/hash (map string-copy source-ids))
          (string-copy policy-digest)
          (agentic-ai-lab-ai-agentic-context-subtree-mediation-init seed revocation-epoch))))
    (.o kind private-runtime-state)))

(def (context-governance-enroll-source! host source-cut)
  (let* ((s (state host))
         (admitted (context-query-source! (gov-owner-state-query-host s) source-cut))
         (sid (.ref admitted 'identity)))
    (unless (member sid (gov-owner-state-source-ids s))
      (set! (gov-owner-state-source-ids s)
        (append (gov-owner-state-source-ids s) (list (string-copy sid)))))
    admitted))

(def (context-governance-live-graph host)
  (let* ((s (state host))
         (qhost (gov-owner-state-query-host s))
         (cuts (map (cut context-query-current-source qhost <>)
                    (gov-owner-state-source-ids s))))
    (agentic-ai-lab-ai-agentic-context-governance-graph
     (gov-owner-state-graph-id s) cuts #t)))

(def (context-governance-mediation-state host)
  (gov-owner-state-mediation-state (state host)))

(def (context-governance-issue-token host proposal now-tick expiry-tick)
  (let* ((s (state host))
         (qhost (gov-owner-state-query-host s))
         (gov (context-governance-live-graph host))
         (cut (context-query-current-source qhost (.ref proposal 'source-id)))
         (epoch (.ref (gov-owner-state-mediation-state s) 'revocation-epoch)))
    (agentic-ai-lab-ai-agentic-context-subtree-issue-token
     gov cut proposal (gov-owner-state-policy-digest s) now-tick expiry-tick epoch)))

(def (context-governance-commit-subtree! host proposal token now-tick)
  (let* ((s (state host))
         (qhost (gov-owner-state-query-host s))
         (gov (context-governance-live-graph host))
         (live-cut (context-query-current-source qhost (.ref proposal 'source-id)))
         (receipt (agentic-ai-lab-ai-agentic-context-subtree-commit
                   (gov-owner-state-mediation-state s)
                   gov live-cut proposal token
                   (gov-owner-state-policy-digest s) now-tick)))
    (set! (gov-owner-state-mediation-state s) (.ref receipt 'mediation-state))
    (if (not (.ref receipt 'accepted?))
      receipt
      (let (next-source-cut (context-query-source! qhost (.ref receipt 'next-source-cut)))
        (.o (:: @ receipt) next-source-cut)))))
