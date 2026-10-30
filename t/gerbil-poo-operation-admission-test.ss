;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Contract: executable admission evidence for the pinned gerbil-poo surface.
;;; This test exercises upstream mechanics directly; its Scenario and Session
;;; examples remain native objects and introduce no alternate Agentic AI Lab object,
;;; dispatch, precedence, or inherited-computation adapter.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 check-exception
                 test-suite)
        (only-in :clan/poo/object
                 $computed-slot-spec
                 $constant-slot-spec
                 .@
                 .all-slots
                 .call
                 .cc
                 .def
                 .def!
                 .extend
                 .get
                 .has?
                 .mix
                 .o
                 .put!
                 .putdefault!
                 .putslot!
                 .ref
                 .set!
                 .slot?
                 uninstantiate-object!
                 NoApplicableMethod?)
        (only-in :clan/poo/mop
                 .defgeneric
                 Type
                 Type.
                 TypeError?
                 define-type
                 element?
                 validate))

(export gerbil-poo-operation-admission-test)

;;; The generic selects behavior from a native Type descriptor.  The project
;;; does not copy method lookup or add a registry around the descriptor.
(.defgeneric (admission-project descriptor value)
  slot: .admission-project)

(define-type (AdmissionSymbol @ Type.)
  .element?: symbol?
  .admission-project: symbol->string)

(def gerbil-poo-operation-admission-test
  (test-suite
   "pinned gerbil-poo operation admission"

   (yuanxu-test-case "constructs, projects, calls, and clones native objects"
     (.def base-value
       (identity 'base)
       (render (lambda (suffix) (cons identity suffix))))
     (let (clone (.cc base-value identity: 'clone))
       (check-equal? (.ref base-value 'identity) 'base)
       (check-equal? (.get clone identity) 'clone)
       (check-equal? (.@ clone identity) 'clone)
       (check-equal? (.call clone render '(tail)) '(clone tail))
       (check-equal? (.slot? clone 'render) #t)
       (check-equal? (length (.all-slots clone)) 2)))

   (yuanxu-test-case "expresses a Scenario as defaults, inherited refinement, nested composition, and behavior"
     (.def scenario-base
       (profiles ? '())
       (metadata (.o (owner 'agentic-ai-lab)
                     (runtime-owner 'marlin)))
       (prepare (lambda (facts)
                  (list 'prepared facts profiles))))
     (.def (github-release @ scenario-base)
       (profiles => append '(developer staging production))
       (metadata =>.+ (.o (provider 'github-actions)))
       (prepare (lambda (facts)
                  (list 'github-release facts profiles))))
     (check-equal? (.get github-release profiles)
                   '(developer staging production))
     (check-equal? (.get github-release metadata owner) 'agentic-ai-lab)
     (check-equal? (.get github-release metadata provider) 'github-actions)
     ;; In the pinned provider `.has?` checks several slots on one receiver;
     ;; explicitly select a child object before reflecting over its slots.
     (check-equal? (.has? (.get github-release metadata)
                          owner provider runtime-owner)
                   #t)
     (check-equal? (.call github-release prepare 'repository-ready)
                   '(github-release repository-ready
                     (developer staging production))))

   (yuanxu-test-case "keeps run-local Session mutation outside the shared prototype"
     (.def (session-prototype @)
       (state 'created)
       (history '())
       (transition!
        (lambda (next-state)
          (.set! @ state next-state)
          (.put! @ 'history (append history (list next-state)))
          @)))
     (let ((first-session (.mix session-prototype))
           (second-session (.mix session-prototype)))
       (.call first-session transition! 'admitted)
       (.call first-session transition! 'projected)
       (check-equal? (.get first-session state) 'projected)
       (check-equal? (.get first-session history) '(admitted projected))
       (check-equal? (.get second-session state) 'created)
       (check-equal? (.get second-session history) '())
       (check-equal? (.get session-prototype state) 'created)
       ;; A further mix uses the prototype, never the mutated instance cache.
       (check-equal? (.get (.mix first-session) state) 'created)))

   (yuanxu-test-case "invalidates derived caches after prototype surgery"
     (.def evolving-scenario
       (status ? 'draft)
       (version 1))
     (check-equal? (.get evolving-scenario version) 1)
     (let ((derived (.mix evolving-scenario)))
       (check-equal? (.get derived version) 1)
       (.putslot! evolving-scenario 'version ($constant-slot-spec 2))
       ;; Supported specification writes invalidate the source and descendants.
       (check-equal? (.get evolving-scenario version) 2)
       (check-equal? (.get derived version) 2))
     (uninstantiate-object! evolving-scenario)
     (check-equal? (.get evolving-scenario version) 2)
     (uninstantiate-object! evolving-scenario)
     (.putdefault! evolving-scenario 'status 'ready)
     (.def! evolving-scenario projection-kind () 'github-workflow)
     (check-equal? (.get evolving-scenario status) 'ready)
     (check-equal? (.get evolving-scenario projection-kind)
                   'github-workflow))

   (yuanxu-test-case "preserves C4 super order and lazy slot caching"
     (let ((b-evaluations 0)
           (c-evaluations 0))
       (let* ((a (.o (responsibility '(a))))
              (b
               (.extend
                a
                (cons
                 'responsibility
                 ($computed-slot-spec
                  (lambda (_self inherited)
                    (set! b-evaluations (1+ b-evaluations))
                    (cons 'b (inherited)))))))
              (c
               (.extend
                a
                (cons
                 'responsibility
                 ($computed-slot-spec
                  (lambda (_self inherited)
                    (set! c-evaluations (1+ c-evaluations))
                    (cons 'c (inherited)))))))
              (d (.mix b c)))
         (check-equal? (.ref d 'responsibility) '(b c a))
         (check-equal? (.ref d 'responsibility) '(b c a))
         (check-equal? b-evaluations 1)
         (check-equal? c-evaluations 1))))

   (yuanxu-test-case "dispatches validation and projection through a Type descriptor"
     (check-equal? (element? Type AdmissionSymbol) #t)
     (check-equal? (validate AdmissionSymbol 'flow) 'flow)
     (check-equal? (admission-project AdmissionSymbol 'flow) "flow")
     (check-exception (validate AdmissionSymbol 42) TypeError?))

   (yuanxu-test-case "preserves native missing-method failure"
     (check-exception
      (admission-project (.o) 'flow)
      NoApplicableMethod?))

   (yuanxu-test-case "preserves native invalid-precedence failure"
     (let* ((x (.o))
            (y (.o))
            (xy (.mix x y))
            (yx (.mix y x))
            (inconsistent (.mix xy yx)))
       (check-exception (.slot? inconsistent 'identity) true)))))
