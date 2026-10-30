;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: turn an admitted governance Profile into a generic contribution.
;;; Invariant: this projection remains inert and grants no runtime authority.
(import (only-in :clan/poo/object .ref .slot?)
        (only-in :std/list/list every)
        (only-in :yuanxu/contribution/objects
                 make-contribution
                 contribution?)
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-user-module-selection?
                 yuanxu-user-module-selection-flags
                 yuanxu-user-module-selection-key)
        (only-in :agentic-ai-lab/modules/governance/types
                 agentic-ai-lab-governance-profile?
                 agentic-ai-lab-governance-assess))

(export agentic-ai-lab-governance-contribution
        agentic-ai-lab-governance-module-contribution
        agentic-ai-lab-governance-module-config
        agentic-ai-lab-governance-evaluate)

;;; Derived Profiles replace their native method slot while callers retain one
;;; open protocol.  The result remains a semantic assessment, not authority.
(def (agentic-ai-lab-governance-evaluate profile-value context-value)
  (unless (agentic-ai-lab-governance-profile? profile-value)
    (error "invalid governance profile" profile-value))
  (agentic-ai-lab-governance-assess profile-value context-value))

(def (agentic-ai-lab-governance-contribution profile-value facets requirements)
  (unless (agentic-ai-lab-governance-profile? profile-value)
    (error "invalid governance profile" profile-value))
  (unless (and (list? facets) (pair? facets) (every symbol? facets)
               (list? requirements) (every symbol? requirements))
    (error "invalid governance contribution facets or requirements"))
  (make-contribution
   (.ref profile-value 'identity)
   (.ref profile-value 'revision)
   (.ref profile-value 'owner)
   profile-value
   facets
   requirements))

;;; Module families declare their identity once on the Profile.  This shared
;;; projection keeps contributor funs/config roles thin without introducing a
;;; macro or a parallel module declaration language.
(def (agentic-ai-lab-governance-module-contribution
      profile-value module-family-value facets requirements)
  (unless (and (symbol? module-family-value)
               (.slot? profile-value 'module-family)
               (eq? (.ref profile-value 'module-family) module-family-value))
    (error "governance Profile belongs to another module family"
           module-family-value profile-value))
  (agentic-ai-lab-governance-contribution profile-value facets requirements))

(def (agentic-ai-lab-governance-module-config
      selection module-family-value contribution-value)
  (unless (and (symbol? module-family-value)
               (yuanxu-user-module-selection? selection)
               (equal? (yuanxu-user-module-selection-key selection)
                       (cons 'custom module-family-value))
               (null? (yuanxu-user-module-selection-flags selection))
               (contribution? contribution-value)
               (.slot? (.ref contribution-value 'profile) 'module-family)
               (eq? (.ref (.ref contribution-value 'profile) 'module-family)
                    module-family-value))
    (error "invalid governance module selection"
           module-family-value selection contribution-value))
  contribution-value)
