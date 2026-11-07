;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: shared fixtures for root user-interface tests.
;;; Invariant: fixtures are declarative data and never realize descriptors.

(import (only-in :clan/poo/object .o .ref)
        :yuanxu/module-system/selection/objects
        (only-in :yuanxu/module-system/selection/syntax
                 yuanxu-modules!)
        :agentic-ai-lab/modules/loop-engine/config
        :yuanxu/profile-composition/user-profile
        :agentic-ai-lab/modules/workflow/profiles/kernel/interface)

(export test-yuanxu-user-module-bundles
        test-agentic-ai-lab-user-modules
        test-agentic-ai-lab-user-custom-module-bundles
        test-agentic-ai-lab-user-custom-profile
        test-agentic-ai-lab-user-profile
        test-agentic-ai-lab-user-broken-profile
        test-agentic-ai-lab-user-profile-set
        test-agentic-ai-lab-user-broken-profile-set
        test-agentic-ai-lab-user-settings
        test-agentic-ai-lab-user-config
        alist-value
        diagnostic-code-member?)

;; : (-> Unit [[PooUserModuleSelection]])
(def test-yuanxu-user-module-bundles
  (yuanxu-user-module-bundles-extend
   agentic-ai-lab-kernel-profile-module-bundles
   (list
    (agentic-ai-lab-loop-engine-configs
     (.def (test-loop @ loop-engine-use-case name)
       name: 'test-loop)

     (.def (test-loop-governor @ loop-engine-governor capabilities)
       capabilities: '(+strategy +policy))

     (.def (test-loop-judges @ loop-engine-agent-judges
                             auditor verifier governor)
       auditor: 'repo-audit-agent
       verifier: 'repo-verifier-agent
       governor: 'repo-governor)

     (.def (test-loop-human-audit @ loop-engine-human-audit actions)
       actions: '(+approval +changes-requested))

     (.def (test-loop-runtime @ loop-engine-runtime capabilities)
       capabilities: '(+manifest-handoff))

     (.def (test-loop-profile @ loop-engine-profile
                              use-case governor agent-judges
                              human-audit runtime)
       use-case: test-loop
       governor: test-loop-governor
       agent-judges: test-loop-judges
       human-audit: test-loop-human-audit
       runtime: test-loop-runtime)))))

;; : (-> Unit [PooUserModuleSelection])
(def test-agentic-ai-lab-user-modules
  (yuanxu-user-module-bundles->modules test-yuanxu-user-module-bundles))

;; : (-> Unit [[PooUserModuleSelection]])
(def test-agentic-ai-lab-user-custom-module-bundles
  (yuanxu-modules!
   :custom
   (my-module @ "./custom/my-module" +private +doctor)))

;; : (-> Unit PooUserProfile)
(def test-agentic-ai-lab-user-custom-profile
  (yuanxuUserProfileExtend
   'custom-developer
   agentic-ai-lab-kernel-profile
   test-agentic-ai-lab-user-custom-module-bundles))

;; : (-> Unit PooUserProfile)
(def test-agentic-ai-lab-user-profile
  (yuanxuUserProfile
   'developer
   test-yuanxu-user-module-bundles
   (.o (:: @ (yuanxuDefaultUserSettings 'developer)) surface: "agentic-ai-lab")
   yuanxu-default-user-setting-keys))

;; : (-> Unit PooUserProfile)
(def test-agentic-ai-lab-user-broken-profile
  (yuanxuUserProfile 'broken (list (yuanxu-user-module-bundle
     (flow workflow +typed-receipts)
     (flow workflow +duplicate)) (yuanxu-user-module-when #f
     (sandbox cubeSandbox +doctor))) (yuanxu-settings surface: "agentic-ai-lab") '(surface missing-key)))

;; : (-> Unit PooUserProfileSet)
(def test-agentic-ai-lab-user-profile-set
  (yuanxuUserProfileSet 'workspace 'developer (list test-agentic-ai-lab-user-profile test-agentic-ai-lab-user-custom-profile)))

;; : (-> Unit PooUserProfileSet)
(def test-agentic-ai-lab-user-broken-profile-set
  (yuanxuUserProfileSet 'broken-workspace 'missing (list test-agentic-ai-lab-user-profile test-agentic-ai-lab-user-profile)))

;; : (-> Unit POOObject)
(def test-agentic-ai-lab-user-settings
  (.ref test-agentic-ai-lab-user-profile 'user-settings))

;; : (-> Unit PooUserConfig)
(def test-agentic-ai-lab-user-config
  (yuanxuUserConfigFromProfile test-agentic-ai-lab-user-profile))

;; : (-> UserInterfaceEntry Alist MaybeValue)
(def (alist-value key entries)
  (cond
   ((null? entries) #f)
   ((equal? key (caar entries)) (cdar entries))
   (else
    (alist-value key (cdr entries)))))

;; : (-> Symbol [Alist] Boolean)
(def (diagnostic-code-member? code diagnostics)
  (cond
   ((null? diagnostics) #f)
   ((equal? code (alist-value 'code (car diagnostics))) #t)
   (else
    (diagnostic-code-member? code (cdr diagnostics)))))
