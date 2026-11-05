;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Reason about what this reader must understand before choosing pictures.
;;; The model supplies open concept dependencies, visual candidates, meaning
;;; reviews and critiques. No object-kind -> box/icon/layout table lives here.
(import (only-in :clan/poo/object .ref)
        (only-in :gerbil-ascent/program/syntax ascent)
        (only-in :gerbil-ascent/program/interface gerbil-ascent-evaluate-program))
(export d2-plan-explanation)
(def (explanation-rows objects slots)
  (map (lambda (value) (map (lambda (slot) (.ref value slot)) slots)) objects))
(def (d2-plan-explanation input)
  (gerbil-ascent-evaluate-program
   (ascent
    (relation View (v r audience)
      (explanation-rows (.ref input 'views) '(identity revision audience)))
    (relation ObjectState (v r subject state)
      (explanation-rows (.ref input 'object-states) '(view revision subject state)))
    (relation Goal (v r subject concept)
      (explanation-rows (.ref input 'goals) '(view revision subject concept)))
    (relation Prerequisite (concept premise)
      (explanation-rows (.ref input 'prerequisites) '(concept premise)))
    ;; A scoped reader-model observation, not "unknown because no row exists".
    (relation AudienceGap (audience concept)
      (explanation-rows (.ref input 'audience-gaps) '(audience concept)))
    (relation Distinction (concept facet)
      (explanation-rows (.ref input 'distinctions) '(concept facet)))
    (relation Candidate (p subject state asset)
      (explanation-rows (.ref input 'candidates) '(identity subject state asset-ref)))
    (relation MakesVisible (p facet)
      (explanation-rows (.ref input 'makes-visible) '(candidate facet)))
    (relation MeaningReviewed (v r p)
      (explanation-rows (.ref input 'meaning-reviews) '(view revision candidate)))
    (relation Critique (v r p reason)
      (explanation-rows (.ref input 'critiques) '(view revision candidate reason)))
    ;; Complete for this proposed view/cut, never a closed catalog of all future
    ;; learning questions or possible model-generated representations.
    (relation GoalInventory (v r)
      (explanation-rows (.ref input 'goal-inventories) '(view revision)))

    (relation NeededConcept (v r subject concept))
    (relation ExplanationNeed (v r subject facet))
    (relation HasNeed (v r subject))
    (relation Relevant (v r subject p asset))
    (relation MissingFacet (v r p facet))
    (relation HasMissingFacet (v r p))
    (relation NeedsMeaningReview (v r p))
    (relation Criticized (v r p))
    (relation StateMismatch (v r p))
    (relation CandidateForReview (v r subject p asset))

    ((NeededConcept V R O C) <-- (Goal V R O C))
    ((NeededConcept V R O P) <-- (NeededConcept V R O C) (Prerequisite C P))
    ((ExplanationNeed V R O D) <-- (View V R A) (NeededConcept V R O C)
      (AudienceGap A C) (Distinction C D))
    ((HasNeed V R O) <-- (ExplanationNeed V R O D))
    ((Relevant V R O P Asset) <-- (View V R A) (ObjectState V R O State)
      (Candidate P O State Asset) (HasNeed V R O))
    ((MissingFacet V R P D) <-- (Relevant V R O P Asset) (GoalInventory V R)
      (ExplanationNeed V R O D) (not (MakesVisible P D)))
    ((HasMissingFacet V R P) <-- (MissingFacet V R P D))
    ((NeedsMeaningReview V R P) <-- (Relevant V R O P Asset)
      (not (MeaningReviewed V R P)))
    ((Criticized V R P) <-- (Critique V R P Reason))
    ((StateMismatch V R P) <-- (View V R A) (ObjectState V R O Current)
      (Candidate P O Prior Asset) (if (Current Prior) (not (equal? Current Prior))))
    ((CandidateForReview V R O P Asset) <-- (Relevant V R O P Asset)
      (GoalInventory V R) (MeaningReviewed V R P)
      (not (HasMissingFacet V R P)) (not (Criticized V R P)))
    ;; A candidate can be text, an analogy, an object scene, a timeline, a graph
    ;; or a model-generated asset. Passing these supplied checks is not a claim
    ;; that a pupil understood it. Actual look-back review remains necessary.
    (bounds 512 4096 8192))))
