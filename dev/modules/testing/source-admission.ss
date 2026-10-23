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
        (only-in :yuanxu/observability/output
                 yuanxu-write-observation-line!)
        (only-in :yuanxu/module-system/observability/presentation
                 yuanxu-poo-slot-authoring-file-observations
                 yuanxu-poo-slot-authoring-observation-ok?))

(export agentic-ai-lab-source-admission-observability-profile-prototype
        agentic-ai-lab-source-admission-observability-profile?
        agentic-ai-lab-default-source-admission-observability-profile
        agentic-ai-lab-observe-source-admission!
        agentic-ai-lab-source-admission)

;;; A test declares observation policy as a POO value.  Presentation stays in
;;; the Observability owner instead of being repeated as ad hoc `displayln`
;;; calls in every module-specific suite.
(def agentic-ai-lab-source-admission-observability-profile-prototype
  (.o (source-admission-observability-profile? #t)
      (identity 'source-admission/default)
      (owner 'agentic-ai-lab)
      (module 'all)
      (emit-summary? #t)
      (emit-diagnostics? #t)))

(def (agentic-ai-lab-source-admission-observability-profile? value)
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

(def agentic-ai-lab-default-source-admission-observability-profile
  (.o (:: @ agentic-ai-lab-source-admission-observability-profile-prototype)))

(def (agentic-ai-lab-observe-source-admission! profile receipt)
  (unless (agentic-ai-lab-source-admission-observability-profile? profile)
    (error "invalid source-admission observability profile" profile))
  (when (.ref profile 'emit-summary?)
    (yuanxu-write-observation-line!
     "[agentic-ai-lab-observability] phase=source-scanned profile=%a owner=%a module=%a files=%a observations=%a diagnostics=%a preparedGraphElapsedUs=%a policyElapsedUs=%a elapsedUs=%a"
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
    (yuanxu-write-observation-line!
     "[agentic-ai-lab-observability] phase=source-diagnostics profile=%a owner=%a module=%a diagnostics=%a"
     (.ref profile 'identity)
     (.ref profile 'owner)
     (.ref profile 'module)
     (.ref receipt 'diagnostics)))
  receipt)

(def (agentic-ai-lab-source-admission-slot name value)
  (cons name ($constant-slot-spec value)))

(def (agentic-ai-lab-source-admission-phase thunk)
  (let (started-at (monotonic-micros))
    (let (result (thunk))
      (values result
              (duration-micros started-at (monotonic-micros))))))

(def (agentic-ai-lab-source-admission-prepared-sources root entries)
  (let (previous-directory (current-directory))
    (dynamic-wind
      (lambda () (current-directory root))
      (lambda ()
        (asp-gerbil-scheme-prepared-native-import-closure root entries))
      (lambda () (current-directory previous-directory)))))

;;; Fold observations as each file is read.  The admission receipt needs only
;;; counts and diagnostics, so successful observation rows are never retained.
(def (agentic-ai-lab-source-admission-scan root sources)
  (foldl
   (lambda (source state)
     (let (path (path-expand source root))
       (foldl
        (lambda (observation inner-state)
          (cons (+ (car inner-state) 1)
                (if (yuanxu-poo-slot-authoring-observation-ok? observation)
                  (cdr inner-state)
                  (cons observation (cdr inner-state)))))
        state
        (yuanxu-poo-slot-authoring-file-observations
         (string->symbol path) path))))
   (cons 0 [])
   sources))

;; agentic-ai-lab-source-admission
;;   : (-> Path [Path] POOObject)
;;   | contract: observe exactly the Gerbil-native import closure of entries
;;   | result: a bounded POO receipt with no retained successful source rows
(def (agentic-ai-lab-source-admission root entries)
  (let* ((normalized-root (path-normalize (path-expand root)))
         (started-at (monotonic-micros)))
    (let-values (((sources prepared-graph-elapsed-us)
                  (agentic-ai-lab-source-admission-phase
                   (lambda ()
                     (list-sort
                      string<?
                      (agentic-ai-lab-source-admission-prepared-sources
                       normalized-root entries))))))
      (let-values (((scan-result policy-elapsed-us)
                    (agentic-ai-lab-source-admission-phase
                     (lambda ()
                       (agentic-ai-lab-source-admission-scan
                        normalized-root sources)))))
        (let (diagnostics (reverse (cdr scan-result)))
          (make-object
           slots:
           (list
            (agentic-ai-lab-source-admission-slot
             'kind 'agentic-ai-lab-source-admission)
            (agentic-ai-lab-source-admission-slot 'root normalized-root)
            (agentic-ai-lab-source-admission-slot 'file-count (length sources))
            (agentic-ai-lab-source-admission-slot
             'observation-count (car scan-result))
            (agentic-ai-lab-source-admission-slot 'diagnostics diagnostics)
            (agentic-ai-lab-source-admission-slot
             'diagnostic-count (length diagnostics))
            (agentic-ai-lab-source-admission-slot
             'prepared-graph-elapsed-us prepared-graph-elapsed-us)
            (agentic-ai-lab-source-admission-slot
             'authoring-policy-elapsed-us policy-elapsed-us)
            (agentic-ai-lab-source-admission-slot
             'elapsed-us
             (duration-micros started-at (monotonic-micros)))
            (agentic-ai-lab-source-admission-slot
             'admitted? (null? diagnostics))
            (agentic-ai-lab-source-admission-slot 'runtime-executed? #f))))))))
