;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Opt-in illustrative profile, not the Context runtime authority.
;;; POO objects supply facts; ASCENT Scheme
;;; derives membership, competing support, impact and review candidates.
;;; No generated JSON schema, task selector or knowledge publication authority.
(import (only-in :clan/poo/object .o .ref)
        (only-in :gerbil-ascent/program/syntax ascent)
        (only-in :gerbil-ascent/program/api gerbil-ascent-evaluate-program))
(export ExperienceWindow. context-evolution-evaluate context-evolution-rows)

(def ExperienceWindow.
  (.o identity: #f revision: #f scope: #f
      start: 0 end: 0 as-of: 0))

;;; Internal projection only: public inputs are POO objects with named slots.
(def (source-rows objects slots)
  (map (lambda (value) (map (lambda (slot) (.ref value slot)) slots)) objects))

(def (context-evolution-evaluate input)
  (gerbil-ascent-evaluate-program
   (ascent
    ;; This slice assumes one declared, comparable clock domain. Source
    ;; authentication and current-cut qualification belong to existing owners.
    (relation Window (w v scope start end as-of)
      (source-rows (.ref input 'windows) '(identity revision scope start end as-of)))
    (relation Observation (e scope event-time known-time cut)
      (source-rows (.ref input 'observations) '(identity scope event-time known-time cut)))
    (relation CurrentCut (scope cut)
      (source-rows (.ref input 'current-cuts) '(scope cut)))
    (relation Hypothesis (h scope)
      (source-rows (.ref input 'hypotheses) '(identity scope)))
    (relation Supports (e h)
      (source-rows (.ref input 'supports) '(evidence hypothesis)))
    (relation Contradicts (e h)
      (source-rows (.ref input 'contradicts) '(evidence hypothesis)))
    (relation Depends (subject premise)
      (source-rows (.ref input 'dependencies) '(subject premise)))
    (relation Changed (subject)
      (source-rows (.ref input 'changes) '(identity)))
    (relation Proposal (p h scope)
      (source-rows (.ref input 'proposals) '(identity hypothesis scope)))
    (relation Requires (p q)
      (source-rows (.ref input 'requirements) '(proposal requirement)))
    (relation Meets (e p q)
      (source-rows (.ref input 'meets) '(evidence proposal requirement)))
    (relation InventoryComplete (p)
      (source-rows (.ref input 'complete-inventories) '(proposal)))
    (relation ScopeChecked (p scope)
      (source-rows (.ref input 'scope-checks) '(proposal scope)))

    (relation Member (w v e))
    (relation Usable (w v e))
    (relation Support (w v h e))
    (relation Opposition (w v h e))
    (relation HasSupport (w v h))
    (relation HasOpposition (w v h))
    (relation Conflicted (w v h))
    (relation Affected (subject))
    (relation Met (w v p q))
    (relation Gap (w v p q))
    (relation HasGap (w v p))
    (relation HasRequirement (p))
    (relation KnowledgeCandidate (w v p))
    (relation VisualEdge (w v from to role))

    ;; Event time selects the interval; known time selects what was available.
    ((Member W V E) <-- (Window W V S Start End AsOf)
      (Observation E S Event Known Cut)
      (if (Start End AsOf Event Known)
        (and (<= Start Event) (< Event End) (<= Known AsOf))))
    ((Affected X) <-- (Changed X))
    ((Affected X) <-- (Depends X Y) (Affected Y))
    ((Usable W V E) <-- (Member W V E) (Observation E S Event Known Cut)
      (CurrentCut S Cut) (not (Affected E)))

    ((Support W V H E) <-- (Window W V S Start End AsOf)
      (Hypothesis H S) (Usable W V E) (Supports E H))
    ((Opposition W V H E) <-- (Window W V S Start End AsOf)
      (Hypothesis H S) (Usable W V E) (Contradicts E H))
    ((HasSupport W V H) <-- (Support W V H E))
    ((HasOpposition W V H) <-- (Opposition W V H E))
    ((Conflicted W V H) <-- (HasSupport W V H) (HasOpposition W V H))

    ;; A missing witness is an open obligation in this snapshot, not falsehood.
    ((Met W V P Q) <-- (Proposal P H S) (Window W V S Start End AsOf)
      (Requires P Q) (Meets E P Q) (Usable W V E))
    ((HasRequirement P) <-- (Requires P Q))
    ((Gap W V P Q) <-- (Proposal P H S) (Window W V S Start End AsOf)
      (InventoryComplete P) (Requires P Q) (not (Met W V P Q)))
    ((HasGap W V P) <-- (Gap W V P Q))
    ;; This is only a review candidate relative to supplied finite inputs.
    ;; No rule promotes it to truth, permanent memory or execution permission.
    ((KnowledgeCandidate W V P) <-- (Window W V S Start End AsOf)
      (Proposal P H S) (ScopeChecked P S) (InventoryComplete P)
      (HasRequirement P) (HasSupport W V H)
      (not (HasGap W V P)) (not (HasOpposition W V H)) (not (Affected P)))

    ;; The diagram consumes consequences of the same rules, not a manual graph.
    ((VisualEdge W V W E (lit 'in-window)) <-- (Member W V E))
    ((VisualEdge W V E H (lit 'supports)) <-- (Support W V H E))
    ((VisualEdge W V E H (lit 'contradicts)) <-- (Opposition W V H E))
    ((VisualEdge W V P H (lit 'proposes)) <-- (Proposal P H S)
      (Window W V S Start End AsOf))
    (bounds 256 512 1024))))

(def (context-evolution-rows result relation)
  ((.ref result 'rows-of) relation))
