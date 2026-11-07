;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object)
(export TeachingItems TeachingMechanism CaseNeeds)
(def Org "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/18-runtime-durable-source-commands.org")
(def Root "ContextRepeatedRecovery::compositionDesign")
(def (depict id-value facet-value referent-value family-value state-value intent-value title-value detail-value action-value quotation-value)
  (.o identity: id-value question: 'how-context-is-extended target: Root referent: referent-value facet: facet-value
    glyph: (if (memq id-value '(restore mismatch)) "" (string-append "dev/d2/examples/durable-feature-composition/assets/" (symbol->string id-value) ".svg"))
    title: title-value explanation: detail-value rationale: action-value
    representation: (.o family: family-value state: state-value intent: intent-value action: action-value)
    source: Org excerpt: quotation-value))
(def TeachingItems (list (depict 'extension 'module-extension 'context 'context-module 'declared 'input "Context + recovery Feature" "Declares how Context is extended." "A fitted extension tab adds recovery to the Context module while a named socket declares its Durable need." "The Context recovery Feature extends Context; Durable supplies its required contract.") (depict 'provider 'durable-provider 'durable 'durable-module 'published 'state "Durable / independent Module" "Saves decisions together." "A durable journal provider presents a matching contract plug; it does not contain Task scheduling." "Durable is an independent Module providing the journal, commit boundary, writer\nfence and retained decision integrity.") (depict 'binding 'core-binding 'binding 'contract-binding 'matched 'check "Core / bind the extension" "Match contract name and version." "An extension socket and a provider plug meet at a contract seam, with the runtime handoff still unopened." "Feature binding is a declaration, not a running owner or permission to replay an effect.") (depict 'composed 'extended-context 'context 'context-module 'extended 'outcome "Keep with the checkpoint" "" "A folded record lists the five retained fields in Feature, provider and checkpoint groups." "Save the admitted composition with the checkpoint.")
  (depict 'restore 'recovery-match 'context 'context-module 'restore 'object
    "After restart" "Compare with the binding Core resolves now."
    "The saved composition identifies the extension, options and Durable contract."
    "On recovery, match that record before interpreting the checkpoint.")
  (depict 'mismatch 'unresolved-attempt 'context 'context-module 'unmatched 'object
    "No match? Keep the Attempt open." "Its checkpoint needs the original binding."
    "Without an admitted interpretation the original work remains unresolved."
    "If the matching binding is unavailable, the Attempt stays unresolved until an")))
(def CaseNeeds (map (lambda (p) (.o question: 'how-context-is-extended target: Root facet: (.ref p 'facet))) TeachingItems))
(def (rel id-value from-value to-value role-value label-value quote-value meaning-value)
  (.o identity: id-value from: from-value to: to-value role: role-value label: label-value
    meaning: meaning-value propagates?: (not (eq? role-value 'explanation)) style: (if (eq? role-value 'basis) "support" "flow")
    source: Org excerpt: quote-value))
(def TeachingMechanism (.o links: (list (rel 'contribute 'extension 'binding 'input "extension" "The Context recovery Feature extends Context; Durable supplies its required contract." (.o)) (rel 'supply 'provider 'binding 'basis "contract" "Durable is an independent Module providing the journal, commit boundary, writer\nfence and retained decision integrity." (.o)) (rel 'extend 'binding 'composed 'admitted "bind" "Feature binding is a declaration, not a running owner or permission to replay an effect." (.o))
 (rel 'recognize 'restore 'composed 'explanation "" "On recovery, match that record before interpreting the checkpoint." (.o annotation?: #t))
 (rel 'keep-open 'mismatch 'restore 'explanation ""
   "If the matching binding is unavailable, the Attempt stays unresolved until an"
   (.o annotation?: #t)))
 requirements: (list (.o question: 'how-context-is-extended from: 'binding to: 'composed role: 'admitted))
 traces: (list (.o question: 'how-context-is-extended from: 'extension to: 'composed))))
