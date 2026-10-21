;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-engine runtime base facts and policy envelopes.
;;; Invariant: base helpers are pure report rows and never realize runtime work.

(import (only-in :core/modules/funflow/graph-projection
                 poo-flow-funflow-workflow-agreement)
        "core.ss"
        "result-contract.ss")

(export poo-flow-user-loop-engine-primary-agent
        poo-flow-user-loop-engine-intent-status
        poo-flow-user-loop-engine-intent-operation-kind
        poo-flow-user-loop-engine-agent-judge-ref
        poo-flow-user-loop-engine-agent-judge-pair
        poo-flow-user-loop-engine-agent-judge-pairs
        poo-flow-user-loop-engine-intent-primary-sandbox-profile
        poo-flow-user-loop-engine-intent-agent-profile-refs
        poo-flow-user-loop-engine-intent-operation-result-contract
        poo-flow-user-loop-engine-intent-workflow-agreement
        poo-flow-user-loop-engine-intent-sandbox-handoff-agreement
        poo-flow-user-loop-engine-intent-runtime-intent
        poo-flow-user-loop-engine-intent-policy)

;;; The first configured judge is the default runtime target so simple
;;; single-agent loops do not need an explicit governor role.
;; : (-> List Symbol)
(def (poo-flow-user-loop-engine-primary-agent agent-judges)
  (cond
   ((null? agent-judges) 'loop-governor-agent)
   ((and (pair? (car agent-judges))
         (pair? (cdr (car agent-judges))))
    (cadr (car agent-judges)))
   ((pair? (car agent-judges)) (cdr (car agent-judges)))
   (else (car agent-judges))))

;;; Human-audit declarations change admission state before any backend runtime
;;; receives the request; Scheme only records the waiting state.
;; : (-> Alist Symbol)
(def (poo-flow-user-loop-engine-intent-status intent)
  (if (null? (poo-flow-user-loop-engine-intent-ref intent 'human-audit '()))
    'admitted
    'waiting-human))

;;; Operation kind mirrors the same human gate so downstream receipts can be
;;; audited without inspecting the raw user module sections.
;; : (-> Alist Symbol)
(def (poo-flow-user-loop-engine-intent-operation-kind intent)
  (if (null? (poo-flow-user-loop-engine-intent-ref intent 'human-audit '()))
    'governor-judge
    'human-audit))

;;; Judge rows come from user flags, not a validated schema, so role lookup has
;;; to accept both list-shaped and dotted entries while keeping defaults stable.
;; : (-> [Value] Symbol Value Value)
(def (poo-flow-user-loop-engine-agent-judge-ref agent-judges role default-value)
  (cond
   ((null? agent-judges) default-value)
   ((and (pair? (car agent-judges))
         (equal? (caar agent-judges) role))
    (let (row (car agent-judges))
      (cond
       ((null? (cdr row)) default-value)
       ((pair? (cdr row)) (cadr row))
       (else (cdr row)))))
   (else
    (poo-flow-user-loop-engine-agent-judge-ref
     (cdr agent-judges)
     role
     default-value))))

;;; Role/name normalization is shared by profile, harness, and session
;;; projection so every downstream row receives the same naming decision.
;; : (-> Value MaybeAgentJudgeRef)
(def (poo-flow-user-loop-engine-agent-judge-pair row)
  (and (pair? row)
       (symbol? (poo-flow-user-loop-engine-agent-judge-role row))
       (let (tail (poo-flow-user-loop-engine-agent-judge-tail row))
         (and (not (null? tail))
              (cons (poo-flow-user-loop-engine-agent-judge-role row)
                    (poo-flow-user-loop-engine-agent-judge-value tail))))))

;; : (-> AgentJudgeRow Symbol)
(def (poo-flow-user-loop-engine-agent-judge-role row)
  (car row))

;; : (-> AgentJudgeRow AgentJudgeTail)
(def (poo-flow-user-loop-engine-agent-judge-tail row)
  (cdr row))

;;; Boundary: user loop engine agent judge value is the policy-visible edge for
;;; module-system, loop behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> AgentJudgeTail AgentJudgeValue)
(def (poo-flow-user-loop-engine-agent-judge-value tail)
  (if (pair? tail) (car tail) tail))

;;; Invalid judge rows are skipped rather than repaired; malformed user config
;;; should stay visible in the original intent while projections remain total.
;; : (-> [Value] [AgentJudgeRef])
(def (poo-flow-user-loop-engine-agent-judge-pairs agent-judges)
  (cond
   ((null? agent-judges) '())
   ((poo-flow-user-loop-engine-agent-judge-pair (car agent-judges))
    => (lambda (role-ref)
         (cons role-ref
               (poo-flow-user-loop-engine-agent-judge-pairs
                (cdr agent-judges)))))
   (else
    (poo-flow-user-loop-engine-agent-judge-pairs (cdr agent-judges)))))

;;; Loop-engine agent boundaries use the first declared sandbox profile as a
;;; policy reference only. Actual sandbox realization remains backend-owned.
;; : (-> Alist MaybeSymbol)
(def (poo-flow-user-loop-engine-intent-primary-sandbox-profile intent)
  (let (refs (poo-flow-user-loop-engine-intent-ref
              intent
              'sandbox-profile-refs
              '()))
    (if (null? refs) #f (car refs))))

;;; Human audit is modeled as a named profile beside machine judges so agents
;;; can inspect the same profile/harness/session graph for both reviewer types.
;; : (-> Alist [AgentProfileRef])
(def (poo-flow-user-loop-engine-intent-agent-profile-refs intent)
  (append
   (poo-flow-user-loop-engine-agent-judge-pairs
    (poo-flow-user-loop-engine-intent-ref intent 'agent-judges '()))
   (if (null? (poo-flow-user-loop-engine-intent-ref intent 'human-audit '()))
     '()
     (list (cons 'human-audit 'human-audit)))))

;;; The operation-level adapter is the only result-contract function that needs
;;; operation-kind. The full contract packet lives in loop-engine-result-contract.
;; : (-> Alist Symbol)
(def (poo-flow-user-loop-engine-intent-operation-result-contract intent)
  (if (eq? (poo-flow-user-loop-engine-intent-operation-kind intent)
           'human-audit)
    (poo-flow-user-loop-engine-intent-role-result-contract
     intent
     'human-audit)
    (poo-flow-user-loop-engine-intent-role-result-contract
     intent
     'governor)))

;;; Workflow agreement is Funflow-owned data cached on the intent. The fallback
;;; keeps older loop-engine rows presentable while still using Funflow's rules.
;; : (-> Alist Alist)
(def (poo-flow-user-loop-engine-intent-workflow-agreement intent)
  (poo-flow-user-loop-engine-intent-ref
   intent
   'workflow-agreement
    (poo-flow-funflow-workflow-agreement
     (poo-flow-user-loop-engine-intent-workflow-ref intent)
     '())))

;;; Runtime consumers may receive older intent rows without the agreement slot;
;;; this accessor makes sandbox readiness total and keeps snapshot/handoff code
;;; from re-encoding agreement shape in multiple places.
;; : (-> Alist Alist)
(def (poo-flow-user-loop-engine-intent-sandbox-handoff-agreement intent)
  (poo-flow-user-loop-engine-intent-ref
   intent
   'sandbox-handoff-agreement
   (poo-flow-user-loop-engine-sandbox-handoff-agreement
    (poo-flow-user-loop-engine-intent-ref
     intent
     'sandbox-profile-refs
     '())
    (poo-flow-user-loop-engine-intent-ref
     intent
     'sandbox-runtime-summaries
     '())
    (poo-flow-user-loop-engine-intent-ref
     intent
     'sandbox-handoff-summaries
     '())
    (poo-flow-user-loop-engine-intent-ref
     intent
     'sandbox-unresolved-profile-refs
     '()))))

;;; Runtime intent is the compact policy pointer embedded in profiles,
;;; harnesses, receipts, and operations before a backend materializes them.
;; : (-> Alist Alist)
(def (poo-flow-user-loop-engine-intent-runtime-intent intent)
  (list
   (cons 'runtime-handoff
         (poo-flow-user-loop-engine-intent-ref
          intent
          'runtime-handoff
          'loop-governor-marlin-runtime-manifest))
   (cons 'runtime-owner
         (poo-flow-user-loop-engine-intent-ref
          intent
          'runtime-owner
          "marlin-agent-core"))
   (cons 'handoff-contracts +poo-flow-user-loop-engine-handoff-contracts+)
   (cons 'runtime-command-contract
         +poo-flow-user-loop-engine-runtime-command-contract+)
   (cons 'result-contract
         (poo-flow-user-loop-engine-intent-result-contract intent))
   (cons 'object-families
         +poo-flow-user-loop-engine-runtime-object-families+)
   (cons 'receipt-contracts
         +poo-flow-user-loop-engine-receipt-contracts+)
   (cons 'workflow-ref
         (poo-flow-user-loop-engine-intent-workflow-ref intent))
   (cons 'workflow-agreement
         (poo-flow-user-loop-engine-intent-workflow-agreement intent))
   (cons 'lineage-policy
         (poo-flow-user-loop-engine-intent-ref intent 'lineage-policy '()))
   (cons 'selector-policy
         (poo-flow-user-loop-engine-intent-ref intent 'selector-policy '()))
   (cons 'resource-policy
         (poo-flow-user-loop-engine-intent-ref intent 'resource-policy '()))
   (cons 'capability-policy
         (poo-flow-user-loop-engine-intent-ref
          intent
          'capability-policy
          '()))
   (cons 'memory-policies
         (poo-flow-user-loop-engine-intent-ref
          intent
          'memory-policies
          '()))
   (cons 'compression-policy
         (poo-flow-user-loop-engine-intent-ref
          intent
          'compression-policy
          '()))
   (cons 'session-selector-receipts
         (poo-flow-user-loop-engine-intent-ref
          intent
          'session-selector-receipts
          '()))
   (cons 'session-materialization-receipts
         (poo-flow-user-loop-engine-intent-ref
          intent
          'session-materialization-receipts
          '()))
   (cons 'policy-extension-receipts
         (poo-flow-user-loop-engine-intent-ref
          intent
          'policy-extension-receipts
          '()))
   (cons 'spec-evolution-reviews
         (poo-flow-user-loop-engine-intent-ref
          intent
          'spec-evolution-reviews
          '()))
   (cons 'spec-evolution-human-audit-review-items
         (poo-flow-user-loop-engine-intent-ref
          intent
          'spec-evolution-human-audit-review-items
          '()))
   (cons 'spec-evolution-runtime-manifest-rows
         (poo-flow-user-loop-engine-intent-ref
          intent
          'spec-evolution-runtime-manifest-rows
          '()))
   (cons 'executes-runtime #f)))

;;; Policy projection is the loop-engine guardrail packet. It keeps governor,
;;; human audit, sandbox, budget, and observability rows together so Marlin sees
;;; one coherent handoff policy instead of scattered presentation fields.
;; : (-> Alist Alist)
(def (poo-flow-user-loop-engine-intent-policy intent)
  (list
   (cons 'governor
         (poo-flow-user-loop-engine-intent-ref intent 'governor '()))
   (cons 'human-audit
         (poo-flow-user-loop-engine-intent-ref intent 'human-audit '()))
   (cons 'sandbox
         (poo-flow-user-loop-engine-intent-ref intent 'sandbox '()))
   (cons 'sandbox-profile-refs
         (poo-flow-user-loop-engine-intent-ref
          intent
          'sandbox-profile-refs
          '()))
   (cons 'sandbox-runtime-summaries
         (poo-flow-user-loop-engine-intent-ref
          intent
          'sandbox-runtime-summaries
          '()))
   (cons 'sandbox-handoff-summaries
         (poo-flow-user-loop-engine-intent-ref
          intent
          'sandbox-handoff-summaries
          '()))
   (cons 'sandbox-handoff-agreement
         (poo-flow-user-loop-engine-intent-sandbox-handoff-agreement
          intent))
   (cons 'sandbox-unresolved-profile-refs
         (poo-flow-user-loop-engine-intent-ref
          intent
          'sandbox-unresolved-profile-refs
          '()))
   (cons 'workflow-agreement
         (poo-flow-user-loop-engine-intent-workflow-agreement intent))
   (cons 'lineage-policy
         (poo-flow-user-loop-engine-intent-ref intent 'lineage-policy '()))
   (cons 'selector-policy
         (poo-flow-user-loop-engine-intent-ref intent 'selector-policy '()))
   (cons 'resource-policy
         (poo-flow-user-loop-engine-intent-ref intent 'resource-policy '()))
   (cons 'capability-policy
         (poo-flow-user-loop-engine-intent-ref
          intent
          'capability-policy
          '()))
   (cons 'memory-policies
         (poo-flow-user-loop-engine-intent-ref
          intent
          'memory-policies
          '()))
   (cons 'compression-policy
         (poo-flow-user-loop-engine-intent-ref
          intent
          'compression-policy
          '()))
   (cons 'policy-extension-receipts
         (poo-flow-user-loop-engine-intent-ref
          intent
          'policy-extension-receipts
          '()))
   (cons 'spec-evolution-reviews
         (poo-flow-user-loop-engine-intent-ref
          intent
          'spec-evolution-reviews
          '()))
   (cons 'spec-evolution-human-audit-review-items
         (poo-flow-user-loop-engine-intent-ref
          intent
          'spec-evolution-human-audit-review-items
          '()))
   (cons 'spec-evolution-runtime-manifest-rows
         (poo-flow-user-loop-engine-intent-ref
          intent
          'spec-evolution-runtime-manifest-rows
          '()))
   (cons 'budget
         (poo-flow-user-loop-engine-intent-ref intent 'budget '()))
   (cons 'observability
         (poo-flow-user-loop-engine-intent-ref intent 'observability '()))
   (cons 'runtime-executed #f)))
