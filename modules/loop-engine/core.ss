;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-engine declaration helpers and shared runtime vocabulary.
;;; Invariant: this owner normalizes user rows but never builds command manifests.

(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :poo-flow/modules/session/materialization
                 poo-flow-session-materialization-receipt?
                 poo-flow-session-materialization-receipt->alist)
        (only-in :poo-flow/modules/session/selector
                 poo-flow-session-selector-receipt?
                 poo-flow-session-selector-receipt->alist)
        (only-in :poo-flow/modules/loop-engine/control/spec-evolution
                 spec-evolution-review-item?
                 spec-evolution-review-item->alist
                 spec-evolution-review-item->human-audit-review-item
                 spec-evolution-review-item->runtime-manifest-row)
        :core/module-system/selection/objects
        "prototypes.ss"
        "contract.ss"
        "kind-contract.ss"
        "row-utils.ss"
        "runtime-vocabulary.ss"
        "intent-utils.ss"
        "sandbox-handoff.ss"
        "object-rows.ss"
        "policy-rows.ss"
        "policy-extension.ss")

(export poo-flow-user-loop-engine-section
        (import: "prototypes.ss")
        (import: "runtime-vocabulary.ss")
        (import: "intent-utils.ss")
        (import: "sandbox-handoff.ss")
        (import: "policy-extension.ss")
        poo-flow-user-loop-engine-poo-use-case?
        poo-flow-user-loop-engine-poo-profile?
        poo-flow-user-loop-engine-poo-config-flags
        poo-flow-user-loop-engine-selection-poo-intent)

;;; Section extraction normalizes module flags into list-shaped rows so profile
;;; lowering can treat shorthand flags and repeated entries uniformly.
;; : (-> PooUserModuleSelection Symbol [Value])
(def (poo-flow-user-loop-engine-section selection section)
  (let (entry (poo-flow-user-module-selection-flag-entry selection section))
    (cond
     ((and entry (pair? entry)) (cdr entry))
     (entry (list entry))
     (else '()))))

;;; Boundary: user loop engine use case row name list is the policy-visible
;;; edge for module-system, loop, core behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> Alist [Symbol])
(def (poo-flow-user-loop-engine-use-case-row-name-list row)
  (if (and (pair? row) (symbol? (car row)))
    (list (car row))
    '()))

;;; Session selector receipts are functional values supplied by session modules.
;;; Loop profiles store the values, and this boundary projects them once.
;; : (-> PooSessionSelectorReceipt Alist)
(def (poo-flow-user-loop-engine-session-selector-receipt->row receipt)
  (poo-flow-user-loop-engine-require
   "loop-engine session-selector-receipts slot requires selector receipts"
   (poo-flow-session-selector-receipt? receipt)
   receipt)
  (poo-flow-session-selector-receipt->alist receipt))

;; : (-> [PooSessionSelectorReceipt] [Alist])
(def (poo-flow-user-loop-engine-session-selector-receipts->rows receipts)
  (cond
   ((null? receipts) '())
   ((pair? receipts)
    (cons
     (poo-flow-user-loop-engine-session-selector-receipt->row
      (car receipts))
     (poo-flow-user-loop-engine-session-selector-receipts->rows
      (cdr receipts))))
   (else
    (error "loop-engine profile session-selector-receipts slot must be a list"
           receipts))))

;;; Session materialization receipts stay runtime-owned; Scheme only carries
;;; their report shape into the loop handoff packet.
;; : (-> PooSessionMaterializationReceipt Alist)
(def (poo-flow-user-loop-engine-session-materialization-receipt->row receipt)
  (poo-flow-user-loop-engine-require
   "loop-engine session-materialization-receipts slot requires materialization receipts"
   (poo-flow-session-materialization-receipt? receipt)
   receipt)
  (poo-flow-session-materialization-receipt->alist receipt))

;; : (-> [PooSessionMaterializationReceipt] [Alist])
(def (poo-flow-user-loop-engine-session-materialization-receipts->rows receipts)
  (cond
   ((null? receipts) '())
   ((pair? receipts)
    (cons
     (poo-flow-user-loop-engine-session-materialization-receipt->row
      (car receipts))
     (poo-flow-user-loop-engine-session-materialization-receipts->rows
      (cdr receipts))))
   (else
    (error "loop-engine profile session-materialization-receipts slot must be a list"
           receipts))))

;;; Spec evolution rows are Human Audit inputs. Users attach POO review items to
;;; the profile; this owner only projects them into report-only boundary rows.
;; : (-> SpecEvolutionReviewItem Alist)
(def (poo-flow-user-loop-engine-spec-evolution-review-item->row item)
  (poo-flow-user-loop-engine-require
   "loop-engine spec-evolution-review-items slot requires spec evolution review items"
   (spec-evolution-review-item? item)
   item)
  (spec-evolution-review-item->alist item))

;; : (-> SpecEvolutionReviewItem Alist)
(def (poo-flow-user-loop-engine-spec-evolution-review-item->human-audit-row
      item)
  (poo-flow-user-loop-engine-require
   "loop-engine spec-evolution-review-items slot requires spec evolution review items"
   (spec-evolution-review-item? item)
   item)
  (spec-evolution-review-item->human-audit-review-item item))

;; : (-> SpecEvolutionReviewItem Alist)
(def (poo-flow-user-loop-engine-spec-evolution-review-item->manifest-row
      item)
  (poo-flow-user-loop-engine-require
   "loop-engine spec-evolution-review-items slot requires spec evolution review items"
   (spec-evolution-review-item? item)
   item)
  (spec-evolution-review-item->runtime-manifest-row item))

;; : (-> [SpecEvolutionReviewItem] [Alist])
(def (poo-flow-user-loop-engine-spec-evolution-review-items->rows items)
  (cond
   ((null? items) '())
   ((pair? items)
    (cons
     (poo-flow-user-loop-engine-spec-evolution-review-item->row (car items))
     (poo-flow-user-loop-engine-spec-evolution-review-items->rows
      (cdr items))))
   (else
    (error "loop-engine profile spec-evolution-review-items slot must be a list"
           items))))

;; : (-> [SpecEvolutionReviewItem] [Alist])
(def (poo-flow-user-loop-engine-spec-evolution-review-items->human-audit-rows
      items)
  (cond
   ((null? items) '())
   ((pair? items)
    (cons
     (poo-flow-user-loop-engine-spec-evolution-review-item->human-audit-row
      (car items))
     (poo-flow-user-loop-engine-spec-evolution-review-items->human-audit-rows
      (cdr items))))
   (else
    (error "loop-engine profile spec-evolution-review-items slot must be a list"
           items))))

;; : (-> [SpecEvolutionReviewItem] [Alist])
(def (poo-flow-user-loop-engine-spec-evolution-review-items->manifest-rows
      items)
  (cond
   ((null? items) '())
   ((pair? items)
    (cons
     (poo-flow-user-loop-engine-spec-evolution-review-item->manifest-row
      (car items))
     (poo-flow-user-loop-engine-spec-evolution-review-items->manifest-rows
      (cdr items))))
   (else
    (error "loop-engine profile spec-evolution-review-items slot must be a list"
           items))))

;;; Profile intent projection is the sole join point for object rows, policy
;;; rows, policy-extension receipts, and runtime ownership facts. Keeping this
;;; normalized alist report-only lets presentation and runtime manifest code
;;; consume the same shape without rebuilding POO objects.
;; : (-> PooFlowLoopEngineProfilePrototype Alist)
(def (poo-flow-user-loop-engine-poo-profile->intent-fields profile)
  (poo-flow-user-loop-engine-require
   "loop-engine config object must extend loop-engine-profile"
   (poo-flow-user-loop-engine-poo-profile? profile)
   profile)
  (let* ((profile-name (.ref profile 'profile-name))
         (use-case (.ref profile 'use-case))
         (use-cases (.ref profile 'use-cases))
         (use-case-row
          (if use-case
            (poo-flow-user-loop-engine-poo-use-case->row use-case)
            '()))
         (use-case-rows
          (poo-flow-user-loop-engine-poo-use-cases->rows use-cases))
         (use-case-names
          (append
           (poo-flow-user-loop-engine-use-case-row-name-list use-case-row)
           (poo-flow-user-loop-engine-use-case-names/add use-case-rows)))
         (runtime (.ref profile 'runtime))
         (metadata (.ref profile 'metadata)))
    (poo-flow-user-loop-engine-require-maybe-symbol-slot
     'loop-engine-profile 'profile-name profile-name)
    (poo-flow-user-loop-engine-require-slot
     'loop-engine-profile
     'use-cases
     'list
     (list? use-cases)
     use-cases)
    (poo-flow-user-loop-engine-require-alist-slot
     'loop-engine-profile 'metadata metadata)
    (append
     (list
      (cons 'use-case
            use-case-row)
      (cons 'use-cases use-case-rows)
      (cons 'governor
            (poo-flow-user-loop-engine-poo-governor->rows
             (.ref profile 'governor)))
      (cons 'agent-judges
            (poo-flow-user-loop-engine-poo-agent-judges->rows
             (.ref profile 'agent-judges)))
      (cons 'human-audit
            (poo-flow-user-loop-engine-poo-human-audit->rows
             (.ref profile 'human-audit)))
      (cons 'schedule
            (poo-flow-user-loop-engine-poo-schedule->rows
             (.ref profile 'schedule)))
      (cons 'state
            (poo-flow-user-loop-engine-poo-state->rows
             (.ref profile 'state)))
      (cons 'sandbox
            (poo-flow-user-loop-engine-poo-sandbox->rows
             (.ref profile 'sandbox)))
      (cons 'budget
            (poo-flow-user-loop-engine-poo-budget->rows
             (.ref profile 'budget)))
      (cons 'observability
            (poo-flow-user-loop-engine-poo-observability->rows
             (.ref profile 'observability)))
      (cons 'result
            (poo-flow-user-loop-engine-poo-result->rows
             (.ref profile 'result)))
      (cons 'runtime
            (poo-flow-user-loop-engine-poo-runtime->rows runtime))
      (cons 'lineage-policy
            (poo-flow-user-loop-engine-poo-lineage-policy->rows
             (.ref profile 'lineage-policy)))
      (cons 'selector-policy
            (poo-flow-user-loop-engine-poo-selector-policy->rows
             (.ref profile 'selector-policy)))
      (cons 'resource-policy
            (poo-flow-user-loop-engine-poo-resource-policy->rows
             (.ref profile 'resource-policy)))
      (cons 'capability-policy
            (poo-flow-user-loop-engine-poo-capability-policy->rows
             (.ref profile 'capability-policy)))
      (cons 'memory-policies
            (poo-flow-user-loop-engine-poo-memory-policies->rows
             (.ref profile 'memory-policies)
             use-case-names))
      (cons 'compression-policy
            (poo-flow-user-loop-engine-poo-compression-policy->rows
             (.ref profile 'compression-policy)))
      (cons 'session-selector-receipts
            (poo-flow-user-loop-engine-session-selector-receipts->rows
             (.ref profile 'session-selector-receipts)))
      (cons 'session-materialization-receipts
            (poo-flow-user-loop-engine-session-materialization-receipts->rows
             (.ref profile 'session-materialization-receipts)))
      (cons 'policy-extension-receipts
            (poo-flow-user-loop-engine-poo-policy-extensions->receipts
             (.ref profile 'policy-extensions)))
      (cons 'spec-evolution-reviews
            (poo-flow-user-loop-engine-spec-evolution-review-items->rows
             (.ref profile 'spec-evolution-review-items)))
      (cons 'spec-evolution-human-audit-review-items
            (poo-flow-user-loop-engine-spec-evolution-review-items->human-audit-rows
             (.ref profile 'spec-evolution-review-items)))
      (cons 'spec-evolution-runtime-manifest-rows
            (poo-flow-user-loop-engine-spec-evolution-review-items->manifest-rows
             (.ref profile 'spec-evolution-review-items)))
      (cons 'runtime-handoff
            (if runtime
              (.ref runtime 'handoff)
              'loop-governor-marlin-runtime-manifest))
      (cons 'runtime-owner
            (if runtime
              (.ref runtime 'owner)
              "marlin-agent-core")))
     metadata)))

;;; Config filtering accepts mixed helper prototypes from `use-module :config`,
;;; but only loop-engine profiles are promoted to module flags; support objects
;;; remain local POO extension material for the profile.
;; : (-> [PooFlowLoopEngineConfigPrototype] [PooFlowLoopEngineProfilePrototype])
(def (poo-flow-user-loop-engine-poo-config-profiles prototypes)
  (cond
   ((null? prototypes) '())
   ((poo-flow-user-loop-engine-poo-profile? (car prototypes))
    (cons (car prototypes)
          (poo-flow-user-loop-engine-poo-config-profiles (cdr prototypes))))
   ((pair? prototypes)
    (poo-flow-user-loop-engine-poo-config-profiles (cdr prototypes)))
   (else
    (error "loop-engine POO config prototypes must be a list" prototypes))))

;;; The flag packet is the compatibility bridge from POO-native user config to
;;; the older module-selection surface. It preserves the authored profile for
;;; diagnostics and stores normalized intent rows for projection.
;; : (-> [PooFlowLoopEngineConfigPrototype] Alist [UserModuleFlagEntry])
(def (poo-flow-user-loop-engine-poo-config-flags prototypes user-config)
  (let (profiles (poo-flow-user-loop-engine-poo-config-profiles prototypes))
    (poo-flow-user-loop-engine-require
     "loop-engine POO config must define exactly one loop-engine-profile"
     (= (length profiles) 1)
     prototypes)
    (let (intent-fields
          (poo-flow-user-loop-engine-poo-profile->intent-fields
           (car profiles)))
      (list '+loop-engine
            '+runtime-manifest
            (cons ':config (list (car profiles)))
            (cons ':loop-engine-intent intent-fields)
            (cons ':user-config user-config)))))

;;; Selection lookup is read-only: runtime code receives the precomputed intent
;;; alist and must not infer or rehydrate profile objects from selection flags.
;; : (-> PooUserModuleSelection MaybeAlist)
(def (poo-flow-user-loop-engine-selection-poo-intent selection)
  (let (entry
        (poo-flow-user-module-selection-flag-entry
         selection
         ':loop-engine-intent))
    (and entry (pair? entry) (cdr entry))))
