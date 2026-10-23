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

(defrules agentic-ai-lab-profile-set (default profiles)
  ((_ name (default default-name) (profiles profile ...))
   (.o kind: "yuanxu.modules.user-profile-set.v1"
       profile-set-name: 'name
       default-profile-name: 'default-name
       user-profiles: (list profile ...))))

(defrules agentic-ai-lab-profile (modules settings setting-keys)
  ((_ name (modules module ...)
      (settings setting ...)
      (setting-keys key ...))
   (.o kind: "yuanxu.modules.user-profile.v1"
       profile-name: 'name
       profile-selection-bundles: (list module ...)
       user-settings: (.o setting ...)
       public-setting-keys: '(key ...))))

(defrules yuanxu-user-module-bundle ()
  ((_ (category module feature ...) ...)
   (list
    (yuanxu-user-module-selection 'category
                                    'module
                                    '(feature ...))
    ...)))

(defrules yuanxu-user-module-when ()
  ((_ condition (category module feature ...))
   (if condition
     (list
      (.o kind: "agentic-ai-lab.modules.user-module.v1"
          category: 'category
          module: 'module
          features: '(feature ...)
          module-category: 'category
          module-name: 'module
          module-features: '(feature ...)))
     [])))

(def (yuanxu-user-module-bundles-extend base-bundles extra-bundles)
  (append base-bundles extra-bundles))

(def (yuanxu-user-module-bundles->modules bundles)
  (apply append bundles))

(def yuanxu-default-user-setting-keys
  '(surface profile flow-mode loop-strategy sandbox-policy sandbox-backends mode-lock))

(def (yuanxuDefaultUserSettings profile-name)
  (.o surface: "agentic-ai-lab"
      profile: (symbol->string profile-name)
      flow-mode: 'funflow
      loop-strategy: 'governed
      sandbox-policy: 'module-gated
      sandbox-backends: '(nono cube docker)
      mode-lock: "stable"))

(def (yuanxuUserProfile name module-bundles settings setting-keys)
  (.o kind: "yuanxu.modules.user-profile.v1"
      profile-name: name
      profile-selection-bundles: module-bundles
      user-settings: settings
      public-setting-keys: setting-keys))

(def (yuanxuUserProfileExtend name base-profile module-bundles)
  (yuanxuUserProfile
   name
   (append (.ref base-profile 'profile-selection-bundles) module-bundles)
   (.ref base-profile 'user-settings)
   (.ref base-profile 'public-setting-keys)))

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
   (yuanxuDefaultUserSettings 'developer)
   yuanxu-default-user-setting-keys))

;; : (-> Unit PooUserProfile)
(def test-agentic-ai-lab-user-broken-profile
  (agentic-ai-lab-profile broken
   (modules
    (yuanxu-user-module-bundle
     (flow workflow +typed-receipts)
     (flow workflow +duplicate))
    (yuanxu-user-module-when #f
     (sandbox cubeSandbox +doctor)))
   (settings
    surface: "agentic-ai-lab")
   (setting-keys
    surface
    missing-key)))

;; : (-> Unit PooUserProfileSet)
(def test-agentic-ai-lab-user-profile-set
  (agentic-ai-lab-profile-set workspace
   (default developer)
   (profiles
    test-agentic-ai-lab-user-profile
    test-agentic-ai-lab-user-custom-profile)))

;; : (-> Unit PooUserProfileSet)
(def test-agentic-ai-lab-user-broken-profile-set
  (agentic-ai-lab-profile-set broken-workspace
   (default missing)
   (profiles
    test-agentic-ai-lab-user-profile
    test-agentic-ai-lab-user-profile)))

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
