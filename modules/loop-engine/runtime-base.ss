;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-engine runtime base facts and policy envelopes.
;;; Invariant: base helpers are pure report rows and never realize runtime work.

(import (only-in :yuanxu/modules/funflow/graph-projection
                 yuanxu-funflow-workflow-agreement)
        "core.ss"
        "result-contract.ss")

(export agentic-ai-lab-user-loop-engine-primary-agent
        agentic-ai-lab-user-loop-engine-intent-status
        agentic-ai-lab-user-loop-engine-intent-operation-kind
        agentic-ai-lab-user-loop-engine-agent-judge-ref
        agentic-ai-lab-user-loop-engine-agent-judge-pair
        agentic-ai-lab-user-loop-engine-agent-judge-pairs
        agentic-ai-lab-user-loop-engine-intent-primary-sandbox-profile
        agentic-ai-lab-user-loop-engine-intent-agent-profile-refs
        agentic-ai-lab-user-loop-engine-intent-operation-result-contract
        agentic-ai-lab-user-loop-engine-intent-workflow-agreement
        agentic-ai-lab-user-loop-engine-intent-sandbox-handoff-agreement
        agentic-ai-lab-user-loop-engine-intent-runtime-intent
        agentic-ai-lab-user-loop-engine-intent-policy)

;;; The first configured judge is the default runtime target so simple
;;; single-agent loops do not need an explicit governor role.
;; : (-> List Symbol)
(def (agentic-ai-lab-user-loop-engine-primary-agent agent-judges)
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
(def (agentic-ai-lab-user-loop-engine-intent-status intent)
  (if (null? (agentic-ai-lab-user-loop-engine-intent-ref intent 'human-audit '()))
    'admitted
    'waiting-human))

;;; Operation kind mirrors the same human gate so downstream receipts can be
;;; audited without inspecting the raw user module sections.
;; : (-> Alist Symbol)
(def (agentic-ai-lab-user-loop-engine-intent-operation-kind intent)
  (if (null? (agentic-ai-lab-user-loop-engine-intent-ref intent 'human-audit '()))
    'governor-judge
    'human-audit))

;;; Judge rows come from user flags, not a validated schema, so role lookup has
;;; to accept both list-shaped and dotted entries while keeping defaults stable.
;; : (-> [Value] Symbol Value Value)
(def (agentic-ai-lab-user-loop-engine-agent-judge-ref agent-judges role default-value)
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
    (agentic-ai-lab-user-loop-engine-agent-judge-ref
     (cdr agent-judges)
     role
     default-value))))

;;; Role/name normalization is shared by profile, harness, and session
;;; projection so every downstream row receives the same naming decision.
;; : (-> Value MaybeAgentJudgeRef)
(def (agentic-ai-lab-user-loop-engine-agent-judge-pair row)
  (and (pair? row)
       (symbol? (agentic-ai-lab-user-loop-engine-agent-judge-role row))
       (let (tail (agentic-ai-lab-user-loop-engine-agent-judge-tail row))
         (and (not (null? tail))
              (cons (agentic-ai-lab-user-loop-engine-agent-judge-role row)
                    (agentic-ai-lab-user-loop-engine-agent-judge-value tail))))))

;; : (-> AgentJudgeRow Symbol)
(def (agentic-ai-lab-user-loop-engine-agent-judge-role row)
  (car row))

;; : (-> AgentJudgeRow AgentJudgeTail)
(def (agentic-ai-lab-user-loop-engine-agent-judge-tail row)
  (cdr row))

;;; Boundary: user loop engine agent judge value is the policy-visible edge for
;;; module-system, loop behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> AgentJudgeTail AgentJudgeValue)
(def (agentic-ai-lab-user-loop-engine-agent-judge-value tail)
  (if (pair? tail) (car tail) tail))

;;; Invalid judge rows are skipped rather than repaired; malformed user config
;;; should stay visible in the original intent while projections remain total.
;; : (-> [Value] [AgentJudgeRef])
(def (agentic-ai-lab-user-loop-engine-agent-judge-pairs agent-judges)
  (cond
   ((null? agent-judges) '())
   ((agentic-ai-lab-user-loop-engine-agent-judge-pair (car agent-judges))
    => (lambda (role-ref)
         (cons role-ref
               (agentic-ai-lab-user-loop-engine-agent-judge-pairs
                (cdr agent-judges)))))
   (else
    (agentic-ai-lab-user-loop-engine-agent-judge-pairs (cdr agent-judges)))))

;;; Loop-engine agent boundaries use the first declared sandbox profile as a
;;; policy reference only. Actual sandbox realization remains backend-owned.
;; : (-> Alist MaybeSymbol)
(def (agentic-ai-lab-user-loop-engine-intent-primary-sandbox-profile intent)
  (let (refs (agentic-ai-lab-user-loop-engine-intent-ref
              intent
              'sandbox-profile-refs
              '()))
    (if (null? refs) #f (car refs))))

;;; Human audit is modeled as a named profile beside machine judges so agents
;;; can inspect the same profile/harness/session graph for both reviewer types.
;; : (-> Alist [AgentProfileRef])
(def (agentic-ai-lab-user-loop-engine-intent-agent-profile-refs intent)
  (append
   (agentic-ai-lab-user-loop-engine-agent-judge-pairs
    (agentic-ai-lab-user-loop-engine-intent-ref intent 'agent-judges '()))
   (if (null? (agentic-ai-lab-user-loop-engine-intent-ref intent 'human-audit '()))
     '()
     (list (cons 'human-audit 'human-audit)))))

;;; The operation-level adapter is the only result-contract function that needs
;;; operation-kind. The full contract packet lives in loop-engine-result-contract.
;; : (-> Alist Symbol)
(def (agentic-ai-lab-user-loop-engine-intent-operation-result-contract intent)
  (if (eq? (agentic-ai-lab-user-loop-engine-intent-operation-kind intent)
           'human-audit)
    (agentic-ai-lab-user-loop-engine-intent-role-result-contract
     intent
     'human-audit)
    (agentic-ai-lab-user-loop-engine-intent-role-result-contract
     intent
     'governor)))

;;; Workflow agreement is Funflow-owned data cached on the intent. The fallback
;;; keeps older loop-engine rows presentable while still using Funflow's rules.
;; : (-> Alist Alist)
(def (agentic-ai-lab-user-loop-engine-intent-workflow-agreement intent)
  (agentic-ai-lab-user-loop-engine-intent-ref
   intent
   'workflow-agreement
    (yuanxu-funflow-workflow-agreement
     (agentic-ai-lab-user-loop-engine-intent-workflow-ref intent)
     '())))

;;; Runtime consumers may receive older intent rows without the agreement slot;
;;; this accessor makes sandbox readiness total and keeps snapshot/handoff code
;;; from re-encoding agreement shape in multiple places.
;; : (-> Alist Alist)
(def (agentic-ai-lab-user-loop-engine-intent-sandbox-handoff-agreement intent)
  (agentic-ai-lab-user-loop-engine-intent-ref
   intent
   'sandbox-handoff-agreement
   (agentic-ai-lab-user-loop-engine-sandbox-handoff-agreement
    (agentic-ai-lab-user-loop-engine-intent-ref
     intent
     'sandbox-profile-refs
     '())
    (agentic-ai-lab-user-loop-engine-intent-ref
     intent
     'sandbox-runtime-summaries
     '())
    (agentic-ai-lab-user-loop-engine-intent-ref
     intent
     'sandbox-handoff-summaries
     '())
    (agentic-ai-lab-user-loop-engine-intent-ref
     intent
     'sandbox-unresolved-profile-refs
     '()))))

;;; Runtime intent is the compact policy pointer embedded in profiles,
;;; harnesses, receipts, and operations before a backend materializes them.
;; : (-> Alist Alist)
(def (agentic-ai-lab-user-loop-engine-intent-runtime-intent intent)
  (list
   (cons 'runtime-handoff
         (agentic-ai-lab-user-loop-engine-intent-ref
          intent
          'runtime-handoff
          'loop-governor-marlin-runtime-manifest))
   (cons 'runtime-owner
         (agentic-ai-lab-user-loop-engine-intent-ref
          intent
          'runtime-owner
          "marlin-agent-core"))
   (cons 'handoff-contracts +agentic-ai-lab-user-loop-engine-handoff-contracts+)
   (cons 'runtime-command-contract
         +agentic-ai-lab-user-loop-engine-runtime-command-contract+)
   (cons 'result-contract
         (agentic-ai-lab-user-loop-engine-intent-result-contract intent))
   (cons 'object-families
         +agentic-ai-lab-user-loop-engine-runtime-object-families+)
   (cons 'receipt-contracts
         +agentic-ai-lab-user-loop-engine-receipt-contracts+)
   (cons 'workflow-ref
         (agentic-ai-lab-user-loop-engine-intent-workflow-ref intent))
   (cons 'workflow-agreement
         (agentic-ai-lab-user-loop-engine-intent-workflow-agreement intent))
   (cons 'lineage-policy
         (agentic-ai-lab-user-loop-engine-intent-ref intent 'lineage-policy '()))
   (cons 'selector-policy
         (agentic-ai-lab-user-loop-engine-intent-ref intent 'selector-policy '()))
   (cons 'resource-policy
         (agentic-ai-lab-user-loop-engine-intent-ref intent 'resource-policy '()))
   (cons 'capability-policy
         (agentic-ai-lab-user-loop-engine-intent-ref
          intent
          'capability-policy
          '()))
   (cons 'memory-policies
         (agentic-ai-lab-user-loop-engine-intent-ref
          intent
          'memory-policies
          '()))
   (cons 'compression-policy
         (agentic-ai-lab-user-loop-engine-intent-ref
          intent
          'compression-policy
          '()))
   (cons 'session-selector-receipts
         (agentic-ai-lab-user-loop-engine-intent-ref
          intent
          'session-selector-receipts
          '()))
   (cons 'session-materialization-receipts
         (agentic-ai-lab-user-loop-engine-intent-ref
          intent
          'session-materialization-receipts
          '()))
   (cons 'policy-extension-receipts
         (agentic-ai-lab-user-loop-engine-intent-ref
          intent
          'policy-extension-receipts
          '()))
   (cons 'spec-evolution-reviews
         (agentic-ai-lab-user-loop-engine-intent-ref
          intent
          'spec-evolution-reviews
          '()))
   (cons 'spec-evolution-human-audit-review-items
         (agentic-ai-lab-user-loop-engine-intent-ref
          intent
          'spec-evolution-human-audit-review-items
          '()))
   (cons 'spec-evolution-runtime-manifest-rows
         (agentic-ai-lab-user-loop-engine-intent-ref
          intent
          'spec-evolution-runtime-manifest-rows
          '()))
   (cons 'executes-runtime #f)))

;;; Policy projection is the loop-engine guardrail packet. It keeps governor,
;;; human audit, sandbox, budget, and observability rows together so Marlin sees
;;; one coherent handoff policy instead of scattered presentation fields.
;; : (-> Alist Alist)
(def (agentic-ai-lab-user-loop-engine-intent-policy intent)
  (list
   (cons 'governor
         (agentic-ai-lab-user-loop-engine-intent-ref intent 'governor '()))
   (cons 'human-audit
         (agentic-ai-lab-user-loop-engine-intent-ref intent 'human-audit '()))
   (cons 'sandbox
         (agentic-ai-lab-user-loop-engine-intent-ref intent 'sandbox '()))
   (cons 'sandbox-profile-refs
         (agentic-ai-lab-user-loop-engine-intent-ref
          intent
          'sandbox-profile-refs
          '()))
   (cons 'sandbox-runtime-summaries
         (agentic-ai-lab-user-loop-engine-intent-ref
          intent
          'sandbox-runtime-summaries
          '()))
   (cons 'sandbox-handoff-summaries
         (agentic-ai-lab-user-loop-engine-intent-ref
          intent
          'sandbox-handoff-summaries
          '()))
   (cons 'sandbox-handoff-agreement
         (agentic-ai-lab-user-loop-engine-intent-sandbox-handoff-agreement
          intent))
   (cons 'sandbox-unresolved-profile-refs
         (agentic-ai-lab-user-loop-engine-intent-ref
          intent
          'sandbox-unresolved-profile-refs
          '()))
   (cons 'workflow-agreement
         (agentic-ai-lab-user-loop-engine-intent-workflow-agreement intent))
   (cons 'lineage-policy
         (agentic-ai-lab-user-loop-engine-intent-ref intent 'lineage-policy '()))
   (cons 'selector-policy
         (agentic-ai-lab-user-loop-engine-intent-ref intent 'selector-policy '()))
   (cons 'resource-policy
         (agentic-ai-lab-user-loop-engine-intent-ref intent 'resource-policy '()))
   (cons 'capability-policy
         (agentic-ai-lab-user-loop-engine-intent-ref
          intent
          'capability-policy
          '()))
   (cons 'memory-policies
         (agentic-ai-lab-user-loop-engine-intent-ref
          intent
          'memory-policies
          '()))
   (cons 'compression-policy
         (agentic-ai-lab-user-loop-engine-intent-ref
          intent
          'compression-policy
          '()))
   (cons 'policy-extension-receipts
         (agentic-ai-lab-user-loop-engine-intent-ref
          intent
          'policy-extension-receipts
          '()))
   (cons 'spec-evolution-reviews
         (agentic-ai-lab-user-loop-engine-intent-ref
          intent
          'spec-evolution-reviews
          '()))
   (cons 'spec-evolution-human-audit-review-items
         (agentic-ai-lab-user-loop-engine-intent-ref
          intent
          'spec-evolution-human-audit-review-items
          '()))
   (cons 'spec-evolution-runtime-manifest-rows
         (agentic-ai-lab-user-loop-engine-intent-ref
          intent
          'spec-evolution-runtime-manifest-rows
          '()))
   (cons 'budget
         (agentic-ai-lab-user-loop-engine-intent-ref intent 'budget '()))
   (cons 'observability
         (agentic-ai-lab-user-loop-engine-intent-ref intent 'observability '()))
   (cons 'runtime-executed #f)))
