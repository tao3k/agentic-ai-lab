;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test :clan/poo/object
        (only-in "../dev/d2/init.ss" agentic-ai-lab/dev/d2.init.exports))
(export d2-image-reading-test)
(def Scope (.get agentic-ai-lab/dev/d2.init.exports modules d2))
(def Context. (.get Scope prototypes AuthoringContext))
(def (sample)
  (.o (:: @ Context.)
    views: (list (.o identity: 'v revision: 'r source-cut: 'cut audience: 'reader))
    proposals: (list (.o identity: 'p view: 'v revision: 'r source-cut: 'cut asset-ref: "scene.svg" asset-sha: "asset"))
    renders: (list (.o proposal: 'p asset-sha: "asset" image-sha: "image"))
    questions: (list (.o identity: 'q audience: 'reader subject: 'knowledge))
    facet-needs: (list (.o question: 'q facet: 'method target: 'knowledge)
                       (.o question: 'q facet: 'limit target: 'knowledge))
    inspections: (list (.o identity: 'reading view: 'v revision: 'r source-cut: 'cut
                           image-sha: "image" question: 'q producer: 'current-model))
    image-anchors: (list (.o image-sha: "image" identity: "a" text: "Compare builds" left: 0 top: 0 right: 100 bottom: 20)
                         (.o image-sha: "image" identity: "b" text: "Same tool versions" left: 0 top: 30 right: 100 bottom: 50))
    image-evidence: (list (.o inspection: 'reading facet: 'method anchor: "a" excerpt: "Compare builds"))
    explanation-plan: (.o views: '() object-states: '() goals: '() prerequisites: '()
                         audience-gaps: '() distinctions: '() candidates: '() makes-visible: '()
                         meaning-reviews: '() critiques: '() goal-inventories: '())))
(def (result input) ((.get Scope author) input))
(def (kinds input) (map (lambda (request) (.ref request 'kind)) (.ref (result input) 'requests)))
(def (with-limit base)
  (.o (:: @ base) image-evidence: (cons (.o inspection: 'reading facet: 'limit anchor: "b" excerpt: "Same tool versions")
                                      (.ref base 'image-evidence))))
(def d2-image-reading-test
  (test-suite "Grounded image findings, without favorable verdicts"
    (test-case "actual inspection turns an unanswered question into a specific explanation change"
      (check-equal? (kinds (sample)) '(explain))
      (check-equal? (.ref (result (sample)) 'answers) '()))
    (test-case "a scoped answer derives from exact observed anchors, not a pass flag"
      (def complete (with-limit (sample)))
      (check-equal? (kinds complete) '())
      (check-equal? (.ref (result complete) 'answers) '((v r p "image" q)))
      (check-equal? (.ref complete 'feedback) '())
      (check-equal? (.ref complete 'learner-checks) '()))
    (test-case "invented quotations do not provide an answer basis"
      (def base (sample))
      (def invented (.o (:: @ base) image-evidence:
        (list (.o inspection: 'reading facet: 'limit anchor: "b" excerpt: "Any tool version works"))))
      (check-equal? (kinds invented) '(explain explain)))
    (test-case "image and source changes require new inspection"
      (def base (with-limit (sample)))
      (def new-image (.o (:: @ base) renders: (list (.o proposal: 'p asset-sha: "asset" image-sha: "new-image"))))
      (check-equal? (kinds new-image) '(inspect))
      (def new-cut (.o (:: @ base)
        views: (list (.o identity: 'v revision: 'r source-cut: 'new-cut audience: 'reader))
        proposals: (list (.o identity: 'p view: 'v revision: 'r source-cut: 'new-cut asset-ref: "scene.svg" asset-sha: "asset"))))
      (check-equal? (kinds new-cut) '(inspect)))
    (test-case "a representation gap stays open even when all captions are present"
      (def base (with-limit (sample)))
      (def issue (.o (:: @ base) representation-gaps:
        (list (.o inspection: 'reading facet: 'limit target: 'knowledge reason: 'caption-does-not-show-boundary))))
      (check-equal? (kinds issue) '(illustrate))
      (check-equal? (.ref (result issue) 'answers) '()))
    (test-case "natural image evidence discharges only its matching explanation-plan facets"
      (def base (sample))
      (def plan-base (.ref base 'explanation-plan))
      (def planned (.o (:: @ base) explanation-plan:
        (.o (:: @ plan-base)
          views: (list (.o identity: 'v revision: 'r audience: 'reader))
          object-states: (list (.o view: 'v revision: 'r subject: 'knowledge state: 'captured))
          goals: (list (.o view: 'v revision: 'r subject: 'knowledge concept: 'two-obligations))
          audience-gaps: (list (.o audience: 'reader concept: 'two-obligations))
          distinctions: (list (.o concept: 'two-obligations facet: 'method)
                              (.o concept: 'two-obligations facet: 'limit)))))
      (check-equal? (kinds planned) '(explain))
      (check-equal? (kinds (with-limit planned)) '())
      (check-equal? (.ref (result (with-limit planned)) 'answers) '((v r p "image" q))))
    (test-case "layout concerns require actual measured rectangle intersection"
      (def base (with-limit (sample)))
      (def concern (.o (:: @ base) layout-concerns: (list (.o inspection: 'reading first: "a" second: "b"))))
      (check-equal? (kinds concern) '())
      (def overlap (.o (:: @ concern) image-anchors:
        (list (.o image-sha: "image" identity: "a" text: "Compare builds" left: 0 top: 0 right: 100 bottom: 20)
              (.o image-sha: "image" identity: "b" text: "Same tool versions" left: 40 top: 10 right: 140 bottom: 30))))
      (check-equal? (kinds overlap) '(relayout)))
    (test-case "scoped host geometry detects collisions without a manually filled concern"
      (def base (with-limit (sample)))
      (def overlap (.o (:: @ base) image-anchors:
        (list (.o image-sha: "image" identity: "a" text: "Compare builds" left: 0 top: 0 right: 100 bottom: 20
                  owner: "depiction" facet: 'method target: 'knowledge)
              (.o image-sha: "image" identity: "b" text: "Same tool versions" left: 40 top: 10 right: 140 bottom: 30
                  owner: "depiction" facet: 'limit target: 'knowledge))))
      (check-equal? (.ref overlap 'layout-concerns) '())
      (check-equal? (kinds overlap) '(relayout))
      (check-equal? (.ref (result overlap) 'answers) '()))
    (test-case "scoped captions cannot be assigned to another object's requirement"
      (def base (with-limit (sample)))
      (def wrong-target (.o (:: @ base) image-anchors:
        (list (.o image-sha: "image" identity: "a" text: "Compare builds" left: 0 top: 0 right: 100 bottom: 20
                  owner: "another" facet: 'method target: 'another-object)
              (cadr (.ref base 'image-anchors)))))
      (check-equal? (kinds wrong-target) '(explain))
      (check-equal? (.ref (result wrong-target) 'answers) '()))
    (test-case "caption coverage cannot close an unshown causal relationship"
      (def base (with-limit (sample)))
      (def incomplete (.o (:: @ base) structure-gaps:
        (list (.o question: 'q target: 'knowledge reason: 'missing-state-change-trace))))
      (check-equal? (kinds incomplete) '(relate))
      (check-equal? (.ref (result incomplete) 'answers) '()))
    (test-case "a number needs a visible referent, quantity and actual reading"
      (def base (with-limit (sample)))
      (def (anchor id-value text-value x-value)
        (.o image-sha: "image" identity: id-value text: text-value left: x-value top: 0 right: (+ x-value 20) bottom: 20
          owner: "plot" facet: 'method target: 'knowledge))
      (def numeral (anchor "number" "8" 200))
      (def unexplained (.o (:: @ base) image-anchors: (cons numeral (.ref base 'image-anchors))))
      (check-equal? (kinds unexplained) '(illustrate))
      (check-equal? (.ref (result unexplained) 'answers) '())
      (def declared (.o (:: @ unexplained) visual-expressions:
        (list (.o identity: 'owner-generation owner: 'plot question: 'q facet: 'method target: 'knowledge
          kind: 'number token: "8" role-label: "Owner now" quantity-label: "generation"))))
      (def labeled (.o (:: @ declared) image-anchors:
        (append (list (.o (:: @ numeral) expression: 'owner-generation)
                      (anchor "role" "Owner now" 240) (anchor "quantity" "generation" 280))
          (.ref base 'image-anchors))))
      ;; Printing good labels does not establish that the current model read 8.
      (check-equal? (kinds labeled) '(illustrate))
      (def observed (.o (:: @ labeled) image-evidence:
        (cons (.o inspection: 'reading facet: 'method anchor: "number" excerpt: "8") (.ref base 'image-evidence))))
      (check-equal? (kinds observed) '())
      (def missing-role (.o (:: @ observed) image-anchors:
        (filter (lambda (a) (not (equal? (.ref a 'identity) "role"))) (.ref labeled 'image-anchors))))
      (check-equal? (kinds missing-role) '(illustrate))
      (def stale (.o (:: @ observed) image-anchors:
        (map (lambda (a) (if (equal? (.ref a 'identity) "role")
          (.o (:: @ a) image-sha: "old-image") a)) (.ref labeled 'image-anchors))))
      (check-equal? (kinds stale) '(illustrate)))
    (test-case "actual text size reopens an otherwise grounded explanation"
      (def base (with-limit (sample)))
      (def small (.o (:: @ base) minimum-reader-text: 18 image-anchors:
        (list (.o image-sha: "image" identity: "a" text: "Compare builds" left: 0 top: 0 right: 100 bottom: 20
                  owner: "one" facet: 'method target: 'knowledge font-size: 15)
              (.o image-sha: "image" identity: "b" text: "Same tool versions" left: 0 top: 30 right: 100 bottom: 50
                  owner: "two" facet: 'limit target: 'knowledge font-size: 20))))
      (check-equal? (kinds small) '(relayout))
      (check-equal? (.ref (result small) 'answers) '())
      (def clear (.o (:: @ small) image-anchors:
        (list (.o (:: @ (car (.ref small 'image-anchors))) font-size: 20)
              (cadr (.ref small 'image-anchors)))))
      (check-equal? (kinds clear) '())
      (def stale (.o (:: @ small) image-anchors:
        (list (.o (:: @ (car (.ref small 'image-anchors))) image-sha: "old-image")
              (cadr (.ref small 'image-anchors)))))
      (check-equal? (member 'relayout (kinds stale)) #f))
    (test-case "measured route detours reopen covered questions; missing measurements stay open"
      (def base (with-limit (sample)))
      (def need-route (.o (:: @ base) route-needs:
        (list (.o question: 'q edge: "e" from: 'input to: 'knowledge maximum-stretch: 2.0))))
      (check-equal? (kinds need-route) '(measure))
      (def long-route (.o (:: @ need-route) image-routes:
        (list (.o image-sha: "image" identity: "e" from: 'input to: 'knowledge length: 300 direct: 100))))
      (check-equal? (kinds long-route) '(relayout))
      (check-equal? (.ref (result long-route) 'answers) '())
      (def short-route (.o (:: @ need-route) image-routes:
        (list (.o image-sha: "image" identity: "e" from: 'input to: 'knowledge length: 150 direct: 100))))
      (check-equal? (kinds short-route) '())
      (def stale (.o (:: @ need-route) image-routes:
        (list (.o image-sha: "old-image" identity: "e" from: 'input to: 'knowledge length: 150 direct: 100))))
      (check-equal? (kinds stale) '(measure)))))


