;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object)
(export TeachingItems TeachingMechanism CaseNeeds)
(def Org "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org")
(def Root "ContextRepeatedRecovery::recoveryExtensionLayers")
(def (depict id-value facet-value referent-value family-value state-value intent-value title-value detail-value action-value quotation-value)
  (.o identity: id-value question: 'what-survives-an-owner target: Root referent: referent-value facet: facet-value
    glyph: (string-append "dev/d2/examples/durable-owner-recovery/assets/" (symbol->string id-value) ".svg")
    title: title-value explanation: detail-value rationale: action-value
    representation: (.o family: family-value state: state-value intent: intent-value action: action-value)
    source: Org excerpt: quotation-value))
(def TeachingItems
  (list
    (depict 'assembly 'module-feature 'assembly 'module-assembly 'bound 'input
      "Core / assemble modules" "Bind the independent Durable Module."
      "The Context Feature connects to the Durable provider at a contract socket."
      "Core binds the Context recovery Feature to the independent Durable Module.")
    (depict 'settings 'engine-policy 'config 'poo-config 'configured 'state
      "Durable / configure the engine" "A retry still needs both checks."
      "A two-part POO card shows which evidence each policy reads."
      "The assembly supplies a POO configuration to the Durable engine.")
    (depict 'judgment 'recovered-attempt 'attempt 'recovery-ticket 'open 'outcome
      "The same Attempt stays open" "Policy says retry. Guards say hold."
      "The retained Attempt ticket reports a matching binding, unknown effect and ineligible retry despite a positive proposal."
      "Durable interprets effect evidence and judges retry under its own contracts.")))
(def CaseNeeds (map (lambda (p) (.o question: 'what-survives-an-owner target: Root facet: (.ref p 'facet))) TeachingItems))
(def (rel id-value from-value to-value role-value label-value quote-value meaning-value)
  (.o identity: id-value from: from-value to: to-value role: role-value label: label-value
    meaning: meaning-value propagates?: (not (eq? role-value 'explanation)) style: (if (eq? role-value 'basis) "support" "flow")
    source: Org excerpt: quote-value))
(def TeachingMechanism
  (.o links: (list
        (rel 'supply 'assembly 'settings 'input "supplies config"
          "The assembly supplies a POO configuration to the Durable engine." (.o))
        (rel 'apply-policy 'settings 'judgment 'basis "interprets evidence"
          "Durable interprets effect evidence and judges retry under its own contracts." (.o)))
      requirements: '()
      traces: '()))
