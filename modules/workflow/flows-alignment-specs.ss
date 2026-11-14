;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Funflow tutorial alignment spec rows and gate proof catalog.
;;; Invariant: this owner stores audit metadata only and never runs tests.

(import (only-in :clan/poo/object .o .ref object?))

(export agentic-ai-lab-funflow-tutorial-alignment-schema
        agentic-ai-lab-funflow-tutorial-alignment-spec-kind
        agentic-ai-lab-funflow-tutorial-alignment-report-kind
        agentic-ai-lab-funflow-tutorial-alignment-spec
        agentic-ai-lab-funflow-tutorial-alignment-spec?
        agentic-ai-lab-funflow-tutorial-alignment-report?
        agentic-ai-lab-funflow-tutorial-alignment-spec-id
        agentic-ai-lab-funflow-tutorial-alignment-spec-status
        agentic-ai-lab-funflow-tutorial-alignment-specs
        agentic-ai-lab-funflow-tutorial-alignment-gate-proofs
        alignment-gate-proof-id
        alignment-gate-proof-commands
        agentic-ai-lab-funflow-tutorial-alignment-gate-ids)

;;; Boundary: this schema symbol is the stable POO report envelope identity.
;;; Tests and docs compare this value directly, so it must not drift with paths.
;; | AgenticAILabFunflowTutorialAlignmentSchema = Symbol
;; : (-> Unit AgenticAILabFunflowTutorialAlignmentSchema)
(def (agentic-ai-lab-funflow-tutorial-alignment-schema)
  'agentic-ai-lab.modules.funflow.tutorial-alignment.v1)

;;; Boundary: spec kind tags individual tutorial evidence rows inside the report.
;;; It separates row objects from the aggregate report without runtime loading.
;; | AgenticAILabFunflowTutorialAlignmentKind = String
;; : (-> Unit AgenticAILabFunflowTutorialAlignmentKind)
(def (agentic-ai-lab-funflow-tutorial-alignment-spec-kind)
  "agentic-ai-lab.modules.funflow.tutorial-alignment.spec.v1")

;;; Boundary: report kind tags the aggregate alignment object consumed by tests.
;;; The string is external evidence metadata, not an executable workflow handle.
;; | AgenticAILabFunflowTutorialAlignmentKind = String
;; : (-> Unit AgenticAILabFunflowTutorialAlignmentKind)
(def (agentic-ai-lab-funflow-tutorial-alignment-report-kind)
  "agentic-ai-lab.modules.funflow.tutorial-alignment.report.v1")

;; : (-> PooObject AgenticAILabFunflowTutorialAlignmentKind Boolean)
(def (agentic-ai-lab-funflow-alignment-kind? value kind)
  (and (object? value)
       (equal? (.ref value 'kind) kind)
       (equal? (.ref value 'schema)
               (agentic-ai-lab-funflow-tutorial-alignment-schema))))

;; : (-> Symbol String String Symbol [Symbol] [String] [Symbol] [Symbol] PooObject)
(def (agentic-ai-lab-funflow-tutorial-alignment-spec
      id source observable status coverage proofs runtime-owned deferred)
  (let ((id-value id)
        (source-value source)
        (observable-value observable)
        (status-value status)
        (coverage-value coverage)
        (proofs-value proofs)
        (runtime-owned-value runtime-owned)
        (deferred-value deferred))
    (.o kind: (agentic-ai-lab-funflow-tutorial-alignment-spec-kind)
        schema: (agentic-ai-lab-funflow-tutorial-alignment-schema)
        id: id-value
        source: source-value
        observable: observable-value
        status: status-value
        coverage: coverage-value
        proofs: proofs-value
        runtime-owned: runtime-owned-value
        deferred: deferred-value)))

;; : (-> PooObject Boolean)
(def (agentic-ai-lab-funflow-tutorial-alignment-spec? value)
  (agentic-ai-lab-funflow-alignment-kind?
   value
   (agentic-ai-lab-funflow-tutorial-alignment-spec-kind)))

;; : (-> PooObject Boolean)
(def (agentic-ai-lab-funflow-tutorial-alignment-report? value)
  (agentic-ai-lab-funflow-alignment-kind?
   value
   (agentic-ai-lab-funflow-tutorial-alignment-report-kind)))

;; : (-> PooObject Symbol)
(def (agentic-ai-lab-funflow-tutorial-alignment-spec-id spec)
  (.ref spec 'id))

;; : (-> PooObject Symbol)
(def (agentic-ai-lab-funflow-tutorial-alignment-spec-status spec)
  (.ref spec 'status))

;;; Boundary: this table is the canonical Funflow tutorial alignment corpus.
;;; Keep row construction centralized so report tests can detect drift in coverage.
;; : (-> Unit [PooObject])
(def (agentic-ai-lab-funflow-tutorial-alignment-specs)
  (list
   (agentic-ai-lab-funflow-tutorial-alignment-spec
    'tutorial1
    "funflow-tutorial/notebooks/Tutorial1.ipynb"
    "runFlow over input 1 returns 2"
    'result-covered
    '(pure-flow runner-result)
    '("gxtest t/tutorial-result-test.ss: stage 1 tutorial1 minimal pure flow returns 2")
    '()
    '())
   (agentic-ai-lab-funflow-tutorial-alignment-spec
    'quick-reference
    "funflow-tutorial/notebooks/QuickReference.ipynb"
    "Hello Watson !, Hello world, conditional result 1, cached increment reuse"
    'result-covered
    '(pure-flow composition conditional-flow cached-scheme-flow)
    '("gxtest t/tutorial-result-test.ss: stage 2 quick reference hello and composition results"
      "gxtest t/tutorial-feature-batch-test.ss: stage 11 quick reference conditional and cached increment run")
    '()
    '())
   (agentic-ai-lab-funflow-tutorial-alignment-spec
    'tutorial2-custom-task
    "funflow-tutorial/notebooks/Tutorial2.ipynb"
    "Kangaroo goes woop! repeated seven times"
    'result-covered
    '(custom-task-family custom-run-config extension-owned-interpreter)
    '("gxtest t/tutorial-result-test.ss: stage 3 tutorial2 extension behavior repeats custom text"
      "gxtest t/tutorial-feature-batch-test.ss: stage 12 tutorial2 custom task interpreter runs through extension")
    '()
    '())
   (agentic-ai-lab-funflow-tutorial-alignment-spec
    'word-count
    "funflow-tutorial/notebooks/WordCount/WordCount.ipynb"
    "word count lines include a: 3, and: 3, Lets: 2, FILE: 1"
    'result-covered
    '(text-task-family word-count-summary)
    '("gxtest t/tutorial-result-test.ss: stage 4 word count exposes deterministic counts"
      "gxtest t/tutorial-feature-batch-test.ss: stage 13 word count extension returns notebook counts")
    '()
    '())
   (agentic-ai-lab-funflow-tutorial-alignment-spec
    'external-config
    "funflow-tutorial/notebooks/ExternalConfig/ExternalConfig.ipynb"
    "file/env/literal arguments render before Docker work; missing keys fail fast"
    'result-covered
    '(config-preflight argument-rendering missing-config-diagnostics)
    '("gxtest t/tutorial-result-test.ss: stage 5 external config fails before runtime submission"
      "gxtest t/store-funflow-alignment-test.ss: aligns Funflow external config preflight and rendering")
    '(docker-echo runtime-container)
    '(real-docker-echo-output))
   (agentic-ai-lab-funflow-tutorial-alignment-spec
    'error-handling
    "funflow-tutorial/notebooks/ErrorHandling.ipynb"
    "try boundary routes local and runtime failures to handled values"
    'result-covered
    '(try-flow runner-recover adapter-failure-receipt)
    '("gxtest t/tutorial-result-test.ss: stage 6 error handling try-flow routes thrown failures"
      "gxtest t/tutorial-feature-batch-test.ss: stage 15 error handling recovers local throw and adapter failure")
    '(runtime-failure-source)
    '())
   (agentic-ai-lab-funflow-tutorial-alignment-spec
    'ccompilation
    "funflow-tutorial/notebooks/CCompilation/CCompilation.ipynb"
    "Docker-backed GCC flow prints 15 for input 3"
    'runtime-manifest-covered
    '(docker-flow stdout-runtime-response docker-store-handoff runtime-manifest)
    '("gxtest t/tutorial-runtime-result-test.ss: stage 7 docker process runtime command returns CCompilation visible result"
      "gxtest t/tutorial-runtime-result-test.ss: stage 8 docker artifact feeds store manifest"
      "gxtest t/tutorial-runtime-result-test.ss: stage 9 descriptor command drives docker store workflow"
      "gxtest t/tutorial-runtime-result-test.ss: stage 10 descriptor manifest exposes rust cli handoff")
    '(docker-process cas-materialization artifact-store)
    '(real-container-execution real-cas-write))
   (agentic-ai-lab-funflow-tutorial-alignment-spec
    'tensorflow-docker
    "funflow-tutorial/notebooks/TensorflowDocker/TensorflowDocker.ipynb"
    "store data, train model, run inference, render summary.png"
    'descriptor-covered
    '(tensorflow-train-flow tensorflow-inference-flow docker-store-plan)
    '("gxtest t/tutorial-feature-batch-test.ss: stage 14 ccompilation and tensorflow workflow descriptors are public")
    '(docker-process python-training image-rendering cas-materialization)
    '(real-training-result real-inference-output summary-png))
   (agentic-ai-lab-funflow-tutorial-alignment-spec
    'makefile-tool
    "funflow-examples/makefile-tool/README.md"
    "parse Makefile project, build hello target, return process output"
    'runtime-manifest-covered
    '(external-parse-flow external-run-flow runtime-cli-manifest)
    '("gxtest t/tutorial-feature-batch-test.ss: stage 16 makefile tool workflow descriptor is public"
      "gxtest t/tutorial-makefile-runtime-test.ss: stage 17 descriptor command drives makefile tool workflow"
      "gxtest t/tutorial-makefile-runtime-test.ss: stage 18 makefile tool descriptor manifest exposes rust cli handoff")
    '(make-process filesystem-build)
    '(real-make-execution real-hello-binary-output))))

;; | AgenticAILabAlignmentGateProof = Alist

;;; Boundary: gate proofs are report metadata, not test execution directives.
;;; Keeping proof strings inert lets downstream tooling audit coverage safely.
;; : (-> Symbol [String] AgenticAILabAlignmentGateProof)
(def (alignment-gate-proof id proofs)
  (list (cons 'id id)
        (cons 'proofs proofs)))

;;; Boundary: result gates track the repository proof ladder, not upstream files.
;;; The catalog connects tutorial parity to concrete local verification commands.
;; : (-> Unit [AgenticAILabAlignmentGateProof])
(def (agentic-ai-lab-funflow-tutorial-alignment-gate-proofs)
  (list
   (alignment-gate-proof
    'stage-1-minimal-flow
    '("gxtest t/tutorial-result-test.ss: stage 1 tutorial1 minimal pure flow returns 2"))
   (alignment-gate-proof
    'stage-2-composition-and-greeting
    '("gxtest t/tutorial-result-test.ss: stage 2 quick reference hello and composition results"))
   (alignment-gate-proof
    'stage-3-extension-behavior
    '("gxtest t/tutorial-result-test.ss: stage 3 tutorial2 extension behavior repeats custom text"
      "gxtest t/tutorial-feature-batch-test.ss: stage 12 tutorial2 custom task interpreter runs through extension"))
   (alignment-gate-proof
    'stage-4-word-count-pipeline
    '("gxtest t/tutorial-result-test.ss: stage 4 word count exposes deterministic counts"
      "gxtest t/tutorial-feature-batch-test.ss: stage 13 word count extension returns notebook counts"))
   (alignment-gate-proof
    'stage-5-external-config-fail-fast
    '("gxtest t/tutorial-result-test.ss: stage 5 external config fails before runtime submission"))
   (alignment-gate-proof
    'stage-6-error-handling-try-boundary
    '("gxtest t/tutorial-result-test.ss: stage 6 error handling try-flow routes thrown failures"
      "gxtest t/functional-flow-kernel-test.ss: authors functional flows with hygienic Gerbil macros"))
   (alignment-gate-proof
    'stage-7-docker-cas-real-runtime
    '("gxtest t/tutorial-runtime-result-test.ss: stage 7 docker process runtime command returns CCompilation visible result"
      "gxtest t/docker-descriptor-test.ss: captures CCompilation-style docker payload"
      "gxtest t/docker-descriptor-test.ss: captures ExternalConfig-style rendered arguments"))
   (alignment-gate-proof
    'stage-8-docker-artifact-handoff-to-store
    '("gxtest t/tutorial-runtime-result-test.ss: stage 8 docker artifact feeds store manifest"))
   (alignment-gate-proof
    'stage-9-descriptor-declared-runtime-command
    '("gxtest t/runtime-bridge-test.ss: stdout runtime command descriptor materializes process command"
      "gxtest t/tutorial-runtime-result-test.ss: stage 9 descriptor command drives docker store workflow"))
   (alignment-gate-proof
    'stage-10-descriptor-manifest-for-rust-cli-handoff
    '("gxtest t/runtime-bridge-test.ss: runtime command descriptor exports cli manifest"
      "gxtest t/tutorial-runtime-result-test.ss: stage 10 descriptor manifest exposes rust cli handoff"))
   (alignment-gate-proof
    'stage-11-quick-reference-conditional-and-cache
    '("gxtest t/tutorial-feature-batch-test.ss: stage 11 quick reference conditional and cached increment run"))
   (alignment-gate-proof
    'stage-12-tutorial2-custom-task-interpreter
    '("gxtest t/tutorial-feature-batch-test.ss: stage 12 tutorial2 custom task interpreter runs through extension"))
   (alignment-gate-proof
    'stage-13-word-count-text-extension
    '("gxtest t/tutorial-feature-batch-test.ss: stage 13 word count extension returns notebook counts"))
   (alignment-gate-proof
    'stage-14-ccompilation-and-tensorflow-descriptors
    '("gxtest t/tutorial-feature-batch-test.ss: stage 14 ccompilation and tensorflow workflow descriptors are public"))
   (alignment-gate-proof
    'stage-15-error-handling-recovery-boundary
    '("gxtest t/tutorial-feature-batch-test.ss: stage 15 error handling recovers local throw and adapter failure"))
   (alignment-gate-proof
    'stage-16-makefile-tool-workflow-descriptor
    '("gxtest t/tutorial-feature-batch-test.ss: stage 16 makefile tool workflow descriptor is public"))
   (alignment-gate-proof
    'stage-17-makefile-tool-descriptor-runtime-result
    '("gxtest t/tutorial-makefile-runtime-test.ss: stage 17 descriptor command drives makefile tool workflow"))
   (alignment-gate-proof
    'stage-18-makefile-tool-rust-cli-manifest
    '("gxtest t/tutorial-makefile-runtime-test.ss: stage 18 makefile tool descriptor manifest exposes rust cli handoff"))
   (alignment-gate-proof
    'stage-19-runtime-manifest-consumer
    '("gxtest t/runtime-manifest-test.ss: runtime command descriptor exports cli manifest"
      "gxtest t/runtime-manifest-test.ss: runtime command manifest consumer executes stdout protocol"
      "gxtest t/runtime-manifest-test.ss: runtime command manifest rejects unsupported protocol"))
   (alignment-gate-proof
    'stage-20-functional-flow-kernel-and-macro-authoring
    '("gxtest t/functional-flow-kernel-test.ss: functional flow kernel"))
   (alignment-gate-proof
    'stage-21-workflow-module-macro-authoring
    '("gxtest t/tutorial-feature-batch-test.ss: authors extension-owned workflows with Gerbil macros"
      "gxtest t/tutorial-makefile-runtime-test.ss: authors makefile runtime descriptor with Gerbil macros"))
   (alignment-gate-proof
    'stage-22-poo-tutorial-alignment-report
    '("gxtest t/funflow-tutorial-alignment-report-test.ss: funflow tutorial alignment report"))
   (alignment-gate-proof
    'stage-23-user-interface-marlin-handoff-projection
    '("gxtest t/user-interface-cicd-test.ss: projects user config into Marlin runtime handoff ABI"
      "gxtest t/funflow-tutorial-alignment-report-test.ss: user-interface Marlin handoff result gate"))))

;; : (-> AgenticAILabAlignmentGateProof Symbol)
(def (alignment-gate-proof-id gate-proof)
  (cdr (assoc 'id gate-proof)))

;; : (-> AgenticAILabAlignmentGateProof [String])
(def (alignment-gate-proof-commands gate-proof)
  (cdr (assoc 'proofs gate-proof)))

;;; Boundary: ids are projected from the proof catalog to prevent drift.
;;; Downstream code should consume ids and proofs from the same source.
;; : (-> Unit [Symbol])
(def (agentic-ai-lab-funflow-tutorial-alignment-gate-ids)
  (map alignment-gate-proof-id
       (agentic-ai-lab-funflow-tutorial-alignment-gate-proofs)))
