;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: use-module config must be inspectable before runtime.
;;; Invariant: presentation is inert; no module descriptors or runtimes execute.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        :core/module-system/selection/objects
        :poo-flow/modules/workflow/scenario/configuration/presentation-config
        :poo-flow/modules/workflow/scenario/configuration/init-syntax
        :poo-flow/modules/agent-sandbox/config
        (only-in "../user-interface/custom/my-module/profiles/agent-sandbox-audit"
                 poo-flow-custom-module-agent-sandbox-audit-module))

;; : (-> Symbol PresentationAlist MaybePresentationValue)
(def (alist-value key entries)
  (cond
   ((null? entries) #f)
   ((equal? key (caar entries)) (cdar entries))
   (else
    (alist-value key (cdr entries)))))

;; : (-> NonEmptyLineageSteps LineageStep)
(def (last-value values)
  (if (null? (cdr values))
    (car values)
    (last-value (cdr values))))

;; : (-> (-> Unit Value) Boolean)
(def (presentation-test-error? thunk)
  (with-catch (lambda (_failure) #t)
              (lambda ()
                (thunk)
                #f)))

(export user-interface-config-presentation-test)

(def user-interface-config-presentation-test
 (test-suite "user-interface config presentation"
   (poo-flow-test-case "shows an independent custom-module profile fragment as user config"
     (let* ((config (pooFlowUserConfig
                     poo-flow-custom-module-agent-sandbox-audit-module
                     (poo-flow-settings)))
            (presentation (pooFlowUserConfigPresentation config))
            (module-row (car (.ref presentation 'modules)))
            (feature-row (car (.ref presentation 'feature-facts)))
            (sandbox-profile-derivations
             (.ref presentation 'sandbox-profile-derivations))
            (session-derivation (car sandbox-profile-derivations))
            (branch-derivation (cadr sandbox-profile-derivations))
            (visible-flags (alist-value 'flags module-row))
            (feature-flags (alist-value 'flags feature-row))
            (selection
             (car poo-flow-custom-module-agent-sandbox-audit-module))
            (internal-flags
             (poo-flow-user-module-selection-flags selection))
            (internal-config-entry
             (alist-value ':config internal-flags))
            (base-profile (car internal-config-entry))
            (session-profile (cadr internal-config-entry))
            (branch-profile (caddr internal-config-entry))
            (branch-metadata
             (poo-flow-sandbox-profile-metadata branch-profile))
            (branch-lineage
             (alist-value 'derivation-path branch-metadata))
            (last-lineage-step (last-value branch-lineage)))
       (check-equal? visible-flags
                     '((:config
                        (binding native-ffi)
                        (.def (agent/audit-base
                               @
                               nono-sandbox-profile
                               network
                               capabilities
                               resources
                               metadata)
                              network: (deny-network)
                              capabilities: audit-base-capabilities
                              resources: =>.+ readwrite-project-workspace-resources
                              metadata: =>
                              (lambda (super-metadata)
                                (append super-metadata audit-base-metadata)))
                        (.def (agent/audit-session
                               @
                               agent/audit-base
                               network
                               capabilities
                               resources
                               metadata)
                              network: (allowlisted-network "github.com")
                              capabilities: =>
                              (lambda (super-capabilities)
                                (append super-capabilities cache-capabilities))
                              resources: =>.+ runtime-volume-resources
                              (metadata (super-metadata)
                                (profile-derivation-metadata
                                 (super-metadata)
                                 audit-session-name
                                 audit-base-name
                                 session-scope
                                 "agent-session"
                                 audit-session-metadata)))
                        (.def (agent/audit-branch
                               @
                               agent/audit-session
                               network
                               capabilities
                               resources
                               metadata)
                              network: (deny-network)
                              capabilities: audit-branch-capabilities
                              resources: =>.+ readonly-project-workspace-resources
                              (metadata (super-metadata)
                                (profile-derivation-metadata
                                 (super-metadata)
                                 audit-branch-name
                                 audit-session-name
                                 branch-scope
                                 "feature/agent-sandbox-audit"
                                 audit-branch-metadata))))))
       (check-equal? feature-flags visible-flags)
       (check-equal? (alist-value ':binding visible-flags) #f)
       (check-equal? (alist-value ':user-config visible-flags) #f)
       (check-equal? (alist-value 'kind (alist-value ':config visible-flags))
                     #f)
       (check-equal? (.ref presentation 'sandbox-profile-derivation-count)
                     2)
       (check-equal? (alist-value 'module session-derivation)
                     'nono-sandbox)
       (check-equal? (alist-value 'profile-name session-derivation)
                     'agent/audit-session)
       (check-equal? (alist-value 'parent-profile session-derivation)
                     'agent/audit-base)
       (check-equal? (alist-value 'scope session-derivation)
                     'session)
       (check-equal? (alist-value 'scope-ref session-derivation)
                     "agent-session")
       (check-equal? (alist-value 'derivation-depth session-derivation)
                     1)
       (check-equal? (alist-value 'profile-name branch-derivation)
                     'agent/audit-branch)
       (check-equal? (alist-value 'parent-profile branch-derivation)
                     'agent/audit-session)
       (check-equal? (alist-value 'scope branch-derivation)
                     'branch)
       (check-equal? (alist-value 'scope-ref branch-derivation)
                     "feature/agent-sandbox-audit")
       (check-equal? (alist-value 'derivation-depth branch-derivation)
                     2)
       (check-equal? (length (alist-value 'derivation-path branch-derivation))
                     2)
       (check-equal? (alist-value 'kind branch-derivation) #f)
       (check-equal? (alist-value 'runtime-owner branch-derivation)
                     "marlin-agent-core")
       (check-equal? (alist-value 'descriptor-realized? branch-derivation)
                     #f)
       (check-equal? (alist-value 'runtime-executed branch-derivation)
                     #f)
       (check-equal? (poo-flow-sandbox-profile? base-profile) #t)
       (check-equal? (poo-flow-sandbox-profile-backend-kind session-profile)
                     'nono)
       (check-equal? (poo-flow-sandbox-profile-name base-profile)
                     'agent/audit-base)
       (check-equal? (poo-flow-sandbox-profile-name session-profile)
                     'agent/audit-session)
       (check-equal? (poo-flow-sandbox-profile-name branch-profile)
                     'agent/audit-branch)
       (check-equal? (poo-flow-sandbox-profile-capabilities branch-profile)
                     '(process-run filesystem-read tmpdir cache-mount))
       (check-equal? (length branch-lineage) 2)
       (check-equal? (alist-value 'parent-profile last-lineage-step)
                     'agent/audit-session)
       (check-equal? (alist-value 'scope last-lineage-step) 'branch)
       (check-equal? (alist-value 'scope-ref last-lineage-step)
                     "feature/agent-sandbox-audit")
       (check-equal? (alist-value ':binding internal-flags) 'native-ffi)))
   (poo-flow-test-case "rejects user-layer derive parents that are not POO profiles"
     (let (not-profile 'not-a-poo-profile)
       (check-equal?
        (presentation-test-error?
         (lambda ()
           (use-module nono-sandbox
             (.def (agent/bad-parent @ not-profile)
               metadata: => (lambda (super-metadata)
                              super-metadata)))))
        #t)))))
