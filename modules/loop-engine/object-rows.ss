;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-engine non-policy POO objects lowered into intent row fragments.
;;; Invariant: object rows validate declarations and stay runtime-report data.

(import (only-in :clan/poo/object .ref)
        "prototypes.ss"
        "contract.ss"
        "kind-contract.ss"
        "row-utils.ss")

(export agentic-ai-lab-user-loop-engine-poo-use-case->row
        agentic-ai-lab-user-loop-engine-poo-use-cases->rows
        agentic-ai-lab-user-loop-engine-poo-governor->rows
        agentic-ai-lab-user-loop-engine-judge-row
        agentic-ai-lab-user-loop-engine-poo-agent-judges->rows
        agentic-ai-lab-user-loop-engine-poo-human-audit->rows
        agentic-ai-lab-user-loop-engine-poo-schedule->rows
        agentic-ai-lab-user-loop-engine-poo-state->rows
        agentic-ai-lab-user-loop-engine-poo-sandbox->rows
        agentic-ai-lab-user-loop-engine-poo-budget->rows
        agentic-ai-lab-user-loop-engine-result-role-row
        agentic-ai-lab-user-loop-engine-poo-result->rows
        agentic-ai-lab-user-loop-engine-poo-observability->rows
        agentic-ai-lab-user-loop-engine-poo-runtime->rows)

;;; Use-case rows are the named branch declarations consumed by selector,
;;; memory, and runtime handoff projections.
;; : (-> Value AgenticAILabLoopEngineUseCaseRow)
(def (agentic-ai-lab-user-loop-engine-poo-use-case->row use-case)
  (agentic-ai-lab-user-loop-engine-require
   "loop-engine use-case config object must extend loop-engine-use-case"
   (agentic-ai-lab-user-loop-engine-poo-use-case? use-case)
   use-case)
  (let ((name (.ref use-case 'name))
        (level (.ref use-case 'level))
        (mode (.ref use-case 'mode))
        (goal (.ref use-case 'goal))
        (workflow (.ref use-case 'workflow))
        (metadata (.ref use-case 'metadata)))
    (agentic-ai-lab-user-loop-engine-require
     "loop-engine use-case name must be a symbol"
     (symbol? name)
     name)
    (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
     'loop-engine-use-case 'level level)
    (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
     'loop-engine-use-case 'mode mode)
    (agentic-ai-lab-user-loop-engine-require-maybe-symbol-or-string-slot
     'loop-engine-use-case 'goal goal)
    (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
     'loop-engine-use-case 'workflow workflow)
    (agentic-ai-lab-user-loop-engine-require-alist-slot
     'loop-engine-use-case 'metadata metadata)
    (cons name
          (append
           (agentic-ai-lab-user-loop-engine-optional-row 'level level)
           (agentic-ai-lab-user-loop-engine-optional-row 'mode mode)
           (agentic-ai-lab-user-loop-engine-optional-row 'goal goal)
           (agentic-ai-lab-user-loop-engine-optional-row 'workflow workflow)
           metadata))))

;;; Use-case lists preserve declaration order because selector defaults and
;;; presentation rows use that same order downstream.
;; : (-> [AgenticAILabLoopEngineUseCasePrototype] [AgenticAILabLoopEngineUseCaseRow])
(def (agentic-ai-lab-user-loop-engine-poo-use-cases->rows use-cases)
  (cond
   ((null? use-cases) '())
   ((pair? use-cases)
    (cons
     (agentic-ai-lab-user-loop-engine-poo-use-case->row (car use-cases))
     (agentic-ai-lab-user-loop-engine-poo-use-cases->rows (cdr use-cases))))
   (else
    (error "loop-engine profile use-cases slot must be a list" use-cases))))

;;; Governor rows describe strategy capabilities only. Runtime selection of the
;;; governor agent happens later from agent-judges.
;; : (-> AgenticAILabLoopEngineGovernorPrototype [AgenticAILabLoopEngineFlatRow])
(def (agentic-ai-lab-user-loop-engine-poo-governor->rows governor)
  (cond
   ((not governor) '())
   ((agentic-ai-lab-user-loop-engine-poo-kind?
     governor
     +agentic-ai-lab-user-loop-engine-governor-prototype-kind+)
    (let ((capabilities (.ref governor 'capabilities))
          (metadata (.ref governor 'metadata)))
      (agentic-ai-lab-user-loop-engine-require-symbol-list-slot
       'loop-engine-governor 'capabilities capabilities)
      (agentic-ai-lab-user-loop-engine-require-alist-slot
       'loop-engine-governor 'metadata metadata)
      (append capabilities metadata)))
   (else
    (error "loop-engine governor slot must extend loop-engine-governor"
           governor))))

;;; Judge rows use list shape to preserve the role/name distinction in alist
;;; presentation without treating agent names as executable selectors.
;; : (-> Symbol Value [AgenticAILabLoopEngineRoleRow])
(def (agentic-ai-lab-user-loop-engine-judge-row role value)
  (if value (list (list role value)) '()))

;;; Agent-judge rows name the human and model roles that Marlin may bind later.
;;; Scheme only validates the optional symbol slots.
;; : (-> Value [AgenticAILabLoopEngineRoleRow])
(def (agentic-ai-lab-user-loop-engine-poo-agent-judges->rows agent-judges)
  (cond
   ((not agent-judges) '())
   ((agentic-ai-lab-user-loop-engine-poo-kind?
     agent-judges
     +agentic-ai-lab-user-loop-engine-agent-judges-prototype-kind+)
    (let ((auditor (.ref agent-judges 'auditor))
          (verifier (.ref agent-judges 'verifier))
          (reviewer (.ref agent-judges 'reviewer))
          (governor (.ref agent-judges 'governor))
          (metadata (.ref agent-judges 'metadata)))
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-agent-judges 'auditor auditor)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-agent-judges 'verifier verifier)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-agent-judges 'reviewer reviewer)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-agent-judges 'governor governor)
      (agentic-ai-lab-user-loop-engine-require-alist-slot
       'loop-engine-agent-judges 'metadata metadata)
      (append
       (agentic-ai-lab-user-loop-engine-judge-row 'auditor auditor)
       (agentic-ai-lab-user-loop-engine-judge-row 'verifier verifier)
       (agentic-ai-lab-user-loop-engine-judge-row 'reviewer reviewer)
       (agentic-ai-lab-user-loop-engine-judge-row 'governor governor)
       metadata)))
   (else
    (error "loop-engine agent-judges slot must extend loop-engine-agent-judges"
           agent-judges))))

;;; Human-audit rows keep manual gate actions as policy vocabulary. They do not
;;; invoke reviewers or block execution inside Scheme.
;; : (-> AgenticAILabLoopEngineHumanAuditPrototype [AgenticAILabLoopEngineFlatRow])
(def (agentic-ai-lab-user-loop-engine-poo-human-audit->rows human-audit)
  (cond
   ((not human-audit) '())
   ((agentic-ai-lab-user-loop-engine-poo-kind?
     human-audit
     +agentic-ai-lab-user-loop-engine-human-audit-prototype-kind+)
    (let ((actions (.ref human-audit 'actions))
          (metadata (.ref human-audit 'metadata)))
      (agentic-ai-lab-user-loop-engine-require-symbol-list-slot
       'loop-engine-human-audit 'actions actions)
      (agentic-ai-lab-user-loop-engine-require-alist-slot
       'loop-engine-human-audit 'metadata metadata)
      (append actions metadata)))
   (else
    (error "loop-engine human-audit slot must extend loop-engine-human-audit"
           human-audit))))

;;; Schedule rows are trigger metadata only; timers and recurrence are runtime
;;; or external scheduler responsibilities.
;; : (-> Value AgenticAILabLoopEngineFlatRow)
(def (agentic-ai-lab-user-loop-engine-poo-schedule->rows schedule)
  (cond
   ((not schedule) '())
   ((agentic-ai-lab-user-loop-engine-poo-kind?
     schedule
     +agentic-ai-lab-user-loop-engine-schedule-prototype-kind+)
    (let ((trigger (.ref schedule 'trigger))
          (cadence (.ref schedule 'cadence))
          (entries (.ref schedule 'entries)))
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-schedule 'trigger trigger)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-schedule 'cadence cadence)
      (agentic-ai-lab-user-loop-engine-require-alist-slot
       'loop-engine-schedule 'entries entries)
      (append
       (agentic-ai-lab-user-loop-engine-optional-row 'trigger trigger)
       (agentic-ai-lab-user-loop-engine-optional-row 'cadence cadence)
       entries)))
   (else
    (error "loop-engine schedule slot must extend loop-engine-schedule"
           schedule))))

;;; State rows name stores and paths as handoff facts. They do not read or
;;; mutate state files in the Scheme control plane.
;; : (-> Value AgenticAILabLoopEngineFlatRow)
(def (agentic-ai-lab-user-loop-engine-poo-state->rows state)
  (cond
   ((not state) '())
   ((agentic-ai-lab-user-loop-engine-poo-kind?
     state
     +agentic-ai-lab-user-loop-engine-state-prototype-kind+)
    (let ((store (.ref state 'store))
          (path (.ref state 'path))
          (acting-on (.ref state 'acting-on))
          (entries (.ref state 'entries)))
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-state 'store store)
      (agentic-ai-lab-user-loop-engine-require-maybe-string-slot
       'loop-engine-state 'path path)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-state 'acting-on acting-on)
      (agentic-ai-lab-user-loop-engine-require-alist-slot
       'loop-engine-state 'entries entries)
      (append
       (agentic-ai-lab-user-loop-engine-optional-row 'store store)
       (agentic-ai-lab-user-loop-engine-optional-row 'path path)
       (agentic-ai-lab-user-loop-engine-optional-row 'acting-on acting-on)
       entries)))
   (else
    (error "loop-engine state slot must extend loop-engine-state" state))))

;;; Sandbox rows collect profile references and per-use-case overrides for the
;;; sandbox agreement owner; they do not start containers or processes.
;; : (-> Value AgenticAILabLoopEngineFlatRow)
(def (agentic-ai-lab-user-loop-engine-poo-sandbox->rows sandbox)
  (cond
   ((not sandbox) '())
   ((agentic-ai-lab-user-loop-engine-poo-kind?
     sandbox
     +agentic-ai-lab-user-loop-engine-sandbox-prototype-kind+)
    (let ((profile (.ref sandbox 'profile))
          (isolation (.ref sandbox 'isolation))
          (profile-refs (.ref sandbox 'profile-refs))
          (case-profile-refs (.ref sandbox 'case-profile-refs))
          (entries (.ref sandbox 'entries)))
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-sandbox 'profile profile)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-sandbox 'isolation isolation)
      (agentic-ai-lab-user-loop-engine-require-symbol-list-slot
       'loop-engine-sandbox 'profile-refs profile-refs)
      (agentic-ai-lab-user-loop-engine-require-alist-slot
       'loop-engine-sandbox 'case-profile-refs case-profile-refs)
      (agentic-ai-lab-user-loop-engine-require-alist-slot
       'loop-engine-sandbox 'entries entries)
      (append
       (agentic-ai-lab-user-loop-engine-optional-row 'profile profile)
       (agentic-ai-lab-user-loop-engine-optional-row 'isolation isolation)
       profile-refs
       case-profile-refs
       entries)))
   (else
    (error "loop-engine sandbox slot must extend loop-engine-sandbox"
           sandbox))))

;;; Budget rows express declarative limits for runtime enforcement. Scheme only
;;; preserves the configured numbers.
;; : (-> Value AgenticAILabLoopEngineFlatRow)
(def (agentic-ai-lab-user-loop-engine-poo-budget->rows budget)
  (cond
   ((not budget) '())
   ((agentic-ai-lab-user-loop-engine-poo-kind?
     budget
     +agentic-ai-lab-user-loop-engine-budget-prototype-kind+)
    (let ((max-actionable (.ref budget 'max-actionable))
          (max-attempts (.ref budget 'max-attempts))
          (weekly-runs (.ref budget 'weekly-runs))
          (entries (.ref budget 'entries)))
      (agentic-ai-lab-user-loop-engine-require-maybe-integer-slot
       'loop-engine-budget 'max-actionable max-actionable)
      (agentic-ai-lab-user-loop-engine-require-maybe-integer-slot
       'loop-engine-budget 'max-attempts max-attempts)
      (agentic-ai-lab-user-loop-engine-require-maybe-integer-slot
       'loop-engine-budget 'weekly-runs weekly-runs)
      (agentic-ai-lab-user-loop-engine-require-alist-slot
       'loop-engine-budget 'entries entries)
      (append
       (agentic-ai-lab-user-loop-engine-optional-row
        'max-actionable
        max-actionable)
       (agentic-ai-lab-user-loop-engine-optional-row 'max-attempts max-attempts)
       (agentic-ai-lab-user-loop-engine-optional-row 'weekly-runs weekly-runs)
       entries)))
   (else
    (error "loop-engine budget slot must extend loop-engine-budget" budget))))

;;; Result role rows preserve role-specific result contracts while keeping a
;;; compact alist representation for downstream validators.
;; : (-> Symbol Value [AgenticAILabLoopEngineRoleRow])
(def (agentic-ai-lab-user-loop-engine-result-role-row role value)
  (if value (list (cons role value)) '()))

;;; Result rows are schema references only. Validation of concrete result
;;; payloads remains a runtime or ABI consumer responsibility.
;; : (-> Value AgenticAILabLoopEngineFlatRow)
(def (agentic-ai-lab-user-loop-engine-poo-result->rows result)
  (cond
   ((not result) '())
   ((agentic-ai-lab-user-loop-engine-poo-kind?
     result
     +agentic-ai-lab-user-loop-engine-result-prototype-kind+)
    (let ((default (.ref result 'default))
          (auditor (.ref result 'auditor))
          (verifier (.ref result 'verifier))
          (reviewer (.ref result 'reviewer))
          (governor (.ref result 'governor))
          (human-audit (.ref result 'human-audit))
          (format (.ref result 'format))
          (required-fields (.ref result 'required-fields))
          (entries (.ref result 'entries)))
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-result 'default default)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-result 'auditor auditor)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-result 'verifier verifier)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-result 'reviewer reviewer)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-result 'governor governor)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-result 'human-audit human-audit)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-result 'format format)
      (agentic-ai-lab-user-loop-engine-require-symbol-list-slot
       'loop-engine-result 'required-fields required-fields)
      (agentic-ai-lab-user-loop-engine-require-alist-slot
       'loop-engine-result 'entries entries)
      (append
       (agentic-ai-lab-user-loop-engine-result-role-row 'default default)
       (agentic-ai-lab-user-loop-engine-result-role-row 'auditor auditor)
       (agentic-ai-lab-user-loop-engine-result-role-row 'verifier verifier)
       (agentic-ai-lab-user-loop-engine-result-role-row 'reviewer reviewer)
       (agentic-ai-lab-user-loop-engine-result-role-row 'governor governor)
       (agentic-ai-lab-user-loop-engine-result-role-row 'human-audit human-audit)
       (list (cons 'format format)
             (cons 'required-fields required-fields))
       entries)))
   (else
    (error "loop-engine result slot must extend loop-engine-result" result))))

;;; Observability rows expose receipt and run-log preferences as data so the
;;; runtime can decide how to materialize traces.
;; : (-> Value AgenticAILabLoopEngineFlatRow)
(def (agentic-ai-lab-user-loop-engine-poo-observability->rows observability)
  (cond
   ((not observability) '())
   ((agentic-ai-lab-user-loop-engine-poo-kind?
     observability
     +agentic-ai-lab-user-loop-engine-observability-prototype-kind+)
    (let ((receipt (.ref observability 'receipt))
          (run-log (.ref observability 'run-log))
          (entries (.ref observability 'entries)))
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-observability 'receipt receipt)
      (agentic-ai-lab-user-loop-engine-require-maybe-string-slot
       'loop-engine-observability 'run-log run-log)
      (agentic-ai-lab-user-loop-engine-require-alist-slot
       'loop-engine-observability 'entries entries)
      (append
       (agentic-ai-lab-user-loop-engine-optional-row 'receipt receipt)
       (agentic-ai-lab-user-loop-engine-optional-row 'run-log run-log)
       entries)))
   (else
    (error
     "loop-engine observability slot must extend loop-engine-observability"
     observability))))

;;; Runtime rows describe handoff contract and owner selection. They do not
;;; invoke the runtime adapter or shell out.
;; : (-> AgenticAILabLoopEngineRuntimePrototype [AgenticAILabLoopEngineFlatRow])
(def (agentic-ai-lab-user-loop-engine-poo-runtime->rows runtime)
  (cond
   ((not runtime) '())
   ((agentic-ai-lab-user-loop-engine-poo-kind?
     runtime
     +agentic-ai-lab-user-loop-engine-runtime-prototype-kind+)
    (let ((capabilities (.ref runtime 'capabilities))
          (handoff (.ref runtime 'handoff))
          (owner (.ref runtime 'owner))
          (entries (.ref runtime 'entries)))
      (agentic-ai-lab-user-loop-engine-require-symbol-list-slot
       'loop-engine-runtime 'capabilities capabilities)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-runtime 'handoff handoff)
      (agentic-ai-lab-user-loop-engine-require-maybe-string-slot
       'loop-engine-runtime 'owner owner)
      (agentic-ai-lab-user-loop-engine-require-alist-slot
       'loop-engine-runtime 'entries entries)
      (append capabilities entries)))
   (else
    (error "loop-engine runtime slot must extend loop-engine-runtime"
           runtime))))
