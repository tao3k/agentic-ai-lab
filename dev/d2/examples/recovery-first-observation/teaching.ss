;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Inert source-qualified explanatory objects; no layout or runtime decisions.
(import :clan/poo/object)
(export TeachingItems TeachingMechanism RecoveryNeeds)
(def Org "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/33-recovery-first-observation.org")
(def Fixture "RecoveryFirstObservation::fixture")
(def Plan "The toy edit changes =mode: slow= to =mode: fast=.")
(def Gap "A missing receipt is not proof that a write did not happen.")
(def Read "A read can reveal current content without proving who wrote it.")
(def Match "The matching content does not complete the Task.")
(def Explore "The model can\nadd another hypothesis without changing its program.")
(def Duties "Reading =mode: fast= narrows the current-content question. It does not resolve\nwhether the original Attempt wrote the file, whether every planned path changed,\nwhether another writer can still act, or whether the Task's acceptance checks hold.")
(def (depict id-value facet-value referent-value family-value state-value intent-value title-value detail-value action-value quotation-value)
  (.o identity: id-value question: 'what-can-we-know target: Fixture facet: facet-value referent: referent-value
    glyph: (string-append "dev/d2/examples/recovery-first-observation/assets/" (symbol->string id-value) ".svg")
    title: title-value explanation: detail-value
    representation: (.o family: family-value state: state-value intent: intent-value action: action-value)
    rationale: action-value source: Org excerpt: quotation-value))
(def TeachingItems
  (list
    (depict 'plan 'retained-intent 'intent 'edit-intent 'retained 'state
      "The saved plan" "Change slow to fast."
      "A saved edit shows the old word being replaced by the desired word; it records intent, not execution." Plan)
    (depict 'unknown 'unknown-effect 'recovered-view 'workspace-view 'unobserved 'input
      "Context / what is unknown?" "We do not know if the edit ran."
      "An unfilled dashed receipt shows that no record was saved; the separate file asks whether the old action ran." Gap)
    (depict 'observed 'fresh-content 'recovered-view 'workspace-view 'content-observed 'state
      "A fresh read finds fast" "Reading does not write the file."
      "A reading lens reveals mode: fast while the historical writer remains unidentified." Read)
    (depict 'compare 'evidence-limit 'comparison 'content-comparison 'match-without-attribution 'check
      "ASCENT / separate the facts" "Same text does not prove who."
      "The expected and observed words meet inside one comparison lens; an open causal question remains." Match)
    (depict 'explore 'open-hypotheses 'hypotheses 'competing-traces 'open 'object
      "Model / follow a new clue" "Our write? Another writer?"
      "Two possible pencil traces lead to the same word; neither explanation is chosen or erased." Explore)
    (depict 'duties 'open-responsibility 'obligations 'responsibility-folder 'pending 'outcome
      "Task / keep it open" "Do not repeat the edit yet."
      "An open folder retains questions about origin, the whole change and acceptance; it is not a progress score." Duties)))
(def RecoveryNeeds (map (lambda (p) (.o question: 'what-can-we-know target: Fixture facet: (.ref p 'facet))) TeachingItems))
(def (rel id-value from-value to-value role-value label-value quotation-value (meaning-value (.o)))
  (.o identity: id-value from: from-value to: to-value role: role-value label: label-value
    meaning: meaning-value style: (if (memq role-value '(basis uncertainty)) "support" "flow")
    propagates?: #t source: Org excerpt: quotation-value))
(def TeachingMechanism
  (.o links:
    (list (rel 'read-reveals 'unknown 'observed 'state-change "" Read)
          (rel 'expected 'plan 'compare 'basis "plan" Plan)
          (rel 'actual 'observed 'compare 'basis "read" Read)
          (rel 'unresolved 'unknown 'compare 'uncertainty "unknown" Gap (.o input?: #t))
          (rel 'questions 'compare 'explore 'qualification "" Explore)
          (rel 'responsibilities 'compare 'duties 'obligation "" Duties (.o outcome?: #t)))
    requirements: (list (.o question: 'what-can-we-know from: 'unknown to: 'compare role: 'uncertainty)
                        (.o question: 'what-can-we-know from: 'observed to: 'compare role: 'basis))
    traces: (list (.o question: 'what-can-we-know from: 'unknown to: 'duties))))
