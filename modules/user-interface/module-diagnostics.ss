;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: non-mutating module diagnostics within Observability.
;;; Invariant: diagnostics never change activation behavior.

(import :poo-flow/modules/workflow/control-plane/task
        :poo-flow/modules/workflow/control-plane/flow
        :poo-flow/modules/module-authoring/module-descriptor
        (only-in :core/utilities/functional
                 poo-flow-stable-duplicates)
        :core/module-system/observability/diagnostics
        :core/utilities/final-projection-syntax)

(export poo-flow-module-diagnostic-prototype
        make-poo-flow-module-diagnostic
        poo-flow-module-diagnostic?
        poo-flow-module-diagnostic-severity
        poo-flow-module-diagnostic-code
        poo-flow-module-diagnostic-target
        poo-flow-module-diagnostic-detail
        poo-flow-module-diagnostic->alist
        poo-flow-module-diagnostics
        poo-flow-module-diagnostics-status
        poo-flow-module-doctor-report-prototype
        make-poo-flow-module-doctor-report
        poo-flow-module-doctor-report?
        poo-flow-module-doctor-report-modules
        poo-flow-module-doctor-report-status
        poo-flow-module-doctor-report-diagnostics
        poo-flow-module-doctor
        poo-flow-module-doctor-ok?
        poo-flow-module-doctor-report->alist)

;; : (-> PooModuleDiagnostic Alist)
(defpoo-final-projection
  poo-flow-module-diagnostic->alist (diagnostic)
  (bindings ())
  (fields ((severity (poo-flow-module-diagnostic-severity diagnostic))
           (code (poo-flow-module-diagnostic-code diagnostic))
           (target (poo-flow-module-diagnostic-target diagnostic))
           (detail (poo-flow-module-diagnostic-detail diagnostic)))))

;;; Boundary: module diagnostic key member predicate is the policy-visible edge
;;; for module-system behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> DiagnosticKey [DiagnosticKey] Boolean)
;;; Boundary: duplicate computation preserves first duplicate owner order.
;;; Intent: doctor remains responsive when downstream overlays repeat template option keys.
;; : (-> [DiagnosticKey] [DiagnosticKey])
(def (poo-flow-module-duplicate-symbols values)
  (poo-flow-stable-duplicates values))

;;; Boundary: option diagnostics look only at keys, not option payloads.
;; : (-> ModuleOptionAlist [Symbol])
(def (poo-flow-module-option-keys options)
  (if (null? options)
    '()
    (cons (caar options)
          (poo-flow-module-option-keys (cdr options)))))

;;; Boundary: task diagnostic projection ignores task payloads.
;; : (-> [PooModuleTaskDescriptor] [Symbol] [Symbol])
(def (poo-flow-module-task-family-names/rev tasks names-rev)
  (if (null? tasks)
    names-rev
    (poo-flow-module-task-family-names/rev
     (cdr tasks)
     (cons (task-family-name (car tasks)) names-rev))))

;; : (-> [PooModuleDescriptor] [Symbol])
(def (poo-flow-module-task-family-names modules)
  (reverse
   (poo-flow-module-task-family-names/rev
    (poo-flow-module-all-task-descriptors modules)
    '())))

;;; Boundary: flow diagnostic projection ignores flow payloads.
;; : (-> [PooModuleFlowDescriptor] [Symbol] [Symbol])
(def (poo-flow-module-flow-declaration-kinds/rev flows kinds-rev)
  (if (null? flows)
    kinds-rev
    (poo-flow-module-flow-declaration-kinds/rev
     (cdr flows)
     (cons (flow-declaration-kind (car flows)) kinds-rev))))

;; : (-> [PooModuleDescriptor] [Symbol])
(def (poo-flow-module-flow-declaration-kinds modules)
  (reverse
   (poo-flow-module-flow-declaration-kinds/rev
    (poo-flow-module-all-flow-descriptors modules)
    '())))

;;; Boundary: option diagnostic projection ignores option values.
;; : (-> [PooModuleDescriptor] [Symbol])
(def (poo-flow-module-all-option-keys modules)
  (poo-flow-module-option-keys (poo-flow-module-all-options modules)))

;;; Boundary: duplicate detail shape is shared across task/flow/option diagnostics.
;; : (-> Symbol [Symbol] DiagnosticDetail DiagnosticDetail)
(def (poo-flow-module-duplicate-detail/rev key duplicates details-rev)
  (if (null? duplicates)
    details-rev
    (poo-flow-module-duplicate-detail/rev
     key
     (cdr duplicates)
     (cons (list (cons key (car duplicates))) details-rev))))

;; : (-> Symbol [Symbol] DiagnosticDetail)
(def (poo-flow-module-duplicate-detail key duplicates)
  (reverse (poo-flow-module-duplicate-detail/rev key duplicates '())))

;;; Boundary: empty details suppress diagnostics instead of emitting noise.
;; : (-> Symbol Symbol Symbol DiagnosticDetail [PooModuleDiagnostic])
(def (poo-flow-module-diagnostic-if-present severity code target detail)
  (if (null? detail)
    '()
    (list (make-poo-flow-module-diagnostic severity code target detail))))

;;; Boundary: missing import diagnostics reuse activation validation facts.
;; : (-> [PooModuleDescriptor] [PooModuleDiagnostic])
(def (poo-flow-module-missing-import-diagnostics modules)
  (poo-flow-module-diagnostic-if-present
   'error
   'missing-module-imports
   'imports
   (poo-flow-module-missing-imports modules)))

;;; Boundary: duplicate task names remain warnings in this slice.
;; : (-> [PooModuleDescriptor] [PooModuleDiagnostic])
(def (poo-flow-module-duplicate-task-diagnostics modules)
  (poo-flow-module-diagnostic-if-present
   'warning
   'duplicate-task-family
   'task-registry
   (poo-flow-module-duplicate-detail
    'task-family
    (poo-flow-module-duplicate-symbols
     (poo-flow-module-task-family-names modules)))))

;;; Boundary: duplicate flow kinds remain warnings in this slice.
;; : (-> [PooModuleDescriptor] [PooModuleDiagnostic])
(def (poo-flow-module-duplicate-flow-diagnostics modules)
  (poo-flow-module-diagnostic-if-present
   'warning
   'duplicate-flow-declaration
   'flow-registry
   (poo-flow-module-duplicate-detail
    'flow-kind
    (poo-flow-module-duplicate-symbols
     (poo-flow-module-flow-declaration-kinds modules)))))

;;; Boundary: duplicate option keys remain warnings in this slice.
;; : (-> [PooModuleDescriptor] [PooModuleDiagnostic])
(def (poo-flow-module-duplicate-option-diagnostics modules)
  (poo-flow-module-diagnostic-if-present
   'warning
   'duplicate-module-option
   'options
   (poo-flow-module-duplicate-detail
    'option
    (poo-flow-module-duplicate-symbols
     (poo-flow-module-all-option-keys modules)))))

;;; Boundary: empty modules are visible as diagnostics, not activation blockers.
;; : (-> PooModuleDescriptor Boolean)
(def (poo-flow-module-empty-contribution? module)
  (and (null? (poo-flow-module-task-descriptors module))
       (null? (poo-flow-module-flow-descriptors module))))

;;; Boundary: empty-contribution remains warning-only until loader semantics exist.
;; : (-> [PooModuleDescriptor] DiagnosticDetail)
(def (poo-flow-module-empty-contribution-detail modules)
  (cond
   ((null? modules) '())
   ((poo-flow-module-empty-contribution? (car modules))
    (cons (list (cons 'module (poo-flow-module-name (car modules))))
          (poo-flow-module-empty-contribution-detail (cdr modules))))
   (else
    (poo-flow-module-empty-contribution-detail (cdr modules)))))

;;; Boundary: empty contribution diagnostics are warning-only.
;; : (-> [PooModuleDescriptor] [PooModuleDiagnostic])
(def (poo-flow-module-empty-contribution-diagnostics modules)
  (poo-flow-module-diagnostic-if-present
   'warning
   'empty-module-contribution
   'module
   (poo-flow-module-empty-contribution-detail modules)))

;;; Boundary: doctor runs over closure so inline imports are visible.
;; : (-> [PooModuleDescriptor] [PooModuleDiagnostic])
(def (poo-flow-module-diagnostics modules)
  (let (closed-modules (poo-flow-module-closure modules))
    (append (poo-flow-module-missing-import-diagnostics closed-modules)
            (poo-flow-module-duplicate-task-diagnostics closed-modules)
            (poo-flow-module-duplicate-flow-diagnostics closed-modules)
            (poo-flow-module-duplicate-option-diagnostics closed-modules)
            (poo-flow-module-empty-contribution-diagnostics closed-modules))))

;;; Boundary: doctor reports summarize closure health without activation.
;; : (-> [PooModuleDescriptor] PooModuleDoctorReport)
(def (poo-flow-module-doctor modules)
  (let ((closed-modules (poo-flow-module-closure modules))
        (diagnostics (poo-flow-module-diagnostics modules)))
    (make-poo-flow-module-doctor-report
     (poo-flow-module-names closed-modules)
     (poo-flow-module-diagnostics-status diagnostics)
     diagnostics)))

;;; Boundary: alist conversion is reserved for CLI/agent presentation edges.
;; : (-> PooModuleDoctorReport Alist)
(defpoo-final-projection
  poo-flow-module-doctor-report->alist (report)
  (bindings ((diagnostics
              (map poo-flow-module-diagnostic->alist
                   (poo-flow-module-doctor-report-diagnostics report)))))
  (fields ((modules (poo-flow-module-doctor-report-modules report))
           (status (poo-flow-module-doctor-report-status report))
           (diagnostics diagnostics))))
