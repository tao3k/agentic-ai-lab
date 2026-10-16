;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: inert test fixtures for downstream module-system live cases.
;;; Invariant: no sandbox execution or process work here.
;;; Note: this is not the module-system POO object model. That model is owned by
;;; core/module-system/schema/interface.ss, modules/*/objects.ss, and object-validation.ss.

(import (only-in :clan/poo/object
                 .ref
                 object?
                 make-object
                 $constant-slot-spec)
        (only-in :poo-flow/modules/agent-sandbox/config
                 poo-flow-sandbox-profile-by-name)
        (only-in :core/module-system/selection/objects
                 poo-flow-user-module-selection-flag-entry))

(export pooFlowModuleSystemLiveCase
        pooFlowModuleSystemLiveCaseFromModuleSelection
        poo-flow-module-system-live-case?
        poo-flow-module-system-live-case-name
        poo-flow-module-system-live-case-module-bundle
        poo-flow-module-system-live-case-supers
        poo-flow-module-system-live-case-super-names
        poo-flow-module-system-live-case-config
        poo-flow-module-system-live-case-alist-ref
        poo-flow-module-system-live-case-config-ref
        poo-flow-module-system-live-case-section-ref)

;;; Slot specs keep live-case objects inert; no accessor or runtime bridge is
;;; installed while downstream declarations are being loaded.
;; : (-> Symbol Value PooLiveCaseSlotSpec)
(def (poo-flow-module-system-live-case-slot key value)
  (cons key ($constant-slot-spec value)))

;;; Boundary: module system live case module profiles is the policy-visible
;;; edge for module-system, object, test harness behavior, keeping validation,
;;; lookup, or projection responsibilities centralized for callers.
;; : (-> [PooUserModuleSelection] [PooSandboxProfile])
(def (poo-flow-module-system-live-case-module-profiles module-bundle)
  (let* ((module-selection
          (if (and (pair? module-bundle) (car module-bundle))
            (car module-bundle)
            (error "live case requires a module bundle")))
         (config-entry
          (poo-flow-user-module-selection-flag-entry module-selection
                                                     ':config)))
    (if (and config-entry (pair? config-entry))
      (cdr config-entry)
      (error "live case module bundle has no :config profiles"))))

;;; Boundary: module system live case profile super is the policy-visible edge
;;; for module-system, object, test harness behavior, keeping validation,
;;; lookup, or projection responsibilities centralized for callers.
;; : (-> [PooSandboxProfile] Symbol PooSandboxProfile)
(def (poo-flow-module-system-live-case-profile-super profiles name)
  (let (profile (poo-flow-sandbox-profile-by-name profiles name))
    (if profile
      profile
      (error "live case inherited profile not found" name))))

;;; Boundary: module system live case profile supers is the policy-visible edge
;;; for module-system, object, test harness behavior, keeping validation,
;;; lookup, or projection responsibilities centralized for callers.
;; : (-> [PooSandboxProfile] [Symbol] [PooSandboxProfile])
(def (poo-flow-module-system-live-case-profile-supers profiles names)
  (if (null? names)
    '()
    (cons (poo-flow-module-system-live-case-profile-super profiles
                                                          (car names))
          (poo-flow-module-system-live-case-profile-supers profiles
                                                           (cdr names)))))

;;; Live-case objects bind user selections, profile inheritance, and config
;;; rows into one POO object so tests exercise the same path as user config.
;; pooFlowModuleSystemLiveCase
;;   : (-> Symbol [PooUserModuleSelection] [Symbol] LiveCaseConfig POOObject)
;;   | contract: constructs inert live-case POO objects for the testing runner
;;   | result: runtime-executed remains #f until src/testing/module-system-live-case.ss starts it
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (pooFlowModuleSystemLiveCase
;;        'current-system-build
;;        module-bundle
;;        '(ci/build)
;;        '((isolation (mode . project-copy))))
;;       ;; => live-case object
;;       ```
;;     %
(def (pooFlowModuleSystemLiveCase name-value
                                   module-bundle-value
                                   super-name-values
                                   config-value)
  (let (super-values
        (poo-flow-module-system-live-case-profile-supers
         (poo-flow-module-system-live-case-module-profiles module-bundle-value)
         super-name-values))
    (make-object
     supers: super-values
     slots: (list
             (poo-flow-module-system-live-case-slot
              'kind
              "poo-flow.testing.module-system-live-case.v1")
             (poo-flow-module-system-live-case-slot 'name name-value)
             (poo-flow-module-system-live-case-slot
              'module-bundle
              module-bundle-value)
             (poo-flow-module-system-live-case-slot 'supers super-values)
             (poo-flow-module-system-live-case-slot
              'super-names
              super-name-values)
             (poo-flow-module-system-live-case-slot 'config config-value)
             (poo-flow-module-system-live-case-slot
              'case-owner
              "src/testing")
             (poo-flow-module-system-live-case-slot
              'framework-owner
              "modules/testing/module-system-live-case.ss")
             (poo-flow-module-system-live-case-slot 'runtime-executed #f)))))

;;; Boundary: module system live case flag value is the policy-visible edge for
;;; module-system, object, test harness behavior, keeping validation, lookup,
;;; or projection responsibilities centralized for callers.
;; : (-> PooUserModuleSelection Symbol Value)
(def (poo-flow-module-system-live-case-flag-value selection flag)
  (let (entry (poo-flow-user-module-selection-flag-entry selection flag))
    (if (and entry (pair? entry))
      (cdr entry)
      (error "live case module selection missing required flag" flag))))

;;; Boundary: module system live case inherits list is the policy-visible edge
;;; for module-system, object, test harness behavior, keeping validation,
;;; lookup, or projection responsibilities centralized for callers.
;; : (-> Value [Symbol])
(def (poo-flow-module-system-live-case-inherits-list value)
  (cond
   ((symbol? value) (list value))
   ((list? value) value)
   (else
    (error "live case :inherits must be a symbol or list of symbols" value))))

;; : (-> PooUserModuleSelection Symbol Symbol LiveCaseConfigSection)
(def (poo-flow-module-system-live-case-config-section selection flag section)
  (cons section
        (poo-flow-module-system-live-case-flag-value selection flag)))

;;; Module-selection live cases reuse the same inert object constructor after
;;; decoding :inherits and config flags from user-facing selection bundles.
;; : (-> Symbol [PooUserModuleSelection] [PooUserModuleSelection] POOObject)
(def (pooFlowModuleSystemLiveCaseFromModuleSelection name-value
                                                      module-bundle-value
                                                      case-bundle-value)
  (let* ((case-selection
          (if (and (pair? case-bundle-value) (car case-bundle-value))
            (car case-bundle-value)
            (error "live case requires a module selection bundle")))
         (super-name-values
          (poo-flow-module-system-live-case-inherits-list
           (poo-flow-module-system-live-case-flag-value case-selection
                                                         ':inherits)))
         (config-value
          (list
           (poo-flow-module-system-live-case-config-section
            case-selection ':isolation 'isolation)
           (poo-flow-module-system-live-case-config-section
            case-selection ':environment 'environment)
           (poo-flow-module-system-live-case-config-section
            case-selection ':command 'command)
           (poo-flow-module-system-live-case-config-section
            case-selection ':nono 'nono))))
    (pooFlowModuleSystemLiveCase name-value
                                  module-bundle-value
                                  super-name-values
                                  config-value)))

;; | PooFlowModuleSystemLiveCaseCandidate = Object
;; : (-> PooFlowModuleSystemLiveCaseCandidate Boolean)
(def (poo-flow-module-system-live-case? value)
  (and (object? value)
       (equal? (.ref value 'kind)
               "poo-flow.testing.module-system-live-case.v1")))

;; : (-> POOObject Symbol)
(def (poo-flow-module-system-live-case-name live-case)
  (.ref live-case 'name))

;; : (-> POOObject [PooUserModuleSelection])
(def (poo-flow-module-system-live-case-module-bundle live-case)
  (.ref live-case 'module-bundle))

;; : (-> POOObject [PooSandboxProfile])
(def (poo-flow-module-system-live-case-supers live-case)
  (.ref live-case 'supers))

;; : (-> POOObject [Symbol])
(def (poo-flow-module-system-live-case-super-names live-case)
  (.ref live-case 'super-names))

;; : (-> POOObject LiveCaseConfig)
(def (poo-flow-module-system-live-case-config live-case)
  (.ref live-case 'config))

;;; Alist lookup is local to live-case config so test objects can inspect
;;; nested declarative clauses without depending on runtime config readers.
;; : (-> Alist Symbol Value Value)
(def (poo-flow-module-system-live-case-alist-ref entries key default)
  (let (entry
        (and (list? entries)
             (poo-flow-module-system-live-case-alist-entry entries key)))
    (if entry
      (poo-flow-module-system-live-case-alist-entry-value entry)
      default)))

;; : (-> Alist Symbol MaybeLiveCaseConfigEntry)
(def (poo-flow-module-system-live-case-alist-entry entries key)
  (assoc key entries))

;; : (-> LiveCaseConfigEntry Value)
(def (poo-flow-module-system-live-case-alist-entry-value entry)
  (cdr entry))

;; : (-> POOObject Symbol Value Value)
(def (poo-flow-module-system-live-case-config-ref live-case key default)
  (poo-flow-module-system-live-case-alist-ref
   (poo-flow-module-system-live-case-config live-case)
   key
   default))

;; : (-> POOObject Symbol Symbol Value Value)
(def (poo-flow-module-system-live-case-section-ref live-case
                                                    section
                                                    key
                                                    default)
  (poo-flow-module-system-live-case-alist-ref
   (poo-flow-module-system-live-case-config-ref live-case section '())
   key
   default))
