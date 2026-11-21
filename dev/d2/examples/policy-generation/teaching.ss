;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Source-qualified meanings and object artwork only; no layout settings.
(import :clan/poo/object)
(export TeachingItems TeachingMechanism PolicyNeeds)
(def Org "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/21-runtime-policy-transition.org")
(def Sysml "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/21-policy-transition.sysml")
(def Fixture "ContextPolicyTransition::fixture")
(def Generation "Generation matters even if policy bytes are unchanged: a deadline can advance\nthat generation.")
(def Check "Both expected generation and digest must equal the registered policy head.")
(def Freeze "policy identity and freezes the expected registered generation, expected\npolicy digest and proposed policy into the existing journal wire format.")
(def Refusal "A stale expected cut receives a durable refusal rather\nthan an automatic rebase onto the new policy.")
(def (picture name) (string-append "dev/d2/examples/policy-generation/assets/" name ".svg"))
(def (mark id-value token-value role-value meaning-value)
  (.o identity: id-value kind: 'number token: token-value role-label: role-value
      quantity-label: "version tag" meaning: meaning-value use: 'exact-match scale: 'identity))
(def (depict id-value referent-value facet-value family-value state-value intent-value title-value explanation-value quote-value (expression-values '()))
  (.o identity: id-value question: 'why-refuse target: Fixture referent: referent-value facet: facet-value
    glyph: (picture (symbol->string id-value)) title: title-value explanation: explanation-value
    representation: (.o family: family-value state: state-value intent: intent-value action: (case id-value
      ((captured) "A policy sheet carries a detachable version tag before the fork.")
      ((current) "A deadline turns the live record; the policy strokes stay while its tag changes.")
      ((request) "A captured sheet sits inside a snapshot frame; its old tag remains attached.")
      ((check) "A magnifier exposes matching policy strokes beside two different version tags.")
      (else "A moving request meets a stop arm while a separate refusal receipt is filed.")) expressions: expression-values)
    rationale: "Use the object's visible values and relationships to explain this source-qualified stale-command example."
    source: Org excerpt: quote-value))
(def TeachingItems
  (list
    (depict 'captured 'policy-head 'captured-head 'versioned-owner-record 'g7 'state
      "Start with one record" "Save it before the deadline." Generation
      (list (mark 'captured-generation "7" "Record at capture"
        "The registered owner generation captured before the deadline event.")))
    (depict 'current 'policy-head 'current-head 'versioned-owner-record 'g8 'state
      "The live version changes" "Same words. A new version tag." Generation
      (list (mark 'current-generation "8" "Owner record now"
        "The current registered owner generation after the deadline event; not an authorization score.")))
    (depict 'request 'command 'frozen-expectation 'policy-command 'expected7 'input
      "The snapshot stays behind" "The request keeps its old tag." Freeze
      (list (mark 'request-generation "7" "Request saved"
        "The expected owner generation frozen into the request; it does not follow later owner changes.")))
    (depict 'check 'guard 'check-reason 'comparison 'mismatch 'check
      "Look at the tags" "Matching words are not enough." Check
      (list (mark 'registered-generation "8" "Owner now"
              "The current registered generation used as the comparison reference.")
            (mark 'expected-generation "7" "Request saved"
              "The request's expected generation, compared for exact equality rather than numerical ranking.")))
    (depict 'refused 'decision 'durable-refusal 'journal-decision 'refused 'outcome
      "Stop this update" "No update. Refusal saved." Refusal)))
(def PolicyNeeds
  (map (lambda (p) (.o question: 'why-refuse target: Fixture facet: (.ref p 'facet))) TeachingItems))
(def (rel id-value from-value to-value role-value label-value quotation-value)
  (.o identity: id-value from: from-value to: to-value role: role-value label: label-value
    style: (if (eq? role-value 'basis) "support" "flow") propagates?: #t
    source: Org excerpt: quotation-value))
(def TeachingMechanism
  (.o links:
    (list (rel 'advance 'captured 'current 'state-change "deadline" Generation)
          (rel 'freeze 'captured 'request 'capture "save copy" Freeze)
          (rel 'submit 'request 'check 'input "" Check)
          (rel 'consult 'current 'check 'basis "" Check)
          (rel 'reject 'check 'refused 'rejected "tags differ" Refusal))
    requirements: (list (.o question: 'why-refuse from: 'current to: 'check role: 'basis)
                        (.o question: 'why-refuse from: 'check to: 'refused role: 'rejected))
    traces: (list (.o question: 'why-refuse from: 'request to: 'refused))))
