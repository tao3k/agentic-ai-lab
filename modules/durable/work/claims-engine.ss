;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Pure Concurrent `:ID:` Ownership & Heartbeat-Expiry Custody Takeover Engine
;;; operating over abstract ClaimTable + fenced durable-journal (Slice 49).
;;; INVARIANT: ZERO orgize imports, ZERO ai-agentic-context imports.

(import (only-in :clan/poo/object .o .ref)
        (only-in :std/list/list filter find)
        "contracts.ss")

(export work-find-claim
        work-assert-write-owner
        work-claim!
        work-extend!
        work-handover!)

(def (claim-journal-key task-id node-id)
  (string-append "orchestrator:claim:" task-id ":" node-id))

(def (work-find-claim claims node-id)
  (find (lambda (c) (equal? (.ref c 'node-id) node-id)) claims))

(def (replace-or-append-claim claims next-claim)
  (let ((nid (.ref next-claim 'node-id)))
    (append (filter (lambda (c) (not (equal? (.ref c 'node-id) nid))) claims)
            (list next-claim))))

(def (work-assert-write-owner claims node-id actor
                              now: (now #f)
                              expected-epoch: (expected-epoch #f))
  (let ((claim (work-find-claim claims node-id)))
    (cond
     ((or (not claim)
          (not (.ref claim 'owner-actor))
          (not (equal? (.ref claim 'claim-state) "claimed-active")))
      (if (and expected-epoch (not (= expected-epoch (if claim (.ref claim 'claim-lease-epoch) 0))))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.durable.write-ownership-check.v1
            admitted?: #f
            reason: 'stale-lease-epoch-cas-mismatch
            node-id: node-id
            actor: actor
            current-owner: (and claim (.ref claim 'owner-actor)))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.durable.write-ownership-check.v1
            admitted?: #t
            reason: 'node-unclaimed-or-inactive
            node-id: node-id
            actor: actor
            current-owner: (and claim (.ref claim 'owner-actor)))))
     ((and expected-epoch (not (= expected-epoch (.ref claim 'claim-lease-epoch))))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.write-ownership-check.v1
          admitted?: #f
          reason: 'stale-lease-epoch-cas-mismatch
          node-id: node-id
          actor: actor
          current-owner: (.ref claim 'owner-actor)))
     ((and (exact-integer? now) (>= now (+ (.ref claim 'heartbeat-at) (.ref claim 'lease-ttl))))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.write-ownership-check.v1
          admitted?: #f
          reason: 'active-lease-expired
          node-id: node-id
          actor: actor
          current-owner: (.ref claim 'owner-actor)))
     ((equal? (.ref claim 'owner-actor) actor)
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.write-ownership-check.v1
          admitted?: #t
          reason: 'active-owner-matched
          node-id: node-id
          actor: actor
          current-owner: actor))
     (else
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.write-ownership-check.v1
          admitted?: #f
          reason: 'non-owner-overwrite-forbidden
          node-id: node-id
          actor: actor
          current-owner: (.ref claim 'owner-actor))))))

(def (work-claim! journal task-id claims node-id actor
                  worktree: (worktree "main")
                  now: (now 0)
                  ttl: (ttl 120)
                  span: (span #f)
                  expected-epoch: (expected-epoch #f))
  (let ((check (work-assert-write-owner claims node-id actor expected-epoch: expected-epoch)))
    (if (not (.ref check 'admitted?))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.claim-result.v1
          claimed?: #f
          reason: (.ref check 'reason)
          node-id: node-id
          actor: actor
          current-owner: (.ref check 'current-owner)
          next-claims: claims)
      (let* ((existing (work-find-claim claims node-id))
             (next-epoch (+ 1 (if existing (.ref existing 'claim-lease-epoch) 0)))
             (next-claim (make-checked-work-claim
                          node-id actor "claimed-active" next-epoch now ttl worktree
                          (and existing (.ref existing 'extends-id))
                          (or span (and existing (.ref existing 'span)))))
             (next-claims (replace-or-append-claim claims next-claim))
             (receipt (.o bind-these: #f
                          kind: 'agentic-ai-lab.durable.claim-receipt.v1
                          task-id: task-id
                          node-id: node-id
                          owner-actor: actor
                          claim-lease-epoch: next-epoch
                          heartbeat-at: now
                          lease-ttl: ttl
                          digest: (canonical-sha256 (list task-id node-id actor next-epoch now))))
             (key (claim-journal-key task-id node-id)))
        (when journal
          (journal-put-fenced! journal (string-append key ":" (number->string next-epoch)) key receipt))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.durable.claim-result.v1
            claimed?: #t
            reason: 'claimed-active
            node-id: node-id
            actor: actor
            claim-lease-epoch: next-epoch
            claim: next-claim
            next-claims: next-claims
            receipt: receipt)))))

(def (work-extend! journal task-id claims parent-node-id new-node-id actor
                   worktree: (worktree "main")
                   role: (role "extension")
                   now: (now 0)
                   ttl: (ttl 120))
  (cond
   ((equal? parent-node-id new-node-id)
    (.o bind-these: #f
        kind: 'agentic-ai-lab.durable.extend-result.v1
        extended?: #f
        reason: 'extension-id-must-be-disjoint-from-parent
        parent-node-id: parent-node-id
        new-node-id: new-node-id
        next-claims: claims))
   ((work-find-claim claims new-node-id)
    (.o bind-these: #f
        kind: 'agentic-ai-lab.durable.extend-result.v1
        extended?: #f
        reason: 'extension-id-already-exists
        parent-node-id: parent-node-id
        new-node-id: new-node-id
        next-claims: claims))
   (else
    (let* ((ext-claim (make-checked-work-claim
                       new-node-id actor "claimed-active" 1 now ttl worktree parent-node-id #f))
           (next-claims (append claims (list ext-claim)))
           (receipt (.o bind-these: #f
                        kind: 'agentic-ai-lab.durable.extend-receipt.v1
                        task-id: task-id
                        parent-node-id: parent-node-id
                        new-node-id: new-node-id
                        actor: actor
                        role: role
                        digest: (canonical-sha256 (list task-id parent-node-id new-node-id actor now))))
           (key (claim-journal-key task-id new-node-id)))
      (when journal
        (journal-put-fenced! journal (string-append key ":ext:" (.ref receipt 'digest)) key receipt))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.extend-result.v1
          extended?: #t
          reason: 'disjoint-peer-extension-appended
          parent-node-id: parent-node-id
          new-node-id: new-node-id
          actor: actor
          claim: ext-claim
          next-claims: next-claims
          receipt: receipt)))))

(def (work-handover! journal task-id claims node-id next-actor
                     now: (now 0)
                     force-explicit?: (force-explicit? #f)
                     endorsed-by: (endorsed-by #f)
                     expected-epoch: (expected-epoch #f)
                     custody-oid: (custody-oid #f))
  (let ((claim (work-find-claim claims node-id)))
    (if (not claim)
      (.o bind-these: #f
          kind: 'agentic-ai-lab.durable.handover-result.v1
          handed-over?: #f
          reason: 'node-not-claimed
          node-id: node-id
          next-claims: claims)
      (let* ((hb (.ref claim 'heartbeat-at))
             (ttl (.ref claim 'lease-ttl))
             (cur-epoch (.ref claim 'claim-lease-epoch))
             (expired? (>= now (+ hb ttl)))
             (epoch-ok? (or (not expected-epoch) (= expected-epoch cur-epoch)))
             (valid-endorser? (and (string? endorsed-by)
                                   (> (string-length endorsed-by) 0)
                                   (not (equal? endorsed-by next-actor))))
             (has-custody? (and (string? custody-oid) (> (string-length custody-oid) 0))))
        (cond
         ((not epoch-ok?)
          (.o bind-these: #f
              kind: 'agentic-ai-lab.durable.handover-result.v1
              handed-over?: #f
              reason: 'stale-lease-epoch-cas-mismatch
              node-id: node-id
              current-owner: (.ref claim 'owner-actor)
              current-epoch: cur-epoch
              next-claims: claims))
         ((and (not force-explicit?) (not expired?))
          (.o bind-these: #f
              kind: 'agentic-ai-lab.durable.handover-result.v1
              handed-over?: #f
              reason: 'active-lease-not-expired
              node-id: node-id
              current-owner: (.ref claim 'owner-actor)
              expires-at: (+ hb ttl)
              next-claims: claims))
         ((and force-explicit? (not expired?) (not valid-endorser?))
          (.o bind-these: #f
              kind: 'agentic-ai-lab.durable.handover-result.v1
              handed-over?: #f
              reason: 'explicit-early-handover-requires-non-self-endorsement
              node-id: node-id
              current-owner: (.ref claim 'owner-actor)
              next-claims: claims))
         ((not has-custody?)
          (.o bind-these: #f
              kind: 'agentic-ai-lab.durable.handover-result.v1
              handed-over?: #f
              reason: 'handover-requires-custody-snapshot
              node-id: node-id
              next-claims: claims))
         (else
          (let* ((next-epoch (+ 1 cur-epoch))
                 (next-claim (make-checked-work-claim
                              node-id next-actor "claimed-active" next-epoch now ttl
                              (.ref claim 'worktree) (.ref claim 'extends-id) (.ref claim 'span)))
                 (next-claims (replace-or-append-claim claims next-claim))
                 (receipt (.o bind-these: #f
                              kind: 'agentic-ai-lab.durable.handover-receipt.v1
                              task-id: task-id
                              node-id: node-id
                              prior-owner: (.ref claim 'owner-actor)
                              next-owner: next-actor
                              endorsed-by: endorsed-by
                              claim-lease-epoch: next-epoch
                              custody-oid: custody-oid
                              via-expiry?: expired?
                              digest: (canonical-sha256
                                       (list task-id node-id next-actor endorsed-by next-epoch custody-oid))))
                 (key (claim-journal-key task-id node-id)))
            (when journal
              (journal-put-fenced! journal (string-append key ":ho:" (number->string next-epoch)) key receipt))
            (.o bind-these: #f
                kind: 'agentic-ai-lab.durable.handover-result.v1
                handed-over?: #t
                reason: (if expired? 'expired-lease-custody-takeover 'explicit-endorsed-custody-handover)
                node-id: node-id
                prior-owner: (.ref claim 'owner-actor)
                next-owner: next-actor
                endorsed-by: endorsed-by
                claim-lease-epoch: next-epoch
                custody-oid: custody-oid
                claim: next-claim
                next-claims: next-claims
                receipt: receipt))))))))
