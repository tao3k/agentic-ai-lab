;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test :clan/poo/object
        (only-in "../dev/d2/init.ss" agentic-ai-lab/dev/d2.init.exports))
(export d2-teaching-test)
(def Scope (.get agentic-ai-lab/dev/d2.init.exports modules d2))
(def source-value (.o nodes: (list (.o source-ref: "native/a") (.o source-ref: "native/b"))
  documents: (list (.o identity: "design.org" text: "Originals stay. Results are proposals."))))
(def (proposal name q facet-value target-value)
  (.o identity: name question: q facet: facet-value target: target-value glyph: "new-picture.svg"
      source: "design.org" excerpt: "Results are proposals."))
(def (need q facet-value target-value) (.o question: q facet: facet-value target: target-value))
(def empty-mechanism (.o links: '() requirements: '() traces: '()))
(def (project proposals needs) ((.get Scope teaching) source-value proposals needs empty-mechanism))
(def d2-teaching-test
  (test-suite "Source-qualified teaching groups are driven by reader questions"
    (test-case "different questions can depict the same native object differently"
      (def result (project (list (proposal 'one 'q1 'f1 "native/a") (proposal 'two 'q2 'f2 "native/a"))
        (list (need 'q1 'f1 "native/a") (need 'q2 'f2 "native/a"))))
      (check-equal? (length (.ref result 'items)) 2)
      (check-equal? (length (.ref result 'groups)) 2)
      (check-equal? (.ref result 'missing) '()))
    (test-case "removing a reader need removes only the irrelevant depiction"
      (def result (project (list (proposal 'one 'q1 'f1 "native/a") (proposal 'two 'q2 'f2 "native/b"))
        (list (need 'q2 'f2 "native/b"))))
      (check-equal? (map (lambda (p) (.ref p 'identity)) (.ref result 'items)) '(two)))
    (test-case "a quotation on another native object cannot cover a required facet"
      (def result (project (list (proposal 'one 'q1 'f1 "native/b")) (list (need 'q1 'f1 "native/a"))))
      (check-equal? (.ref result 'items) '())
      (check-equal? (.ref result 'missing) '((q1 f1 "native/a"))))
    (test-case "invented quotations and native targets remain unsupported"
      (def bad (.o (:: @ (proposal 'one 'q1 'f1 "native/a")) excerpt: "Everything is approved."))
      (def result (project (list bad (proposal 'two 'q2 'f2 "invented"))
        (list (need 'q1 'f1 "native/a") (need 'q2 'f2 "invented"))))
      (check-equal? (length (.ref result 'unsupported)) 2)
      (check-equal? (length (.ref result 'missing)) 2)
      (check-equal? (.ref result 'items) '()))
    (test-case "complete isolated captions do not satisfy a required mechanism"
      (def ps (list (proposal 'one 'q1 'f1 "native/a") (proposal 'two 'q1 'f2 "native/b")))
      (def ns (list (need 'q1 'f1 "native/a") (need 'q1 'f2 "native/b")))
      (def mechanism (.o links: '()
        requirements: (list (.o question: 'q1 from: 'one to: 'two role: 'conditional-change))
        traces: (list (.o question: 'q1 from: 'one to: 'two))))
      (def r ((.get Scope teaching) source-value ps ns mechanism))
      (check-equal? (.ref r 'missing) '())
      (check-equal? (.ref r 'missing-links) '((q1 one two conditional-change)))
      (check-equal? (.ref r 'missing-traces) '((q1 one two)))
      (check-equal? (length (.ref r 'structure-gaps)) 2))
    (test-case "a composed illustration cannot discharge missing semantic relations"
      (def m (.o (:: @ empty-mechanism) artwork: "model-composed.svg"
        requirements: (list (.o question: 'q1 from: 'one to: 'two role: 'conditional-change))
        traces: (list (.o question: 'q1 from: 'one to: 'two))))
      (check-exception ((.get Scope teaching) source-value
        (list (proposal 'one 'q1 'f1 "native/a") (proposal 'two 'q1 'f2 "native/b"))
        (list (need 'q1 'f1 "native/a") (need 'q1 'f2 "native/b")) m) exception?))
    (test-case "a non-propagating constraint is not a state-change trace"
      (def ps (list (proposal 'one 'q1 'f1 "native/a") (proposal 'two 'q1 'f2 "native/b")))
      (def ns (list (need 'q1 'f1 "native/a") (need 'q1 'f2 "native/b")))
      (def l (.o identity: 'edge from: 'one to: 'two role: 'distinction propagates?: #f
        source: "design.org" excerpt: "Results are proposals."))
      (def m (.o links: (list l) requirements: '() traces: (list (.o question: 'q1 from: 'one to: 'two))))
      (def r ((.get Scope teaching) source-value ps ns m))
      (check-equal? (length (.ref r 'links)) 1)
      (check-equal? (.get r composition route-needs) '())
      (check-equal? (.ref r 'missing-traces) '((q1 one two)))
      (def causal (.o (:: @ m) links: (list (.o (:: @ l) propagates?: #t))))
      (check-equal? (.ref ((.get Scope teaching) source-value ps ns causal) 'missing-traces) '())
      (def attachment (list (.o child: 'one parent: 'two)))
      (def attached-note (.o (:: @ m) attachments: attachment))
      (check-equal? (.ref ((.get Scope teaching) source-value ps ns attached-note) 'attachments) '((one two)))
      (def hidden-flow (.o (:: @ causal) attachments: attachment))
      (check-equal? (.ref ((.get Scope teaching) source-value ps ns hidden-flow) 'invalid-attachments) '((one two)))
      (def false-negation (.o (:: @ causal) links:
        (list (.o (:: @ l) style: "negation" propagates?: #t))))
      (check-equal? (.ref ((.get Scope teaching) source-value ps ns false-negation) 'invalid-negations) '((edge))))
    (test-case "composition follows semantic relations under unrelated object identities"
      (def (p name facet-value state-value intent-value family-value)
        (.o (:: @ (proposal name 'q facet-value "native/a")) glyph: (symbol->string name)
          referent: 'policy representation: (.o family: family-value state: state-value intent: intent-value)))
      (def ps (list (p 'earlier 'old 'v1 'state 'version)
                    (p 'later 'new 'v2 'state 'version)
                    (p 'candidate 'input 'pending 'object 'command)
                    (p 'judge 'check 'comparing 'check 'comparison)))
      (def ns (map (lambda (p) (need 'q (.ref p 'facet) "native/a")) ps))
      (def (edge name a b role-value)
        (.o identity: name from: a to: b role: role-value propagates?: #t
          source: "design.org" excerpt: "Results are proposals."))
      (def m (.o (:: @ empty-mechanism) links:
        (list (edge 'e1 'earlier 'later 'state-change)
              (edge 'e2 'candidate 'judge 'input)
              (edge 'e3 'later 'judge 'basis))))
      (def c (.get ((.get Scope teaching) source-value ps ns m) composition))
      (check-equal? (.ref c 'comparisons) '((earlier later)))
      (check-equal? (.ref c 'checks) '((judge)))
      (check-equal? (.ref c 'gaps) '())
      (check-equal? (.ref c 'non-sequential) '((e3)))
      (check-equal? (not (not (member '(candidate judge check-input) (.ref c 'near)))) #t)
      ;; One changed source relationship alters the composition, not a case name.
      (def custom (.o (:: @ m) links:
        (list (.o (:: @ (edge 'new-role 'candidate 'judge 'investigation)) meaning: (.o input?: #t))
              (edge 'e3 'later 'judge 'basis))))
      (check-equal? (.get ((.get Scope teaching) source-value ps ns custom) composition checks) '((judge)))
      (check-equal? (.get ((.get Scope teaching) source-value ps ns custom) composition comparisons) '())
      (def crowded (.o (:: @ m) links:
        (list (edge 'r1 'earlier 'judge 'basis) (edge 'r2 'later 'judge 'basis)
              (edge 'r3 'candidate 'judge 'basis))))
      (check-equal? (.get ((.get Scope teaching) source-value ps ns crowded) composition direction) 'down)
      (check-equal? (.ref c 'direction) 'right)
      (def repeated (cons (.o (:: @ (car ps)) glyph: "same")
        (cons (.o (:: @ (cadr ps)) glyph: "same") (cddr ps))))
      (check-equal? (length (.get ((.get Scope teaching) source-value repeated ns m) composition gaps)) 1)
      (def no-check (map (lambda (p) (if (eq? (.ref p 'identity) 'judge)
        (.o (:: @ p) representation: (.o family: 'logo state: 'static intent: 'object)) p)) ps))
      (check-equal? (length (.get ((.get Scope teaching) source-value no-check ns m) composition gaps)) 1))
    (test-case "capture and change select an open investigation rather than an interest verdict"
      (def (p name state-value intent-value)
        (.o (:: @ (proposal name 'q name "native/a")) referent: 'r
          glyph: (symbol->string name)
          representation: (.o family: 'record state: state-value intent: intent-value)))
      (def ps (list (p 'seed 'old 'state) (p 'live 'new 'state)
                   (p 'copy 'old 'input) (p 'meeting 'different 'check) (p 'result 'blocked 'outcome)))
      (def (e name a b role-value)
        (.o identity: name from: a to: b role: role-value propagates?: #t
          source: "design.org" excerpt: "Results are proposals."))
      (def edges (list (e 'a 'seed 'live 'state-change) (e 'b 'seed 'copy 'capture)
                      (e 'c 'copy 'meeting 'input) (e 'd 'live 'meeting 'basis) (e 'e 'meeting 'result 'rejected)))
      (def ns (map (lambda (p) (need 'q (.ref p 'identity) "native/a")) ps))
      (def (compose values link-values)
        (.get ((.get Scope teaching) source-value values ns
          (.o (:: @ empty-mechanism) links: link-values)) composition))
      (def c (compose ps edges))
      (check-equal? (.ref c 'divergences) '((seed live copy meeting)))
      (check-equal? (map (lambda (g) (.ref g 'members)) (.ref c 'regions)) '((meeting result)))
      (check-equal? (length (.ref c 'explorations)) 6)
      (check-equal? (length (.ref c 'gaps)) 4)
      ;; A proposed action removes the missing-description gap; it does not
      ;; remove the questions or create an engagement/comprehension verdict.
      (def described (map (lambda (p) (.o (:: @ p) representation:
        (.o (:: @ (.ref p 'representation)) action: "Compare visible retained and changed marks."))) ps))
      (def offered (compose described edges))
      (check-equal? (.ref offered 'gaps) '())
      (check-equal? (.ref offered 'explorations) (.ref c 'explorations))
      ;; Removing the capture relation changes the inquiry, despite identical
      ;; names, pictures and declared actions.
      (check-equal? (.ref (compose described (cons (car edges) (cddr edges))) 'explorations) '()))
    (test-case "an uncertainty comparison opens inquiry without choosing a cause"
      (def (p name intent-value)
        (.o (:: @ (proposal name 'q name "native/a"))
          representation: (.o family: 'view state: name intent: intent-value
            action: "Expose observed differences and retain unknown causes.")))
      (def ps (list (p 'unclear 'input) (p 'premise 'state) (p 'inspection 'check)))
      (def ns (map (lambda (p) (need 'q (.ref p 'identity) "native/a")) ps))
      (def (edge name from-value role-value meaning-value)
        (.o identity: name from: from-value to: 'inspection role: role-value
          meaning: meaning-value source: "design.org" excerpt: "Results are proposals." propagates?: #t))
      (def basis (edge 'evidence 'premise 'basis (.o)))
      (def (c meaning-value)
        (.get ((.get Scope teaching) source-value ps ns
          (.o (:: @ empty-mechanism) links:
            (list basis (edge 'open-input 'unclear 'new-role meaning-value)))) composition))
      (def uncertain (c (.o input?: #t uncertainty?: #t)))
      (check-equal? (.ref uncertain 'checks) '((inspection)))
      (check-equal? (length (.ref uncertain 'explorations)) 6)
      (check-equal? (.ref uncertain 'gaps) '())
      (check-equal? (not (not (member '(open-input) (.ref uncertain 'non-sequential)))) #t)
      (check-equal? (not (not (member "open-input"
        (map (lambda (r) (.ref r 'edge)) (.ref uncertain 'route-needs))))) #t)
      (def peers (append ps (list (p 'alternative 'object) (p 'responsibility 'outcome))))
      (def peer-result ((.get Scope teaching) source-value peers
        (map (lambda (p) (need 'q (.ref p 'identity) "native/a")) peers)
        (.o (:: @ empty-mechanism) links:
          (list basis (edge 'open-input 'unclear 'new-role (.o input?: #t uncertainty?: #t))
            (.o identity: 'other from: 'inspection to: 'alternative role: 'qualification
              propagates?: #t source: "design.org" excerpt: "Results are proposals.")
            (.o identity: 'duty from: 'inspection to: 'responsibility role: 'not-admitted
              propagates?: #t source: "design.org" excerpt: "Results are proposals.")))))
      ;; A parallel explanation must not be pushed behind a compound outcome
      ;; that would make it look like the next step of a mandatory sequence.
      (check-equal? (.ref peer-result 'regions) '())
      (check-equal? (.ref (c (.o input?: #t)) 'explorations) '()))
    (test-case "visual expressions carry meaning and use instead of number ranking"
      (def (mark mode-value scale-value meaning-value)
        (.o identity: 'tag kind: 'number token: "8" role-label: "Owner now" quantity-label: "generation"
          meaning: meaning-value use: mode-value scale: scale-value))
      (def (composition mark-value)
        (.get ((.get Scope teaching) source-value
          (list (.o (:: @ (proposal 'owner 'q 'current "native/a"))
            representation: (.o family: 'head state: 'v8 intent: 'state expressions: (list mark-value))))
          (list (need 'q 'current "native/a")) empty-mechanism) composition))
      (def good (composition (mark 'exact-match 'identity "Current registered owner generation.")))
      (check-equal? (.ref good 'gaps) '())
      (check-equal? (length (.ref good 'reflections)) 3)
      (check-equal? (length (.ref (composition (mark 'exact-match 'ranked "Current head.")) 'gaps)) 1)
      (check-equal? (length (.ref (composition (mark 'unspecified 'identity "")) 'gaps)) 2)
      (check-equal? (length (.ref (composition (mark 'decoration 'identity "Unneeded ornament.")) 'gaps)) 1))
    (test-case "source-qualified causal neighbors cannot be dispersed despite complete captions"
      (def ps (list (proposal 'one 'q1 'f1 "native/a") (proposal 'two 'q1 'f2 "native/b")))
      (def ns (list (need 'q1 'f1 "native/a") (need 'q1 'f2 "native/b")))
      (def m (.o (:: @ empty-mechanism) cohesion: (list (.o question: 'q1 first: 'one second: 'two))))
      (def apart ((.get Scope teaching) source-value ps ns m))
      (check-equal? (.ref apart 'missing) '())
      (check-equal? (.ref apart 'missing-cohesion) '((q1 one two)))
      (def g (.o identity: 'neighborhood members: '(one two) source: "design.org" excerpt: "Results are proposals."))
      (def together (.o (:: @ m) regions: (list g)))
      (check-equal? (.ref ((.get Scope teaching) source-value ps ns together) 'missing-cohesion) '())
      (def invented (.o (:: @ m) regions: (list (.o (:: @ g) members: '(one unknown)))))
      (check-equal? (.ref ((.get Scope teaching) source-value ps ns invented) 'invalid-regions) '((neighborhood))))))


