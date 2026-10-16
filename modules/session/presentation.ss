;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: session presentation rows for the module system.
;;; Invariant: this module projects selected session features only; session
;;; values and graph receipts stay in modules/session.

(import :core/module-system/selection/objects)

(export poo-flow-user-module-selection-session?
        poo-flow-user-module-selection-session-intent
        poo-flow-user-config-session-intents)

;; : (-> PooUserModuleSelection Boolean)
(def (poo-flow-user-module-selection-session? selection)
  (equal? (poo-flow-user-module-selection-key selection)
          '(session . session)))

;; : (-> PooUserModuleSelection Alist)
(def (poo-flow-user-module-selection-session-intent selection)
  (let (flags (poo-flow-user-module-selection-flags selection))
    (list (cons 'kind 'poo-flow.session.intent)
          (cons 'key (poo-flow-user-module-selection-key selection))
          (cons 'flags flags)
          (cons 'lineage-enabled?
                (poo-flow-user-module-selection-has-flag? selection '+lineage))
          (cons 'placement-enabled?
                (poo-flow-user-module-selection-has-flag? selection '+placement))
          (cons 'handoff-enabled?
                (poo-flow-user-module-selection-has-flag? selection '+handoff))
          (cons 'graph-enabled?
                (poo-flow-user-module-selection-has-flag? selection '+graph))
          (cons 'transform-enabled?
                (poo-flow-user-module-selection-has-flag? selection
                                                            '+transform))
          (cons 'doctor-enabled?
                (poo-flow-user-module-selection-has-flag? selection '+doctor))
          (cons 'runtime-owner "marlin-agent-core")
          (cons 'descriptor-realized? #f)
          (cons 'runtime-executed #f))))

;;; Boundary: user config session core intents add is the policy-visible edge
;;; for module-system, core behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> [PooUserModuleSelection] [Alist] [Alist])
(def (poo-flow-user-config-session-intents/add-rev selections
                                                           intents-rev)
  (if (null? selections)
    intents-rev
    (let (intent
          (poo-flow-user-config-session-intent (car selections)))
      (poo-flow-user-config-session-intents/add-rev
       (cdr selections)
       (if intent
         (cons intent intents-rev)
         intents-rev)))))

;; : (-> [PooUserModuleSelection] [Alist])
(def (poo-flow-user-config-session-intents/add selections)
  (reverse
   (poo-flow-user-config-session-intents/add-rev selections '())))

;; : (-> PooUserModuleSelection MaybeAlist)
(def (poo-flow-user-config-session-intent selection)
  (and (poo-flow-user-module-selection-session? selection)
       (poo-flow-user-module-selection-session-intent selection)))

;; : (-> PooUserConfig [Alist])
(def (poo-flow-user-config-session-intents config)
  (poo-flow-user-config-session-intents/add
   (poo-flow-user-config-modules config)))
