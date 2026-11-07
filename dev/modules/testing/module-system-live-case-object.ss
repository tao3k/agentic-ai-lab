;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: inert test fixtures for downstream module-system live cases.
;;; Invariant: no sandbox execution or process work here.
;;; Note: this is not the module-system POO object model. That model is owned by
;;; yuanxu/module-system/schema/interface.ss, modules/*/objects.ss, and object-validation.ss.

(import (only-in :clan/poo/object
                 .ref
                 object?
                 make-object
                 $constant-slot-spec)
        (only-in :agentic-ai-lab/modules/agent-sandbox/config
                 agentic-ai-lab-sandbox-profile-by-name)
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-user-module-selection-flag-entry))

(export agenticAiLabModuleSystemLiveCase
        agenticAiLabModuleSystemLiveCaseFromModuleSelection
        agentic-ai-lab-module-system-live-case?
        agentic-ai-lab-module-system-live-case-name
        agentic-ai-lab-module-system-live-case-module-bundle
        agentic-ai-lab-module-system-live-case-supers
        agentic-ai-lab-module-system-live-case-super-names
        agentic-ai-lab-module-system-live-case-config
        agentic-ai-lab-module-system-live-case-alist-ref
        agentic-ai-lab-module-system-live-case-config-ref
        agentic-ai-lab-module-system-live-case-section-ref)

;;; Slot specs keep live-case objects inert; no accessor or runtime bridge is
;;; installed while downstream declarations are being loaded.
;; : (-> Symbol Value PooLiveCaseSlotSpec)
(def (agentic-ai-lab-module-system-live-case-slot key value)
  (cons key ($constant-slot-spec value)))

;;; Boundary: module system live case module profiles is the policy-visible
;;; edge for module-system, object, test harness behavior, keeping validation,
;;; lookup, or projection responsibilities centralized for callers.
;; : (-> [PooUserModuleSelection] [PooSandboxProfile])
(def (agentic-ai-lab-module-system-live-case-module-profiles module-bundle)
  (let* ((module-selection
          (if (and (pair? module-bundle) (car module-bundle))
            (car module-bundle)
            (error "live case requires a module bundle")))
         (config-entry
          (yuanxu-user-module-selection-flag-entry module-selection
                                                     ':config)))
    (if (and config-entry (pair? config-entry))
      (cdr config-entry)
      (error "live case module bundle has no :config profiles"))))

;;; Boundary: module system live case profile super is the policy-visible edge
;;; for module-system, object, test harness behavior, keeping validation,
;;; lookup, or projection responsibilities centralized for callers.
;; : (-> [PooSandboxProfile] Symbol PooSandboxProfile)
(def (agentic-ai-lab-module-system-live-case-profile-super profiles name)
  (let (profile (agentic-ai-lab-sandbox-profile-by-name profiles name))
    (if profile
      profile
      (error "live case inherited profile not found" name))))

;;; Boundary: module system live case profile supers is the policy-visible edge
;;; for module-system, object, test harness behavior, keeping validation,
;;; lookup, or projection responsibilities centralized for callers.
;; : (-> [PooSandboxProfile] [Symbol] [PooSandboxProfile])
(def (agentic-ai-lab-module-system-live-case-profile-supers profiles names)
  (if (null? names)
    '()
    (cons (agentic-ai-lab-module-system-live-case-profile-super profiles
                                                          (car names))
          (agentic-ai-lab-module-system-live-case-profile-supers profiles
                                                           (cdr names)))))

;;; Live-case objects bind user selections, profile inheritance, and config
;;; rows into one POO object so tests exercise the same path as user config.
;; agenticAiLabModuleSystemLiveCase
;;   : (-> Symbol [PooUserModuleSelection] [Symbol] LiveCaseConfig POOObject)
;;   | contract: constructs inert live-case POO objects for the testing runner
;;   | result: runtime-executed remains #f until src/testing/module-system-live-case.ss starts it
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agenticAiLabModuleSystemLiveCase
;;        'current-system-build
;;        module-bundle
;;        '(ci/build)
;;        '((isolation (mode . project-copy))))
;;       ;; => live-case object
;;       ```
;;     %
(def (agenticAiLabModuleSystemLiveCase name-value
                                   module-bundle-value
                                   super-name-values
                                   config-value)
  (let (super-values
        (agentic-ai-lab-module-system-live-case-profile-supers
         (agentic-ai-lab-module-system-live-case-module-profiles module-bundle-value)
         super-name-values))
    (make-object
     supers: super-values
     slots: (list
             (agentic-ai-lab-module-system-live-case-slot
              'kind
              "agentic-ai-lab.testing.module-system-live-case.v1")
             (agentic-ai-lab-module-system-live-case-slot 'name name-value)
             (agentic-ai-lab-module-system-live-case-slot
              'module-bundle
              module-bundle-value)
             (agentic-ai-lab-module-system-live-case-slot 'supers super-values)
             (agentic-ai-lab-module-system-live-case-slot
              'super-names
              super-name-values)
             (agentic-ai-lab-module-system-live-case-slot 'config config-value)
             (agentic-ai-lab-module-system-live-case-slot
              'case-owner
              "src/testing")
             (agentic-ai-lab-module-system-live-case-slot
              'framework-owner
              "dev/modules/testing/module-system-live-case.ss")
             (agentic-ai-lab-module-system-live-case-slot 'runtime-executed #f)))))

;;; Boundary: module system live case flag value is the policy-visible edge for
;;; module-system, object, test harness behavior, keeping validation, lookup,
;;; or projection responsibilities centralized for callers.
;; : (-> PooUserModuleSelection Symbol Value)
(def (agentic-ai-lab-module-system-live-case-flag-value selection flag)
  (let (entry (yuanxu-user-module-selection-flag-entry selection flag))
    (if (and entry (pair? entry))
      (cdr entry)
      (error "live case module selection missing required flag" flag))))

;;; Boundary: module system live case inherits list is the policy-visible edge
;;; for module-system, object, test harness behavior, keeping validation,
;;; lookup, or projection responsibilities centralized for callers.
;; : (-> Value [Symbol])
(def (agentic-ai-lab-module-system-live-case-inherits-list value)
  (cond
   ((symbol? value) (list value))
   ((list? value) value)
   (else
    (error "live case :inherits must be a symbol or list of symbols" value))))

;; : (-> PooUserModuleSelection Symbol Symbol LiveCaseConfigSection)
(def (agentic-ai-lab-module-system-live-case-config-section selection flag section)
  (cons section
        (agentic-ai-lab-module-system-live-case-flag-value selection flag)))

;;; Module-selection live cases reuse the same inert object constructor after
;;; decoding :inherits and config flags from user-facing selection bundles.
;; : (-> Symbol [PooUserModuleSelection] [PooUserModuleSelection] POOObject)
(def (agenticAiLabModuleSystemLiveCaseFromModuleSelection name-value
                                                      module-bundle-value
                                                      case-bundle-value)
  (let* ((case-selection
          (if (and (pair? case-bundle-value) (car case-bundle-value))
            (car case-bundle-value)
            (error "live case requires a module selection bundle")))
         (super-name-values
          (agentic-ai-lab-module-system-live-case-inherits-list
           (agentic-ai-lab-module-system-live-case-flag-value case-selection
                                                         ':inherits)))
         (config-value
          (list
           (agentic-ai-lab-module-system-live-case-config-section
            case-selection ':isolation 'isolation)
           (agentic-ai-lab-module-system-live-case-config-section
            case-selection ':environment 'environment)
           (agentic-ai-lab-module-system-live-case-config-section
            case-selection ':command 'command)
           (agentic-ai-lab-module-system-live-case-config-section
            case-selection ':nono 'nono))))
    (agenticAiLabModuleSystemLiveCase name-value
                                  module-bundle-value
                                  super-name-values
                                  config-value)))

;; | AgenticAILabModuleSystemLiveCaseCandidate = Object
;; : (-> AgenticAILabModuleSystemLiveCaseCandidate Boolean)
(def (agentic-ai-lab-module-system-live-case? value)
  (and (object? value)
       (equal? (.ref value 'kind)
               "agentic-ai-lab.testing.module-system-live-case.v1")))

;; : (-> POOObject Symbol)
(def (agentic-ai-lab-module-system-live-case-name live-case)
  (.ref live-case 'name))

;; : (-> POOObject [PooUserModuleSelection])
(def (agentic-ai-lab-module-system-live-case-module-bundle live-case)
  (.ref live-case 'module-bundle))

;; : (-> POOObject [PooSandboxProfile])
(def (agentic-ai-lab-module-system-live-case-supers live-case)
  (.ref live-case 'supers))

;; : (-> POOObject [Symbol])
(def (agentic-ai-lab-module-system-live-case-super-names live-case)
  (.ref live-case 'super-names))

;; : (-> POOObject LiveCaseConfig)
(def (agentic-ai-lab-module-system-live-case-config live-case)
  (.ref live-case 'config))

;;; Alist lookup is local to live-case config so test objects can inspect
;;; nested declarative clauses without depending on runtime config readers.
;; : (-> Alist Symbol Value Value)
(def (agentic-ai-lab-module-system-live-case-alist-ref entries key default)
  (let (entry
        (and (list? entries)
             (agentic-ai-lab-module-system-live-case-alist-entry entries key)))
    (if entry
      (agentic-ai-lab-module-system-live-case-alist-entry-value entry)
      default)))

;; : (-> Alist Symbol MaybeLiveCaseConfigEntry)
(def (agentic-ai-lab-module-system-live-case-alist-entry entries key)
  (assoc key entries))

;; : (-> LiveCaseConfigEntry Value)
(def (agentic-ai-lab-module-system-live-case-alist-entry-value entry)
  (cdr entry))

;; : (-> POOObject Symbol Value Value)
(def (agentic-ai-lab-module-system-live-case-config-ref live-case key default)
  (agentic-ai-lab-module-system-live-case-alist-ref
   (agentic-ai-lab-module-system-live-case-config live-case)
   key
   default))

;; : (-> POOObject Symbol Symbol Value Value)
(def (agentic-ai-lab-module-system-live-case-section-ref live-case
                                                    section
                                                    key
                                                    default)
  (agentic-ai-lab-module-system-live-case-alist-ref
   (agentic-ai-lab-module-system-live-case-config-ref live-case section '())
   key
   default))
