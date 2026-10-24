;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: tests verify maintained root declaration cases.
;;; Invariant: cases are downstream declarations and report data, never runtime work.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check
                 check-eq?
                 check-equal?
                 check-false
                 check-not-equal?
                 check-output
                 check-true
                 test-error
                 test-suite)
        (only-in :clan/poo/object .ref)
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-user-config-presentation-kind
                 yuanxu-user-config?)
        (only-in :agentic-ai-lab/modules/workflow/scenario/configuration/declaration-case
                 agenticAiLabRootDeveloperDeclarationCase
                 agentic-ai-lab-declaration-case?
                 agentic-ai-lab-declaration-case-name
                 agentic-ai-lab-declaration-case-case-file
                 agentic-ai-lab-declaration-case-init-file
                 agentic-ai-lab-declaration-case-custom-module-file
                 agentic-ai-lab-declaration-case-config
                 agentic-ai-lab-declaration-case-presentation
                 agentic-ai-lab-declaration-case-expected-setting-keys
                 agentic-ai-lab-declaration-case-expected-module-keys
                 agentic-ai-lab-declaration-case-expected-trace-stages
                 agentic-ai-lab-declaration-case-alist-value
                 agentic-ai-lab-declaration-case-trace-stages
                 agentic-ai-lab-declaration-case-trace-safe?
                 agentic-ai-lab-declaration-case-presentation-matches?)
        (only-in :agentic-ai-lab/modules/workflow/scenario/configuration/root-profile
                 agenticAiLabRootConfig)
        (only-in :agentic-ai-lab/user-interface/init
                 yuanxu-user-module-bundles))

(export declaration-case-test)

;; : (-> UserInterfaceEntry Alist MaybeValue)
;; : (-> Unit POOObject)
(def (root-developer-case)
  (agenticAiLabRootDeveloperDeclarationCase
   (agenticAiLabRootConfig yuanxu-user-module-bundles)))

;; : (-> [Alist] Pair MaybeAlist)
(def (agentic-ai-lab-declaration-case-find-entry entries key)
  (cond
   ((null? entries) #f)
   ((equal? (agentic-ai-lab-declaration-case-alist-value 'key (car entries)) key)
    (car entries))
   (else
    (agentic-ai-lab-declaration-case-find-entry (cdr entries) key))))

;; : (-> Unit TestSuite)
;;; This suite keeps downstream declaration cases declarative while the
;;; upstream module system owns validation.
(def declaration-case-test
  (test-suite "agentic-ai-lab declaration cases"
    (yuanxu-test-case "keeps developer case as an explicit root declaration contract"
      (let* ((case-object (root-developer-case))
             (presentation
              (agentic-ai-lab-declaration-case-presentation case-object)))
        (check-equal? (agentic-ai-lab-declaration-case? case-object) #t)
        (check-equal? (agentic-ai-lab-declaration-case-name case-object)
                      'developer)
        (check-equal? (agentic-ai-lab-declaration-case-case-file case-object)
                      "modules/workflow/scenario/configuration/declaration-case.ss")
        (check-equal? (agentic-ai-lab-declaration-case-init-file case-object)
                      "user-interface/init.ss")
        (check-equal? (agentic-ai-lab-declaration-case-custom-module-file
                       case-object)
                      "user-interface/custom/my-module/interface.ss")
        (check-equal? (.ref case-object 'declaration-owned?) #t)
        (check-equal? (.ref case-object 'declarative-only?) #t)
        (check-equal? (.ref case-object 'runtime-owner) "marlin-agent-core")
        (check-equal? (.ref case-object 'descriptor-realized?) #f)
        (check-equal? (.ref case-object 'runtime-executed) #f)
        (check-equal? (yuanxu-user-config?
                       (agentic-ai-lab-declaration-case-config case-object))
                      #t)
        (check-equal? (.ref presentation 'kind)
                      yuanxu-user-config-presentation-kind)))
    (yuanxu-test-case "presents selected modules and custom entrypoint from the case"
      (let* ((case-object (root-developer-case))
             (presentation
              (agentic-ai-lab-declaration-case-presentation case-object))
             (modules (.ref presentation 'modules))
             (custom-module
              (agentic-ai-lab-declaration-case-find-entry
               modules
               '(custom . my-module)))
             (feature-facts (.ref presentation 'feature-facts))
             (custom-fact
              (agentic-ai-lab-declaration-case-find-entry
               feature-facts
               '(custom . my-module)))
             (cicd-intent (car (.ref presentation 'cicd-intents))))
        (check-equal?
         (.ref presentation 'module-count)
         (length
          (agentic-ai-lab-declaration-case-expected-module-keys case-object)))
        (check-equal? (.ref presentation 'module-keys)
                      (agentic-ai-lab-declaration-case-expected-module-keys
                       case-object))
        (check-equal? (.ref presentation 'setting-keys)
                      (agentic-ai-lab-declaration-case-expected-setting-keys
                       case-object))
        (check-equal? (agentic-ai-lab-declaration-case-alist-value
                       'key
                       custom-module)
                      '(custom . my-module))
        (check-equal? (agentic-ai-lab-declaration-case-alist-value
                       'entrypoint
                       custom-module)
                      "./custom/my-module/interface.ss")
        (check-equal? (agentic-ai-lab-declaration-case-alist-value
                       'flags
                       custom-module)
                      '(+private +doctor))
        (check-equal? (agentic-ai-lab-declaration-case-alist-value
                       'declaration-index
                       custom-fact)
                      7)
        (check-equal? (agentic-ai-lab-declaration-case-alist-value
                       'declaration-phase
                       custom-fact)
                      'init-selection)
        (check-equal? (agentic-ai-lab-declaration-case-alist-value
                       'package-management?
                       custom-fact)
                      #f)
        (check-equal? (agentic-ai-lab-declaration-case-alist-value
                       'dependency-installation?
                       custom-fact)
                      #f)
        (check-equal? (agentic-ai-lab-declaration-case-alist-value
                       'descriptor-realized?
                       custom-fact)
                      #f)
        (check-equal? (agentic-ai-lab-declaration-case-alist-value
                       'loader-executed?
                       custom-fact)
                      #f)
        (check-equal? (agentic-ai-lab-declaration-case-alist-value
                       'feature
                       cicd-intent)
                      '+cicd)
        (check-equal? (agentic-ai-lab-declaration-case-alist-value
                       'runtime-handoff
                       cicd-intent)
                      'runtime-command-manifest)
        (check-equal? (agentic-ai-lab-declaration-case-alist-value
                       'runtime-owner
                       cicd-intent)
                      "marlin-agent-core")
        (check-equal? (agentic-ai-lab-declaration-case-alist-value
                       'runtime-executed
                       cicd-intent)
                      #f)
        (check-equal? (.ref presentation 'loop-engine-intent-count) 0)
        (check-equal? (.ref presentation 'loop-engine-intents) '())))
    (yuanxu-test-case "exposes trace observability for the maintained case"
      (let* ((case-object (root-developer-case))
             (presentation
              (agentic-ai-lab-declaration-case-presentation case-object))
             (trace (.ref presentation 'presentation-trace)))
        (check-equal? (agentic-ai-lab-declaration-case-trace-stages trace)
                      (agentic-ai-lab-declaration-case-expected-trace-stages
                       case-object))
        (check-equal? (agentic-ai-lab-declaration-case-trace-safe? case-object)
                      #t)
        (check-equal? (agentic-ai-lab-declaration-case-presentation-matches?
                       case-object)
                      #t)
        (check-equal? (.ref presentation 'descriptor-realized?) #f)
        (check-equal? (.ref presentation 'runtime-executed) #f)))))
