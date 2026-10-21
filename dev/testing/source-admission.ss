;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: native gxtest prepares the declared entry files before this POO
;;; extension runs. Gerbil's import model then projects those cached contexts;
;;; this extension only observes the resulting source set.

(import :gerbil/core
        (only-in :asp-gerbil-scheme/src/build-api/native-import-closure
                 asp-gerbil-scheme-prepared-native-import-closure)
        (only-in :asp-gerbil-scheme/src/support/time
                 duration-micros monotonic-micros)
        (only-in :clan/poo/object
                 .o .ref .slot? object? make-object $constant-slot-spec)
        (only-in :core/observability/output
                 poo-flow-write-observation-line!)
        (only-in :core/module-system/observability/presentation
                 poo-flow-poo-slot-authoring-file-observations
                 poo-flow-poo-slot-authoring-observation-ok?))

(export poo-flow-source-admission-observability-profile-prototype
        poo-flow-source-admission-observability-profile?
        poo-flow-default-source-admission-observability-profile
        poo-flow-observe-source-admission!
        poo-flow-source-admission)

;;; A test declares observation policy as a POO value.  Presentation stays in
;;; the Observability owner instead of being repeated as ad hoc `displayln`
;;; calls in every module-specific suite.
(def poo-flow-source-admission-observability-profile-prototype
  (.o (source-admission-observability-profile? #t)
      (identity 'source-admission/default)
      (owner 'poo-flow)
      (module 'all)
      (emit-summary? #t)
      (emit-diagnostics? #t)))

(def (poo-flow-source-admission-observability-profile? value)
  (and (object? value)
       (.slot? value 'source-admission-observability-profile?)
       (.ref value 'source-admission-observability-profile?)
       (.slot? value 'identity)
       (symbol? (.ref value 'identity))
       (.slot? value 'owner)
       (symbol? (.ref value 'owner))
       (.slot? value 'module)
       (symbol? (.ref value 'module))
       (.slot? value 'emit-summary?)
       (boolean? (.ref value 'emit-summary?))
       (.slot? value 'emit-diagnostics?)
       (boolean? (.ref value 'emit-diagnostics?))))

(def poo-flow-default-source-admission-observability-profile
  (.o (:: @ poo-flow-source-admission-observability-profile-prototype)))

(def (poo-flow-observe-source-admission! profile receipt)
  (unless (poo-flow-source-admission-observability-profile? profile)
    (error "invalid source-admission observability profile" profile))
  (when (.ref profile 'emit-summary?)
    (poo-flow-write-observation-line!
     "[poo-flow-observability] phase=source-scanned profile=%a owner=%a module=%a files=%a observations=%a diagnostics=%a preparedGraphElapsedUs=%a policyElapsedUs=%a elapsedUs=%a"
     (.ref profile 'identity)
     (.ref profile 'owner)
     (.ref profile 'module)
     (.ref receipt 'file-count)
     (.ref receipt 'observation-count)
     (.ref receipt 'diagnostic-count)
     (.ref receipt 'prepared-graph-elapsed-us)
     (.ref receipt 'authoring-policy-elapsed-us)
     (.ref receipt 'elapsed-us)))
  (when (and (.ref profile 'emit-diagnostics?)
             (> (.ref receipt 'diagnostic-count) 0))
    (poo-flow-write-observation-line!
     "[poo-flow-observability] phase=source-diagnostics profile=%a owner=%a module=%a diagnostics=%a"
     (.ref profile 'identity)
     (.ref profile 'owner)
     (.ref profile 'module)
     (.ref receipt 'diagnostics)))
  receipt)

(def (poo-flow-source-admission-slot name value)
  (cons name ($constant-slot-spec value)))

(def (poo-flow-source-admission-phase thunk)
  (let (started-at (monotonic-micros))
    (let (result (thunk))
      (values result
              (duration-micros started-at (monotonic-micros))))))

(def (poo-flow-source-admission-prepared-sources root entries)
  (let (previous-directory (current-directory))
    (dynamic-wind
      (lambda () (current-directory root))
      (lambda ()
        (asp-gerbil-scheme-prepared-native-import-closure root entries))
      (lambda () (current-directory previous-directory)))))

;;; Fold observations as each file is read.  The admission receipt needs only
;;; counts and diagnostics, so successful observation rows are never retained.
(def (poo-flow-source-admission-scan root sources)
  (foldl
   (lambda (source state)
     (let (path (path-expand source root))
       (foldl
        (lambda (observation inner-state)
          (cons (+ (car inner-state) 1)
                (if (poo-flow-poo-slot-authoring-observation-ok? observation)
                  (cdr inner-state)
                  (cons observation (cdr inner-state)))))
        state
        (poo-flow-poo-slot-authoring-file-observations
         (string->symbol path) path))))
   (cons 0 [])
   sources))

;; poo-flow-source-admission
;;   : (-> Path [Path] POOObject)
;;   | contract: observe exactly the Gerbil-native import closure of entries
;;   | result: a bounded POO receipt with no retained successful source rows
(def (poo-flow-source-admission root entries)
  (let* ((normalized-root (path-normalize (path-expand root)))
         (started-at (monotonic-micros)))
    (let-values (((sources prepared-graph-elapsed-us)
                  (poo-flow-source-admission-phase
                   (lambda ()
                     (list-sort
                      string<?
                      (poo-flow-source-admission-prepared-sources
                       normalized-root entries))))))
      (let-values (((scan-result policy-elapsed-us)
                    (poo-flow-source-admission-phase
                     (lambda ()
                       (poo-flow-source-admission-scan
                        normalized-root sources)))))
        (let (diagnostics (reverse (cdr scan-result)))
          (make-object
           slots:
           (list
            (poo-flow-source-admission-slot
             'kind 'poo-flow-source-admission)
            (poo-flow-source-admission-slot 'root normalized-root)
            (poo-flow-source-admission-slot 'file-count (length sources))
            (poo-flow-source-admission-slot
             'observation-count (car scan-result))
            (poo-flow-source-admission-slot 'diagnostics diagnostics)
            (poo-flow-source-admission-slot
             'diagnostic-count (length diagnostics))
            (poo-flow-source-admission-slot
             'prepared-graph-elapsed-us prepared-graph-elapsed-us)
            (poo-flow-source-admission-slot
             'authoring-policy-elapsed-us policy-elapsed-us)
            (poo-flow-source-admission-slot
             'elapsed-us
             (duration-micros started-at (monotonic-micros)))
            (poo-flow-source-admission-slot
             'admitted? (null? diagnostics))
            (poo-flow-source-admission-slot 'runtime-executed? #f))))))))
