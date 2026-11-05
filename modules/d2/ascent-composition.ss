;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Infer explanatory constraints, never a case-specific canvas or schedule.
(import (only-in :clan/poo/object .o .ref .slot?)
        (only-in :gerbil-ascent/program/syntax ascent)
        (only-in :gerbil-ascent/program/interface gerbil-ascent-evaluate-program)
        "config.ss")
(export d2-compose)
(def (optional value slot fallback) (if (.slot? value slot) (.ref value slot) fallback))
(def (d2-compose items links (policy D2Config))
  (def expression-values
    (apply append (map (lambda (p)
      (map (lambda (e) (.o (:: @ e) owner: (.ref p 'identity) question: (.ref p 'question)
        target: (.ref p 'target) facet: (.ref p 'facet)
        kind: (optional e 'kind 'unknown) token: (optional e 'token "")
        role-label: (optional e 'role-label "") quantity-label: (optional e 'quantity-label "")
        meaning: (optional e 'meaning "") use: (optional e 'use 'unspecified) scale: (optional e 'scale 'unspecified)))
        (optional (optional p 'representation (.o)) 'expressions '()))) items)))
  (def (expression-rows)
    (map (lambda (e) (list (.ref e 'identity) (.ref e 'owner) (.ref e 'question)
      (optional e 'kind 'unknown) (optional e 'token "") (optional e 'role-label "")
      (optional e 'quantity-label "") (optional e 'meaning "")
      (optional e 'use 'unspecified) (optional e 'scale 'unspecified))) expression-values))
  (def (item-rows)
    (map (lambda (p)
      (let (encoding (optional p 'representation (.o family: #f state: #f intent: 'object)))
        (list (.ref p 'identity) (.ref p 'question)
          (optional p 'referent (.ref p 'target)) (.ref p 'glyph)
          (.ref encoding 'family) (.ref encoding 'state) (.ref encoding 'intent)))) items))
  ;; Link roles are open. A model may describe a new role through the same POO
  ;; qualities; recognized semantic roles supply defaults, not a node registry.
  (def (meaning-rows key defaults)
    (map (lambda (l) (list (.ref l 'identity)))
      (filter (lambda (l)
        (or (member (.ref l 'role) defaults)
            (and (.slot? l 'meaning) (optional (.ref l 'meaning) key #f)))) links)))
  (def reason-values (meaning-rows 'reason? '(basis current-cut guard)))
  (def evaluation
    (gerbil-ascent-evaluate-program
      (ascent
        (relation Item (id q referent glyph family state intent) (item-rows))
        (relation Link (id from to) (map (lambda (l) (list (.ref l 'identity) (.ref l 'from) (.ref l 'to))) links))
        (relation Input (id) (meaning-rows 'input? '(input transport proposal)))
        (relation Reason (id) reason-values)
        (relation Transition (id) (meaning-rows 'change? '(state-change)))
        (relation Outcome (id) (meaning-rows 'outcome? '(admitted not-admitted rejected)))
        (relation Capture (id) (meaning-rows 'capture? '(capture)))
        (relation Qualification (id) (meaning-rows 'qualification? '(qualification locality distinction)))
        (relation Uncertainty (id) (meaning-rows 'uncertainty? '(uncertainty)))
        (relation Near (first second basis))
        (relation Compare (first second))
        (relation Check (id))
        (relation Outgoing (id))
        (relation PeerExplanation (judge))
        (relation ConsequenceNeighborhood (judge consequence))
        ((Outgoing A) <-- (Link E A B))
        ((PeerExplanation J) <-- (Check J) (Link E J B) (Qualification E))
        ((ConsequenceNeighborhood J O) <-- (Check J)
          (Link E J O) (Outcome E) (not (Outgoing O)) (not (PeerExplanation J)))
        ;; A saved branch and a changing branch meet again. This is an
        ;; explanatory opportunity, not a prescribed sequence of drawing jobs.
        (relation Divergence (origin live saved judge))
        (relation UncertainCheck (judge subject))
        (relation RetainedReconstruction (origin saved replacement))
        (relation InvestigableFork ())
        (relation Placement (strategy))
        (relation BalancedExplanation ())
        (relation Explore (judge subject aspect))
        (relation Action (id description)
          (map (lambda (p) (list (.ref p 'identity)
            (optional (optional p 'representation (.o)) 'action ""))) items))
        (relation Reading (edge))
        (relation NonSequential (edge))
        ;; Count the bounded supplied facts once, rather than materializing
        ;; all triples of reasons just to establish the existence of three.
        (relation ReasonCount (judge count)
          (map (lambda (p) (list (.ref p 'identity)
            (length (filter (lambda (l)
              (and (eq? (.ref l 'to) (.ref p 'identity))
                   (member (list (.ref l 'identity)) reason-values))) links)))) items))
        (relation DenseReasons ())
        (relation Direction (value))
        (relation BranchClearance ())
        (relation LayerGap (value))
        (relation EncodingGap (id q reason))
        (relation Expression (id owner q kind token role quantity meaning use scale) (expression-rows))
        (relation MarkGap (id owner q reason))
        (relation Reflect (id owner aspect))
        ((MarkGap E Owner Q (lit 'name-the-referent-and-quantity)) <--
          (Expression E Owner Q Kind Token Role Quantity Meaning Use Scale)
          (if (Token Role Quantity Meaning)
            (or (equal? Token "") (equal? Role "") (equal? Quantity "") (equal? Meaning ""))))
        ((MarkGap E Owner Q (lit 'explain-the-role-in-the-judgment)) <--
          (Expression E Owner Q Kind Token Role Quantity Meaning Use Scale)
          (if (Use) (eq? Use 'unspecified)))
        ((MarkGap E Owner Q (lit 'identity-match-is-not-a-ranking)) <--
          (Expression E Owner Q Kind Token Role Quantity Meaning Use Scale)
          (if (Use Scale) (and (eq? Use 'exact-match) (not (eq? Scale 'identity)))))
        ((MarkGap E Owner Q (lit 'remove-a-number-that-only-decorates)) <--
          (Expression E Owner Q (lit 'number) Token Role Quantity Meaning (lit 'decoration) Scale))
        ((Reflect E Owner (lit 'referent)) <-- (Expression E Owner Q Kind Token Role Quantity Meaning Use Scale))
        ((Reflect E Owner (lit 'judgment-use)) <-- (Expression E Owner Q Kind Token Role Quantity Meaning Use Scale))
        ((Reflect E Owner (lit 'possible-misreading)) <-- (Expression E Owner Q Kind Token Role Quantity Meaning Use Scale))
        ((Near A B (lit 'check-input)) <-- (Link E A B) (Input E))
        ((Near A B (lit 'check-reason)) <-- (Link E A B) (Reason E))
        ((Near A B (lit 'state-difference)) <-- (Compare A B))
        ((Near A B (lit 'decision-consequence)) <-- (Link E A B) (Outcome E))
        ((Near A B (lit 'captured-expectation)) <-- (Link E A B) (Capture E))
        ((Compare A B) <-- (Link E A B) (Transition E))
        ((Compare A B) <-- (Link E A J) (Reason E) (Link F J B) (Outcome F)
          (Item A Q Ref Glyph1 Family1 State1 Intent1) (Item B Q2 Ref Glyph2 Family2 State2 Intent2)
          (if (State1 State2) (and State1 State2 (not (equal? State1 State2)))))
        ((Check J) <-- (Link E A J) (Input E) (Link F R J) (Reason F))
        ((Divergence A Live Saved J) <--
          (Link E A Live) (Transition E) (Link F A Saved) (Capture F)
          (Link G Saved J) (Input G) (Link H Live J) (Reason H))
        ((InvestigableFork) <-- (Divergence A Live Saved J))
        ;; Retained state explains a replacement's reconstruction. Infer a
        ;; persistent/change contrast from relations, not a recovery template.
        ((RetainedReconstruction A Saved Live) <--
          (Link E A Live) (Transition E) (Link F A Saved) (Capture F)
          (Link G Saved Live) (Reason G))
        ((InvestigableFork) <-- (RetainedReconstruction A Saved Live))
        ((Explore Live Saved (lit 'what-survives-and-why)) <-- (RetainedReconstruction A Saved Live))
        ((Explore Live Live (lit 'which-old-evidence-is-not-current-authority)) <-- (RetainedReconstruction A Saved Live))
        ((Explore Live Live (lit 'what-is-still-unresolved-after-readiness)) <-- (RetainedReconstruction A Saved Live))
        ((Explore Live A (lit 'can-the-reader-see-the-same-object-change)) <-- (RetainedReconstruction A Saved Live))

        ((UncertainCheck J U) <-- (Check J) (Link E U J) (Uncertainty E))
        ((InvestigableFork) <-- (UncertainCheck J U))
        ((Explore J U (lit 'what-is-unknown-versus-actually-observed)) <-- (UncertainCheck J U))
        ;; An open evidence question should invite discovery before technical
        ;; vocabulary. These prompts guide model judgment, never score interest.
        ((Explore J U (lit 'what-would-a-new-reader-expect)) <-- (UncertainCheck J U))
        ((Explore J J (lit 'which-visible-clue-challenges-that-expectation)) <-- (UncertainCheck J U))
        ((Explore J J (lit 'which-object-can-the-reader-investigate-to-find-out-why)) <-- (UncertainCheck J U))
        ((Explore J J (lit 'does-a-matching-appearance-prove-the-proposed-cause)) <-- (UncertainCheck J U))
        ((Explore J J (lit 'which-observation-could-distinguish-competing-explanations)) <-- (UncertainCheck J U))
        ((Explore J J (lit 'which-responsibilities-remain-after-this-observation)) <-- (UncertainCheck J U))
        ((Explore J J (lit 'who-may-admit-a-proposed-investigation)) <-- (UncertainCheck J U))
        ((Explore J J (lit 'where-does-the-metaphor-overstate-the-evidence)) <-- (UncertainCheck J U))
        ;; Balance a split and rejoin around the inspection point. The native
        ;; solver chooses positions; this avoids favoring one branch as a long
        ;; baseline that strands the consequence at a corner.
        ((BalancedExplanation) <-- (InvestigableFork))
        ((BalancedExplanation) <-- (Check J))
        ((Placement (lit "SIMPLE")) <-- (BalancedExplanation))
        ((Placement (lit "NETWORK_SIMPLEX")) <-- (not (BalancedExplanation)))
        ((Explore J A (lit 'what-would-a-new-reader-expect)) <-- (Divergence A Live Saved J))
        ((Explore J Live (lit 'what-change-can-be-discovered-without-reading-the-caption)) <-- (Divergence A Live Saved J))
        ((Explore J Saved (lit 'why-does-the-copy-not-follow-the-original)) <-- (Divergence A Live Saved J))
        ((Explore J J (lit 'which-visible-clue-challenges-that-expectation)) <-- (Divergence A Live Saved J))
        ((Explore J J (lit 'what-could-the-reader-change-to-test-the-explanation)) <-- (Divergence A Live Saved J))
        ((Explore J J (lit 'where-would-the-visual-metaphor-mislead)) <-- (Divergence A Live Saved J))
        ;; An action description is a model proposal to inspect in the actual
        ;; image. Its presence never establishes interest or comprehension.
        ((EncodingGap Subject Q (lit 'make-the-action-perceptible-not-just-a-label)) <--
          (Explore J Subject Aspect) (Action Subject (lit ""))
          (Item Subject Q Ref Glyph Family State Intent))
        ;; An unresolved premise is not a physical processing step. Keep its
        ;; route important without making it the baseline of a fixed sequence.
        ((Reading E) <-- (Input E) (not (Uncertainty E)))
        ((Reading E) <-- (Transition E))
        ((Reading E) <-- (Capture E))
        ((Reading E) <-- (Outcome E))
        ((NonSequential E) <-- (Reason E))
        ((NonSequential E) <-- (Qualification E))
        ((NonSequential E) <-- (Uncertainty E))
        ((DenseReasons) <-- (ReasonCount J Count) (if (Count) (>= Count 3)))
        ;; Give converging evidence and peer explanations enough approach room.
        ;; This native spacing preference is selected by relation structure,
        ;; never by a case identity or manually positioned picture.
        ((BranchClearance) <-- (PeerExplanation J) (ReasonCount J Count)
          (if (Count) (>= Count 2)))
        ((LayerGap (lit "56")) <-- (BranchClearance))
        ((LayerGap (lit "36")) <-- (not (BranchClearance)))
        ((Direction (lit 'down)) <-- (DenseReasons))
        ((Direction (lit 'right)) <-- (not (DenseReasons)))
        ((EncodingGap A Q (lit 'show-comparable-states)) <-- (Compare A B)
          (Item A Q Ref Glyph1 Family1 State1 Intent1) (Item B Q2 Ref2 Glyph2 Family2 State2 Intent2)
          (if (Glyph1 Glyph2 Family1 Family2 State1 State2)
            (or (not Family1) (not (equal? Family1 Family2)) (not State1) (not State2)
                (equal? State1 State2) (equal? Glyph1 Glyph2))))
        ((EncodingGap J Q (lit 'show-what-is-compared)) <-- (Check J)
          (Item J Q Ref Glyph Family State Intent) (if (Intent) (not (eq? Intent 'check))))
        (bounds 1024 8192 16384))))
  (def rows (.ref evaluation 'rows-of))
  (def (ids name) (map car (rows name)))
  (def (option name-value setting-value) (.o name: name-value value: setting-value))
  (.o inference: evaluation near: (rows 'Near) comparisons: (rows 'Compare) checks: (rows 'Check)
      ;; Compact a check and its terminal consequence as a causal neighborhood.
      ;; Native nested layout chooses their geometry; other graph structures
      ;; need not have this neighborhood at all. No canvas slots are allocated.
      regions: (map (lambda (j)
        (.o identity: (string->symbol (string-append "d2-consequence-" (symbol->string j)))
          label: "" visible?: #f
          members: (cons j (map cadr (filter (lambda (r) (eq? (car r) j)) (rows 'ConsequenceNeighborhood))))
          layout-options: (list (option "elk.spacing.nodeNode" "20")
            ;; Leave a clear approach for the retained and live branches at
            ;; the neighborhood boundary, rather than pinching their routes.
            (option "elk.padding" "[top=16,left=36,bottom=16,right=16]")
            (option "elk.layered.spacing.nodeNodeBetweenLayers" "24"))))
        (filter (lambda (j) (pair? (filter (lambda (r) (eq? (car r) j)) (rows 'ConsequenceNeighborhood)))) (ids 'Check)))
      divergences: (rows 'Divergence) explorations: (rows 'Explore)
      expressions: expression-values reflections: (rows 'Reflect)
      minimum-reader-text: (.ref policy 'minimum-reader-text)
      reading: (rows 'Reading) non-sequential: (rows 'NonSequential)
      direction: (caar (rows 'Direction))
      ;; Only native solver preferences are projected. No object names, ranks,
      ;; coordinates, canvas slots, SVG paths or an execution sequence occur here.
      layout-options: (list (option "elk.algorithm" "layered")
        (option "elk.spacing.nodeNode" "28")
        (option "elk.layered.spacing.nodeNodeBetweenLayers" (caar (rows 'LayerGap)))
        (option "elk.layered.nodePlacement.strategy" (caar (rows 'Placement))))
      edge-options:
      (map (lambda (l)
        (let* ((id (.ref l 'identity))
               (comparison? (member (list (.ref l 'from) (.ref l 'to)) (rows 'Compare)))
               (reading? (member id (ids 'Reading)))
               (reason? (member id (ids 'NonSequential))))
          (.o identity: id options:
            (list (option "elk.layered.priority.direction" (if reading? "8" "0"))
                  (option "elk.layered.priority.shortness" (if comparison? "64" (if reason? "32" "16")))
                  (option "elk.layered.priority.straightness" (if comparison? "64" (if reading? "16" "4"))))))) links)
      gaps: (append (map (lambda (row)
        (.o question: (cadr row) target: (car row) reason: (caddr row))) (rows 'EncodingGap))
        (map (lambda (row) (.o question: (caddr row) target: (cadr row) reason: (cadddr row))) (rows 'MarkGap)))
      route-needs:
      (apply append (map (lambda (l)
        (if (or (member (.ref l 'identity) (ids 'Reading))
                (member (.ref l 'identity) (ids 'Reason))
                (member (.ref l 'identity) (ids 'Uncertainty)))
          (map (lambda (p) (.o question: (.ref p 'question)
            edge: (symbol->string (.ref l 'identity)) from: (.ref l 'from) to: (.ref l 'to) maximum-stretch: 2.0))
            (filter (lambda (p) (eq? (.ref p 'identity) (.ref l 'to))) items)) '())) links))))
