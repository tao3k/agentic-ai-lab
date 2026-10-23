;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: behavioral Scenario Case and fresh Session objects for one closed
;;; user-composition value. Scenario owns execution projection and lifecycle.
;;; Invariant: planning remains pure; only a fresh Session instance mutates.

(import (only-in :clan/poo/object .all-slots .call .mix .o .put! .ref .set! object?)
        (rename-in (only-in :yuanxu/modules/funflow/control-plane/graph
                            execution-plan?
                            plan-node-count)
                   (plan-node-count core-plan-node-count))
        (only-in :agentic-ai-lab/modules/workflow/scenario/plan-projection
                 agentic-ai-lab-scenario-case->execution-plan))

(export +agentic-ai-lab-scenario-case-kind+
        +agentic-ai-lab-scenario-session-kind+
        +agentic-ai-lab-scenario-admission-kind+
        +agentic-ai-lab-scenario-presentation-kind+
        agentic-ai-lab-scenario-case
        agentic-ai-lab-scenario-case?
        agentic-ai-lab-scenario-session
        agentic-ai-lab-scenario-session?
        agentic-ai-lab-scenario-session-state
        agentic-ai-lab-scenario-session-events
        agentic-ai-lab-scenario-session-last-result)

(def +agentic-ai-lab-scenario-case-kind+ 'agentic-ai-lab.scenario-case.v1)
(def +agentic-ai-lab-scenario-session-kind+ 'agentic-ai-lab.scenario-session.v1)
(def +agentic-ai-lab-scenario-admission-kind+ 'agentic-ai-lab.scenario.admission.v1)
(def +agentic-ai-lab-scenario-presentation-kind+ 'agentic-ai-lab.scenario.presentation.v1)

(def (agentic-ai-lab-scenario-kind? value expected)
  (and (object? value)
       (with-catch (lambda (_failure) #f)
                   (lambda () (eq? (.ref value 'kind) expected)))))

(def (agentic-ai-lab-scenario-case? value)
  (agentic-ai-lab-scenario-kind? value +agentic-ai-lab-scenario-case-kind+))

(def (agentic-ai-lab-scenario-session? value)
  (agentic-ai-lab-scenario-kind? value +agentic-ai-lab-scenario-session-kind+))

(def (agentic-ai-lab-scenario-admission composition)
  (with-catch
   (lambda (failure)
     (.o (kind +agentic-ai-lab-scenario-admission-kind+)
         (accepted? #f)
         (case composition)
         (plan #f)
         (diagnostics (list failure))))
   (lambda ()
     (let (plan-value (.ref composition 'execution-plan))
       (.o (kind +agentic-ai-lab-scenario-admission-kind+)
           (accepted? (execution-plan? plan-value))
           (case composition)
           (plan plan-value)
           (diagnostics '()))))))

(def (agentic-ai-lab-scenario-presentation composition admission)
  (let ((accepted-value (.ref admission 'accepted?))
        (plan-value (.ref admission 'plan)))
    (.o (kind +agentic-ai-lab-scenario-presentation-kind+)
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

(def (agentic-ai-lab-scenario-project composition projection)
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

(def (agentic-ai-lab-scenario-session-require-state session expected operation)
  (let (actual (.ref session 'state))
    (unless (eq? actual expected)
      (error "invalid Scenario Session transition"
             operation expected actual))))

(def (agentic-ai-lab-scenario-session-record!
      session next-state operation result)
  (let ((operation-value operation)
        (result-value result))
    (.set! session state next-state)
    (.put! session 'last-result result-value)
    (.put! session 'events-rev
           (cons
            (.o (kind 'agentic-ai-lab.scenario.session-event.v1)
                (operation operation-value)
                (state next-state)
                (result result-value))
            (.ref session 'events-rev)))
    result-value))

(def agentic-ai-lab-scenario-session-prototype
  (.o (:: @)
      (kind +agentic-ai-lab-scenario-session-kind+)
      (state 'created)
      (events-rev '())
      (last-result #f)
      (prepare!
       (lambda ()
         (agentic-ai-lab-scenario-session-require-state @ 'created 'prepare!)
         (agentic-ai-lab-scenario-session-record!
          @ 'prepared 'prepare!
          (.call (.ref @ 'composition) prepare))))
      (admit!
       (lambda ()
         (agentic-ai-lab-scenario-session-require-state @ 'prepared 'admit!)
         (let (receipt (.call (.ref @ 'composition) admit))
           (agentic-ai-lab-scenario-session-record!
            @
            (if (.ref receipt 'accepted?) 'admitted 'rejected)
            'admit!
            receipt))))
      (project!
       (lambda (projection)
         (agentic-ai-lab-scenario-session-require-state @ 'admitted 'project!)
         (agentic-ai-lab-scenario-session-record!
          @ 'projected 'project!
          (.call (.ref @ 'composition) project projection))))))

(def (agentic-ai-lab-scenario-session composition)
  (unless (agentic-ai-lab-scenario-case? composition)
    (error "Scenario Session requires a closed Scenario Case" composition))
  (let (composition-value composition)
    (.mix (.o (composition composition-value))
          agentic-ai-lab-scenario-session-prototype)))

(def (agentic-ai-lab-scenario-session-state session)
  (.ref session 'state))

(def (agentic-ai-lab-scenario-session-events session)
  (reverse (.ref session 'events-rev)))

(def (agentic-ai-lab-scenario-session-last-result session)
  (.ref session 'last-result))

(def (agentic-ai-lab-scenario-case
      name module-bindings profiles stages profile-bindings)
  (let ((name-value name)
        (module-bindings-value module-bindings)
        (profiles-value profiles)
        (stages-value stages)
        (profile-bindings-value profile-bindings))
    (.o (:: @)
        (kind +agentic-ai-lab-scenario-case-kind+)
        (name name-value)
        (modules module-bindings-value)
        (profiles profiles-value)
        (stages stages-value)
        (profile-bindings profile-bindings-value)
        (execution-plan (agentic-ai-lab-scenario-case->execution-plan @))
        (admission (agentic-ai-lab-scenario-admission @))
        (presentation
         (agentic-ai-lab-scenario-presentation @ (.ref @ 'admission)))
        (prepare (lambda () (.ref @ 'execution-plan)))
        (admit (lambda () (.ref @ 'admission)))
        (project
         (lambda (projection)
           (agentic-ai-lab-scenario-project @ projection)))
        (present
         (lambda ()
           (.ref @ 'presentation)))
        (new-session
         (lambda () (agentic-ai-lab-scenario-session @))))))
