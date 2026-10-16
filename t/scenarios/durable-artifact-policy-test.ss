;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         :std/test
        :clan/poo/object
        :poo-flow/modules/ai-agentic-context/features/memory/durable/artifact-policy
        (only-in :core/module-system/schema/relations poo-flow-semantic-identity)
        :core/module-system/authoring/roles
        (only-in :poo-flow/modules/module-authoring/semantic-module UserConfigSourceRole. poo-flow-user-root-module-authoring-profile)
        :core/profile-composition/selection-syntax
        :poo-flow/modules/workflow/scenario/composition-syntax
        :core/profile-composition/profile-bundle
        :poo-flow/modules/workflow/scenario/accessors
        (only-in :poo-flow/modules/workflow/scenario/case poo-flow-scenario-case?))


(def (profile-id profile)
  (.ref profile (if (.slot? profile 'identity) 'identity 'name)))

(def (test-ref row key)
  (let (entry (assoc key row))
    (if entry (cdr entry) #f)))

(def report/base
  (.o (name 'report/base)
      (scope '(tenant project workflow session publish-channel))
      (storage '(file-system))
      (analysis '(checksum))
      (publish '(human-approved))))

(def tool-output/base
  (.o (name 'tool-output/base)
      (scope '(session agent tool-call sandbox))
      (storage '(kv))
      (analysis '(checksum))
      (retention '(checkpoint-linked))))

(def research-report
  (artifact-profile research-report
    :extends report/base
    :scope (tenant project workflow session human-handoff publish-channel)
    :storage (file-system object-store vector-index checkpoint-store)
    :analysis (checksum schema provenance)
    :publish (human-approved proof-gated)
    :retention (project-retained audit-log)))

(def (with-audit-retention profile)
  (poo-flow-artifact-profile-extend
   (.ref profile 'name)
   profile
   (.o (analysis (append (.ref profile 'analysis) '(citation-trace)))
       (retention '(project-retained audit-log)))))

(def audited-report
  (artifact-profile audited-report
    :extends research-report
    :scope (tenant project workflow session human-handoff publish-channel)
    :storage (file-system object-store vector-index checkpoint-store)
    :analysis (checksum schema provenance)
    :publish (human-approved proof-gated)
    :retention (project-retained audit-log)
    :with with-audit-retention))

(def agent-artifacts
  (artifact-module
    (profile research-report
      :extends report/base
      :scope (session human-handoff publish-channel)
      :storage (file object vector)
      :analysis (checksum schema provenance)
      :publish (human-approved proof-gated))
    (profile tool-output
      :extends tool-output/base
      :scope (session agent tool-call sandbox)
      :storage (kv checkpoint-store)
      :analysis (checksum schema)
      :retention (checkpoint-linked))))

(def artifact-databases
  (database-module
    (profile turso
      :kind libsql
      :storage (file-system vector-index checkpoint-store)
      :capabilities (concurrent-writes
                     local-first-push-pull
                     ai-vector-search
                     vector-top-k))))

(def ArtifactTestModule
  (poo-flow-semantic-module
   (poo-flow-semantic-identity 'test 'artifact)
   profiles:
   (poo-flow-module-profiles
    (poo-flow-profile-export 'research-report
                             (.ref agent-artifacts 'research-report))
    (poo-flow-profile-export 'tool-output
                             (.ref agent-artifacts 'tool-output))
    (poo-flow-profile-export 'turso (.ref artifact-databases 'turso)))))

(.def ArtifactScenarioProfile
  (identity 'artifact-production)
  (stages
   (.o production:
       (.o graph: 'artifact-lifecycle
           loop: (.o fuel: 4 exit: 'published)
           proofs:
           (.o artifact-scope-contained: #t
               artifact-publish-gated: #t
               database-capability-satisfied: #t)))))

(user-composition artifact-composition
  (compose profiles
    (use-module ArtifactTestModule as artifact
      research-report tool-output turso)
    ArtifactScenarioProfile))

(.def InternalReportProfile
  (identity 'internal-report)
  (name 'internal-report)
  (extends (.ref agent-artifacts 'research-report))
  (publish '(human-approved proof-gated internal-registry))
  (retention '(project-retained audit-log)))

(def InlineArtifactTestModule
  (poo-flow-semantic-module
   (poo-flow-semantic-identity 'test 'inline-artifact)
   profiles:
   (poo-flow-module-profiles
    (poo-flow-profile-export 'research-report
                             (.ref agent-artifacts 'research-report))
    (poo-flow-profile-export 'internal-report InternalReportProfile))))

(.def InlineArtifactScenarioProfile
  (identity 'inline-artifact-production)
  (stages
   (.o production:
       (.o proofs:
           (.o artifact-scope-contained: #t
               artifact-publish-gated: #t)))))

(user-composition inline-artifact-composition
  (compose profiles
    (use-module InlineArtifactTestModule as artifact
      research-report internal-report)
    InlineArtifactScenarioProfile))

(def report-artifact
  (durable-artifact report/artifact-1
    :kind report
    :scope (tenant project workflow session human-handoff publish-channel)
    :storage-class file-system
    :state created
    :producer agent/build
    :owner project/team
    :sandbox (sandbox/build)
    :checksum checksum/sha256
    :analysis (checksum schema provenance)
    :index vector-top-k
    :call read-only
    :publish (human-approved proof-gated)
    :retention project-retained
    :grants (actor/reviewer)))

(def invalid-artifact
  (durable-artifact report/artifact-invalid
    :kind report
    :scope (external)
    :storage-class memory-only
    :state unknown
    :producer agent/build
    :owner project/team
    :sandbox (sandbox/build)
    :checksum checksum/sha256
    :analysis (unsafe-analysis)
    :index missing-vector-capability
    :call read-only
    :publish (auto-publish)
    :retention forever
    :grants ()))

(def artifact-policy-receipt
  (poo-flow-durable-artifact-validate
   report-artifact
   research-report
   (.ref artifact-databases 'turso)))

(def artifact-manifest-receipt
  (poo-flow-durable-artifact-manifest
   report-artifact
   research-report
   (.ref artifact-databases 'turso)
   '((manifest-id . artifact-manifest/report-1)
     (metadata . ((source . scenario)
                  (case . durable-artifact-policy))))))

(def artifact-manifest-handoff
  (poo-flow-durable-artifact-manifest->marlin-handoff
   artifact-manifest-receipt))

(def invalid-artifact-policy-receipt
  (poo-flow-durable-artifact-validate
   invalid-artifact
   research-report
   (.ref artifact-databases 'turso)))

(def session-actor
  (.o (actor-ref 'actor/session)
      (scope '(project session))
      (artifact-grants '())))

(def outside-actor
  (.o (actor-ref 'actor/outside)
      (scope '(external workspace))
      (artifact-grants '())))

(def reviewer-actor
  (.o (actor-ref 'actor/reviewer)
      (scope '(external workspace))
      (artifact-grants '())))

(def granted-tool-actor
  (.o (actor-ref 'actor/tool)
      (scope '(external workspace))
      (artifact-grants '(report/artifact-1))))

(def durable-artifact-policy-test
  (test-suite "durable artifact policy"
    (poo-flow-test-case "artifact profile macro creates reusable POO objects"
      (check-equal? (poo-flow-artifact-profile? research-report) #t)
      (check-equal? (.ref research-report 'name) 'research-report)
      (check-equal? (.ref research-report 'kind) 'research-report)
      (check-equal? (.ref research-report 'extends) 'report/base)
      (check-equal? (.ref research-report 'scope)
                    '(tenant project workflow session human-handoff publish-channel))
      (check-equal? (.ref research-report 'storage)
                    '(file-system object-store vector-index checkpoint-store))
      (check-equal? (poo-flow-artifact-scope-contained?
                     research-report
                     '(session publish-channel))
                    #t)
      (check-equal? (poo-flow-artifact-publish-gated? research-report) #t))

    (poo-flow-test-case "profile hook composes native POO object extension"
      (check-equal? (poo-flow-artifact-profile? audited-report) #t)
      (check-equal? (.ref audited-report 'name) 'audited-report)
      (check-equal? (.ref audited-report 'storage)
                    '(file-system object-store vector-index checkpoint-store))
      (check-equal? (.ref audited-report 'analysis)
                    '(checksum schema provenance citation-trace))
      (check-equal? (.ref audited-report 'retention)
                    '(project-retained audit-log)))

    (poo-flow-test-case "durable artifact object implements policy scope"
      (check-equal? (poo-flow-durable-artifact? report-artifact) #t)
      (check-equal? (.ref report-artifact 'artifact-id) 'report/artifact-1)
      (check-equal? (.ref report-artifact 'artifact-kind) 'report)
      (check-equal? (.ref report-artifact 'storage-class) 'file-system)
      (check-equal? (.ref report-artifact 'lifecycle-state) 'created)
      (check-equal? (poo-flow-durable-artifact-visible?
                     report-artifact
                     session-actor)
                    #t)
      (check-equal? (poo-flow-durable-artifact-visible?
                     report-artifact
                     outside-actor)
                    #f)
      (check-equal? (poo-flow-durable-artifact-visible?
                     report-artifact
                     reviewer-actor)
                    #t)
      (check-equal? (poo-flow-durable-artifact-visible?
                     report-artifact
                     granted-tool-actor)
                    #t))

    (poo-flow-test-case "durable artifact validation emits policy receipts"
      (check-equal? (poo-flow-durable-artifact-policy-receipt?
                     artifact-policy-receipt)
                    #t)
      (check-equal? (poo-flow-durable-artifact-policy-receipt-valid?
                     artifact-policy-receipt)
                    #t)
      (check-equal? (test-ref
                     (poo-flow-durable-artifact-policy-receipt->alist
                      artifact-policy-receipt)
                     'artifact-id)
                    'report/artifact-1)
      (check-equal? (test-ref
                     (poo-flow-durable-artifact-policy-receipt->alist
                      artifact-policy-receipt)
                     'profile-name)
                    'research-report)
      (check-equal? (test-ref
                     (poo-flow-durable-artifact-policy-receipt->alist
                      artifact-policy-receipt)
                     'database-name)
                    'turso)
      (check-equal? (test-ref
                     (poo-flow-durable-artifact-policy-receipt->alist
                      artifact-policy-receipt)
                     'valid?) #t)
      (check-equal? (test-ref
                     (poo-flow-durable-artifact-policy-receipt->alist
                      artifact-policy-receipt)
                     'runtime-executed) #f)
      (check-equal? (test-ref
                     (poo-flow-durable-artifact-policy-receipt->alist
                      artifact-policy-receipt)
                     'source)
                    'poo-flow.durable.artifact.policy)
      (check-equal? (test-ref
                     (poo-flow-durable-artifact-policy-receipt->alist
                      artifact-policy-receipt)
                     'diagnostics)
                    '())
      (check-equal? (poo-flow-durable-artifact-policy-receipt-valid?
                     invalid-artifact-policy-receipt)
                    #f)
      (check-equal? (test-ref
                     (poo-flow-durable-artifact-policy-receipt->alist
                      invalid-artifact-policy-receipt)
                     'diagnostics)
                    '(artifact-scope-not-contained-by-profile
                      artifact-storage-not-supported-by-profile
                      artifact-analysis-not-supported-by-profile
                      artifact-publish-policy-not-gated
                      artifact-retention-not-supported-by-profile
                      artifact-lifecycle-state-invalid
                      artifact-storage-not-supported-by-database
                      artifact-database-capability-not-satisfied)))

    (poo-flow-test-case "durable artifact manifest projects Marlin handoff"
      (let ((manifest-row
             (poo-flow-durable-artifact-manifest-receipt->alist
              artifact-manifest-receipt)))
        (check-equal? (poo-flow-durable-artifact-manifest-receipt?
                       artifact-manifest-receipt)
                      #t)
        (check-equal? (poo-flow-durable-artifact-manifest-receipt-valid?
                       artifact-manifest-receipt)
                      #t)
        (check-equal? (test-ref manifest-row 'manifest-id)
                      'artifact-manifest/report-1)
        (check-equal? (test-ref manifest-row 'artifact-id)
                      'report/artifact-1)
        (check-equal? (test-ref manifest-row 'storage-class) 'file-system)
        (check-equal? (test-ref manifest-row 'handoff-required) #t)
        (check-equal? (test-ref manifest-row 'runtime-executed) #f)
        (check-equal? (test-ref artifact-manifest-handoff 'kind)
                      'poo-flow.durable.artifact.marlin-handoff)
        (check-equal? (test-ref artifact-manifest-handoff 'handoff-ready?) #t)
        (check-equal? (test-ref artifact-manifest-handoff
                                'runtime-executed)
                      #f)
        (check-equal? (test-ref artifact-manifest-handoff
                                'runtime-parses-scheme-source)
                      #f)
        (check-equal? (test-ref artifact-manifest-handoff
                                'scheme-manufactures-runtime-handlers)
                      #f)))

    (poo-flow-test-case "durable artifact lifecycle follows document edges"
      (let (stored (poo-flow-durable-artifact-transition
                    report-artifact
                    'stored))
        (check-equal? (.ref stored 'lifecycle-state) 'stored)
        (check-equal? (.ref stored 'artifact-id) 'report/artifact-1)
        (check-equal? (poo-flow-durable-artifact-lifecycle-transition-allowed?
                       'stored
                       'indexed)
                      #t)
        (check-equal? (poo-flow-durable-artifact-lifecycle-transition-allowed?
                       'created
                       'published)
                      #f)))

    (poo-flow-test-case "artifact and database profiles feed inline composition syntax"
      (let* ((stages (poo-flow-scenario-case-stages artifact-composition))
             (stage (.ref stages 'production))
             (compose-payload (poo-flow-scenario-case-profiles
                               artifact-composition))
             (loop-value (.ref stage 'loop)))
        (check-equal? (poo-flow-scenario-case? artifact-composition) #t)
        (check-equal? (poo-flow-scenario-case-name artifact-composition)
                      'agent-artifacts)
        (check-equal? (length (poo-flow-scenario-case-modules
                               artifact-composition))
                      1)
        (check-equal? (map profile-id compose-payload)
                      '(research-report tool-output turso artifact-production))
        (check-equal? (.ref stage 'graph) 'artifact-lifecycle)
        (check-equal? (.ref loop-value 'fuel) 4)
        (check-equal? (.ref loop-value 'exit) 'published)
        (check-equal? (.all-slots (.ref stage 'proofs))
                      '(artifact-scope-contained
                        artifact-publish-gated
                        database-capability-satisfied))))

    (poo-flow-test-case "inline use-module profiles expand to POO module objects"
      (let* ((modules (poo-flow-scenario-case-modules inline-artifact-composition))
             (module-binding (car modules))
             (module-object (.ref module-binding 'module))
             (compose-payload (poo-flow-scenario-case-profiles
                               inline-artifact-composition)))
        (check-equal? (poo-flow-scenario-case? inline-artifact-composition) #t)
        (check-equal? (.ref (.ref module-object 'identity) 'name)
                      'inline-artifact)
        (check-equal? (.ref (.ref InternalReportProfile 'extends) 'name)
                      'research-report)
        (check-equal? (.ref InternalReportProfile 'retention)
                      '(project-retained audit-log))
        (check-equal? (map profile-id compose-payload)
                      '(research-report internal-report
                        inline-artifact-production))))))
