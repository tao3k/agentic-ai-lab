;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Post-ReAct Loop Engine Core — Module 1:
;;; Immutable Content-Addressed POO Obligation & Epistemic Graph
;;; (`modules/loop-engine/obligation-graph.ss`).
;;;
;;; Replaces the flat ReAct chat transcript with a typed relational world-model:
;;; - GoalObligations (with required evidence, dependencies & active defeaters)
;;; - CompetingHypotheses (preserving contradictions & defeaters, never collapsed)
;;; - EvidenceFacts (bitemporal lineage, cut-stamped, retractable)
;;; - DeterministicTaskNodes (typed FunFlow computations run with 0 LLM calls)
;;; - SynthesisHoles (irreducible epistemic gaps filled by stateless leaf oracle)
;;; - AttemptedHoleTuples (`(hole-id . premise-digest)` permanent idempotence set)
;;; - Selective Bitemporal Premise Retraction (`obligation-graph-apply-event`)

(import (only-in :clan/poo/object .def .o .ref .slot? object?)
        (only-in :std/list/list filter every any)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-scope
                 agentic-ai-lab-ai-agentic-context-digest))

(export Obligation.
        Hypothesis.
        EvidenceFact.
        DeterministicTaskNode.
        SynthesisHole.
        ObligationGraph.
        make-obligation
        obligation?
        make-hypothesis
        hypothesis?
        make-evidence-fact
        evidence-fact?
        make-deterministic-task-node
        deterministic-task-node?
        make-synthesis-hole
        synthesis-hole?
        make-obligation-graph
        obligation-graph?
        obligation-graph-live-evidence
        obligation-graph-premise-digest
        obligation-graph-hole-attempted?
        obligation-graph-with-evidence
        obligation-graph-with-tasks
        obligation-graph-with-hypotheses
        obligation-graph-mark-task-completed
        obligation-graph-mark-hole-attempted
        obligation-graph-record-branch-matrix
        obligation-graph-add-human-inbox
        obligation-graph-append-capsule
        obligation-graph-apply-event)

(def digest agentic-ai-lab-ai-agentic-context-digest)

(def (opt-ref obj key default)
  (if (and (object? obj) (.slot? obj key))
    (.ref obj key)
    default))

(.def Obligation.
  kind: 'agentic-ai-lab.loop-engine.obligation.v1)

(.def Hypothesis.
  kind: 'agentic-ai-lab.loop-engine.hypothesis.v1)

(.def EvidenceFact.
  kind: 'agentic-ai-lab.loop-engine.evidence-fact.v1)

(.def DeterministicTaskNode.
  kind: 'agentic-ai-lab.loop-engine.deterministic-task-node.v1)

(.def SynthesisHole.
  kind: 'agentic-ai-lab.loop-engine.synthesis-hole.v1)

(.def ObligationGraph.
  kind: 'agentic-ai-lab.loop-engine.obligation-graph.v1)

(def (make-obligation
      obligation-id
      title: (title "")
      required-evidence-ids: (required-evidence-ids '())
      depends-on: (depends-on '())
      active-defeaters: (active-defeaters '())
      premise-ids: (premise-ids '()))
  (.o bind-these: #f
      kind: 'agentic-ai-lab.loop-engine.obligation.v1
      obligation-id: obligation-id
      title: title
      required-evidence-ids: required-evidence-ids
      depends-on: depends-on
      active-defeaters: active-defeaters
      premise-ids: premise-ids))

(def (obligation? v)
  (and (object? v) (.slot? v 'kind)
       (eq? (.ref v 'kind) 'agentic-ai-lab.loop-engine.obligation.v1)))

(def (make-hypothesis
      hypothesis-id
      claim
      supporting-evidence-ids: (supporting-evidence-ids '())
      contradicting-evidence-ids: (contradicting-evidence-ids '())
      active-defeaters: (active-defeaters '())
      open-questions: (open-questions '()))
  (.o bind-these: #f
      kind: 'agentic-ai-lab.loop-engine.hypothesis.v1
      hypothesis-id: hypothesis-id
      claim: claim
      supporting-evidence-ids: supporting-evidence-ids
      contradicting-evidence-ids: contradicting-evidence-ids
      active-defeaters: active-defeaters
      open-questions: open-questions))

(def (hypothesis? v)
  (and (object? v) (.slot? v 'kind)
       (eq? (.ref v 'kind) 'agentic-ai-lab.loop-engine.hypothesis.v1)))

(def (make-evidence-fact
      evidence-id
      payload
      cut: (cut 1)
      premise-ids: (premise-ids '())
      origin-tier: (origin-tier 'observed-fact)
      endorsed?: (endorsed? #t)
      retracted?: (retracted? #f))
  (let ((pdig (digest (list 'evidence-payload.v1 evidence-id payload))))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.loop-engine.evidence-fact.v1
        evidence-id: evidence-id
        payload: payload
        payload-digest: pdig
        cut: cut
        premise-ids: premise-ids
        origin-tier: origin-tier
        endorsed?: (and endorsed? #t)
        retracted?: (and retracted? #t))))

(def (evidence-fact? v)
  (and (object? v) (.slot? v 'kind)
       (eq? (.ref v 'kind) 'agentic-ai-lab.loop-engine.evidence-fact.v1)))

(def (make-deterministic-task-node
      task-id
      obligation-id
      produces-evidence-id
      flow
      input
      required-evidence-ids: (required-evidence-ids '())
      premise-ids: (premise-ids '())
      depends-on-tasks: (depends-on-tasks '())
      read-footprint: (read-footprint '())
      write-footprint: (write-footprint '())
      span: (span #f)
      effect-class: (effect-class 'pure-cas)
      sandbox-profile: (sandbox-profile #f)
      env-digest: (env-digest "sha256:default-env")
      idempotency-key: (idempotency-key #f)
      idempotency-commits: (idempotency-commits '()))
  (.o bind-these: #f
      kind: 'agentic-ai-lab.loop-engine.deterministic-task-node.v1
      task-id: task-id
      obligation-id: obligation-id
      produces-evidence-id: produces-evidence-id
      flow: flow
      input: input
      required-evidence-ids: required-evidence-ids
      premise-ids: premise-ids
      depends-on-tasks: depends-on-tasks
      read-footprint: read-footprint
      write-footprint: write-footprint
      span: span
      effect-class: effect-class
      sandbox-profile: sandbox-profile
      env-digest: env-digest
      idempotency-key: idempotency-key
      idempotency-commits: idempotency-commits))

(def (deterministic-task-node? v)
  (and (object? v) (.slot? v 'kind)
       (eq? (.ref v 'kind) 'agentic-ai-lab.loop-engine.deterministic-task-node.v1)))

(def (make-synthesis-hole
      hole-id
      obligation-id
      description: (description "")
      premise-ids: (premise-ids '())
      max-branches: (max-branches 4))
  (.o bind-these: #f
      kind: 'agentic-ai-lab.loop-engine.synthesis-hole.v1
      hole-id: hole-id
      obligation-id: obligation-id
      description: description
      premise-ids: premise-ids
      max-branches: (max 1 max-branches)))

(def (synthesis-hole? v)
  (and (object? v) (.slot? v 'kind)
       (eq? (.ref v 'kind) 'agentic-ai-lab.loop-engine.synthesis-hole.v1)))

(def (make-obligation-graph
      graph-id
      cut: (cut 1)
      obligations: (obligations '())
      hypotheses: (hypotheses '())
      evidence: (evidence '())
      det-tasks: (det-tasks '())
      synthesis-holes: (synthesis-holes '())
      attempted-holes: (attempted-holes '())
      completed-tasks: (completed-tasks '())
      branch-matrices: (branch-matrices '())
      human-inbox: (human-inbox '())
      audit-capsules: (audit-capsules '())
      cedar-grant-live?: (cedar-grant-live? #t)
      mcp-manifest-healthy?: (mcp-manifest-healthy? #t)
      max-reconcile-steps: (max-reconcile-steps 32))
  (.o bind-these: #f
      kind: 'agentic-ai-lab.loop-engine.obligation-graph.v1
      graph-id: graph-id
      cut: cut
      obligations: obligations
      hypotheses: hypotheses
      evidence: evidence
      det-tasks: det-tasks
      synthesis-holes: synthesis-holes
      attempted-holes: attempted-holes
      completed-tasks: completed-tasks
      branch-matrices: branch-matrices
      human-inbox: human-inbox
      audit-capsules: audit-capsules
      cedar-grant-live?: (and cedar-grant-live? #t)
      mcp-manifest-healthy?: (and mcp-manifest-healthy? #t)
      max-reconcile-steps: (max 1 max-reconcile-steps)))

(def (obligation-graph? v)
  (and (object? v) (.slot? v 'kind)
       (eq? (.ref v 'kind) 'agentic-ai-lab.loop-engine.obligation-graph.v1)))

(def (clone-graph g
                  cut: (cut #f)
                  obligations: (obligations #f)
                  hypotheses: (hypotheses #f)
                  evidence: (evidence #f)
                  det-tasks: (det-tasks #f)
                  synthesis-holes: (synthesis-holes #f)
                  attempted-holes: (attempted-holes #f)
                  completed-tasks: (completed-tasks #f)
                  branch-matrices: (branch-matrices #f)
                  human-inbox: (human-inbox #f)
                  audit-capsules: (audit-capsules #f)
                  cedar-grant-live?: (cedar-grant-live? 'keep)
                  mcp-manifest-healthy?: (mcp-manifest-healthy? 'keep))
  (make-obligation-graph
   (.ref g 'graph-id)
   cut: (or cut (.ref g 'cut))
   obligations: (or obligations (.ref g 'obligations))
   hypotheses: (or hypotheses (.ref g 'hypotheses))
   evidence: (or evidence (.ref g 'evidence))
   det-tasks: (or det-tasks (.ref g 'det-tasks))
   synthesis-holes: (or synthesis-holes (.ref g 'synthesis-holes))
   attempted-holes: (or attempted-holes (.ref g 'attempted-holes))
   completed-tasks: (or completed-tasks (.ref g 'completed-tasks))
   branch-matrices: (or branch-matrices (.ref g 'branch-matrices))
   human-inbox: (or human-inbox (.ref g 'human-inbox))
   audit-capsules: (or audit-capsules (.ref g 'audit-capsules))
   cedar-grant-live?: (if (eq? cedar-grant-live? 'keep) (.ref g 'cedar-grant-live?) cedar-grant-live?)
   mcp-manifest-healthy?: (if (eq? mcp-manifest-healthy? 'keep) (.ref g 'mcp-manifest-healthy?) mcp-manifest-healthy?)
   max-reconcile-steps: (.ref g 'max-reconcile-steps)))

(def (obligation-graph-live-evidence g)
  (filter (lambda (ev) (not (.ref ev 'retracted?))) (.ref g 'evidence)))

;;; Computes the canonical premise digest for a given set of watched `premise-ids`
;;; plus any active defeaters on `obligation-id`. Any new evidence, retraction,
;;; or defeater touching those premises strictly changes the resulting SHA-256;
;;; unrelated graph changes leave it bit-for-bit identical!
(def (obligation-graph-premise-digest g obligation-id premise-ids)
  (let* ((live-ev (obligation-graph-live-evidence g))
         (relevant-ev
          (filter (lambda (ev)
                    (or (null? premise-ids)
                        (member (.ref ev 'evidence-id) premise-ids)
                        (any (lambda (pid) (member pid premise-ids))
                             (.ref ev 'premise-ids))))
                  live-ev))
         (ev-sig (list-sort (lambda (a b) (string<? (car a) (car b)))
                            (map (lambda (ev)
                                   (cons (.ref ev 'evidence-id) (.ref ev 'payload-digest)))
                                 relevant-ev)))
         (ob-list (filter (lambda (o) (equal? (.ref o 'obligation-id) obligation-id))
                          (.ref g 'obligations)))
         (defeaters (if (pair? ob-list)
                      (list-sort string<? (map (lambda (d) (if (string? d) d (symbol->string d)))
                                               (.ref (car ob-list) 'active-defeaters)))
                      '())))
    (digest (list 'obligation-premise-digest.v1 obligation-id premise-ids ev-sig defeaters))))

(def (obligation-graph-hole-attempted? g hole)
  (let* ((hid (.ref hole 'hole-id))
         (pdig (obligation-graph-premise-digest g (.ref hole 'obligation-id) (.ref hole 'premise-ids))))
    (and (member (cons hid pdig) (.ref g 'attempted-holes)) #t)))

(def (obligation-graph-with-evidence g new-ev)
  (let* ((eid (.ref new-ev 'evidence-id))
         (kept (filter (lambda (e) (not (equal? (.ref e 'evidence-id) eid)))
                       (.ref g 'evidence))))
    (clone-graph g evidence: (append kept (list new-ev)))))

(def (obligation-graph-with-tasks g new-tasks)
  (let* ((new-ids (map (lambda (t) (.ref t 'task-id)) new-tasks))
         (kept (filter (lambda (t) (not (member (.ref t 'task-id) new-ids)))
                       (.ref g 'det-tasks))))
    (clone-graph g det-tasks: (append kept new-tasks))))

(def (obligation-graph-with-hypotheses g new-hyps)
  (let* ((new-ids (map (lambda (h) (.ref h 'hypothesis-id)) new-hyps))
         (kept (filter (lambda (h) (not (member (.ref h 'hypothesis-id) new-ids)))
                       (.ref g 'hypotheses))))
    (clone-graph g hypotheses: (append kept new-hyps))))

(def (obligation-graph-mark-task-completed g task-id premise-digest)
  (let* ((key (cons task-id premise-digest))
         (prior (.ref g 'completed-tasks)))
    (if (member key prior)
      g
      (clone-graph g completed-tasks: (append prior (list key))))))

(def (obligation-graph-mark-hole-attempted g hole)
  (let* ((hid (.ref hole 'hole-id))
         (pdig (obligation-graph-premise-digest g (.ref hole 'obligation-id) (.ref hole 'premise-ids)))
         (key (cons hid pdig))
         (prior (.ref g 'attempted-holes)))
    (if (member key prior)
      g
      (clone-graph g attempted-holes: (append prior (list key))))))

(def (obligation-graph-record-branch-matrix g matrix)
  (clone-graph g branch-matrices: (append (.ref g 'branch-matrices) (list matrix))))

(def (obligation-graph-add-human-inbox g item)
  (clone-graph g human-inbox: (append (.ref g 'human-inbox) (list item))))

(def (obligation-graph-append-capsule g capsule)
  (clone-graph g audit-capsules: (append (.ref g 'audit-capsules) (list capsule))))

;;; Bitemporal Selective Event Application (Slice 57 + Temporal Causality):
;;; Applies external Durable Work / Journal events (`evidence-arrived`,
;;; `premise-retracted`, `defeater-discovered`, `cedar-revoked`, `cedar-restored`,
;;; `mcp-manifest-mutated`, `mcp-manifest-repinned`, `human-approved`) by
;;; advancing `cut` and selectively invalidating ONLY dependent evidence/tasks/holes,
;;; leaving all independent discharged obligations and CAS artifacts untouched!
(def (obligation-graph-apply-event g event)
  (let ((ekind (.ref event 'event-kind))
        (next-cut (+ 1 (.ref g 'cut))))
    (cond
     ((eq? ekind 'evidence-arrived)
      (let* ((ev (.ref event 'evidence))
             (g1 (obligation-graph-with-evidence g ev)))
        (clone-graph g1 cut: next-cut)))

     ((eq? ekind 'premise-retracted)
      (let* ((target-id (.ref event 'premise-id))
             (updated-ev
              (map (lambda (ev)
                     (if (or (equal? (.ref ev 'evidence-id) target-id)
                             (member target-id (.ref ev 'premise-ids)))
                       (make-evidence-fact
                        (.ref ev 'evidence-id)
                        (.ref ev 'payload)
                        cut: next-cut
                        premise-ids: (.ref ev 'premise-ids)
                        origin-tier: (.ref ev 'origin-tier)
                        endorsed?: (.ref ev 'endorsed?)
                        retracted?: #t)
                       ev))
                   (.ref g 'evidence)))
             ;; Only tasks that depend on `target-id` are removed from `completed-tasks`;
             ;; independent tasks keep their completed receipts!
             (dependent-task-ids
              (map (lambda (t) (.ref t 'task-id))
                   (filter (lambda (t)
                             (or (member target-id (.ref t 'premise-ids))
                                 (member target-id (.ref t 'required-evidence-ids))))
                           (.ref g 'det-tasks))))
             (kept-completed
              (filter (lambda (entry) (not (member (car entry) dependent-task-ids)))
                      (.ref g 'completed-tasks))))
        (clone-graph g
                     cut: next-cut
                     evidence: updated-ev
                     completed-tasks: kept-completed)))

     ((eq? ekind 'defeater-discovered)
      (let* ((target-ob (opt-ref event 'obligation-id #f))
             (target-hyp (opt-ref event 'hypothesis-id #f))
             (defeater-id (.ref event 'defeater-id))
             (updated-obs
              (map (lambda (o)
                     (if (and target-ob (equal? (.ref o 'obligation-id) target-ob))
                       (make-obligation
                        (.ref o 'obligation-id)
                        title: (.ref o 'title)
                        required-evidence-ids: (.ref o 'required-evidence-ids)
                        depends-on: (.ref o 'depends-on)
                        active-defeaters: (append (.ref o 'active-defeaters) (list defeater-id))
                        premise-ids: (.ref o 'premise-ids))
                       o))
                   (.ref g 'obligations)))
             (updated-hyps
              (map (lambda (h)
                     (if (and target-hyp (equal? (.ref h 'hypothesis-id) target-hyp))
                       (make-hypothesis
                        (.ref h 'hypothesis-id)
                        (.ref h 'claim)
                        supporting-evidence-ids: (.ref h 'supporting-evidence-ids)
                        contradicting-evidence-ids: (.ref h 'contradicting-evidence-ids)
                        active-defeaters: (append (.ref h 'active-defeaters) (list defeater-id))
                        open-questions: (.ref h 'open-questions))
                       h))
                   (.ref g 'hypotheses))))
        (clone-graph g cut: next-cut obligations: updated-obs hypotheses: updated-hyps)))

     ((eq? ekind 'advance-cut)
      (clone-graph g cut: (opt-ref event 'cut next-cut)))

     ((eq? ekind 'cedar-revoked)
      (clone-graph g cut: next-cut cedar-grant-live?: #f))

     ((eq? ekind 'cedar-restored)
      (clone-graph g cut: next-cut cedar-grant-live?: #t))

     ((eq? ekind 'mcp-manifest-mutated)
      (clone-graph g cut: next-cut mcp-manifest-healthy?: #f))

     ((eq? ekind 'mcp-manifest-repinned)
      (clone-graph g cut: next-cut mcp-manifest-healthy?: #t))

     ((eq? ekind 'human-approved)
      (let* ((resolve-defeater (opt-ref event 'resolve-defeater-id #f))
             (updated-obs
              (if resolve-defeater
                (map (lambda (o)
                       (make-obligation
                        (.ref o 'obligation-id)
                        title: (.ref o 'title)
                        required-evidence-ids: (.ref o 'required-evidence-ids)
                        depends-on: (.ref o 'depends-on)
                        active-defeaters: (filter (lambda (d) (not (equal? d resolve-defeater)))
                                                  (.ref o 'active-defeaters))
                        premise-ids: (.ref o 'premise-ids)))
                     (.ref g 'obligations))
                (.ref g 'obligations))))
        (clone-graph g
                     cut: next-cut
                     obligations: updated-obs
                     cedar-grant-live?: #t
                     mcp-manifest-healthy?: #t)))

     (else
      (error "Unknown obligation-graph event kind" ekind)))))
