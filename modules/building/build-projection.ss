;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: bootstrap-safe observation of ASP PackageSpec projection.
;;; This owner depends only on gerbil-poo and its module-owned configuration so
;;; an external package coordinator can load it before the POO Flow image
;;; exists.  build.ss does not import its own package observers.  ASP PackageSpec
;;; and std/make retain projection and execution ownership.

(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :core/observability/output poo-flow-write-observation-line!))

(export poo-flow-build-elapsed-milliseconds
        poo-flow-make-observed-package-spec-projector
        poo-flow-admit-build-package-spec!
        poo-flow-observe-build-projection-start
        poo-flow-observe-build-projection
        poo-flow-observe-build-executor-handoff)

(def (poo-flow-build-elapsed-milliseconds started-jiffy)
  (quotient (* (- (current-jiffy) started-jiffy) 1000)
            (jiffies-per-second)))

(def (poo-flow-make-observed-package-spec-projector projector policy)
  (unless (procedure? projector)
    (error "POO Flow observed PackageSpec projector must be a procedure"
           projector))
  (lambda (package-spec)
    (let (started (current-jiffy))
      (poo-flow-observe-build-projection-start policy)
      (poo-flow-admit-build-package-spec! package-spec policy)
      (let* ((spec (projector package-spec))
             (target-count (length spec))
             (elapsed-ms (poo-flow-build-elapsed-milliseconds started)))
        (poo-flow-observe-build-projection policy target-count elapsed-ms)
        (poo-flow-observe-build-executor-handoff policy target-count)
        spec))))

;;; Validate only the declared PackageSpec boundary.  The ordinary POO Flow
;;; package declares its stable public roots so ASP can project their native
;;; registry closure before handing the resulting targets to std/make.
;;; Observation reports that declaration and never replaces its graph.
(def (poo-flow-admit-build-package-spec! package-spec policy)
  (unless (object? package-spec)
    (error "POO Flow build projection requires a POO PackageSpec"
           package-spec))
  (when (.slot? package-spec 'public-entry-modules)
    (let (roots (.ref package-spec 'public-entry-modules))
      (unless (list? roots)
        (error "POO Flow PackageSpec public-entry-modules must be a list"
               roots))
      (when (and (pair? roots)
                 (poo-flow-build-policy-ref policy 'enabled?))
        (poo-flow-write-observation-line!
         "[poo-flow] phase=spec-input profile=%a mode=public-entry-modules declared-root-count=%a policy=%a owner=asp-build-api/native-import-closure executor=asp-build-api/std-make"
         (poo-flow-build-policy-ref policy 'profile)
         (length roots)
         (poo-flow-build-policy-ref policy 'id))))))

(def (poo-flow-build-policy-ref policy slot)
  (unless (object? policy)
    (error "POO Flow build observation policy must be a POO object" policy))
  (.ref policy slot))

(def (poo-flow-build-policy-budget policy slot)
  (let (value (poo-flow-build-policy-ref policy slot))
    (if (or (not value) (and (exact-integer? value) (> value 0)))
      value
      (error "POO Flow build observation budget must be positive or false"
             (.ref policy 'id) slot value))))

(def (poo-flow-build-budget-action policy slot)
  (let (action (poo-flow-build-policy-ref policy slot))
    (if (memq action '(observe reject))
      action
      (error "POO Flow build observation action must be observe or reject"
             (.ref policy 'id) slot action))))

(def (poo-flow-build-budget-exceeded! policy reason observed budget action)
  (let (profile-name (poo-flow-build-policy-ref policy 'profile))
    (poo-flow-write-observation-line!
     "[poo-flow] phase=spec-budget-exceeded profile=%a reason=%a observed=%a budget=%a action=%a policy=%a owner=observability/build executor=asp-build-api/std-make"
     profile-name reason observed budget action
     (poo-flow-build-policy-ref policy 'id))
    (when (eq? action 'reject)
      (error "POO Flow build observation exceeded its configured budget"
             profile-name reason observed budget))))

(def (poo-flow-observe-build-projection-start policy)
  (when (poo-flow-build-policy-ref policy 'enabled?)
    (let (profile-name (poo-flow-build-policy-ref policy 'profile))
      (poo-flow-write-observation-line!
       "[poo-flow] phase=spec-start profile=%a policy=%a owner=observability/build executor=asp-build-api/std-make"
       profile-name (poo-flow-build-policy-ref policy 'id)))))

(def (poo-flow-observe-build-projection policy target-count elapsed-ms)
  (let* ((profile-name (poo-flow-build-policy-ref policy 'profile))
         (target-budget (poo-flow-build-policy-budget policy 'target-budget))
         (projection-budget-ms
          (poo-flow-build-policy-budget policy 'projection-budget-ms))
         (target-budget-action
          (poo-flow-build-budget-action policy 'target-budget-action))
         (projection-budget-action
          (poo-flow-build-budget-action policy 'projection-budget-action)))
    (when (poo-flow-build-policy-ref policy 'enabled?)
      (poo-flow-write-observation-line!
       "[poo-flow] phase=spec-projected profile=%a target-count=%a elapsedMs=%a policy=%a owner=observability/build executor=asp-build-api/std-make"
       profile-name target-count elapsed-ms
       (poo-flow-build-policy-ref policy 'id)))
    (when (and target-budget (> target-count target-budget))
      (poo-flow-build-budget-exceeded!
       policy "target-count" target-count target-budget target-budget-action))
    (when (and projection-budget-ms (> elapsed-ms projection-budget-ms))
      (poo-flow-build-budget-exceeded!
       policy "projection-elapsed-ms" elapsed-ms projection-budget-ms
       projection-budget-action))))

;;; This observer is available to callers that wrap a projection outside the
;;; package being built. A package build must never import its own observer.
(def (poo-flow-observe-build-executor-handoff policy target-count)
  (let (emit? (poo-flow-build-policy-ref policy 'emit-executor-handoff?))
    (unless (boolean? emit?)
      (error "POO Flow executor handoff emission must be boolean"
             (.ref policy 'id) emit?))
    (when emit?
      ;; This observer does not own std/make's lifetime, so it must not spawn
      ;; an unbounded heartbeat thread.  ASP's scoped projection observer owns
      ;; and terminates its heartbeat with dynamic-wind; this edge records the
      ;; handoff exactly once and then returns control to the native executor.
      (poo-flow-write-observation-line!
       "[poo-flow] phase=executor-handoff profile=%a boundary=std/make/source-import-currentness-or-compile target-count=%a policy=%a owner=observability/build executor=asp-build-api/std-make"
       (poo-flow-build-policy-ref policy 'profile)
       target-count (poo-flow-build-policy-ref policy 'id)))))
