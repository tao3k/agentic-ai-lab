;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: upstream case contracts for downstream declaration practice files.
;;; Invariant: cases consume config declarations; root user-facing files remain declarations only.

(import (only-in :clan/poo/object .o .ref object? object<-alist)
        :agentic-ai-lab/modules/workflow/scenario/configuration/profile-config)

(export agentic-ai-lab-declaration-case-kind
        agentic-ai-lab-declaration-case-default-setting-keys
        agentic-ai-lab-declaration-case-default-module-keys
        agentic-ai-lab-declaration-case-default-trace-stages
        agenticAiLabDeclarationCase
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
        agentic-ai-lab-declaration-case-trace-field-all-equal?
        agentic-ai-lab-declaration-case-trace-safe?
        agentic-ai-lab-declaration-case-presentation-matches?)

;; : (-> Unit AgenticAILabDeclarationCaseKind)
(def agentic-ai-lab-declaration-case-kind
  "agentic-ai-lab.modules.declaration-case.v1")

;; : (-> Unit [Symbol])
(def (agentic-ai-lab-declaration-case-default-setting-keys)
  '(surface
    profile
    flow-mode
    loop-strategy
    sandbox-policy
    sandbox-backends
    mode-lock))

;; : (-> Unit [Pair])
(def (agentic-ai-lab-declaration-case-default-module-keys)
  '((flow . funflow)
    (session . session)
    (loop . governor)
    (sandbox . nono-sandbox)
    (sandbox . cubeSandbox)
    (sandbox . docker-sandbox)
    (flow . loop-engine)
    (custom . my-module)))

;; : (-> Unit [Symbol])
(def (agentic-ai-lab-declaration-case-default-trace-stages)
  '(selected-modules
    feature-facts
    sandbox-profile-derivations
    session-intents
    cicd-intents
    workflow-cicd-pipelines
    workflow-cicd-functional-dags
    workflow-cicd-pipeline-runs
    workflow-cicd-pipeline-results
    workflow-cicd-runtime-readiness
    workflow-cicd-runtime-command-manifest-maps
    workflow-cicd-runtime-command-manifest-summaries
    workflow-cicd-runtime-command-manifest-agreement
    workflow-cicd-marlin-runtime-handoff-abis
    workflow-cicd-receipts
    workflow-cicd-marlin-handoff-receipt-bundle
    loop-engine-intents
    settings))

;; : (-> MaybeValue String Boolean)
(def (agentic-ai-lab-declaration-case-object-kind? value expected-kind)
  (and (object? value)
       (equal? (.ref value 'kind) expected-kind)))

;;; The constructor computes presentation data before constructing the POO
;;; object. This keeps case metadata strict and prevents lazy-slot recursion
;;; between the `config` and `presentation` slots during debugging.
;; agenticAiLabDeclarationCase
;;   : (-> Symbol String String String PooUserConfig [Symbol] [Pair] [Symbol] POOObject)
;;   | contract: wraps a downstream user config in an upstream-owned case object
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agenticAiLabDeclarationCase
;;        'developer
;;        "modules/workflow/scenario/configuration/declaration-case.ss"
;;        "user-interface/init.ss"
;;        "user-interface/custom/my-module/interface.ss"
;;        config
;;        setting-keys
;;        module-keys
;;        trace-stages)
;;       ;; => case object
;;       ```
;;     %
;; : (-> Symbol String String String PooUserConfig [Symbol] [Pair] [Symbol] POOObject)
(def (agenticAiLabDeclarationCase
      name-value
      case-file-path
      init-file-path
      custom-module-file-path
      config-value
      setting-key-list
      expected-module-key-list
      expected-trace-stage-list)
  (let ((presentation-value
         (agenticAiLabUserConfigPresentation config-value setting-key-list)))
    (object<-alist
     (list
      (cons 'kind agentic-ai-lab-declaration-case-kind)
      (cons 'name name-value)
      (cons 'case-file case-file-path)
      (cons 'init-file init-file-path)
      (cons 'custom-module-file custom-module-file-path)
      (cons 'config config-value)
      (cons 'presentation presentation-value)
      (cons 'expected-setting-keys setting-key-list)
      (cons 'expected-module-keys expected-module-key-list)
      (cons 'expected-trace-stages expected-trace-stage-list)
      (cons 'declaration-owned? #t)
      (cons 'declarative-only? #t)
      (cons 'runtime-owner "marlin-agent-core")
      (cons 'descriptor-realized? #f)
      (cons 'runtime-executed #f)))))

;;; This is a maintained template for the root practice interface. The concrete
;;; downstream declarations still live in user-interface/init.ss and custom modules.
;; agenticAiLabRootDeveloperDeclarationCase
;;   : (-> PooUserConfig POOObject)
;;   | contract: builds the developer case from the supplied root config facade
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agenticAiLabRootDeveloperDeclarationCase agentic-ai-lab-user-config)
;;       ;; => root developer case object
;;       ```
;;     %
;; : (-> PooUserConfig POOObject)
(def (agenticAiLabRootDeveloperDeclarationCase config)
  (agenticAiLabDeclarationCase
   'developer
   "modules/workflow/scenario/configuration/declaration-case.ss"
   "user-interface/init.ss"
   "user-interface/custom/my-module/interface.ss"
   config
   (agentic-ai-lab-declaration-case-default-setting-keys)
   (agentic-ai-lab-declaration-case-default-module-keys)
   (agentic-ai-lab-declaration-case-default-trace-stages)))

;; : (-> MaybeValue Boolean)
(def (agentic-ai-lab-declaration-case? value)
  (agentic-ai-lab-declaration-case-object-kind?
   value
   agentic-ai-lab-declaration-case-kind))

;; : (-> POOObject Symbol)
(def (agentic-ai-lab-declaration-case-name case-object)
  (.ref case-object 'name))

;; : (-> POOObject String)
(def (agentic-ai-lab-declaration-case-case-file case-object)
  (.ref case-object 'case-file))

;; : (-> POOObject String)
(def (agentic-ai-lab-declaration-case-init-file case-object)
  (.ref case-object 'init-file))

;; : (-> POOObject String)
(def (agentic-ai-lab-declaration-case-custom-module-file case-object)
  (.ref case-object 'custom-module-file))

;; : (-> POOObject PooUserConfig)
(def (agentic-ai-lab-declaration-case-config case-object)
  (.ref case-object 'config))

;; : (-> POOObject POOObject)
(def (agentic-ai-lab-declaration-case-presentation case-object)
  (.ref case-object 'presentation))

;; : (-> POOObject [Symbol])
(def (agentic-ai-lab-declaration-case-expected-setting-keys case-object)
  (.ref case-object 'expected-setting-keys))

;; : (-> POOObject [Pair])
(def (agentic-ai-lab-declaration-case-expected-module-keys case-object)
  (.ref case-object 'expected-module-keys))

;; : (-> POOObject [Symbol])
(def (agentic-ai-lab-declaration-case-expected-trace-stages case-object)
  (.ref case-object 'expected-trace-stages))

;;; Boundary: declaration case alist value is the policy-visible edge for
;;; module-system behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> Symbol Alist MaybeValue)
(def (agentic-ai-lab-declaration-case-alist-value key entries)
  (cond
   ((null? entries) #f)
   ((equal? key (caar entries)) (cdar entries))
   (else
    (agentic-ai-lab-declaration-case-alist-value key (cdr entries)))))

;; agentic-ai-lab-declaration-case-trace-stages
;;   : (-> [Alist] [Symbol])
;;   | doc m%
;;       Project trace rows into their stage sequence in presentation order.
;;
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-declaration-case-trace-stages trace-rows)
;;       ;; => stage-symbols
;;       ```
;;     %
;; : (-> [Alist] [Symbol] [Symbol])
(def (agentic-ai-lab-declaration-case-trace-stages/rev trace stages-rev)
  (if (null? trace)
    stages-rev
    (agentic-ai-lab-declaration-case-trace-stages/rev
     (cdr trace)
     (cons (agentic-ai-lab-declaration-case-alist-value 'stage (car trace))
           stages-rev))))

;; : (-> [Alist] [Symbol])
(def (agentic-ai-lab-declaration-case-trace-stages trace)
  (reverse (agentic-ai-lab-declaration-case-trace-stages/rev trace '())))

;;; Boundary: declaration case trace field all equal predicate is the policy-
;;; visible edge for module-system behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> Symbol MaybeValue [Alist] Boolean)
(def (agentic-ai-lab-declaration-case-trace-field-all-equal?
      key
      expected
      trace)
  (cond
   ((null? trace) #t)
   ((equal? expected
            (agentic-ai-lab-declaration-case-alist-value key (car trace)))
    (agentic-ai-lab-declaration-case-trace-field-all-equal?
     key
     expected
     (cdr trace)))
   (else #f)))

;; agentic-ai-lab-declaration-case-trace-rows-safe?
;;   : (-> [Alist] [Symbol] Boolean)
;;   | doc m%
;;       Validate trace rows against expected stages while requiring every row
;;       to stay report-only and descriptor-unrealized.
;;
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-declaration-case-trace-rows-safe? trace expected-stages)
;;       ;; => #t
;;       ```
;;     %
;; : (-> [Alist] [Symbol] Boolean)
(def (agentic-ai-lab-declaration-case-trace-row-safe? row expected-stage)
  (and (equal? (agentic-ai-lab-declaration-case-alist-value 'stage row)
               expected-stage)
       (equal? (agentic-ai-lab-declaration-case-alist-value 'status row)
               'ok)
       (equal? (agentic-ai-lab-declaration-case-alist-value
                'descriptor-realized?
                row)
               #f)
       (equal? (agentic-ai-lab-declaration-case-alist-value
                'runtime-executed
                row)
               #f)))

;; : (-> [Alist] [Symbol] Boolean)
(def (agentic-ai-lab-declaration-case-trace-rows-safe? trace expected-stages)
  (and (= (length trace) (length expected-stages))
       (andmap agentic-ai-lab-declaration-case-trace-row-safe?
               trace
               expected-stages)))

;;; Trace checks are the observability contract for declaration cases: a
;;; failing case should show the projection stage instead of hanging on a slot.
;; : (-> POOObject Boolean)
(def (agentic-ai-lab-declaration-case-trace-safe? case-object)
  (let* ((presentation
          (agentic-ai-lab-declaration-case-presentation case-object))
         (trace (.ref presentation 'presentation-trace)))
    (agentic-ai-lab-declaration-case-trace-rows-safe?
     trace
     (agentic-ai-lab-declaration-case-expected-trace-stages case-object))))

;;; Presentation matching is the test-facing predicate; it proves the root
;;; declaration stayed declarative while still exposing module intent.
;; : (-> POOObject Boolean)
(def (agentic-ai-lab-declaration-case-presentation-matches? case-object)
  (let* ((presentation
          (agentic-ai-lab-declaration-case-presentation case-object))
         (module-keys (.ref presentation 'module-keys))
         (setting-keys (.ref presentation 'setting-keys))
         (descriptor-realized? (.ref presentation 'descriptor-realized?))
         (runtime-executed? (.ref presentation 'runtime-executed)))
    (and (equal? module-keys
                 (agentic-ai-lab-declaration-case-expected-module-keys
                  case-object))
         (equal? setting-keys
                 (agentic-ai-lab-declaration-case-expected-setting-keys
                  case-object))
         (equal? descriptor-realized? #f)
         (equal? runtime-executed? #f)
         (agentic-ai-lab-declaration-case-trace-safe? case-object))))
