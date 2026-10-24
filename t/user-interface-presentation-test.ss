;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: tests verify user-interface presentation receipts.
;;; Invariant: presentations stay report-only and never realize descriptors.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        (only-in :agentic-ai-lab/modules/module-authoring/module-interface
                 agentic-ai-lab-brand-group
                 agentic-ai-lab-brand-name)
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-user-config-presentation-kind)
        (only-in :agentic-ai-lab/modules/workflow/scenario/configuration/presentation-config
                 agenticAiLabUserConfigPresentation)
        (only-in :yuanxu/profile-composition/user-profile
                 yuanxu-user-profile-presentation-kind)
        (only-in :agentic-ai-lab/modules/workflow/scenario/configuration/profile-presentation-config
                 agenticAiLabUserProfilePresentation)
        "user-interface-fixtures.ss")

(export user-interface-presentation-test)

;;; Trace stage order is the presentation contract for downstream tooling; the
;;; cases assert order without duplicating the projection implementation.
;; : [Symbol]
(def user-interface-presentation-trace-stages
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

;;; Trace lookup keeps assertions focused on stage names instead of relying on
;;; positional indexes that would hide missing or reordered projection steps.
;; : (-> [Alist] Symbol MaybeAlist)
(def (user-interface-presentation-trace-stage trace stage)
  (cond
   ((null? trace) #f)
   ((equal? (alist-value 'stage (car trace)) stage) (car trace))
   (else
    (user-interface-presentation-trace-stage (cdr trace) stage))))

;;; Config presentation is the broadest receipt surface, covering module
;;; switches, CI/CD handoff rows, loop-engine rows, and ownership boundaries.
;; : (-> Unit TestSuite)
(def (user-interface-config-presentation-test)
  (yuanxu-test-case "presents downstream config without descriptor realization"
      (let* ((presentation
              (agenticAiLabUserConfigPresentation
               test-agentic-ai-lab-user-config
               '(surface
                 profile
                 flow-mode
                 loop-strategy
                 sandbox-policy
                 sandbox-backends
                 mode-lock)))
             (modules (.ref presentation 'modules))
             (feature-facts (.ref presentation 'feature-facts))
             (cicd-intent (car (.ref presentation 'cicd-intents)))
             (loop-engine-intent
              (car (.ref presentation 'loop-engine-intents)))
             (loop-engine-result-contract
              (car (.ref presentation 'loop-engine-result-contracts)))
             (trace (.ref presentation 'presentation-trace))
             (settings (.ref presentation 'settings)))
        (check-equal? (.ref presentation 'kind)
                      yuanxu-user-config-presentation-kind)
        (check-equal? (.ref presentation 'module-count) 7)
        (check-equal? (.ref presentation 'module-keys)
                      '((flow . funflow)
                        (session . session)
                        (loop . governor)
                        (sandbox . nono-sandbox)
                        (sandbox . cubeSandbox)
                        (sandbox . docker-sandbox)
                        (flow . loop-engine)))
        (check-equal? (.ref presentation 'feature-count) 7)
        (check-equal? (.ref presentation 'sandbox-profile-derivation-count)
                      0)
        (check-equal? (.ref presentation 'sandbox-profile-derivations)
                      '())
        (check-equal? (.ref presentation 'session-intent-count) 1)
        (check-equal? (alist-value 'key
                                   (car (.ref presentation
                                             'session-intents)))
                      '(session . session))
        (check-equal? (alist-value 'flags
                                   (car (.ref presentation
                                             'session-intents)))
                      '(+lineage +placement +handoff +graph +transform +doctor))
        (check-equal? (alist-value 'transform-enabled?
                                   (car (.ref presentation
                                             'session-intents)))
                      #t)
        (check-equal? (alist-value 'runtime-executed
                                   (car (.ref presentation
                                             'session-intents)))
                      #f)
        (check-equal? (alist-value 'declaration-index
                                   (car feature-facts))
                      0)
        (check-equal? (alist-value 'declaration-phase
                                   (car feature-facts))
                      'init-selection)
        (check-equal? (alist-value 'key (car feature-facts))
                      '(flow . funflow))
        (check-equal? (alist-value 'dependency-installation?
                                   (car feature-facts))
                      #f)
        (check-equal? (alist-value 'descriptor-realized?
                                   (car feature-facts))
                      #f)
        (check-equal? (.ref presentation 'setting-count) 7)
        (check-equal? (alist-value 'flags (car modules))
                      '(+functional +dag +typed-receipts +runtime-manifest
                        (+cicd
                         (checks +parallel +typed-receipts)
                         (artifacts +export)
                         (release +manual-gate)
                         (webhook +server)
                         (runtime +manifest-handoff))))
        (check-equal? (.ref presentation 'cicd-intent-count) 1)
        (check-equal? (alist-value 'checks cicd-intent)
                      '(+parallel +typed-receipts))
        (check-equal? (alist-value 'runtime-handoff cicd-intent)
                      'runtime-command-manifest)
        (check-equal? (alist-value 'runtime-executed cicd-intent) #f)
        (check-equal? (.ref presentation 'workflow-cicd-pipeline-run-count)
                      0)
        (check-equal? (.ref presentation 'workflow-cicd-pipeline-runs)
                      '())
        (check-equal? (.ref presentation 'workflow-cicd-pipeline-result-count)
                      0)
        (check-equal? (.ref presentation 'workflow-cicd-pipeline-results)
                      '())
        (check-equal? (.ref presentation
                            'workflow-cicd-runtime-command-manifest-agreement-valid?)
                      #t)
        (check-equal? (.ref presentation
                            'workflow-cicd-runtime-command-manifest-agreement-diagnostics)
                      '())
        (check-equal? (.ref presentation
                            'workflow-cicd-marlin-runtime-handoff-abi-count)
                      0)
        (check-equal? (.ref presentation
                            'workflow-cicd-marlin-runtime-handoff-summary-count)
                      0)
        (check-equal? (.ref presentation
                            'workflow-cicd-marlin-runtime-handoff-summaries)
                      '())
        (let ((bundle
               (.ref presentation
                     'workflow-cicd-marlin-handoff-receipt-bundle)))
          (check-equal? (alist-value 'kind bundle)
                        'workflow-cicd-marlin-handoff-receipt-bundle)
          (check-equal? (alist-value 'marlin-runtime-handoff-abi-count bundle)
                        0)
          (check-equal? (alist-value 'runtime-executed bundle) #f))
        (check-equal? (.ref presentation 'loop-engine-intent-count) 1)
        (check-equal? (alist-value 'key loop-engine-intent)
                      '(flow . loop-engine))
        (check-equal? (alist-value 'workflow-owned? loop-engine-intent) #t)
        (check-equal? (alist-value 'governor-derived? loop-engine-intent) #t)
        (check-equal? (alist-value 'governor loop-engine-intent)
                      '(+strategy +policy))
        (check-equal? (alist-value 'agent-judges loop-engine-intent)
                      '((auditor repo-audit-agent)
                        (verifier repo-verifier-agent)
                        (governor repo-governor)))
        (check-equal? (alist-value 'human-audit loop-engine-intent)
                      '(+approval +changes-requested))
        (check-equal? (alist-value 'runtime-handoff loop-engine-intent)
                      'loop-governor-marlin-runtime-manifest)
        (check-equal? (alist-value 'contract loop-engine-result-contract)
                      'agentic-ai-lab.loop-governor.result-contract.v1)
        (check-equal? (alist-value 'valid? loop-engine-result-contract) #t)
        (check-equal? (alist-value 'human-audit loop-engine-result-contract)
                      'agentic-ai-lab.loop-governor.node-result.v1)
        (check-equal? (alist-value 'required-fields
                                   loop-engine-result-contract)
                      '(decision summary evidence))
        (check-equal? (car (.ref presentation 'loop-engine-agent-profiles))
                      (alist-value 'agent-profiles loop-engine-intent))
        (check-equal? (car (.ref presentation
                                  'loop-engine-delegated-operations))
                      (alist-value 'delegated-operation loop-engine-intent))
        (check-equal? (alist-value 'runtime-executed loop-engine-intent) #f)
        (check-equal? (map (lambda (step) (alist-value 'stage step))
                           trace)
                      user-interface-presentation-trace-stages)
        (check-equal? (map (lambda (step) (alist-value 'runtime-executed step))
                           trace)
                      '(#f #f #f #f #f #f #f #f #f #f #f #f #f #f #f #f #f #f))
        (check-equal? (alist-value 'profile settings)
                      "developer")
        (check-equal? (.ref presentation 'brand-name) agentic-ai-lab-brand-name)
        (check-equal? (.ref presentation 'brand-group) agentic-ai-lab-brand-group)
        (check-equal? (not
                       (not
                        (member "yuanxu!"
                                (.ref presentation 'user-entrypoints))))
                      #t)
        (check-equal? (not
                       (not
                        (member "use-module"
                                (.ref presentation 'user-entrypoints))))
                      #t)
        (check-equal? (not
                       (not
                        (member "agenticAiLabUserConfigPresentation"
                                (.ref presentation 'api-entrypoints))))
                      #t)
        (check-equal? (not
                       (not
                        (member "yuanxu-user-config-feature?"
                                (.ref presentation 'api-entrypoints))))
                      #t)
        (check-equal? (not
                       (not
                        (member "agenticAiLabSandboxProfilesPresentation"
                                (.ref presentation 'api-entrypoints))))
                      #t)
        (check-equal? (alist-value 'runtime-owner
                                   (.ref presentation 'boundary))
                      "marlin-agent-core")
        (check-equal? (alist-value 'package-management
                                   (.ref presentation 'boundary))
                      #f)
        (check-equal? (alist-value 'dependency-installation
                                   (.ref presentation 'boundary))
                      #f)
        (check-equal? (.ref presentation 'runtime-owner)
                      "marlin-agent-core")
        (check-equal? (.ref presentation 'package-management?) #f)
        (check-equal? (.ref presentation 'dependency-installation?) #f)
        (check-equal? (.ref presentation 'descriptor-realized?) #f)
        (check-equal? (.ref presentation 'runtime-executed) #f))))

;;; Profile presentation wraps the config projection while preserving the
;;; higher-level Doom-style profile fields users inspect.
;; : (-> Unit TestSuite)
(def (user-interface-profile-presentation-case-test)
  (yuanxu-test-case "presents profile without descriptor realization"
      (let* ((presentation
              (agenticAiLabUserProfilePresentation test-agentic-ai-lab-user-profile)))
        (check-equal? (.ref presentation 'kind)
                      yuanxu-user-profile-presentation-kind)
        (check-equal? (.ref presentation 'profile-name) 'developer)
        (check-equal? (.ref presentation 'module-bundle-count) 7)
        (check-equal? (.ref presentation 'module-count) 7)
        (check-equal? (.ref presentation 'config-presentation-kind)
                      yuanxu-user-config-presentation-kind)
        (check-equal? (.ref presentation 'config-module-count) 7)
        (check-equal? (.ref presentation 'feature-count) 7)
        (check-equal? (.ref presentation 'sandbox-profile-derivation-count)
                      0)
        (check-equal? (.ref presentation 'sandbox-profile-derivations)
                      '())
        (check-equal? (.ref presentation 'session-intent-count) 1)
        (check-equal? (alist-value 'key
                                   (car (.ref presentation
                                             'session-intents)))
                      '(session . session))
        (check-equal? (.ref presentation 'cicd-intent-count) 1)
        (check-equal? (.ref presentation
                            'workflow-cicd-runtime-command-manifest-agreement-valid?)
                      #t)
        (check-equal? (.ref presentation
                            'workflow-cicd-marlin-runtime-handoff-abi-count)
                      0)
        (check-equal? (.ref presentation 'workflow-cicd-pipeline-run-count)
                      0)
        (check-equal? (.ref presentation 'workflow-cicd-pipeline-result-count)
                      0)
        (check-equal? (alist-value
                       'runtime-executed
                       (.ref presentation
                             'workflow-cicd-marlin-handoff-receipt-bundle))
                      #f)
        (check-equal? (.ref presentation 'loop-engine-intent-count) 1)
        (check-equal? (alist-value
                       'valid?
                       (car (.ref presentation 'loop-engine-result-contracts)))
                      #t)
        (check-equal? (car (.ref presentation 'loop-engine-agent-profiles))
                      (alist-value
                       'agent-profiles
                       (car (.ref presentation 'loop-engine-intents))))
        (check-equal? (car (.ref presentation
                                  'loop-engine-delegated-operations))
                      (alist-value
                       'delegated-operation
                       (car (.ref presentation 'loop-engine-intents))))
        (check-equal? (alist-value
                       'runtime-handoff
                       (car (.ref presentation 'cicd-intents)))
                      'runtime-command-manifest)
        (check-equal? (map (lambda (step) (alist-value 'stage step))
                           (.ref presentation 'presentation-trace))
                      user-interface-presentation-trace-stages)
        (check-equal? (alist-value 'declaration-index
                                   (car (.ref presentation 'feature-facts)))
                      0)
        (check-equal? (alist-value 'key
                                   (car (.ref presentation 'feature-facts)))
                      '(flow . funflow))
        (check-equal? (not
                       (not
                        (member "agentic-ai-lab-profile"
                                (.ref presentation 'user-entrypoints))))
                      #t)
        (check-equal? (.ref presentation 'brand-name) agentic-ai-lab-brand-name)
        (check-equal? (.ref presentation 'descriptor-realized?) #f)
        (check-equal? (.ref presentation 'runtime-executed) #f))))

;; : (-> Unit TestSuite)
;;; This suite keeps presentation output aligned with the declarative user
;;; interface contract while each case remains a separately inspectable owner.
(def user-interface-presentation-test
  (test-suite "agentic-ai-lab user interface presentation"
    (user-interface-config-presentation-test)
    (user-interface-profile-presentation-case-test)))
