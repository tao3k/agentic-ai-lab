;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: session presentation rows for the module system.
;;; Invariant: this module projects selected session features only; session
;;; values and graph receipts stay in modules/session.

(import :yuanxu/module-system/selection/objects)

(export agentic-ai-lab-user-module-selection-session?
        agentic-ai-lab-user-module-selection-session-intent
        agentic-ai-lab-user-config-session-intents)

;; : (-> PooUserModuleSelection Boolean)
(def (agentic-ai-lab-user-module-selection-session? selection)
  (equal? (yuanxu-user-module-selection-key selection)
          '(session . session)))

;; : (-> PooUserModuleSelection Alist)
(def (agentic-ai-lab-user-module-selection-session-intent selection)
  (let (flags (yuanxu-user-module-selection-flags selection))
    (list (cons 'kind 'agentic-ai-lab.session.intent)
          (cons 'key (yuanxu-user-module-selection-key selection))
          (cons 'flags flags)
          (cons 'lineage-enabled?
                (yuanxu-user-module-selection-has-flag? selection '+lineage))
          (cons 'placement-enabled?
                (yuanxu-user-module-selection-has-flag? selection '+placement))
          (cons 'handoff-enabled?
                (yuanxu-user-module-selection-has-flag? selection '+handoff))
          (cons 'graph-enabled?
                (yuanxu-user-module-selection-has-flag? selection '+graph))
          (cons 'transform-enabled?
                (yuanxu-user-module-selection-has-flag? selection
                                                            '+transform))
          (cons 'doctor-enabled?
                (yuanxu-user-module-selection-has-flag? selection '+doctor))
          (cons 'runtime-owner "marlin-agent-core")
          (cons 'descriptor-realized? #f)
          (cons 'runtime-executed #f))))

;;; Boundary: user config session core intents add is the policy-visible edge
;;; for module-system, core behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> [PooUserModuleSelection] [Alist] [Alist])
(def (agentic-ai-lab-user-config-session-intents/add-rev selections
                                                           intents-rev)
  (if (null? selections)
    intents-rev
    (let (intent
          (agentic-ai-lab-user-config-session-intent (car selections)))
      (agentic-ai-lab-user-config-session-intents/add-rev
       (cdr selections)
       (if intent
         (cons intent intents-rev)
         intents-rev)))))

;; : (-> [PooUserModuleSelection] [Alist])
(def (agentic-ai-lab-user-config-session-intents/add selections)
  (reverse
   (agentic-ai-lab-user-config-session-intents/add-rev selections '())))

;; : (-> PooUserModuleSelection MaybeAlist)
(def (agentic-ai-lab-user-config-session-intent selection)
  (and (agentic-ai-lab-user-module-selection-session? selection)
       (agentic-ai-lab-user-module-selection-session-intent selection)))

;; : (-> PooUserConfig [Alist])
(def (agentic-ai-lab-user-config-session-intents config)
  (agentic-ai-lab-user-config-session-intents/add
   (yuanxu-user-config-modules config)))
