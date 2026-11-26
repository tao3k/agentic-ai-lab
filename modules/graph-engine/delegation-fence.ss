;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Slice 58 Runtime Implementation:
;;; Multi-Agent Delegated Obligation Capability Attenuation & Concurrent Cedar
;;; Revocation TOCTOU Fence (`modules/loop-engine/delegation-fence.ss`).
;;;
;;; Grounded in documented production failures:
;;; - Claude Code #25000 / #23983: Subagent deny-rule bypass & hook skip
;;; - Claude Code #107019 / #6036: Stale child environment & indirect bypass
;;; - Codex #34043 / #54855:       Session resume deadlock / unclosed child hang
;;; - Codex #15305 / #51116:       Parent/child sandbox override drift & TOCTOU

(import (only-in :clan/poo/object .def .o .ref .slot? object?)
        (only-in :std/list/list filter))

(export CapabilityEnvelope.
        make-capability-envelope
        capability-envelope?
        capability-permitted?
        attenuate-delegation-envelope
        make-delegated-obligation-token
        delegated-obligation-token?
        admit-delegated-execution-fence
        parent-completion-admitted?)

(def (dedup lst)
  (reverse
   (foldl (lambda (x acc) (if (member x acc) acc (cons x acc)))
          '() lst)))

(.def CapabilityEnvelope.
  kind: 'agentic-ai-lab.loop-engine.capability-envelope.v1
  owner-id: "root"
  allowed-caps: '()
  denied-caps: '()
  egress-allowed?: #f)

(def (make-capability-envelope
      owner-id
      allowed-caps: (allowed-caps '())
      denied-caps: (denied-caps '())
      egress-allowed?: (egress-allowed? #f))
  (.o (:: @ CapabilityEnvelope.)
      (owner-id)
      (allowed-caps := (dedup allowed-caps))
      (denied-caps := (dedup denied-caps))
      (egress-allowed? := (and egress-allowed? #t))))

(def (capability-envelope? v)
  (and (object? v) (.slot? v 'kind)
       (eq? (.ref v 'kind) 'agentic-ai-lab.loop-engine.capability-envelope.v1)))

(def (capability-permitted? env cap)
  (unless (capability-envelope? env)
    (error "capability-permitted? expects a CapabilityEnvelope" env))
  (and (member cap (.ref env 'allowed-caps))
       (not (member cap (.ref env 'denied-caps)))
       #t))

;;; Algebraic capability meet (Slice 58 Lean theorems
;;; `delegatedCapability_never_exceeds_parent`, `parentDenylist_dominates_child_delegation`,
;;; `multiHopDelegation_never_escalates`):
;;; - `child.allowed = (parent.allowed ∩ requested) \ parent.denied \ extra-denied`
;;; - `child.denied  = parent.denied ∪ extra-denied`
;;; - `child.egress? = parent.egress? ∧ requested-egress?`
(def (attenuate-delegation-envelope
      parent-env
      child-id
      requested-caps
      extra-denied-caps: (extra-denied-caps '())
      requested-egress?: (requested-egress? #f))
  (unless (capability-envelope? parent-env)
    (error "attenuate-delegation-envelope expects a parent CapabilityEnvelope" parent-env))
  (let* ((p-allowed (.ref parent-env 'allowed-caps))
         (p-denied (.ref parent-env 'denied-caps))
         (c-denied (dedup (append p-denied extra-denied-caps)))
         (c-allowed
          (dedup (filter (lambda (c)
                           (and (member c requested-caps)
                                (not (member c c-denied))))
                         p-allowed)))
         (c-egress (and (.ref parent-env 'egress-allowed?)
                        (and requested-egress? #t))))
    (make-capability-envelope
     child-id
     allowed-caps: c-allowed
     denied-caps: c-denied
     egress-allowed?: c-egress)))

(def (make-delegated-obligation-token
      parent-id
      child-id
      obligation-id
      envelope
      bound-cut
      bound-grant-epoch
      attempt-id: (attempt-id "attempt-1"))
  (unless (capability-envelope? envelope)
    (error "make-delegated-obligation-token expects an attenuated CapabilityEnvelope" envelope))
  (.o (kind := 'agentic-ai-lab.loop-engine.delegated-obligation-token.v1)
      (parent-id) (child-id) (obligation-id) (envelope)
      (bound-cut) (bound-grant-epoch) (attempt-id)))

(def (delegated-obligation-token? v)
  (and (object? v) (.slot? v 'kind)
       (eq? (.ref v 'kind) 'agentic-ai-lab.loop-engine.delegated-obligation-token.v1)))

(def (fence-verdict admitted? reason)
  (.o (admitted?) (reason) (action-authorized? := #f)))

;;; Atomic TOCTOU Execution Fence (Slice 58 Lean theorems
;;; `revokedParentGrant_immediately_blocks_child_toctou`,
;;; `grantEpochAdvance_invalidates_inflight_delegation`,
;;; `staleChildContextCut_rejected_fail_closed`).
(def (admit-delegated-execution-fence
      token
      requested-cap
      live-cut: (live-cut 1)
      live-grant-epoch: (live-grant-epoch 1)
      parent-grant-live?: (parent-grant-live? #t)
      child-grant-live?: (child-grant-live? #t))
  (unless (delegated-obligation-token? token)
    (error "admit-delegated-execution-fence expects a DelegatedObligationToken" token))
  (let ((env (.ref token 'envelope))
        (bound-cut (.ref token 'bound-cut))
        (bound-grant-epoch (.ref token 'bound-grant-epoch)))
    (cond
     ((not parent-grant-live?) (fence-verdict #f 'cedar-parent-grant-revoked))
     ((not child-grant-live?) (fence-verdict #f 'cedar-child-grant-revoked))
     ((not (equal? bound-grant-epoch live-grant-epoch)) (fence-verdict #f 'cedar-grant-epoch-drifted))
     ((not (equal? bound-cut live-cut)) (fence-verdict #f 'stale-child-context-cut-blocked))
     ((not (capability-permitted? env requested-cap)) (fence-verdict #f 'parent-denylist-or-attenuation-denied))
     (else
      (.o (admitted? := #t)
          (reason := 'delegated-execution-fenced-ok)
          (child-id := (.ref token 'child-id))
          (obligation-id := (.ref token 'obligation-id))
          (bound-cut)
          (bound-grant-epoch)
          (action-authorized? := #f))))))

;;; Unclosed Subagent Attempt Recovery Fence (Slice 58 Lean theorem
;;; `unclosedSubagentAttempt_blocks_silent_hang_or_completion`, closing Codex #34043 & #54855).
(def (parent-completion-admitted? all-obligations-discharged? unclosed-child-attempts active-defeaters)
  (cond
   ((pair? unclosed-child-attempts)
    (.o (admitted? := #f)
        (reason := 'unclosed-subagent-attempt-requires-recovery)
        (unclosed-attempts := unclosed-child-attempts)
        (action-authorized? := #f)))
   ((pair? active-defeaters)
    (.o (admitted? := #f)
        (reason := 'active-defeaters-block-completion)
        (active-defeaters)
        (action-authorized? := #f)))
   ((not all-obligations-discharged?)
    (fence-verdict #f 'obligations-still-unsatisfied))
   (else
    (fence-verdict #t 'parent-clean-completion-admitted))))
