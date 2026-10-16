;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: behavioral Scenario Case and fresh Session objects for one closed
;;; user-composition value. Scenario owns execution projection and lifecycle.
;;; Invariant: planning remains pure; only a fresh Session instance mutates.

(import (only-in :clan/poo/object .all-slots .call .mix .o .put! .ref .set! object?)
        (rename-in (only-in :poo-flow/modules/workflow/control-plane/plan
                            execution-plan?
                            plan-node-count)
                   (plan-node-count core-plan-node-count))
        (only-in :poo-flow/modules/workflow/scenario/plan-projection
                 poo-flow-scenario-case->execution-plan))

(export +poo-flow-scenario-case-kind+
        +poo-flow-scenario-session-kind+
        +poo-flow-scenario-admission-kind+
        +poo-flow-scenario-presentation-kind+
        poo-flow-scenario-case
        poo-flow-scenario-case?
        poo-flow-scenario-session
        poo-flow-scenario-session?
        poo-flow-scenario-session-state
        poo-flow-scenario-session-events
        poo-flow-scenario-session-last-result)

(def +poo-flow-scenario-case-kind+ 'poo-flow.scenario-case.v1)
(def +poo-flow-scenario-session-kind+ 'poo-flow.scenario-session.v1)
(def +poo-flow-scenario-admission-kind+ 'poo-flow.scenario.admission.v1)
(def +poo-flow-scenario-presentation-kind+ 'poo-flow.scenario.presentation.v1)

(def (poo-flow-scenario-kind? value expected)
  (and (object? value)
       (with-catch (lambda (_failure) #f)
                   (lambda () (eq? (.ref value 'kind) expected)))))

(def (poo-flow-scenario-case? value)
  (poo-flow-scenario-kind? value +poo-flow-scenario-case-kind+))

(def (poo-flow-scenario-session? value)
  (poo-flow-scenario-kind? value +poo-flow-scenario-session-kind+))

(def (poo-flow-scenario-admission composition)
  (with-catch
   (lambda (failure)
     (.o (kind +poo-flow-scenario-admission-kind+)
         (accepted? #f)
         (case composition)
         (plan #f)
         (diagnostics (list failure))))
   (lambda ()
     (let (plan-value (.ref composition 'execution-plan))
       (.o (kind +poo-flow-scenario-admission-kind+)
           (accepted? (execution-plan? plan-value))
           (case composition)
           (plan plan-value)
           (diagnostics '()))))))

(def (poo-flow-scenario-presentation composition admission)
  (let ((accepted-value (.ref admission 'accepted?))
        (plan-value (.ref admission 'plan)))
    (.o (kind +poo-flow-scenario-presentation-kind+)
        (case-name (.ref composition 'name))
        (accepted? accepted-value)
        (module-count (length (.ref composition 'modules)))
        (profile-count (length (.ref composition 'profiles)))
        (stage-count (length (.all-slots (.ref composition 'stages))))
        (plan-node-count
         (if (and accepted-value (execution-plan? plan-value))
           (core-plan-node-count plan-value)
           0))
        (diagnostics (.ref admission 'diagnostics)))))

(def (poo-flow-scenario-project composition projection)
  (case projection
    ((case) composition)
    ((execution-plan)
     (let (admission (.ref composition 'admission))
       (if (.ref admission 'accepted?)
         (.ref admission 'plan)
         (error "cannot project a rejected Scenario Case" composition))))
    ((admission) (.ref composition 'admission))
    ((presentation summary)
     (.ref composition 'presentation))
    (else
     (error "unknown Scenario Case projection" projection))))

(def (poo-flow-scenario-session-require-state session expected operation)
  (let (actual (.ref session 'state))
    (unless (eq? actual expected)
      (error "invalid Scenario Session transition"
             operation expected actual))))

(def (poo-flow-scenario-session-record!
      session next-state operation result)
  (let ((operation-value operation)
        (result-value result))
    (.set! session state next-state)
    (.put! session 'last-result result-value)
    (.put! session 'events-rev
           (cons
            (.o (kind 'poo-flow.scenario.session-event.v1)
                (operation operation-value)
                (state next-state)
                (result result-value))
            (.ref session 'events-rev)))
    result-value))

(def poo-flow-scenario-session-prototype
  (.o (:: @)
      (kind +poo-flow-scenario-session-kind+)
      (state 'created)
      (events-rev '())
      (last-result #f)
      (prepare!
       (lambda ()
         (poo-flow-scenario-session-require-state @ 'created 'prepare!)
         (poo-flow-scenario-session-record!
          @ 'prepared 'prepare!
          (.call (.ref @ 'composition) prepare))))
      (admit!
       (lambda ()
         (poo-flow-scenario-session-require-state @ 'prepared 'admit!)
         (let (receipt (.call (.ref @ 'composition) admit))
           (poo-flow-scenario-session-record!
            @
            (if (.ref receipt 'accepted?) 'admitted 'rejected)
            'admit!
            receipt))))
      (project!
       (lambda (projection)
         (poo-flow-scenario-session-require-state @ 'admitted 'project!)
         (poo-flow-scenario-session-record!
          @ 'projected 'project!
          (.call (.ref @ 'composition) project projection))))))

(def (poo-flow-scenario-session composition)
  (unless (poo-flow-scenario-case? composition)
    (error "Scenario Session requires a closed Scenario Case" composition))
  (let (composition-value composition)
    (.mix (.o (composition composition-value))
          poo-flow-scenario-session-prototype)))

(def (poo-flow-scenario-session-state session)
  (.ref session 'state))

(def (poo-flow-scenario-session-events session)
  (reverse (.ref session 'events-rev)))

(def (poo-flow-scenario-session-last-result session)
  (.ref session 'last-result))

(def (poo-flow-scenario-case
      name module-bindings profiles stages profile-bindings)
  (let ((name-value name)
        (module-bindings-value module-bindings)
        (profiles-value profiles)
        (stages-value stages)
        (profile-bindings-value profile-bindings))
    (.o (:: @)
        (kind +poo-flow-scenario-case-kind+)
        (name name-value)
        (modules module-bindings-value)
        (profiles profiles-value)
        (stages stages-value)
        (profile-bindings profile-bindings-value)
        (execution-plan (poo-flow-scenario-case->execution-plan @))
        (admission (poo-flow-scenario-admission @))
        (presentation
         (poo-flow-scenario-presentation @ (.ref @ 'admission)))
        (prepare (lambda () (.ref @ 'execution-plan)))
        (admit (lambda () (.ref @ 'admission)))
        (project
         (lambda (projection)
           (poo-flow-scenario-project @ projection)))
        (present
         (lambda ()
           (.ref @ 'presentation)))
        (new-session
         (lambda () (poo-flow-scenario-session @))))))
