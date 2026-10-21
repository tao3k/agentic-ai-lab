;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO Flow owns test-operation observation while ASP retains the
;;; native Gerbil test runner.  Enablement and cadence are POO profile slots;
;;; process environment is transport, not policy.

(import (only-in :clan/poo/object .cc .o .ref .slot? object?)
        (only-in :asp-gerbil-scheme/testing-api
                 testing-import-footprint-profile
                 testing-interface-add-profile
                 testing-interface-call-with-operation)
        (only-in :std/string/path path-expand)
        (only-in :core/observability/output
                 poo-flow-write-observation-line!)
        (only-in :core/observability/debug
                 poo-flow-debug-call-policy
                 call-with-poo-flow-debug-trace))

(export poo-flow-native-observability-enabled?
        poo-flow-testing-observability-profile-prototype
        make-poo-flow-testing-observability-profile
        poo-flow-testing-observability-profile?
        poo-flow-testing-observability-profile-identity
        poo-flow-testing-observability-profile-heartbeat-interval-seconds
        poo-flow-testing-observability-profile-source-load-paths
        +poo-flow-testing-import-footprint-profile+
        poo-flow-default-testing-observability-profile
        poo-flow-current-testing-observability-profile
        poo-flow-observe-testing-operation
        poo-flow-testing-observability-extension)

(def +poo-flow-testing-observation-policy+
  (poo-flow-debug-call-policy 'native-gerbil-testing 8))

;;; ASP derives closure ownership from Gerbil's resident module registry.  POO
;;; Flow declares only the policy slots: what counts as a large closure, how
;;; much non-platform overlap is acceptable, and whether a violation rejects.
(def +poo-flow-testing-import-footprint-profile+
  ;; Reuse ASP's registry policy defaults instead of copying numeric limits
  ;; into the downstream package.  POO Flow contributes only its admission
  ;; action; ASP owns the resident-module algorithm and calibrated defaults.
  (testing-import-footprint-profile [] 0 'reject))

;;; Heartbeat timing is a POO profile so CI, a user profile, or an atomic test
;;; can refine observation cadence without patching the observer.
(def poo-flow-testing-observability-profile-prototype
  (.o (testing-observability-profile? #t)
      (identity 'testing/default)
      (enabled? #t)
      (trace-enabled? #f)
      ;; A batch heartbeat repeats once per concurrent worker and does not
      ;; identify the active Case.  Keep it opt-in for targeted debugging.
      (heartbeat-enabled? #f)
      (heartbeat-interval-seconds 5)
      ;; The profile contributes only its source owner.  Gerbil's active
      ;; library path remains runtime-owned and is projected separately.
      (source-load-paths '("."))))

(def (poo-flow-testing-observability-profile? value)
  (and (object? value)
       (.slot? value 'testing-observability-profile?)
       (.ref value 'testing-observability-profile?)
       (.slot? value 'identity)
       (symbol? (.ref value 'identity))
       (.slot? value 'enabled?)
       (boolean? (.ref value 'enabled?))
       (.slot? value 'trace-enabled?)
       (boolean? (.ref value 'trace-enabled?))
       (.slot? value 'heartbeat-enabled?)
       (boolean? (.ref value 'heartbeat-enabled?))
       (.slot? value 'heartbeat-interval-seconds)
       (real? (.ref value 'heartbeat-interval-seconds))
       (> (.ref value 'heartbeat-interval-seconds) 0)
       (.slot? value 'source-load-paths)
       (list? (.ref value 'source-load-paths))
       (andmap (lambda (path)
                 (and (string? path) (> (string-length path) 0)))
               (.ref value 'source-load-paths))))

(def (make-poo-flow-testing-observability-profile identity-value
                                                   heartbeat-interval-value)
  (let (profile
        (.o (:: @ poo-flow-testing-observability-profile-prototype)
            (identity identity-value)
            (trace-enabled? #t)
            (heartbeat-enabled? #t)
            (heartbeat-interval-seconds heartbeat-interval-value)))
    (unless (poo-flow-testing-observability-profile? profile)
      (error "invalid POO Flow testing observability profile" profile))
    profile))

(def (poo-flow-testing-observability-profile-identity profile)
  (.ref profile 'identity))

(def (poo-flow-testing-observability-profile-heartbeat-interval-seconds profile)
  (.ref profile 'heartbeat-interval-seconds))

(def (poo-flow-testing-observability-profile-source-load-paths profile)
  (.ref profile 'source-load-paths))

(def poo-flow-default-testing-observability-profile
  (.o (:: @ poo-flow-testing-observability-profile-prototype)))

(def poo-flow-current-testing-observability-profile
  (make-parameter poo-flow-default-testing-observability-profile))

;;; ASP 3f5fb71c59d5ebb3232d9c0cca1f463ccae72062 starts one native
;;; `gerbil test` process per selected batch.
;;; Keep the source-root decision in the POO profile and project it once into
;;; Gerbil's documented child-process load-path transport before workers start.
;;; This lets an atomic test import its precise source owner without widening
;;; the production PackageSpec to every qualification and scenario module.
(def (poo-flow-testing-prepare-source-load-path! profile)
  (let (paths
        (map path-expand
             (poo-flow-testing-observability-profile-source-load-paths profile)))
    (when (pair? paths)
      (let ((current
             (or (getenv "GERBIL_LOADPATH" #f)
                 (string-join (load-path) ":")))
            (projected (string-join paths ":")))
        (setenv "GERBIL_LOADPATH"
                (if (and current (> (string-length current) 0))
                  (string-append current ":" projected)
                  projected))))))

;; : (-> Integer Natural)
(def (poo-flow-testing-elapsed-nanoseconds started-jiffy)
  (quotient (* (- (current-jiffy) started-jiffy) 1000000000)
            (jiffies-per-second)))

;; : (forall (a) (-> Symbol (-> a) a))
(def (poo-flow-call-with-testing-heartbeat operation thunk)
  (if (not (and (poo-flow-native-observability-enabled?)
                (.ref (poo-flow-current-testing-observability-profile)
                      'heartbeat-enabled?)))
    (thunk)
    (let* ((started-jiffy (current-jiffy))
           (port (current-error-port))
           (interval
            (poo-flow-testing-observability-profile-heartbeat-interval-seconds
             (poo-flow-current-testing-observability-profile)))
           (heartbeat
            (make-thread
             (lambda ()
               (let loop ()
                 (thread-sleep! interval)
                 (parameterize ((current-output-port port)
                                (current-error-port port))
                   (poo-flow-write-observation-line!
                    "[poo-flow-testing] phase=operation-heartbeat operation=%a elapsedNs=%a"
                    operation
                    (poo-flow-testing-elapsed-nanoseconds started-jiffy)))
                 (loop))))))
      (thread-start! heartbeat)
      (dynamic-wind
        void
        thunk
        (lambda () (thread-terminate! heartbeat))))))

;; : (-> Boolean)
(def (poo-flow-native-observability-enabled?)
  (.ref (poo-flow-current-testing-observability-profile) 'enabled?))

;; : (forall (a) (-> Symbol (-> a) a))
(def (poo-flow-observe-testing-operation operation thunk)
  (call-with-poo-flow-debug-trace
   +poo-flow-testing-observation-policy+
   operation
   (lambda ()
     (poo-flow-call-with-testing-heartbeat operation thunk))
   '()
   emit?: (and (poo-flow-native-observability-enabled?)
               (.ref (poo-flow-current-testing-observability-profile)
                     'trace-enabled?))))

;;; Extend the ASP POO value with behavior only. ASP calls the optional slot
;;; without owning its policy, receipt schema, presentation, or enablement.
;; : (-> TestingInterface TestingInterface)
(def (poo-flow-testing-observability-extension testing . maybe-profile)
  (let (profile
        (if (null? maybe-profile)
          poo-flow-default-testing-observability-profile
          (car maybe-profile)))
    (unless (poo-flow-testing-observability-profile? profile)
      (error "invalid POO Flow testing observability extension profile" profile))
    (poo-flow-testing-prepare-source-load-path! profile)
    (.cc (testing-interface-add-profile
          testing +poo-flow-testing-import-footprint-profile+)
         around-operation:
         (lambda (operation thunk)
           (parameterize
               ((poo-flow-current-testing-observability-profile profile))
             (poo-flow-observe-testing-operation operation thunk))))))
