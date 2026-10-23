;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: non-mutating module diagnostics within Observability.
;;; Invariant: diagnostics never change activation behavior.

(import :yuanxu/modules/funflow/control-plane/task
        :yuanxu/modules/funflow/control-plane/flow
        :agentic-ai-lab/modules/module-authoring/module-descriptor
        (only-in :yuanxu/utilities/functional
                 yuanxu-stable-duplicates)
        (rename-in :yuanxu/module-system/observability/diagnostics
          (make-yuanxu-module-diagnostic make-agentic-ai-lab-module-diagnostic)
          (make-yuanxu-module-doctor-report make-agentic-ai-lab-module-doctor-report))
        :yuanxu/utilities/final-projection-syntax)

(export yuanxu-module-diagnostic-prototype
        make-agentic-ai-lab-module-diagnostic
        yuanxu-module-diagnostic?
        yuanxu-module-diagnostic-severity
        yuanxu-module-diagnostic-code
        yuanxu-module-diagnostic-target
        yuanxu-module-diagnostic-detail
        agentic-ai-lab-module-diagnostic->alist
        agentic-ai-lab-module-diagnostics
        yuanxu-module-diagnostics-status
        yuanxu-module-doctor-report-prototype
        make-agentic-ai-lab-module-doctor-report
        yuanxu-module-doctor-report?
        yuanxu-module-doctor-report-modules
        yuanxu-module-doctor-report-status
        yuanxu-module-doctor-report-diagnostics
        agentic-ai-lab-module-doctor
        yuanxu-module-doctor-ok?
        agentic-ai-lab-module-doctor-report->alist)

;; : (-> PooModuleDiagnostic Alist)
(defpoo-final-projection
  agentic-ai-lab-module-diagnostic->alist (diagnostic)
  (bindings ())
  (fields ((severity (yuanxu-module-diagnostic-severity diagnostic))
           (code (yuanxu-module-diagnostic-code diagnostic))
           (target (yuanxu-module-diagnostic-target diagnostic))
           (detail (yuanxu-module-diagnostic-detail diagnostic)))))

;;; Boundary: module diagnostic key member predicate is the policy-visible edge
;;; for module-system behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> DiagnosticKey [DiagnosticKey] Boolean)
;;; Boundary: duplicate computation preserves first duplicate owner order.
;;; Intent: doctor remains responsive when downstream overlays repeat template option keys.
;; : (-> [DiagnosticKey] [DiagnosticKey])
(def (agentic-ai-lab-module-duplicate-symbols values)
  (yuanxu-stable-duplicates values))

;;; Boundary: option diagnostics look only at keys, not option payloads.
;; : (-> ModuleOptionAlist [Symbol])
(def (agentic-ai-lab-module-option-keys options)
  (if (null? options)
    '()
    (cons (caar options)
          (agentic-ai-lab-module-option-keys (cdr options)))))

;;; Boundary: task diagnostic projection ignores task payloads.
;; : (-> [PooModuleTaskDescriptor] [Symbol] [Symbol])
(def (agentic-ai-lab-module-task-family-names/rev tasks names-rev)
  (if (null? tasks)
    names-rev
    (agentic-ai-lab-module-task-family-names/rev
     (cdr tasks)
     (cons (task-family-name (car tasks)) names-rev))))

;; : (-> [PooModuleDescriptor] [Symbol])
(def (agentic-ai-lab-module-task-family-names modules)
  (reverse
   (agentic-ai-lab-module-task-family-names/rev
    (agentic-ai-lab-module-all-task-descriptors modules)
    '())))

;;; Boundary: flow diagnostic projection ignores flow payloads.
;; : (-> [PooModuleFlowDescriptor] [Symbol] [Symbol])
(def (agentic-ai-lab-module-flow-declaration-kinds/rev flows kinds-rev)
  (if (null? flows)
    kinds-rev
    (agentic-ai-lab-module-flow-declaration-kinds/rev
     (cdr flows)
     (cons (flow-declaration-kind (car flows)) kinds-rev))))

;; : (-> [PooModuleDescriptor] [Symbol])
(def (agentic-ai-lab-module-flow-declaration-kinds modules)
  (reverse
   (agentic-ai-lab-module-flow-declaration-kinds/rev
    (agentic-ai-lab-module-all-flow-descriptors modules)
    '())))

;;; Boundary: option diagnostic projection ignores option values.
;; : (-> [PooModuleDescriptor] [Symbol])
(def (agentic-ai-lab-module-all-option-keys modules)
  (agentic-ai-lab-module-option-keys (agentic-ai-lab-module-all-options modules)))

;;; Boundary: duplicate detail shape is shared across task/flow/option diagnostics.
;; : (-> Symbol [Symbol] DiagnosticDetail DiagnosticDetail)
(def (agentic-ai-lab-module-duplicate-detail/rev key duplicates details-rev)
  (if (null? duplicates)
    details-rev
    (agentic-ai-lab-module-duplicate-detail/rev
     key
     (cdr duplicates)
     (cons (list (cons key (car duplicates))) details-rev))))

;; : (-> Symbol [Symbol] DiagnosticDetail)
(def (agentic-ai-lab-module-duplicate-detail key duplicates)
  (reverse (agentic-ai-lab-module-duplicate-detail/rev key duplicates '())))

;;; Boundary: empty details suppress diagnostics instead of emitting noise.
;; : (-> Symbol Symbol Symbol DiagnosticDetail [PooModuleDiagnostic])
(def (agentic-ai-lab-module-diagnostic-if-present severity code target detail)
  (if (null? detail)
    '()
    (list (make-agentic-ai-lab-module-diagnostic severity code target detail))))

;;; Boundary: missing import diagnostics reuse activation validation facts.
;; : (-> [PooModuleDescriptor] [PooModuleDiagnostic])
(def (agentic-ai-lab-module-missing-import-diagnostics modules)
  (agentic-ai-lab-module-diagnostic-if-present
   'error
   'missing-module-imports
   'imports
   (agentic-ai-lab-module-missing-imports modules)))

;;; Boundary: duplicate task names remain warnings in this slice.
;; : (-> [PooModuleDescriptor] [PooModuleDiagnostic])
(def (agentic-ai-lab-module-duplicate-task-diagnostics modules)
  (agentic-ai-lab-module-diagnostic-if-present
   'warning
   'duplicate-task-family
   'task-registry
   (agentic-ai-lab-module-duplicate-detail
    'task-family
    (agentic-ai-lab-module-duplicate-symbols
     (agentic-ai-lab-module-task-family-names modules)))))

;;; Boundary: duplicate flow kinds remain warnings in this slice.
;; : (-> [PooModuleDescriptor] [PooModuleDiagnostic])
(def (agentic-ai-lab-module-duplicate-flow-diagnostics modules)
  (agentic-ai-lab-module-diagnostic-if-present
   'warning
   'duplicate-flow-declaration
   'flow-registry
   (agentic-ai-lab-module-duplicate-detail
    'flow-kind
    (agentic-ai-lab-module-duplicate-symbols
     (agentic-ai-lab-module-flow-declaration-kinds modules)))))

;;; Boundary: duplicate option keys remain warnings in this slice.
;; : (-> [PooModuleDescriptor] [PooModuleDiagnostic])
(def (agentic-ai-lab-module-duplicate-option-diagnostics modules)
  (agentic-ai-lab-module-diagnostic-if-present
   'warning
   'duplicate-module-option
   'options
   (agentic-ai-lab-module-duplicate-detail
    'option
    (agentic-ai-lab-module-duplicate-symbols
     (agentic-ai-lab-module-all-option-keys modules)))))

;;; Boundary: empty modules are visible as diagnostics, not activation blockers.
;; : (-> PooModuleDescriptor Boolean)
(def (agentic-ai-lab-module-empty-contribution? module)
  (and (null? (agentic-ai-lab-module-task-descriptors module))
       (null? (agentic-ai-lab-module-flow-descriptors module))))

;;; Boundary: empty-contribution remains warning-only until loader semantics exist.
;; : (-> [PooModuleDescriptor] DiagnosticDetail)
(def (agentic-ai-lab-module-empty-contribution-detail modules)
  (cond
   ((null? modules) '())
   ((agentic-ai-lab-module-empty-contribution? (car modules))
    (cons (list (cons 'module (agentic-ai-lab-module-name (car modules))))
          (agentic-ai-lab-module-empty-contribution-detail (cdr modules))))
   (else
    (agentic-ai-lab-module-empty-contribution-detail (cdr modules)))))

;;; Boundary: empty contribution diagnostics are warning-only.
;; : (-> [PooModuleDescriptor] [PooModuleDiagnostic])
(def (agentic-ai-lab-module-empty-contribution-diagnostics modules)
  (agentic-ai-lab-module-diagnostic-if-present
   'warning
   'empty-module-contribution
   'module
   (agentic-ai-lab-module-empty-contribution-detail modules)))

;;; Boundary: doctor runs over closure so inline imports are visible.
;; : (-> [PooModuleDescriptor] [PooModuleDiagnostic])
(def (agentic-ai-lab-module-diagnostics modules)
  (let (closed-modules (agentic-ai-lab-module-closure modules))
    (append (agentic-ai-lab-module-missing-import-diagnostics closed-modules)
            (agentic-ai-lab-module-duplicate-task-diagnostics closed-modules)
            (agentic-ai-lab-module-duplicate-flow-diagnostics closed-modules)
            (agentic-ai-lab-module-duplicate-option-diagnostics closed-modules)
            (agentic-ai-lab-module-empty-contribution-diagnostics closed-modules))))

;;; Boundary: doctor reports summarize closure health without activation.
;; : (-> [PooModuleDescriptor] PooModuleDoctorReport)
(def (agentic-ai-lab-module-doctor modules)
  (let ((closed-modules (agentic-ai-lab-module-closure modules))
        (diagnostics (agentic-ai-lab-module-diagnostics modules)))
    (make-agentic-ai-lab-module-doctor-report
     (agentic-ai-lab-module-names closed-modules)
     (yuanxu-module-diagnostics-status diagnostics)
     diagnostics)))

;;; Boundary: alist conversion is reserved for CLI/agent presentation edges.
;; : (-> PooModuleDoctorReport Alist)
(defpoo-final-projection
  agentic-ai-lab-module-doctor-report->alist (report)
  (bindings ((diagnostics
              (map agentic-ai-lab-module-diagnostic->alist
                   (yuanxu-module-doctor-report-diagnostics report)))))
  (fields ((modules (yuanxu-module-doctor-report-modules report))
           (status (yuanxu-module-doctor-report-status report))
           (diagnostics diagnostics))))
