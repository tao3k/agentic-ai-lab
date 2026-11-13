;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/mop .new)
        (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        :clan/poo/object
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/artifact-policy
        (only-in :tao3k/yuanxu/module-system/schema/relations yuanxu-semantic-identity)
        :tao3k/yuanxu/module-system/authoring/roles
        (only-in :agentic-ai-lab/modules/module-authoring/semantic-module UserConfigSourceRole. agentic-ai-lab-user-root-module-authoring-profile)
        :tao3k/yuanxu/profile-composition/selection-syntax

        :tao3k/yuanxu/profile-composition/profile-bundle

        (only-in :clan/poo/mop element?)
        (only-in :tao3k/yuanxu/modules/funflow/scenario Scenario))


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
  (agentic-ai-lab-artifact-profile-extend
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
  (yuanxu-semantic-module
   (yuanxu-semantic-identity 'test 'artifact)
   profiles:
   (yuanxu-module-profiles
    (yuanxu-profile-export 'research-report
                             (.ref agent-artifacts 'research-report))
    (yuanxu-profile-export 'tool-output
                             (.ref agent-artifacts 'tool-output))
    (yuanxu-profile-export 'turso (.ref artifact-databases 'turso)))))

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

(def artifact-composition
  (.new Scenario name: 'artifact-composition
        config: (compose profiles
    (use-module ArtifactTestModule as artifact
      research-report tool-output turso)
    ArtifactScenarioProfile)))

(.def InternalReportProfile
  (identity 'internal-report)
  (name 'internal-report)
  (extends (.ref agent-artifacts 'research-report))
  (publish '(human-approved proof-gated internal-registry))
  (retention '(project-retained audit-log)))

(def InlineArtifactTestModule
  (yuanxu-semantic-module
   (yuanxu-semantic-identity 'test 'inline-artifact)
   profiles:
   (yuanxu-module-profiles
    (yuanxu-profile-export 'research-report
                             (.ref agent-artifacts 'research-report))
    (yuanxu-profile-export 'internal-report InternalReportProfile))))

(.def InlineArtifactScenarioProfile
  (identity 'inline-artifact-production)
  (stages
   (.o production:
       (.o proofs:
           (.o artifact-scope-contained: #t
               artifact-publish-gated: #t)))))

(def inline-artifact-composition
  (.new Scenario name: 'inline-artifact-composition
        config: (compose profiles
    (use-module InlineArtifactTestModule as artifact
      research-report internal-report)
    InlineArtifactScenarioProfile)))

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
  (agentic-ai-lab-durable-artifact-validate
   report-artifact
   research-report
   (.ref artifact-databases 'turso)))

(def artifact-manifest-receipt
  (agentic-ai-lab-durable-artifact-manifest
   report-artifact
   research-report
   (.ref artifact-databases 'turso)
   '((manifest-id . artifact-manifest/report-1)
     (metadata . ((source . scenario)
                  (case . durable-artifact-policy))))))

(def artifact-manifest-handoff
  (agentic-ai-lab-durable-artifact-manifest->marlin-handoff
   artifact-manifest-receipt))

(def invalid-artifact-policy-receipt
  (agentic-ai-lab-durable-artifact-validate
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

(export durable-artifact-policy-test)

(def durable-artifact-policy-test
  (test-suite "durable artifact policy"
    (yuanxu-test-case "artifact profile macro creates reusable POO objects"
      (check-equal? (agentic-ai-lab-artifact-profile? research-report) #t)
      (check-equal? (.ref research-report 'name) 'research-report)
      (check-equal? (.ref research-report 'kind) 'research-report)
      (check-equal? (.ref research-report 'extends) 'report/base)
      (check-equal? (.ref research-report 'scope)
                    '(tenant project workflow session human-handoff publish-channel))
      (check-equal? (.ref research-report 'storage)
                    '(file-system object-store vector-index checkpoint-store))
      (check-equal? (agentic-ai-lab-artifact-scope-contained?
                     research-report
                     '(session publish-channel))
                    #t)
      (check-equal? (agentic-ai-lab-artifact-publish-gated? research-report) #t))

    (yuanxu-test-case "profile hook composes POO object extension"
      (check-equal? (agentic-ai-lab-artifact-profile? audited-report) #t)
      (check-equal? (.ref audited-report 'name) 'audited-report)
      (check-equal? (.ref audited-report 'storage)
                    '(file-system object-store vector-index checkpoint-store))
      (check-equal? (.ref audited-report 'analysis)
                    '(checksum schema provenance citation-trace))
      (check-equal? (.ref audited-report 'retention)
                    '(project-retained audit-log)))

    (yuanxu-test-case "durable artifact object implements policy scope"
      (check-equal? (agentic-ai-lab-durable-artifact? report-artifact) #t)
      (check-equal? (.ref report-artifact 'artifact-id) 'report/artifact-1)
      (check-equal? (.ref report-artifact 'artifact-kind) 'report)
      (check-equal? (.ref report-artifact 'storage-class) 'file-system)
      (check-equal? (.ref report-artifact 'lifecycle-state) 'created)
      (check-equal? (agentic-ai-lab-durable-artifact-visible?
                     report-artifact
                     session-actor)
                    #t)
      (check-equal? (agentic-ai-lab-durable-artifact-visible?
                     report-artifact
                     outside-actor)
                    #f)
      (check-equal? (agentic-ai-lab-durable-artifact-visible?
                     report-artifact
                     reviewer-actor)
                    #t)
      (check-equal? (agentic-ai-lab-durable-artifact-visible?
                     report-artifact
                     granted-tool-actor)
                    #t))

    (yuanxu-test-case "durable artifact validation emits policy receipts"
      (check-equal? (agentic-ai-lab-durable-artifact-policy-receipt?
                     artifact-policy-receipt)
                    #t)
      (check-equal? (agentic-ai-lab-durable-artifact-policy-receipt-valid?
                     artifact-policy-receipt)
                    #t)
      (check-equal? (test-ref
                     (agentic-ai-lab-durable-artifact-policy-receipt->alist
                      artifact-policy-receipt)
                     'artifact-id)
                    'report/artifact-1)
      (check-equal? (test-ref
                     (agentic-ai-lab-durable-artifact-policy-receipt->alist
                      artifact-policy-receipt)
                     'profile-name)
                    'research-report)
      (check-equal? (test-ref
                     (agentic-ai-lab-durable-artifact-policy-receipt->alist
                      artifact-policy-receipt)
                     'database-name)
                    'turso)
      (check-equal? (test-ref
                     (agentic-ai-lab-durable-artifact-policy-receipt->alist
                      artifact-policy-receipt)
                     'valid?) #t)
      (check-equal? (test-ref
                     (agentic-ai-lab-durable-artifact-policy-receipt->alist
                      artifact-policy-receipt)
                     'runtime-executed) #f)
      (check-equal? (test-ref
                     (agentic-ai-lab-durable-artifact-policy-receipt->alist
                      artifact-policy-receipt)
                     'source)
                    'agentic-ai-lab.durable.artifact.policy)
      (check-equal? (test-ref
                     (agentic-ai-lab-durable-artifact-policy-receipt->alist
                      artifact-policy-receipt)
                     'diagnostics)
                    '())
      (check-equal? (agentic-ai-lab-durable-artifact-policy-receipt-valid?
                     invalid-artifact-policy-receipt)
                    #f)
      (check-equal? (test-ref
                     (agentic-ai-lab-durable-artifact-policy-receipt->alist
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

    (yuanxu-test-case "durable artifact manifest projects Marlin handoff"
      (let ((manifest-row
             (agentic-ai-lab-durable-artifact-manifest-receipt->alist
              artifact-manifest-receipt)))
        (check-equal? (agentic-ai-lab-durable-artifact-manifest-receipt?
                       artifact-manifest-receipt)
                      #t)
        (check-equal? (agentic-ai-lab-durable-artifact-manifest-receipt-valid?
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
                      'agentic-ai-lab.durable.artifact.marlin-handoff)
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

    (yuanxu-test-case "durable artifact lifecycle follows document edges"
      (let (stored (agentic-ai-lab-durable-artifact-transition
                    report-artifact
                    'stored))
        (check-equal? (.ref stored 'lifecycle-state) 'stored)
        (check-equal? (.ref stored 'artifact-id) 'report/artifact-1)
        (check-equal? (agentic-ai-lab-durable-artifact-lifecycle-transition-allowed?
                       'stored
                       'indexed)
                      #t)
        (check-equal? (agentic-ai-lab-durable-artifact-lifecycle-transition-allowed?
                       'created
                       'published)
                      #f)))

    (yuanxu-test-case "artifact and database profiles feed inline composition syntax"
      (let* ((stages (.ref artifact-composition 'stages))
             (stage (.ref stages 'production))
             (compose-payload (.ref artifact-composition 'profiles))
             (loop-value (.ref stage 'loop)))
        (check-equal? (element? Scenario artifact-composition) #t)
        (check-equal? (.ref artifact-composition 'name)
                      'artifact-composition)
        (check-equal? (length (.ref artifact-composition 'modules))
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

    (yuanxu-test-case "inline use-module profiles expand to POO module objects"
      (let* ((modules (.ref inline-artifact-composition 'modules))
             (module-binding (car modules))
             (module-object (.ref module-binding 'module))
             (compose-payload (.ref inline-artifact-composition 'profiles)))
        (check-equal? (element? Scenario inline-artifact-composition) #t)
        (check-equal? (.ref (.ref module-object 'identity) 'name)
                      'inline-artifact)
        (check-equal? (.ref (.ref InternalReportProfile 'extends) 'name)
                      'research-report)
        (check-equal? (.ref InternalReportProfile 'retention)
                      '(project-retained audit-log))
        (check-equal? (map profile-id compose-payload)
                      '(research-report internal-report
                        inline-artifact-production))))))
