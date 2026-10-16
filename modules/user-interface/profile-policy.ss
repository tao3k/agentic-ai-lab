;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: test-time admission policy for module-system profiles.
;;; Invariant: diagnostics are data and never realize descriptors or runtimes.

(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :std/list/list any filter filter-map)
        (only-in :poo-flow/modules/user-interface/module-selection
                 poo-flow-user-module-selection-key)
        (only-in :poo-flow/modules/user-interface/profile-core
                 poo-flow-user-profile-diagnostic-kind
                 poo-flow-user-profile-policy-receipt-kind
                 poo-flow-user-profile-set-policy-receipt-kind
                 poo-flow-user-profile-name
                 poo-flow-user-profile-set-name
                 poo-flow-user-profile-set-default-profile-name
                 poo-flow-user-profile-set-profiles
                 poo-flow-user-profile-set-profile-names
                 poo-flow-user-profile-set-default-profile
                 poo-flow-user-profile-module-bundles
                 poo-flow-user-profile-modules
                 poo-flow-user-profile-settings
                 poo-flow-user-profile-setting-keys)
        (only-in :core/utilities/final-projection-syntax
                 defpoo-final-projection)
        (only-in :core/utilities/functional
                 poo-flow-stable-duplicates))

(export poo-flow-user-profile-policy-admit
        poo-flow-user-profile-set-policy-admit
        poo-flow-user-profile-policy-admitted?
        poo-flow-user-profile-set-policy-admitted?
        poo-flow-user-profile-diagnostics
        poo-flow-user-profile-set-diagnostics
        poo-flow-user-profile-diagnostic->alist)

;; : (-> [PooUserModuleSelection] [Pair])
(def (poo-flow-user-profile-policy-module-keys modules)
  (map poo-flow-user-module-selection-key modules))

;;; User-facing indexes make disabled bundle diagnostics stable and concise.
;; : (-> [[PooUserModuleSelection]] [Integer])
(def (poo-flow-user-profile-empty-bundle-indexes bundles)
  (filter-map
   (lambda (bundle index)
     (and (null? bundle) index))
   bundles
   (iota (length bundles))))

;;; Setting-key validation uses slot introspection instead of `.ref` so policy
;;; can report missing user settings without throwing during presentation.
;; : (-> POOObject Symbol Boolean)
(def (poo-flow-user-settings-key-present? settings key)
  (and (object? settings)
       (.slot? settings key)))

;;; Missing keys are accumulated as data because the user profile can still be
;;; presented even when it is not yet valid for activation.
;; : (-> POOObject [Symbol] [Symbol])
(def (poo-flow-user-missing-setting-keys settings setting-keys)
  (filter (lambda (key)
            (not (poo-flow-user-settings-key-present? settings key)))
          setting-keys))

;;; Profile diagnostics are plain alists so policy receipts stay cheap.
;; : (-> Symbol Symbol Symbol Alist Alist)
(defpoo-final-projection
  poo-flow-user-profile-diagnostic (severity code target detail)
  (bindings ())
  (fields ((kind poo-flow-user-profile-diagnostic-kind)
           (severity severity)
           (code code)
           (target target)
           (detail detail))))

;;; The alist projection is intentionally identity: profile diagnostics are
;;; already presentation-safe facts and should not require object realization.
;; : (-> PooUserProfileDiagnostic Alist)
(def (poo-flow-user-profile-diagnostic->alist diagnostic)
  diagnostic)

;;; Diagnostic access stays alist-based because profile policy output is printed
;;; by downstream tools; wrapping dynamic diagnostic details in POO slots makes
;;; the display path depend on object printer behavior rather than data shape.
;; : (-> PooUserProfileDiagnostic Symbol MaybeValue)
(def (poo-flow-user-profile-diagnostic-ref diagnostic key)
  (let (entry (assq key diagnostic))
    (and entry (cdr entry))))

;;; A profile with no selected modules is actionable: there is no downstream
;;; activation graph to inspect, so policy reports it as an error.
;; : (-> PooUserProfile [PooUserProfileDiagnostic])
(def (poo-flow-user-profile-empty-diagnostics profile)
  (if (null? (poo-flow-user-profile-modules profile))
    (list
     (poo-flow-user-profile-diagnostic
      'error
      'empty-profile
      (poo-flow-user-profile-name profile)
      '((message . "profile selects no modules"))))
    '()))

;;; Disabled conditional bundles are informational, matching the expectation
;;; that user configuration may contain machine- or profile-specific branches.
;; : (-> PooUserProfile [PooUserProfileDiagnostic])
(def (poo-flow-user-profile-empty-bundle-diagnostics profile)
  (let ((indexes
         (poo-flow-user-profile-empty-bundle-indexes
          (poo-flow-user-profile-module-bundles profile))))
    (if (null? indexes)
      '()
      (list
       (poo-flow-user-profile-diagnostic
        'info
        'inactive-module-bundle
        (poo-flow-user-profile-name profile)
        (list (cons 'bundle-indexes indexes)
              (cons 'message
                    "empty bundles are usually disabled conditions")))))))

;;; Duplicate module selections are warnings because later descriptor
;;; realization may still choose a merge policy, but users should see them.
;; : (-> PooUserProfile [PooUserProfileDiagnostic])
(def (poo-flow-user-profile-duplicate-module-diagnostics profile)
  (let ((duplicates
         (poo-flow-stable-duplicates
          (poo-flow-user-profile-policy-module-keys
           (poo-flow-user-profile-modules profile)))))
    (if (null? duplicates)
      '()
      (list
       (poo-flow-user-profile-diagnostic
        'warning
        'duplicate-module-selection
        (poo-flow-user-profile-name profile)
        (list (cons 'module-keys duplicates)))))))

;;; Missing public setting keys are errors: presentation would otherwise need
;;; to read absent slots and fail after the policy phase.
;; : (-> PooUserProfile [PooUserProfileDiagnostic])
(def (poo-flow-user-profile-missing-setting-diagnostics profile)
  (let ((missing
         (poo-flow-user-missing-setting-keys
          (poo-flow-user-profile-settings profile)
          (poo-flow-user-profile-setting-keys profile))))
    (if (null? missing)
      '()
      (list
       (poo-flow-user-profile-diagnostic
        'error
        'missing-setting-key
        (poo-flow-user-profile-name profile)
        (list (cons 'setting-keys missing)))))))

;;; Empty profile registries are errors because no default profile can be
;;; selected for downstream init-style composition.
;; : (-> PooUserProfileSet [PooUserProfileDiagnostic])
(def (poo-flow-user-profile-set-empty-diagnostics profile-set)
  (if (null? (poo-flow-user-profile-set-profiles profile-set))
    (list
     (poo-flow-user-profile-diagnostic
      'error
      'empty-profile-set
      (poo-flow-user-profile-set-name profile-set)
      '((message . "profile set contains no profiles"))))
    '()))

;;; Duplicate profile names make default selection ambiguous, so the registry
;;; policy reports them before any profile is projected into config.
;; : (-> PooUserProfileSet [PooUserProfileDiagnostic])
(def (poo-flow-user-profile-set-duplicate-name-diagnostics profile-set)
  (let ((duplicates
         (poo-flow-stable-duplicates
          (poo-flow-user-profile-set-profile-names profile-set))))
    (if (null? duplicates)
      '()
      (list
       (poo-flow-user-profile-diagnostic
        'error
        'duplicate-profile-name
        (poo-flow-user-profile-set-name profile-set)
        (list (cons 'profile-names duplicates)))))))

;;; Missing defaults are registry errors. This mirrors Doom profile startup:
;;; profile selection is explicit, but the selected profile must exist.
;; : (-> PooUserProfileSet [PooUserProfileDiagnostic])
(def (poo-flow-user-profile-set-missing-default-diagnostics profile-set)
  (if (poo-flow-user-profile-set-default-profile profile-set)
    '()
    (list
     (poo-flow-user-profile-diagnostic
      'error
      'missing-default-profile
      (poo-flow-user-profile-set-name profile-set)
      (list
       (cons 'default-profile
             (poo-flow-user-profile-set-default-profile-name profile-set))
       (cons 'profile-names
             (poo-flow-user-profile-set-profile-names profile-set)))))))

;;; Profile policy checks declaration mistakes before descriptors are realized.
;; : (-> PooUserProfile [PooUserProfileDiagnostic])
(def (poo-flow-user-profile-diagnostics profile)
  (append
   (poo-flow-user-profile-empty-diagnostics profile)
   (poo-flow-user-profile-empty-bundle-diagnostics profile)
   (poo-flow-user-profile-duplicate-module-diagnostics profile)
   (poo-flow-user-profile-missing-setting-diagnostics profile)))

;;; Profile set diagnostics validate the registry layer separately from each
;;; profile's module/settings declaration.
;; : (-> PooUserProfileSet [PooUserProfileDiagnostic])
(def (poo-flow-user-profile-set-diagnostics profile-set)
  (append
   (poo-flow-user-profile-set-empty-diagnostics profile-set)
   (poo-flow-user-profile-set-duplicate-name-diagnostics profile-set)
   (poo-flow-user-profile-set-missing-default-diagnostics profile-set)))

;;; Severity scanning is deliberately independent of diagnostic count: info
;;; diagnostics should remain visible without turning the profile unhealthy.
;; : (-> Symbol [PooUserProfileDiagnostic] Boolean)
(def (poo-flow-user-profile-diagnostics-has-severity? severity diagnostics)
  (any (lambda (diagnostic)
         (eq? severity
              (poo-flow-user-profile-diagnostic-ref diagnostic 'severity)))
       diagnostics))

;;; Status treats inactive conditional bundles as informational: only missing
;;; settings or duplicate selections change the actionable policy state.
;; : (-> [PooUserProfileDiagnostic] Symbol)
(def (poo-flow-user-profile-diagnostics-status diagnostics)
  (cond
   ((poo-flow-user-profile-diagnostics-has-severity? 'error diagnostics) 'error)
   ((poo-flow-user-profile-diagnostics-has-severity? 'warning diagnostics) 'warning)
   (else 'ok)))

;;; Test-time policy validates a profile before descriptor realization or
;;; runtime activation and returns a POO-native admission receipt.
;; : (-> PooUserProfile POOObject)
(def (poo-flow-user-profile-policy-admit profile)
  (let* ((diagnostics (poo-flow-user-profile-diagnostics profile))
         (status (poo-flow-user-profile-diagnostics-status diagnostics)))
    (.o kind: poo-flow-user-profile-policy-receipt-kind
        profile-name: (poo-flow-user-profile-name profile)
        policy-status: status
        admitted?: (eq? status 'ok)
        diagnostic-count: (length diagnostics)
        profile-diagnostics: diagnostics
        module-keys:
        (poo-flow-user-profile-policy-module-keys
         (poo-flow-user-profile-modules profile))
        setting-keys: (poo-flow-user-profile-setting-keys profile)
        descriptor-realized?: #f
        runtime-executed: #f)))

;;; Profile-set policy is a pure declaration receipt. It does not load files,
;;; mutate the environment, or synchronize packages.
;; : (-> PooUserProfileSet POOObject)
(def (poo-flow-user-profile-set-policy-admit profile-set)
  (let* ((diagnostics (poo-flow-user-profile-set-diagnostics profile-set))
         (status (poo-flow-user-profile-diagnostics-status diagnostics)))
    (.o kind: poo-flow-user-profile-set-policy-receipt-kind
        profile-set-name: (poo-flow-user-profile-set-name profile-set)
        default-profile-name:
        (poo-flow-user-profile-set-default-profile-name profile-set)
        profile-names: (poo-flow-user-profile-set-profile-names profile-set)
        policy-status: status
        admitted?: (eq? status 'ok)
        diagnostic-count: (length diagnostics)
        profile-diagnostics: diagnostics
        descriptor-realized?: #f
        runtime-executed: #f)))

;;; Admission predicates inspect policy receipts without presentation or CLI.
;; : (-> PooUserProfilePolicyReceipt Boolean)
(def (poo-flow-user-profile-policy-admitted? receipt)
  (.ref receipt 'admitted?))

;; : (-> PooUserProfileSetPolicyReceipt Boolean)
(def (poo-flow-user-profile-set-policy-admitted? receipt)
  (.ref receipt 'admitted?))
