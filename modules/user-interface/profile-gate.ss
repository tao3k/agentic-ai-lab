;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: proof-backed user-interface profile gate objects.
;;; Invariant: public gate data is POO-native; alists appear only as Lean facts.

(import (only-in :clan/poo/object .o .ref object?)
        (only-in :poo-flow/modules/user-interface/profile-core
                 poo-flow-user-profile?
                 poo-flow-user-profile-name))

(export poo-flow-user-interface-profile-gate-kind
        poo-flow-user-interface-profile-gate-receipt-kind
        poo-flow-user-interface-profile-gate-fact-keys
        poo-flow-user-interface-profile-proof-statuses
        poo-flow-user-interface-profile-gate-receipt
        poo-flow-user-interface-profile-gate
        poo-flow-user-interface-profile-gate/receipt
        pooFlowUserInterfaceProfileGateReceipt
        pooFlowUserInterfaceProfileGate
        pooFlowUserInterfaceProfileGateWithReceipt
        poo-flow-user-interface-profile-gate?
        poo-flow-user-interface-profile-gate-receipt?
        poo-flow-user-interface-profile-gate-profile-name
        poo-flow-user-interface-profile-gate-accepted?
        poo-flow-user-interface-profile-gate->lean-facts
        poo-flow-user-interface-profile-lean-fact-contract-complete?)

;;; User-interface profile gates bind reusable profile declarations to scenario
;;; tests and Lean proof status before they become public library surface.
;; poo-flow-user-interface-profile-gate-kind
;;   : PooFlowUserInterfaceProfileGateKind
;;   | contract: stable POO object kind for user-interface profile gates
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       poo-flow-user-interface-profile-gate-kind
;;       ;; => "poo-flow.modules.user-interface.profile-gate.v1"
;;       ```
;;     %
;; : PooFlowUserInterfaceProfileGateKind
(def poo-flow-user-interface-profile-gate-kind
  "poo-flow.modules.user-interface.profile-gate.v1")

;;; Gate receipts keep benchmark, proof, dependency, scope, and observability
;;; evidence as a POO object instead of turning the public path into a JSON or
;;; alist manifest.
;; : PooFlowUserInterfaceProfileGateReceiptKind
(def poo-flow-user-interface-profile-gate-receipt-kind
  "poo-flow.modules.user-interface.profile-gate-receipt.v1")

;;; Proof status stays a closed Scheme vocabulary so generated Lean facts cannot
;;; silently claim an unknown proof state.
;; poo-flow-user-interface-profile-proof-statuses
;;   : PooFlowUserInterfaceProfileProofStatusSet
;;   | contract: accepted proof status vocabulary for reusable UI profiles
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (memq 'discharged poo-flow-user-interface-profile-proof-statuses)
;;       ;; => non-false
;;       ```
;;     %
;; : PooFlowUserInterfaceProfileProofStatusSet
(def poo-flow-user-interface-profile-proof-statuses
  '(discharged open experimental rejected))

;;; These keys are the complete Scheme-to-Lean contract for this gate family.
;; poo-flow-user-interface-profile-gate-fact-keys
;;   : PooFlowUserInterfaceProfileLeanFactKeySet
;;   | contract: complete Scheme-to-Lean fact vocabulary for UI profile gates
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (memq 'ui.profile/reusable-library-surface
;;             poo-flow-user-interface-profile-gate-fact-keys)
;;       ;; => non-false
;;       ```
;;     %
;; : PooFlowUserInterfaceProfileLeanFactKeySet
(def poo-flow-user-interface-profile-gate-fact-keys
  '(ui.profile/public-profile
    ui.profile/in-profile-set
    ui.profile/default-profile
    ui.profile/tested
    ui.profile/has-scenario
    ui.profile/has-benchmark
    ui.profile/has-fact-projection
    ui.profile/mapped-to-lean-obligations
    ui.profile/has-proof-receipt
    ui.profile/proof-status-known
    ui.profile/discharged-required-obligations
    ui.profile/has-receipt
    ui.profile/dependency-closed
    ui.profile/scope-contained
    ui.profile/observability-clean
    ui.profile/counterexample-rejected
    ui.profile/reusable-library-surface
    ui.profile/experimental))

;; : (-> PooUserInterfaceProfileGateSlotValue Boolean)
(def (poo-flow-user-interface-profile-non-empty-list? value)
  (and (list? value) (not (null? value))))

;; : (-> Symbol [Symbol] Boolean)
(def (poo-flow-user-interface-symbol-member? value values)
  (and (symbol? value) (not (not (memq value values)))))

;; : (-> PooUserInterfaceProfileGateReceiptCandidate Boolean)
(def (poo-flow-user-interface-profile-gate-receipt? value)
  (and (object? value)
       (equal? (.ref value 'kind)
               poo-flow-user-interface-profile-gate-receipt-kind)))

;; : (-> PooUserInterfaceProfileGateReceipt Symbol PooUserInterfaceProfileGateReceiptSlotValue)
(def (poo-flow-user-interface-profile-gate-receipt-slot receipt key)
  (.ref receipt key))

;; : (-> PooUserInterfaceProfileGateReceiptCandidate Symbol PooUserInterfaceProfileGateReceiptSlotValue PooUserInterfaceProfileGateReceiptSlotValue)
(def (poo-flow-user-interface-profile-gate-receipt-slot/default receipt
                                                                  key
                                                                  default-value)
  (if (poo-flow-user-interface-profile-gate-receipt? receipt)
    (poo-flow-user-interface-profile-gate-receipt-slot receipt key)
    default-value))

;; poo-flow-user-interface-profile-gate-receipt
;;   : (-> Symbol Boolean [Symbol] [Symbol] [Symbol] Boolean Boolean Boolean Boolean POOObject)
;;   | contract: POO receipt for proof-backed reusable user-interface profiles
;; : (-> Symbol Boolean [Symbol] [Symbol] [Symbol] Boolean Boolean Boolean Boolean POOObject)
(def (poo-flow-user-interface-profile-gate-receipt profile-set-name
                                                   default-profile?
                                                   scenario-benchmarks
                                                   proof-receipts
                                                   observability-receipts
                                                   dependency-closed?
                                                   scope-contained?
                                                   observability-clean?
                                                   counterexample-rejected?)
  (.o kind: poo-flow-user-interface-profile-gate-receipt-kind
      profile-gate-receipt-profile-set-name: profile-set-name
      profile-gate-receipt-default-profile: default-profile?
      profile-gate-receipt-scenario-benchmarks: scenario-benchmarks
      profile-gate-receipt-proof-receipts: proof-receipts
      profile-gate-receipt-observability-receipts: observability-receipts
      profile-gate-receipt-dependency-closed: dependency-closed?
      profile-gate-receipt-scope-contained: scope-contained?
      profile-gate-receipt-observability-clean: observability-clean?
      profile-gate-receipt-counterexample-rejected: counterexample-rejected?))

;; : (-> Symbol Boolean [Symbol] [Symbol] [Symbol] Boolean Boolean Boolean Boolean POOObject)
(def (pooFlowUserInterfaceProfileGateReceipt profile-set-name
                                             default-profile?
                                             scenario-benchmarks
                                             proof-receipts
                                             observability-receipts
                                             dependency-closed?
                                             scope-contained?
                                             observability-clean?
                                             counterexample-rejected?)
  (poo-flow-user-interface-profile-gate-receipt
   profile-set-name
   default-profile?
   scenario-benchmarks
   proof-receipts
   observability-receipts
   dependency-closed?
   scope-contained?
   observability-clean?
   counterexample-rejected?))

;; poo-flow-user-interface-profile-gate
;;   : (-> PooUserProfile Symbol [Symbol] [Symbol] Symbol [Symbol] Alist POOObject)
;;   | contract: constructs a POO-native proof gate for a reusable UI profile
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-user-interface-profile-gate profile
;;                                            'public
;;                                            '(scenario)
;;                                            '(LeanObligation)
;;                                            'discharged
;;                                            '(test-receipt)
;;                                            '())
;;       ;; => POO gate object
;;       ```
;;     %
;; : (-> PooUserProfile Symbol [Symbol] [Symbol] Symbol [Symbol] Alist POOObject)
(def (poo-flow-user-interface-profile-gate profile
                                           status
                                           scenario-refs
                                           lean-obligation-refs
                                           proof-status
                                           test-receipts
                                           metadata)
  (.o kind: poo-flow-user-interface-profile-gate-kind
      profile-gate-name: (if (poo-flow-user-profile? profile)
                           (poo-flow-user-profile-name profile)
                           'unknown-profile)
      profile-gate-status: status
      profile-gate-scenario-refs: scenario-refs
      profile-gate-lean-obligation-refs: lean-obligation-refs
      profile-gate-proof-status: proof-status
      profile-gate-test-receipts: test-receipts
      profile-gate-receipt: #f
      profile-gate-metadata: metadata))

;; poo-flow-user-interface-profile-gate/receipt
;;   : (-> PooUserProfile Symbol [Symbol] [Symbol] Symbol [Symbol] POOObject Alist POOObject)
;;   | contract: constructs a profile gate with POO-native library receipt
;; : (-> PooUserProfile Symbol [Symbol] [Symbol] Symbol [Symbol] POOObject Alist POOObject)
(def (poo-flow-user-interface-profile-gate/receipt profile
                                                   status
                                                   scenario-refs
                                                   lean-obligation-refs
                                                   proof-status
                                                   test-receipts
                                                   receipt
                                                   metadata)
  (.o kind: poo-flow-user-interface-profile-gate-kind
      profile-gate-name: (if (poo-flow-user-profile? profile)
                           (poo-flow-user-profile-name profile)
                           'unknown-profile)
      profile-gate-status: status
      profile-gate-scenario-refs: scenario-refs
      profile-gate-lean-obligation-refs: lean-obligation-refs
      profile-gate-proof-status: proof-status
      profile-gate-test-receipts: test-receipts
      profile-gate-receipt: receipt
      profile-gate-metadata: metadata))

;; pooFlowUserInterfaceProfileGate
;;   : (-> PooUserProfile Symbol [Symbol] [Symbol] Symbol [Symbol] Alist POOObject)
;;   | contract: camel-case alias for public profile gate construction
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (pooFlowUserInterfaceProfileGate profile
;;                                       'experimental
;;                                       '(scenario)
;;                                       '(LeanObligation)
;;                                       'experimental
;;                                       '()
;;                                       '())
;;       ;; => POO gate object
;;       ```
;;     %
;; : (-> PooUserProfile Symbol [Symbol] [Symbol] Symbol [Symbol] Alist POOObject)
(def (pooFlowUserInterfaceProfileGate profile
                                      status
                                      scenario-refs
                                      lean-obligation-refs
                                      proof-status
                                      test-receipts
                                      metadata)
  (poo-flow-user-interface-profile-gate profile
                                        status
                                        scenario-refs
                                        lean-obligation-refs
                                        proof-status
                                        test-receipts
                                        metadata))

;; : (-> PooUserProfile Symbol [Symbol] [Symbol] Symbol [Symbol] POOObject Alist POOObject)
(def (pooFlowUserInterfaceProfileGateWithReceipt profile
                                                 status
                                                 scenario-refs
                                                 lean-obligation-refs
                                                 proof-status
                                                 test-receipts
                                                 receipt
                                                 metadata)
  (poo-flow-user-interface-profile-gate/receipt profile
                                                status
                                                scenario-refs
                                                lean-obligation-refs
                                                proof-status
                                                test-receipts
                                                receipt
                                                metadata))

;; : (-> PooUserInterfaceProfileGate Symbol PooUserInterfaceProfileGateSlotValue)
(def (poo-flow-user-interface-profile-gate-slot gate key)
  (.ref gate key))

;; : (-> PooUserInterfaceProfileGate Symbol)
(def (poo-flow-user-interface-profile-gate-profile-name gate)
  (poo-flow-user-interface-profile-gate-slot gate 'profile-gate-name))

;; poo-flow-user-interface-profile-gate?
;;   : (-> PooUserInterfaceProfileGateCandidate Boolean)
;;   | contract: recognizes POO-native user-interface profile gate objects
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-user-interface-profile-gate? gate)
;;       ;; => #t
;;       ```
;;     %
;; : (-> PooUserInterfaceProfileGateCandidate Boolean)
(def (poo-flow-user-interface-profile-gate? value)
  (and (object? value)
       (equal? (.ref value 'kind)
               poo-flow-user-interface-profile-gate-kind)))

;; poo-flow-user-interface-profile-gate-accepted?
;;   : (-> PooUserInterfaceProfileGate Boolean)
;;   | contract: accepts only public, tested, scenario-backed, discharged gates
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-user-interface-profile-gate-accepted? gate)
;;       ;; => #t only after test receipts and Lean obligations are present
;;       ```
;;     %
;; : (-> PooUserInterfaceProfileGate Boolean)
(def (poo-flow-user-interface-profile-gate-accepted? gate)
  (let* ((status
          (poo-flow-user-interface-profile-gate-slot gate
                                                     'profile-gate-status))
         (scenario-refs
          (poo-flow-user-interface-profile-gate-slot
           gate
           'profile-gate-scenario-refs))
         (lean-obligation-refs
          (poo-flow-user-interface-profile-gate-slot
           gate
           'profile-gate-lean-obligation-refs))
         (proof-status
          (poo-flow-user-interface-profile-gate-slot
           gate
           'profile-gate-proof-status))
         (test-receipts
          (poo-flow-user-interface-profile-gate-slot
           gate
           'profile-gate-test-receipts))
         (receipt
          (poo-flow-user-interface-profile-gate-slot
           gate
           'profile-gate-receipt))
         (scenario-benchmarks
          (poo-flow-user-interface-profile-gate-receipt-slot/default
           receipt
           'profile-gate-receipt-scenario-benchmarks
           '()))
         (proof-receipts
          (poo-flow-user-interface-profile-gate-receipt-slot/default
           receipt
           'profile-gate-receipt-proof-receipts
           '()))
         (dependency-closed?
          (poo-flow-user-interface-profile-gate-receipt-slot/default
           receipt
           'profile-gate-receipt-dependency-closed
           #f))
         (scope-contained?
          (poo-flow-user-interface-profile-gate-receipt-slot/default
           receipt
           'profile-gate-receipt-scope-contained
           #f))
         (observability-clean?
          (poo-flow-user-interface-profile-gate-receipt-slot/default
           receipt
           'profile-gate-receipt-observability-clean
           #f))
         (counterexample-rejected?
          (poo-flow-user-interface-profile-gate-receipt-slot/default
           receipt
           'profile-gate-receipt-counterexample-rejected
           #f)))
    (and (eq? status 'public)
         (poo-flow-user-interface-profile-non-empty-list? test-receipts)
         (poo-flow-user-interface-profile-non-empty-list? scenario-refs)
         (poo-flow-user-interface-profile-non-empty-list? lean-obligation-refs)
         (poo-flow-user-interface-profile-gate-receipt? receipt)
         (poo-flow-user-interface-profile-non-empty-list? scenario-benchmarks)
         (poo-flow-user-interface-profile-non-empty-list? proof-receipts)
         dependency-closed?
         scope-contained?
         observability-clean?
         counterexample-rejected?
         (poo-flow-user-interface-symbol-member?
          proof-status
          poo-flow-user-interface-profile-proof-statuses)
         (eq? proof-status 'discharged))))

;; poo-flow-user-interface-profile-gate->lean-facts
;;   : (-> PooUserInterfaceProfileGate Alist)
;;   | contract: emits final Scheme-to-Lean fact rows at the projection boundary
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-user-interface-profile-gate->lean-facts gate)
;;       ;; => ((ui.profile/public-profile . #t) ...)
;;       ```
;;     %
;; : (-> PooUserInterfaceProfileGate Alist)
(def (poo-flow-user-interface-profile-gate->lean-facts gate)
  (let* ((status
          (poo-flow-user-interface-profile-gate-slot gate
                                                     'profile-gate-status))
         (scenario-refs
          (poo-flow-user-interface-profile-gate-slot
           gate
           'profile-gate-scenario-refs))
         (lean-obligation-refs
          (poo-flow-user-interface-profile-gate-slot
           gate
           'profile-gate-lean-obligation-refs))
         (proof-status
          (poo-flow-user-interface-profile-gate-slot
           gate
           'profile-gate-proof-status))
         (test-receipts
          (poo-flow-user-interface-profile-gate-slot
           gate
           'profile-gate-test-receipts))
         (receipt
          (poo-flow-user-interface-profile-gate-slot
           gate
           'profile-gate-receipt))
         (profile-set-name
          (poo-flow-user-interface-profile-gate-receipt-slot/default
           receipt
           'profile-gate-receipt-profile-set-name
           #f))
         (default-profile?
          (poo-flow-user-interface-profile-gate-receipt-slot/default
           receipt
           'profile-gate-receipt-default-profile
           #f))
         (scenario-benchmarks
          (poo-flow-user-interface-profile-gate-receipt-slot/default
           receipt
           'profile-gate-receipt-scenario-benchmarks
           '()))
         (proof-receipts
          (poo-flow-user-interface-profile-gate-receipt-slot/default
           receipt
           'profile-gate-receipt-proof-receipts
           '()))
         (observability-receipts
          (poo-flow-user-interface-profile-gate-receipt-slot/default
           receipt
           'profile-gate-receipt-observability-receipts
           '()))
         (dependency-closed?
          (poo-flow-user-interface-profile-gate-receipt-slot/default
           receipt
           'profile-gate-receipt-dependency-closed
           #f))
         (scope-contained?
          (poo-flow-user-interface-profile-gate-receipt-slot/default
           receipt
           'profile-gate-receipt-scope-contained
           #f))
         (observability-clean?
          (poo-flow-user-interface-profile-gate-receipt-slot/default
           receipt
           'profile-gate-receipt-observability-clean
           #f))
         (counterexample-rejected?
          (poo-flow-user-interface-profile-gate-receipt-slot/default
           receipt
           'profile-gate-receipt-counterexample-rejected
           #f))
         (public? (eq? status 'public))
         (tested?
          (poo-flow-user-interface-profile-non-empty-list? test-receipts))
         (has-scenario?
          (poo-flow-user-interface-profile-non-empty-list? scenario-refs))
         (mapped?
          (poo-flow-user-interface-profile-non-empty-list?
           lean-obligation-refs))
         (proof-known?
          (poo-flow-user-interface-symbol-member?
           proof-status
           poo-flow-user-interface-profile-proof-statuses))
         (discharged? (eq? proof-status 'discharged)))
    (list
     (cons 'ui.profile/public-profile public?)
     (cons 'ui.profile/in-profile-set (symbol? profile-set-name))
     (cons 'ui.profile/default-profile default-profile?)
     (cons 'ui.profile/tested tested?)
     (cons 'ui.profile/has-scenario has-scenario?)
     (cons 'ui.profile/has-benchmark
           (poo-flow-user-interface-profile-non-empty-list?
            scenario-benchmarks))
     (cons 'ui.profile/has-fact-projection #t)
     (cons 'ui.profile/mapped-to-lean-obligations mapped?)
     (cons 'ui.profile/has-proof-receipt
           (poo-flow-user-interface-profile-non-empty-list?
            proof-receipts))
     (cons 'ui.profile/proof-status-known proof-known?)
     (cons 'ui.profile/discharged-required-obligations discharged?)
     (cons 'ui.profile/has-receipt
           (poo-flow-user-interface-profile-gate-receipt? receipt))
     (cons 'ui.profile/dependency-closed dependency-closed?)
     (cons 'ui.profile/scope-contained scope-contained?)
     (cons 'ui.profile/observability-clean
           (and observability-clean?
                (poo-flow-user-interface-profile-non-empty-list?
                 observability-receipts)))
     (cons 'ui.profile/counterexample-rejected counterexample-rejected?)
     (cons 'ui.profile/reusable-library-surface
           (and public?
                tested?
                has-scenario?
                mapped?
                proof-known?
                discharged?
                (poo-flow-user-interface-profile-gate-receipt? receipt)
                (poo-flow-user-interface-profile-non-empty-list?
                 scenario-benchmarks)
                (poo-flow-user-interface-profile-non-empty-list?
                 proof-receipts)
                dependency-closed?
                scope-contained?
                observability-clean?
                (poo-flow-user-interface-profile-non-empty-list?
                 observability-receipts)
                counterexample-rejected?))
     (cons 'ui.profile/experimental
           (eq? status 'experimental)))))

;; : (forall (v) (-> [(Pair Symbol v)] Boolean))
;; poo-flow-user-interface-profile-lean-fact-contract-complete?
;;   : (-> Alist Boolean)
;;   | contract: validates that projected Lean fact rows match this gate family
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-user-interface-profile-lean-fact-contract-complete? facts)
;;       ;; => #t when every required UI profile fact key is present
;;       ```
;;     %
(def (poo-flow-user-interface-profile-lean-fact-contract-complete? facts)
  (and (andmap (lambda (key)
                 (and (assq key facts) #t))
               poo-flow-user-interface-profile-gate-fact-keys)
       (andmap (lambda (fact)
                 (and (pair? fact)
                      (memq (car fact)
                            poo-flow-user-interface-profile-gate-fact-keys)
                      #t))
               facts)))
