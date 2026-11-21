;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-engine policy POO objects lowered into intent row fragments.
;;; Invariant: policy rows validate declaration shape but never choose runtime work.

(import (only-in :clan/poo/object .ref)
        "prototypes.ss"
        "contract.ss"
        "kind-contract.ss"
        "row-utils.ss")

(export agentic-ai-lab-user-loop-engine-poo-lineage-policy->rows
        agentic-ai-lab-user-loop-engine-poo-selector-policy->rows
        agentic-ai-lab-user-loop-engine-poo-resource-policy->rows
        agentic-ai-lab-user-loop-engine-poo-capability-policy->rows
        agentic-ai-lab-user-loop-engine-poo-memory-policy->rows
        agentic-ai-lab-user-loop-engine-memory-policy-row-use-case
        agentic-ai-lab-user-loop-engine-require-memory-policy-use-case
        agentic-ai-lab-user-loop-engine-poo-memory-policies->rows/add
        agentic-ai-lab-user-loop-engine-poo-memory-policies->rows
        agentic-ai-lab-user-loop-engine-poo-compression-policy->rows)

;;; Lineage policy rows expose parent-session and export intent as declarative
;;; facts. Scheme validates shape but does not open or traverse sessions.
;; : (-> Value AgenticAILabLoopEngineFlatRow)
(def (agentic-ai-lab-user-loop-engine-poo-lineage-policy->rows lineage-policy)
  (cond
   ((not lineage-policy) '())
   ((agentic-ai-lab-user-loop-engine-poo-kind?
     lineage-policy
     +agentic-ai-lab-user-loop-engine-lineage-policy-prototype-kind+)
    (let ((parent-session-refs (.ref lineage-policy 'parent-session-refs))
          (lineage-kind (.ref lineage-policy 'lineage-kind))
          (lineage-operator (.ref lineage-policy 'lineage-operator))
          (journal (.ref lineage-policy 'journal))
          (export (.ref lineage-policy 'export))
          (entries (.ref lineage-policy 'entries)))
      (agentic-ai-lab-user-loop-engine-require-symbol-list-slot
       'loop-engine-lineage-policy
       'parent-session-refs
       parent-session-refs)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-lineage-policy 'lineage-kind lineage-kind)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-lineage-policy 'lineage-operator lineage-operator)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-lineage-policy 'journal journal)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-lineage-policy 'export export)
      (agentic-ai-lab-user-loop-engine-require-alist-slot
       'loop-engine-lineage-policy 'entries entries)
      (append
       (agentic-ai-lab-user-loop-engine-optional-list-row
        'parent-session-refs
        parent-session-refs)
       (agentic-ai-lab-user-loop-engine-optional-row
        'lineage-kind
        lineage-kind)
       (agentic-ai-lab-user-loop-engine-optional-row
        'lineage-operator
        lineage-operator)
       (agentic-ai-lab-user-loop-engine-optional-row 'journal journal)
       (agentic-ai-lab-user-loop-engine-optional-row 'export export)
       entries)))
   (else
    (error
     "loop-engine lineage-policy slot must extend loop-engine-lineage-policy"
     lineage-policy))))

;;; Selector policy rows keep branch candidates and fallback declarative.
;;; Runtime scoring or model-backed routing happens after Marlin consumes them.
;; : (-> Value AgenticAILabLoopEngineFlatRow)
(def (agentic-ai-lab-user-loop-engine-poo-selector-policy->rows selector-policy)
  (cond
   ((not selector-policy) '())
   ((agentic-ai-lab-user-loop-engine-poo-kind?
     selector-policy
     +agentic-ai-lab-user-loop-engine-selector-policy-prototype-kind+)
    (let ((candidates (.ref selector-policy 'candidates))
          (judge-inputs (.ref selector-policy 'judge-inputs))
          (fallback (.ref selector-policy 'fallback))
          (selected-branch (.ref selector-policy 'selected-branch))
          (entries (.ref selector-policy 'entries)))
      (agentic-ai-lab-user-loop-engine-require-symbol-list-slot
       'loop-engine-selector-policy 'candidates candidates)
      (agentic-ai-lab-user-loop-engine-require-symbol-list-slot
       'loop-engine-selector-policy 'judge-inputs judge-inputs)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-selector-policy 'fallback fallback)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-selector-policy 'selected-branch selected-branch)
      (agentic-ai-lab-user-loop-engine-require-alist-slot
       'loop-engine-selector-policy 'entries entries)
      (append
       (agentic-ai-lab-user-loop-engine-optional-list-row 'candidates candidates)
       (agentic-ai-lab-user-loop-engine-optional-list-row 'judge-inputs judge-inputs)
       (agentic-ai-lab-user-loop-engine-optional-row 'fallback fallback)
       (agentic-ai-lab-user-loop-engine-optional-row
        'selected-branch
        selected-branch)
       entries)))
   (else
    (error
     "loop-engine selector-policy slot must extend loop-engine-selector-policy"
     selector-policy))))

;;; Resource policy rows describe tool/resource collision classes for later
;;; dispatch planning. Scheme preserves the declared groups without scheduling.
;; : (-> Value AgenticAILabLoopEngineFlatRow)
(def (agentic-ai-lab-user-loop-engine-poo-resource-policy->rows resource-policy)
  (cond
   ((not resource-policy) '())
   ((agentic-ai-lab-user-loop-engine-poo-kind?
     resource-policy
     +agentic-ai-lab-user-loop-engine-resource-policy-prototype-kind+)
    (let ((tool-refs (.ref resource-policy 'tool-refs))
          (resource-keys (.ref resource-policy 'resource-keys))
          (collision-classes (.ref resource-policy 'collision-classes))
          (dispatch-groups (.ref resource-policy 'dispatch-groups))
          (entries (.ref resource-policy 'entries)))
      (agentic-ai-lab-user-loop-engine-require-symbol-list-slot
       'loop-engine-resource-policy 'tool-refs tool-refs)
      (agentic-ai-lab-user-loop-engine-require-alist-slot
       'loop-engine-resource-policy 'resource-keys resource-keys)
      (agentic-ai-lab-user-loop-engine-require-alist-slot
       'loop-engine-resource-policy 'collision-classes collision-classes)
      (agentic-ai-lab-user-loop-engine-require-alist-slot
       'loop-engine-resource-policy 'dispatch-groups dispatch-groups)
      (agentic-ai-lab-user-loop-engine-require-alist-slot
       'loop-engine-resource-policy 'entries entries)
      (append
       (agentic-ai-lab-user-loop-engine-optional-list-row 'tool-refs tool-refs)
       (agentic-ai-lab-user-loop-engine-optional-list-row
        'resource-keys
        resource-keys)
       (agentic-ai-lab-user-loop-engine-optional-list-row
        'collision-classes
        collision-classes)
       (agentic-ai-lab-user-loop-engine-optional-list-row
        'dispatch-groups
        dispatch-groups)
       entries)))
   (else
    (error
     "loop-engine resource-policy slot must extend loop-engine-resource-policy"
     resource-policy))))

;;; Capability policy rows record backend requirements as handoff diagnostics.
;;; They do not probe the selected sandbox backend from Scheme.
;; : (-> Value AgenticAILabLoopEngineFlatRow)
(def (agentic-ai-lab-user-loop-engine-poo-capability-policy->rows capability-policy)
  (cond
   ((not capability-policy) '())
   ((agentic-ai-lab-user-loop-engine-poo-kind?
     capability-policy
     +agentic-ai-lab-user-loop-engine-capability-policy-prototype-kind+)
    (let ((backend (.ref capability-policy 'backend))
          (isolation (.ref capability-policy 'isolation))
          (required (.ref capability-policy 'required))
          (optional (.ref capability-policy 'optional))
          (unsupported-behavior (.ref capability-policy 'unsupported-behavior))
          (entries (.ref capability-policy 'entries)))
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-capability-policy 'backend backend)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-capability-policy 'isolation isolation)
      (agentic-ai-lab-user-loop-engine-require-symbol-list-slot
       'loop-engine-capability-policy 'required required)
      (agentic-ai-lab-user-loop-engine-require-symbol-list-slot
       'loop-engine-capability-policy 'optional optional)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-capability-policy
       'unsupported-behavior
       unsupported-behavior)
      (agentic-ai-lab-user-loop-engine-require-alist-slot
       'loop-engine-capability-policy 'entries entries)
      (append
       (agentic-ai-lab-user-loop-engine-optional-row 'backend backend)
       (agentic-ai-lab-user-loop-engine-optional-row 'isolation isolation)
       (agentic-ai-lab-user-loop-engine-optional-list-row 'required required)
       (agentic-ai-lab-user-loop-engine-optional-list-row 'optional optional)
       (agentic-ai-lab-user-loop-engine-optional-row
        'unsupported-behavior
        unsupported-behavior)
       entries)))
   (else
    (error
     "loop-engine capability-policy slot must extend loop-engine-capability-policy"
     capability-policy))))

;;; Memory policy rows are keyed by use-case so a profile can describe several
;;; loop branches without making Scheme choose a memory store.
;; : (-> Value AgenticAILabLoopEngineMemoryPolicyRow)
(def (agentic-ai-lab-user-loop-engine-poo-memory-policy->rows memory-policy)
  (cond
   ((not memory-policy) '())
   ((agentic-ai-lab-user-loop-engine-poo-kind?
     memory-policy
     +agentic-ai-lab-user-loop-engine-memory-policy-prototype-kind+)
    (let ((use-case (.ref memory-policy 'use-case))
          (store (.ref memory-policy 'store))
          (state-path (.ref memory-policy 'state-path))
          (scope (.ref memory-policy 'scope))
          (recall (.ref memory-policy 'recall))
          (commit (.ref memory-policy 'commit))
          (ranking (.ref memory-policy 'ranking))
          (retention (.ref memory-policy 'retention))
          (entries (.ref memory-policy 'entries)))
      (agentic-ai-lab-user-loop-engine-require-slot
       'loop-engine-memory-policy
       'use-case
       'symbol
       (symbol? use-case)
       use-case)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-memory-policy 'store store)
      (agentic-ai-lab-user-loop-engine-require-maybe-string-slot
       'loop-engine-memory-policy 'state-path state-path)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-memory-policy 'scope scope)
      (agentic-ai-lab-user-loop-engine-require-symbol-list-slot
       'loop-engine-memory-policy 'recall recall)
      (agentic-ai-lab-user-loop-engine-require-symbol-list-slot
       'loop-engine-memory-policy 'commit commit)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-memory-policy 'ranking ranking)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-memory-policy 'retention retention)
      (agentic-ai-lab-user-loop-engine-require-alist-slot
       'loop-engine-memory-policy 'entries entries)
      (append
       (list (cons 'use-case use-case))
       (agentic-ai-lab-user-loop-engine-optional-row 'store store)
       (agentic-ai-lab-user-loop-engine-optional-row 'state-path state-path)
       (agentic-ai-lab-user-loop-engine-optional-row 'scope scope)
       (agentic-ai-lab-user-loop-engine-optional-list-row 'recall recall)
       (agentic-ai-lab-user-loop-engine-optional-list-row 'commit commit)
       (agentic-ai-lab-user-loop-engine-optional-row 'ranking ranking)
       (agentic-ai-lab-user-loop-engine-optional-row 'retention retention)
       entries)))
   (else
    (error
     "loop-engine memory-policy slot must extend loop-engine-memory-policy"
     memory-policy))))

;;; The use-case accessor isolates alist shape from duplicate and missing-key
;;; validation so the recursive collector stays readable.
;; : (-> Alist Symbol)
(def (agentic-ai-lab-user-loop-engine-memory-policy-row-use-case row)
  (let (entry (assoc 'use-case row))
    (and entry (cdr entry))))

;;; Memory policy use-case validation keeps profile rows deterministic: every
;;; memory policy must bind exactly one declared loop branch.
;; : (-> Symbol [Symbol] Unit)
(def (agentic-ai-lab-user-loop-engine-require-memory-policy-use-case
      use-case
      use-case-names)
  (agentic-ai-lab-user-loop-engine-require
   "loop-engine memory-policy use-case must match a declared loop-engine use-case"
   (and (symbol? use-case)
        (member use-case use-case-names))
   (list (cons 'use-case use-case)
         (cons 'declared-use-cases use-case-names))))

;;; Memory policy accumulation rejects duplicates early so Marlin receives one
;;; unambiguous state policy for each declared use-case.
;; : (-> [AgenticAILabLoopEngineMemoryPolicyPrototype] [Symbol] [Symbol] [AgenticAILabLoopEngineMemoryPolicyRow])
(def (agentic-ai-lab-user-loop-engine-poo-memory-policies->rows/add
      memory-policies
      use-case-names
      seen-use-cases)
  (cond
   ((null? memory-policies) '())
   ((pair? memory-policies)
    (let* ((row
            (agentic-ai-lab-user-loop-engine-poo-memory-policy->rows
             (car memory-policies)))
           (use-case
            (agentic-ai-lab-user-loop-engine-memory-policy-row-use-case row)))
      (agentic-ai-lab-user-loop-engine-require-memory-policy-use-case
       use-case
       use-case-names)
      (agentic-ai-lab-user-loop-engine-require
       "loop-engine memory-policies must not repeat a use-case"
       (not (member use-case seen-use-cases))
       (list (cons 'use-case use-case)
             (cons 'seen-use-cases seen-use-cases)))
      (cons row
            (agentic-ai-lab-user-loop-engine-poo-memory-policies->rows/add
             (cdr memory-policies)
             use-case-names
             (cons use-case seen-use-cases)))))
   (else
    (error "loop-engine profile memory-policies slot must be a list"
           memory-policies))))

;;; Memory policy lowering starts with an empty seen set; callers pass the
;;; profile-derived use-case names so this owner stays profile-agnostic.
;; : (-> [AgenticAILabLoopEngineMemoryPolicyPrototype] [Symbol] [AgenticAILabLoopEngineMemoryPolicyRow])
(def (agentic-ai-lab-user-loop-engine-poo-memory-policies->rows
      memory-policies
      use-case-names)
  (agentic-ai-lab-user-loop-engine-poo-memory-policies->rows/add
   memory-policies
   use-case-names
   '()))

;;; Compression policy rows describe handoff compaction strategy. Scheme keeps
;;; the declared plan as data and never summarizes session content here.
;; : (-> Value AgenticAILabLoopEngineFlatRow)
(def (agentic-ai-lab-user-loop-engine-poo-compression-policy->rows
      compression-policy)
  (cond
   ((not compression-policy) '())
   ((agentic-ai-lab-user-loop-engine-poo-kind?
     compression-policy
     +agentic-ai-lab-user-loop-engine-compression-policy-prototype-kind+)
    (let ((strategy (.ref compression-policy 'strategy))
          (trigger (.ref compression-policy 'trigger))
          (summary-format (.ref compression-policy 'summary-format))
          (lineage-kind (.ref compression-policy 'lineage-kind))
          (retention (.ref compression-policy 'retention))
          (entries (.ref compression-policy 'entries)))
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-compression-policy 'strategy strategy)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-compression-policy 'trigger trigger)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-compression-policy 'summary-format summary-format)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-compression-policy 'lineage-kind lineage-kind)
      (agentic-ai-lab-user-loop-engine-require-maybe-symbol-slot
       'loop-engine-compression-policy 'retention retention)
      (agentic-ai-lab-user-loop-engine-require-alist-slot
       'loop-engine-compression-policy 'entries entries)
      (append
       (agentic-ai-lab-user-loop-engine-optional-row 'strategy strategy)
       (agentic-ai-lab-user-loop-engine-optional-row 'trigger trigger)
       (agentic-ai-lab-user-loop-engine-optional-row
        'summary-format
        summary-format)
       (agentic-ai-lab-user-loop-engine-optional-row 'lineage-kind lineage-kind)
       (agentic-ai-lab-user-loop-engine-optional-row 'retention retention)
       entries)))
   (else
    (error
     "loop-engine compression-policy slot must extend loop-engine-compression-policy"
     compression-policy))))
