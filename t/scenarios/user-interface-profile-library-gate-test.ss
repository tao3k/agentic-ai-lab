;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: user-interface profile library gate tests.
;;; Invariant: public reusable profiles must carry test and Lean proof status.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        :yuanxu/module-system/selection/objects
        :yuanxu/profile-composition/user-profile
        :yuanxu/profile-composition/gate)


(export user-interface-profile-library-gate-test)

;; : (-> Unit PooUserProfile)
(def gate-test-user-profile
  (yuanxuUserProfile
   'developer
   '()
   (yuanxu-settings
    surface: "agentic-ai-lab"
    profile: "developer")
   '(surface profile)))

;; : (-> Unit PooUserProfile)
(def gate-test-custom-profile
  (yuanxuUserProfile
   'custom-developer
   '()
   (yuanxu-settings
    surface: "agentic-ai-lab"
    profile: "custom-developer")
   '(surface profile)))

;; : (-> Symbol Alist MaybeValue)
(def (alist-value key entries)
  (cond
   ((null? entries) #f)
   ((equal? key (caar entries)) (cdar entries))
   (else
    (alist-value key (cdr entries)))))

;; : (-> Unit PooUserInterfaceProfileGateReceipt)
(def accepted-profile-receipt
  (yuanxu-user-interface-profile-gate-receipt
   'workspace
   #t
   '(scenario-user-interface-profile-library)
   '(lake-build-user-interface-profile-library)
   '(gxpkg-build-warm-path)
   #t
   #t
   #t
   #t))

;; : (-> Unit PooUserInterfaceProfileGateReceipt)
(def scope-leak-profile-receipt
  (yuanxu-user-interface-profile-gate-receipt
   'workspace
   #f
   '(scenario-user-interface-profile-library)
   '(lake-build-user-interface-profile-library)
   '(gxpkg-build-warm-path)
   #t
   #f
   #t
   #f))

;; : (-> Unit PooUserInterfaceProfileGate)
(def accepted-profile-gate
  (yuanxu-user-interface-profile-gate/receipt
   gate-test-user-profile
   'public
   '(developer-profile-scenario)
   '(PublicProfileHasScenario
     ProfileFactProjectionComplete
     PublicProfileProofStatusKnown
     PublicProfileReusableRequiresDischarge)
   'discharged
   '(user-interface-profile-set-case-test
     user-interface-profile-library-gate-test)
   accepted-profile-receipt
   '((owner . public-interface)
     (source . user-interface-profile-library-gate-test))))

;; : (-> Unit PooUserInterfaceProfileGate)
(def scope-leak-profile-gate
  (yuanxu-user-interface-profile-gate/receipt
   gate-test-custom-profile
   'public
   '(custom-developer-profile-scenario)
   '(PublicProfileHasScenario
     ProfileFactProjectionComplete
     PublicProfileProofStatusKnown
     PublicProfileReusableRequiresDischarge)
   'discharged
   '(user-interface-profile-set-case-test
     user-interface-profile-library-gate-test)
   scope-leak-profile-receipt
   '((owner . community)
     (source . user-interface-profile-library-gate-test)
     (bad-case . scope-leak))))

;; : (-> Unit PooUserInterfaceProfileGate)
(def experimental-profile-gate
  (yuanxu-user-interface-profile-gate
   gate-test-custom-profile
   'experimental
   '(custom-developer-profile-scenario)
   '(PublicProfileHasScenario)
   'experimental
   '()
   '((owner . community)
     (source . user-interface-profile-library-gate-test))))

;; : (-> Unit PooUserProfileSet)
(def gate-test-profile-set
  (yuanxuUserProfileSet 'workspace
                         'developer
                         (list gate-test-user-profile
                               gate-test-custom-profile)))

;; : (-> Unit [PooUserInterfaceProfileGate])
(def gate-test-profile-set-gates
  (list accepted-profile-gate
        experimental-profile-gate))

;; : TestSuite
(def user-interface-profile-library-gate-test
  (test-suite "agentic-ai-lab user-interface profile library gate"
    (yuanxu-test-case "accepts only tested proof-backed public profiles"
      (let* ((gate accepted-profile-gate)
             (facts (yuanxu-user-interface-profile-gate->lean-facts gate)))
        (check-equal? (yuanxu-user-interface-profile-gate? gate) #t)
        (check-equal? (yuanxu-user-interface-profile-gate-profile-name gate)
                      'developer)
        (check-equal? (yuanxu-user-interface-profile-gate-accepted? gate)
                      #t)
        (check-equal?
         (yuanxu-user-interface-profile-lean-fact-contract-complete? facts)
         #t)
        (check-equal? (alist-value
                       'ui.profile/reusable-library-surface
                       facts)
                      #t)
        (check-equal? (alist-value 'ui.profile/proof-status-known facts)
                      #t)
        (check-equal? (alist-value
                       'ui.profile/discharged-required-obligations
                       facts)
                      #t)
        (check-equal? (alist-value 'ui.profile/has-benchmark facts) #t)
        (check-equal? (alist-value 'ui.profile/has-receipt facts) #t)
        (check-equal? (alist-value 'ui.profile/dependency-closed facts) #t)
        (check-equal? (alist-value 'ui.profile/scope-contained facts) #t)
        (check-equal? (alist-value 'ui.profile/observability-clean facts) #t)
        (check-equal? (alist-value
                       'ui.profile/counterexample-rejected
                       facts)
                      #t)))
    (yuanxu-test-case "binds profile-set library surface to per-profile gates"
      (let* ((profile-set gate-test-profile-set)
             (gates gate-test-profile-set-gates)
             (fact-sets (map yuanxu-user-interface-profile-gate->lean-facts
                             gates)))
        (check-equal? (yuanxu-user-profile-set? profile-set) #t)
        (check-equal? (yuanxu-user-profile-set-profile-names profile-set)
                      '(developer custom-developer))
        (check-equal? (yuanxu-user-profile-name
                       (yuanxu-user-profile-set-default-profile profile-set))
                      'developer)
        (check-equal? (map yuanxu-user-interface-profile-gate-profile-name
                            gates)
                      '(developer custom-developer))
        (check-equal? (map yuanxu-user-interface-profile-gate-accepted?
                            gates)
                      '(#t #f))
        (check-equal? (map yuanxu-user-interface-profile-lean-fact-contract-complete?
                            fact-sets)
                      '(#t #t))
        (check-equal? (map (lambda (facts)
                             (alist-value
                              'ui.profile/reusable-library-surface
                              facts))
                           fact-sets)
                      '(#t #f))))
    (yuanxu-test-case "rejects discharged public gates when scope proof fails"
      (let* ((gate scope-leak-profile-gate)
             (facts (yuanxu-user-interface-profile-gate->lean-facts gate)))
        (check-equal? (yuanxu-user-interface-profile-gate-profile-name gate)
                      'custom-developer)
        (check-equal? (yuanxu-user-interface-profile-gate-accepted? gate)
                      #f)
        (check-equal?
         (yuanxu-user-interface-profile-lean-fact-contract-complete? facts)
         #t)
        (check-equal? (alist-value 'ui.profile/public-profile facts) #t)
        (check-equal? (alist-value
                       'ui.profile/discharged-required-obligations
                       facts)
                      #t)
        (check-equal? (alist-value 'ui.profile/scope-contained facts) #f)
        (check-equal? (alist-value
                       'ui.profile/counterexample-rejected
                       facts)
                      #f)
        (check-equal? (alist-value
                       'ui.profile/reusable-library-surface
                       facts)
                      #f)))
    (yuanxu-test-case "keeps experimental profiles out of public reusable surface"
      (let* ((gate experimental-profile-gate)
             (facts (yuanxu-user-interface-profile-gate->lean-facts gate)))
        (check-equal? (yuanxu-user-interface-profile-gate-profile-name gate)
                      'custom-developer)
        (check-equal? (yuanxu-user-interface-profile-gate-accepted? gate)
                      #f)
        (check-equal?
         (yuanxu-user-interface-profile-lean-fact-contract-complete? facts)
         #t)
        (check-equal? (alist-value 'ui.profile/experimental facts) #t)
        (check-equal? (alist-value 'ui.profile/public-profile facts) #f)
        (check-equal? (alist-value 'ui.profile/tested facts) #f)
        (check-equal? (alist-value 'ui.profile/proof-status-known facts) #t)
        (check-equal? (alist-value
                       'ui.profile/reusable-library-surface
                       facts)
                      #f)))))
