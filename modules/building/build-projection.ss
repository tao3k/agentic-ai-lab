;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: bootstrap-safe observation of ASP PackageSpec projection.
;;; This owner depends only on gerbil-poo and its module-owned configuration so
;;; an external package coordinator can load it before the Agentic AI Lab image
;;; exists.  build.ss does not import its own package observers.  ASP PackageSpec
;;; and std/make retain projection and execution ownership.

(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :yuanxu/observability/output yuanxu-write-observation-line!))

(export agentic-ai-lab-build-elapsed-milliseconds
        agentic-ai-lab-make-observed-package-spec-projector
        agentic-ai-lab-admit-build-package-spec!
        agentic-ai-lab-observe-build-projection-start
        agentic-ai-lab-observe-build-projection
        agentic-ai-lab-observe-build-executor-handoff)

(def (agentic-ai-lab-build-elapsed-milliseconds started-jiffy)
  (quotient (* (- (current-jiffy) started-jiffy) 1000)
            (jiffies-per-second)))

(def (agentic-ai-lab-make-observed-package-spec-projector projector policy)
  (unless (procedure? projector)
    (error "Agentic AI Lab observed PackageSpec projector must be a procedure"
           projector))
  (lambda (package-spec)
    (let (started (current-jiffy))
      (agentic-ai-lab-observe-build-projection-start policy)
      (agentic-ai-lab-admit-build-package-spec! package-spec policy)
      (let* ((spec (projector package-spec))
             (target-count (length spec))
             (elapsed-ms (agentic-ai-lab-build-elapsed-milliseconds started)))
        (agentic-ai-lab-observe-build-projection policy target-count elapsed-ms)
        (agentic-ai-lab-observe-build-executor-handoff policy target-count)
        spec))))

;;; Validate only the declared PackageSpec boundary.  The ordinary Agentic AI Lab
;;; package declares its stable public roots so ASP can project their native
;;; registry closure before handing the resulting targets to std/make.
;;; Observation reports that declaration and never replaces its graph.
(def (agentic-ai-lab-admit-build-package-spec! package-spec policy)
  (unless (object? package-spec)
    (error "Agentic AI Lab build projection requires a POO PackageSpec"
           package-spec))
  (when (.slot? package-spec 'public-entry-modules)
    (let (roots (.ref package-spec 'public-entry-modules))
      (unless (list? roots)
        (error "Agentic AI Lab PackageSpec public-entry-modules must be a list"
               roots))
      (when (and (pair? roots)
                 (agentic-ai-lab-build-policy-ref policy 'enabled?))
        (yuanxu-write-observation-line!
         "[agentic-ai-lab] phase=spec-input profile=%a mode=public-entry-modules declared-root-count=%a policy=%a owner=asp-build-api/native-import-closure executor=asp-build-api/std-make"
         (agentic-ai-lab-build-policy-ref policy 'profile)
         (length roots)
         (agentic-ai-lab-build-policy-ref policy 'id))))))

(def (agentic-ai-lab-build-policy-ref policy slot)
  (unless (object? policy)
    (error "Agentic AI Lab build observation policy must be a POO object" policy))
  (.ref policy slot))

(def (agentic-ai-lab-build-policy-budget policy slot)
  (let (value (agentic-ai-lab-build-policy-ref policy slot))
    (if (or (not value) (and (exact-integer? value) (> value 0)))
      value
      (error "Agentic AI Lab build observation budget must be positive or false"
             (.ref policy 'id) slot value))))

(def (agentic-ai-lab-build-budget-action policy slot)
  (let (action (agentic-ai-lab-build-policy-ref policy slot))
    (if (memq action '(observe reject))
      action
      (error "Agentic AI Lab build observation action must be observe or reject"
             (.ref policy 'id) slot action))))

(def (agentic-ai-lab-build-budget-exceeded! policy reason observed budget action)
  (let (profile-name (agentic-ai-lab-build-policy-ref policy 'profile))
    (yuanxu-write-observation-line!
     "[agentic-ai-lab] phase=spec-budget-exceeded profile=%a reason=%a observed=%a budget=%a action=%a policy=%a owner=observability/build executor=asp-build-api/std-make"
     profile-name reason observed budget action
     (agentic-ai-lab-build-policy-ref policy 'id))
    (when (eq? action 'reject)
      (error "Agentic AI Lab build observation exceeded its configured budget"
             profile-name reason observed budget))))

(def (agentic-ai-lab-observe-build-projection-start policy)
  (when (agentic-ai-lab-build-policy-ref policy 'enabled?)
    (let (profile-name (agentic-ai-lab-build-policy-ref policy 'profile))
      (yuanxu-write-observation-line!
       "[agentic-ai-lab] phase=spec-start profile=%a policy=%a owner=observability/build executor=asp-build-api/std-make"
       profile-name (agentic-ai-lab-build-policy-ref policy 'id)))))

(def (agentic-ai-lab-observe-build-projection policy target-count elapsed-ms)
  (let* ((profile-name (agentic-ai-lab-build-policy-ref policy 'profile))
         (target-budget (agentic-ai-lab-build-policy-budget policy 'target-budget))
         (projection-budget-ms
          (agentic-ai-lab-build-policy-budget policy 'projection-budget-ms))
         (target-budget-action
          (agentic-ai-lab-build-budget-action policy 'target-budget-action))
         (projection-budget-action
          (agentic-ai-lab-build-budget-action policy 'projection-budget-action)))
    (when (agentic-ai-lab-build-policy-ref policy 'enabled?)
      (yuanxu-write-observation-line!
       "[agentic-ai-lab] phase=spec-projected profile=%a target-count=%a elapsedMs=%a policy=%a owner=observability/build executor=asp-build-api/std-make"
       profile-name target-count elapsed-ms
       (agentic-ai-lab-build-policy-ref policy 'id)))
    (when (and target-budget (> target-count target-budget))
      (agentic-ai-lab-build-budget-exceeded!
       policy "target-count" target-count target-budget target-budget-action))
    (when (and projection-budget-ms (> elapsed-ms projection-budget-ms))
      (agentic-ai-lab-build-budget-exceeded!
       policy "projection-elapsed-ms" elapsed-ms projection-budget-ms
       projection-budget-action))))

;;; This observer is available to callers that wrap a projection outside the
;;; package being built. A package build must never import its own observer.
(def (agentic-ai-lab-observe-build-executor-handoff policy target-count)
  (let (emit? (agentic-ai-lab-build-policy-ref policy 'emit-executor-handoff?))
    (unless (boolean? emit?)
      (error "Agentic AI Lab executor handoff emission must be boolean"
             (.ref policy 'id) emit?))
    (when emit?
      ;; This observer does not own std/make's lifetime, so it must not spawn
      ;; an unbounded heartbeat thread.  ASP's scoped projection observer owns
      ;; and terminates its heartbeat with dynamic-wind; this edge records the
      ;; handoff exactly once and then returns control to the native executor.
      (yuanxu-write-observation-line!
       "[agentic-ai-lab] phase=executor-handoff profile=%a boundary=std/make/source-import-currentness-or-compile target-count=%a policy=%a owner=observability/build executor=asp-build-api/std-make"
       (agentic-ai-lab-build-policy-ref policy 'profile)
       target-count (agentic-ai-lab-build-policy-ref policy 'id)))))
