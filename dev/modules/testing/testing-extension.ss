;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Agentic AI Lab owns test-operation observation while ASP retains the
;;; native Gerbil test runner.  Enablement and cadence are POO profile slots;
;;; process environment is transport, not policy.

(import (only-in :clan/poo/object .cc .o .ref .slot? object?)
        (only-in :asp-gerbil-scheme/testing-api
                 testing-import-footprint-profile
                 testing-interface-add-profile
                 testing-interface-call-with-operation)
        (only-in :std/string/path path-expand)
        (only-in :yuanxu/observability/output
                 yuanxu-write-observation-line!)
        (only-in :yuanxu/observability/debug
                 yuanxu-debug-call-policy
                 call-with-yuanxu-debug-trace))

(export agentic-ai-lab-native-observability-enabled?
        agentic-ai-lab-testing-observability-profile-prototype
        make-agentic-ai-lab-testing-observability-profile
        agentic-ai-lab-testing-observability-profile?
        agentic-ai-lab-testing-observability-profile-identity
        agentic-ai-lab-testing-observability-profile-heartbeat-interval-seconds
        agentic-ai-lab-testing-observability-profile-source-load-paths
        +agentic-ai-lab-testing-import-footprint-profile+
        agentic-ai-lab-default-testing-observability-profile
        agentic-ai-lab-current-testing-observability-profile
        agentic-ai-lab-observe-testing-operation
        agentic-ai-lab-testing-observability-extension)

(def +agentic-ai-lab-testing-observation-policy+
  (yuanxu-debug-call-policy 'native-gerbil-testing 8))

;;; ASP derives closure ownership from Gerbil's resident module registry.  POO
;;; Flow declares only the policy slots: what counts as a large closure, how
;;; much non-platform overlap is acceptable, and whether a violation rejects.
(def +agentic-ai-lab-testing-import-footprint-profile+
  ;; Reuse ASP's registry policy defaults instead of copying numeric limits
  ;; into the downstream package.  Agentic AI Lab contributes only its admission
  ;; action; ASP owns the resident-module algorithm and calibrated defaults.
  (testing-import-footprint-profile [] 0 'reject))

;;; Heartbeat timing is a POO profile so CI, a user profile, or an atomic test
;;; can refine observation cadence without patching the observer.
(def agentic-ai-lab-testing-observability-profile-prototype
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

(def (agentic-ai-lab-testing-observability-profile? value)
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

(def (make-agentic-ai-lab-testing-observability-profile identity-value
                                                   heartbeat-interval-value)
  (let (profile
        (.o (:: @ agentic-ai-lab-testing-observability-profile-prototype)
            (identity identity-value)
            (trace-enabled? #t)
            (heartbeat-enabled? #t)
            (heartbeat-interval-seconds heartbeat-interval-value)))
    (unless (agentic-ai-lab-testing-observability-profile? profile)
      (error "invalid Agentic AI Lab testing observability profile" profile))
    profile))

(def (agentic-ai-lab-testing-observability-profile-identity profile)
  (.ref profile 'identity))

(def (agentic-ai-lab-testing-observability-profile-heartbeat-interval-seconds profile)
  (.ref profile 'heartbeat-interval-seconds))

(def (agentic-ai-lab-testing-observability-profile-source-load-paths profile)
  (.ref profile 'source-load-paths))

(def agentic-ai-lab-default-testing-observability-profile
  (.o (:: @ agentic-ai-lab-testing-observability-profile-prototype)))

(def agentic-ai-lab-current-testing-observability-profile
  (make-parameter agentic-ai-lab-default-testing-observability-profile))

;;; ASP 3f5fb71c59d5ebb3232d9c0cca1f463ccae72062 starts one native
;;; `gerbil test` process per selected batch.
;;; Keep the source-root decision in the POO profile and project it once into
;;; Gerbil's documented child-process load-path transport before workers start.
;;; This lets an atomic test import its precise source owner without widening
;;; the production PackageSpec to every qualification and scenario module.
(def (agentic-ai-lab-testing-prepare-source-load-path! profile)
  (let (paths
        (map path-expand
             (agentic-ai-lab-testing-observability-profile-source-load-paths profile)))
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
(def (agentic-ai-lab-testing-elapsed-nanoseconds started-jiffy)
  (quotient (* (- (current-jiffy) started-jiffy) 1000000000)
            (jiffies-per-second)))

;; : (forall (a) (-> Symbol (-> a) a))
(def (agentic-ai-lab-call-with-testing-heartbeat operation thunk)
  (if (not (and (agentic-ai-lab-native-observability-enabled?)
                (.ref (agentic-ai-lab-current-testing-observability-profile)
                      'heartbeat-enabled?)))
    (thunk)
    (let* ((started-jiffy (current-jiffy))
           (port (current-error-port))
           (interval
            (agentic-ai-lab-testing-observability-profile-heartbeat-interval-seconds
             (agentic-ai-lab-current-testing-observability-profile)))
           (heartbeat
            (make-thread
             (lambda ()
               (let loop ()
                 (thread-sleep! interval)
                 (parameterize ((current-output-port port)
                                (current-error-port port))
                   (yuanxu-write-observation-line!
                    "[agentic-ai-lab-testing] phase=operation-heartbeat operation=%a elapsedNs=%a"
                    operation
                    (agentic-ai-lab-testing-elapsed-nanoseconds started-jiffy)))
                 (loop))))))
      (thread-start! heartbeat)
      (dynamic-wind
        void
        thunk
        (lambda () (thread-terminate! heartbeat))))))

;; : (-> Boolean)
(def (agentic-ai-lab-native-observability-enabled?)
  (.ref (agentic-ai-lab-current-testing-observability-profile) 'enabled?))

;; : (forall (a) (-> Symbol (-> a) a))
(def (agentic-ai-lab-observe-testing-operation operation thunk)
  (call-with-yuanxu-debug-trace
   +agentic-ai-lab-testing-observation-policy+
   operation
   (lambda ()
     (agentic-ai-lab-call-with-testing-heartbeat operation thunk))
   '()
   emit?: (and (agentic-ai-lab-native-observability-enabled?)
               (.ref (agentic-ai-lab-current-testing-observability-profile)
                     'trace-enabled?))))

;;; Extend the ASP POO value with behavior only. ASP calls the optional slot
;;; without owning its policy, receipt schema, presentation, or enablement.
;; : (-> TestingInterface TestingInterface)
(def (agentic-ai-lab-testing-observability-extension testing . maybe-profile)
  (let (profile
        (if (null? maybe-profile)
          agentic-ai-lab-default-testing-observability-profile
          (car maybe-profile)))
    (unless (agentic-ai-lab-testing-observability-profile? profile)
      (error "invalid Agentic AI Lab testing observability extension profile" profile))
    (agentic-ai-lab-testing-prepare-source-load-path! profile)
    (.cc (testing-interface-add-profile
          testing +agentic-ai-lab-testing-import-footprint-profile+)
         around-operation:
         (lambda (operation thunk)
           (parameterize
               ((agentic-ai-lab-current-testing-observability-profile profile))
             (agentic-ai-lab-observe-testing-operation operation thunk))))))
