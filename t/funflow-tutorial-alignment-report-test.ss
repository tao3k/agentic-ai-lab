;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Funflow tutorial alignment is a POO report, not loose prose.
;;; Invariant: heavy Docker/CAS/process work remains runtime-owned.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 test-suite
                 check-equal?
                 )
          (only-in :clan/poo/object .ref object?)
          (only-in :agentic-ai-lab/modules/workflow/flows-alignment-report
                   agentic-ai-lab-funflow-tutorial-alignment-report)
          (only-in :agentic-ai-lab/modules/workflow/flows-alignment-specs
                   agentic-ai-lab-funflow-tutorial-alignment-schema
                   agentic-ai-lab-funflow-tutorial-alignment-report-kind
                   agentic-ai-lab-funflow-tutorial-alignment-spec?
                   agentic-ai-lab-funflow-tutorial-alignment-report?
                   agentic-ai-lab-funflow-tutorial-alignment-specs))

(export funflow-tutorial-alignment-report-test)

;; : (-> Alist Symbol Value)
(def (alignment-test-alist-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;; : (-> Symbol [PooObject] (U PooObject #f))
(def (alignment-test-spec-by-id id specs)
  (cond
   ((null? specs) #f)
   ((eq? id (.ref (car specs) 'id)) (car specs))
   (else (alignment-test-spec-by-id id (cdr specs)))))

;; : (-> Symbol [Alist] (U Alist #f))
(def (alignment-test-gate-proof-by-id id gate-proofs)
  (cond
   ((null? gate-proofs) #f)
   ((eq? id (alignment-test-alist-ref (car gate-proofs) 'id))
    (car gate-proofs))
   (else (alignment-test-gate-proof-by-id id (cdr gate-proofs)))))

;; : (-> String [Alist] (U Alist #f))
(def (alignment-test-entry-by-source source entries)
  (cond
   ((null? entries) #f)
   ((equal? source (alignment-test-alist-ref (car entries) 'source))
    (car entries))
   (else (alignment-test-entry-by-source source (cdr entries)))))

;; : (-> Symbol [Alist] (U Alist #f))
(def (alignment-test-entry-by-status status entries)
  (cond
   ((null? entries) #f)
   ((eq? status (alignment-test-alist-ref (car entries) 'status))
    (car entries))
   (else (alignment-test-entry-by-status status (cdr entries)))))

;; : (-> Symbol [Alist] (U Alist #f))
(def (alignment-test-entry-by-runtime-owner owner entries)
  (cond
   ((null? entries) #f)
   ((eq? owner (alignment-test-alist-ref (car entries) 'runtime-owner))
    (car entries))
   (else (alignment-test-entry-by-runtime-owner owner (cdr entries)))))

;;; Boundary: this suite checks the top-level Funflow report contract and CI
;;; receipt manifest without mixing in source-index details.
;; : TestSuite
(def funflow-tutorial-alignment-report-shape-test
  (test-suite "funflow tutorial alignment report shape"
    (yuanxu-test-case "projects audited upstream tutorial coverage as a POO report"
      (let* ((report (agentic-ai-lab-funflow-tutorial-alignment-report))
             (spec-snapshots (.ref report 'specs))
             (source-index (.ref report 'source-index))
             (source-proof-index (.ref report 'source-proof-index))
             (status-source-matrix (.ref report 'status-source-matrix))
             (runtime-owner-matrix (.ref report 'runtime-owner-matrix))
             (handoff-readiness-summary
              (.ref report 'handoff-readiness-summary))
             (ci-receipt-manifest (.ref report 'ci-receipt-manifest))
             (user-interface-handoff-result-gate
              (.ref report 'user-interface-handoff-result-gate))
             (counts (.ref report 'status-counts)))
        (check-equal? (object? report) #t)
        (check-equal? (agentic-ai-lab-funflow-tutorial-alignment-report? report) #t)
(check-equal? (.ref report 'kind)
              (agentic-ai-lab-funflow-tutorial-alignment-report-kind))
(check-equal? (.ref report 'schema)
              (agentic-ai-lab-funflow-tutorial-alignment-schema))
        (check-equal? (.ref report 'upstream) "tweag/funflow")
        (check-equal? (.ref report 'source-count) 9)
        (check-equal? (length spec-snapshots) 9)
        (check-equal? (length source-index) 9)
        (check-equal? (length source-proof-index) 9)
        (check-equal? (length status-source-matrix) 3)
        (check-equal? (length runtime-owner-matrix) 10)
        (check-equal? (alignment-test-alist-ref counts 'result-covered) 6)
        (check-equal? (alignment-test-alist-ref counts
                                                'runtime-manifest-covered)
                      2)
        (check-equal? (alignment-test-alist-ref counts 'descriptor-covered) 1)
        (check-equal? (> (.ref report 'proof-count) 15) #t)
        (check-equal? (.ref report 'gate-count) 23)
        (check-equal? (length (.ref report 'gate-proofs)) 23)
        (check-equal? (> (.ref report 'gate-proof-count) 25) #t)
        (check-equal? (.ref report 'runtime-gap-count) 5)
        (check-equal? (.ref report 'runtime-owner) "marlin-agent-core")
        (check-equal? (alignment-test-alist-ref handoff-readiness-summary
                                                'runtime-owner)
                      "marlin-agent-core")
        (check-equal? (alignment-test-alist-ref handoff-readiness-summary
                                                'runtime-executed)
                      #f)
        (check-equal? (alignment-test-alist-ref handoff-readiness-summary
                                                'source-count)
                      9)
        (check-equal? (alignment-test-alist-ref handoff-readiness-summary
                                                'result-covered)
                      6)
        (check-equal? (alignment-test-alist-ref handoff-readiness-summary
                                                'runtime-gap-count)
                      5)
        (check-equal? (alignment-test-alist-ref handoff-readiness-summary
                                                'runtime-owner-count)
                      10)
        (check-equal? (alignment-test-alist-ref handoff-readiness-summary
                                                'handoff-required)
                      #t)
        (check-equal? (alignment-test-alist-ref ci-receipt-manifest
                                                'expected-status)
                      'pass)
        (check-equal? (alignment-test-alist-ref ci-receipt-manifest
                                                'runtime-executed)
                      #f)
        (check-equal? (alignment-test-alist-ref
                       (alignment-test-alist-ref ci-receipt-manifest
                                                 'handoff-readiness-summary)
                       'handoff-required)
                      #t)
        (check-equal? (length (alignment-test-alist-ref ci-receipt-manifest
                                                        'result-gates))
                      8)
        (check-equal? (length (alignment-test-alist-ref ci-receipt-manifest
                                                        'commands))
                      8)
        (check-equal? (not
                       (not
                        (member "gxtest t/user-interface-cicd-test.ss"
                                (alignment-test-alist-ref ci-receipt-manifest
                                                          'commands))))
                      #t)
        (check-equal? (alignment-test-alist-ref
                       user-interface-handoff-result-gate
                       'gate-id)
                      'stage-23-user-interface-marlin-handoff-projection)
        (check-equal? (alignment-test-alist-ref
                       user-interface-handoff-result-gate
                       'presentation-field)
                      'workflow-cicd-marlin-runtime-handoff-abis)
        (check-equal? (alignment-test-alist-ref
                       user-interface-handoff-result-gate
                       'bundle-field)
                      'workflow-cicd-marlin-handoff-receipt-bundle)
        (check-equal? (alignment-test-alist-ref
                       user-interface-handoff-result-gate
                       'expected-bundle-kind)
                      'workflow-cicd-marlin-handoff-receipt-bundle)
        (check-equal? (alignment-test-alist-ref
                       user-interface-handoff-result-gate
                       'runtime-owner)
                      "marlin-agent-core")
        (check-equal? (alignment-test-alist-ref
                       user-interface-handoff-result-gate
                       'runtime-executed)
                      #f)
        (check-equal? (not
                       (not
                        (member "gxi build.ss compile"
                                (alignment-test-alist-ref ci-receipt-manifest
                                                          'commands))))
                      #t)
        (check-equal? (not
                       (not
                        (member "asp org lint docs/10-19-design/10.04-funflow-tutorial-result-ladder.org"
                                (alignment-test-alist-ref ci-receipt-manifest
                                                          'commands))))
                      #t)
        (check-equal? (.ref report 'runtime-executed) #f)))))

;;; Runtime-heavy tutorial gaps remain explicit so Scheme control-plane tests do
;;; not pretend Docker, Tensorflow, C compilation, or Make are executed here.
;; : TestSuite
(def funflow-tutorial-alignment-runtime-gap-test
  (test-suite "funflow tutorial alignment runtime gaps"
    (yuanxu-test-case "keeps runtime-heavy tutorial gaps explicit"
      (let* ((report (agentic-ai-lab-funflow-tutorial-alignment-report))
             (specs (agentic-ai-lab-funflow-tutorial-alignment-specs))
             (ccompilation (alignment-test-spec-by-id 'ccompilation specs))
             (tensorflow (alignment-test-spec-by-id 'tensorflow-docker specs))
             (makefile (alignment-test-spec-by-id 'makefile-tool specs)))
        (check-equal? (not (not ccompilation)) #t)
        (check-equal? (not (not tensorflow)) #t)
        (check-equal? (not (not makefile)) #t)
        (check-equal? (.ref ccompilation 'status) 'runtime-manifest-covered)
        (check-equal? (.ref tensorflow 'status) 'descriptor-covered)
        (check-equal? (.ref makefile 'status) 'runtime-manifest-covered)
        (check-equal? (not
                       (not
                        (member 'tensorflow-docker
                                (.ref report 'deferred-ids))))
                      #t)
        (check-equal? (not
                       (not
                        (member 'summary-png (.ref tensorflow 'deferred))))
                      #t)
        (check-equal? (not
                       (not
                        (member 'real-container-execution
                                (.ref ccompilation 'deferred))))
                      #t)
        (check-equal? (not
                       (not
                        (member 'real-hello-binary-output
                                (.ref makefile 'deferred))))
                      #t)))))

;;; Source and runtime-owner indexes are tested separately because they are the
;;; lookup surface downstream diagnostics use.
;; : TestSuite
(def funflow-tutorial-alignment-index-test
  (test-suite "funflow tutorial alignment indexes"
    (yuanxu-test-case "indexes upstream sources and runtime-owned gaps"
      (let* ((report (agentic-ai-lab-funflow-tutorial-alignment-report))
             (source-index (.ref report 'source-index))
             (source-proof-index (.ref report 'source-proof-index))
             (status-source-matrix (.ref report 'status-source-matrix))
             (runtime-owner-matrix (.ref report 'runtime-owner-matrix))
             (gap-index (.ref report 'runtime-gap-index))
             (result-covered
              (alignment-test-entry-by-status 'result-covered
                                              status-source-matrix))
             (descriptor-covered
              (alignment-test-entry-by-status 'descriptor-covered
                                              status-source-matrix))
             (external-config
              (alignment-test-entry-by-source
               "funflow-tutorial/notebooks/ExternalConfig/ExternalConfig.ipynb"
               source-index))
             (external-config-proof
              (alignment-test-entry-by-source
               "funflow-tutorial/notebooks/ExternalConfig/ExternalConfig.ipynb"
               source-proof-index))
             (ccompilation-proof
              (alignment-test-entry-by-source
               "funflow-tutorial/notebooks/CCompilation/CCompilation.ipynb"
               source-proof-index))
             (docker-process
              (alignment-test-entry-by-runtime-owner 'docker-process
                                                     runtime-owner-matrix))
             (make-process
              (alignment-test-entry-by-runtime-owner 'make-process
                                                     runtime-owner-matrix))
             (tensorflow
              (alignment-test-entry-by-source
               "funflow-tutorial/notebooks/TensorflowDocker/TensorflowDocker.ipynb"
               gap-index))
             (makefile
              (alignment-test-entry-by-source
               "funflow-examples/makefile-tool/README.md"
               gap-index)))
        (check-equal? (alignment-test-alist-ref external-config 'id)
                      'external-config)
        (check-equal? (alignment-test-alist-ref external-config 'status)
                      'result-covered)
        (check-equal? (alignment-test-alist-ref external-config-proof
                                                'proof-count)
                      2)
        (check-equal? (not
                       (not
                        (member 'docker-echo
                                (alignment-test-alist-ref external-config-proof
                                                          'runtime-owned))))
                      #t)
        (check-equal? (alignment-test-alist-ref ccompilation-proof
                                                'proof-count)
                      4)
        (check-equal? (not
                       (not
                        (member 'real-cas-write
                                (alignment-test-alist-ref ccompilation-proof
                                                          'deferred))))
                      #t)
        (check-equal? (alignment-test-alist-ref docker-process 'count) 2)
        (check-equal? (alignment-test-alist-ref docker-process 'ids)
                      '(ccompilation tensorflow-docker))
        (check-equal? (alignment-test-alist-ref docker-process 'statuses)
                      '(runtime-manifest-covered descriptor-covered))
        (check-equal? (not
                       (not
                        (member "funflow-tutorial/notebooks/TensorflowDocker/TensorflowDocker.ipynb"
                                (alignment-test-alist-ref docker-process
                                                          'sources))))
                      #t)
        (check-equal? (alignment-test-alist-ref make-process 'ids)
                      '(makefile-tool))
        (check-equal? (not
                       (not
                        (member 'real-hello-binary-output
                                (alignment-test-alist-ref make-process
                                                          'deferred))))
                      #t)
        (check-equal? (alignment-test-alist-ref result-covered 'count) 6)
        (check-equal? (not
                       (not
                        (member "funflow-tutorial/notebooks/ExternalConfig/ExternalConfig.ipynb"
                                (alignment-test-alist-ref result-covered
                                                          'sources))))
                      #t)
        (check-equal? (alignment-test-alist-ref descriptor-covered 'ids)
                      '(tensorflow-docker))
        (check-equal? (not
                       (not
                        (member 'python-training
                                (alignment-test-alist-ref tensorflow
                                                          'runtime-owned))))
                      #t)
        (check-equal? (not
                       (not
                        (member 'summary-png
                                (alignment-test-alist-ref tensorflow
                                                          'deferred))))
                      #t)
        (check-equal? (alignment-test-alist-ref makefile 'status)
                      'runtime-manifest-covered)))))

;;; Result-covered tutorial proof receipts stay in their own owner so changes in
;;; proof payloads do not obscure index or gate failures.
;; : TestSuite
(def funflow-tutorial-alignment-proof-test
  (test-suite "funflow tutorial alignment proofs"
    (yuanxu-test-case "keeps proof receipts attached to result-covered tutorial specs"
      (let* ((specs (agentic-ai-lab-funflow-tutorial-alignment-specs))
             (tutorial1 (alignment-test-spec-by-id 'tutorial1 specs))
             (word-count (alignment-test-spec-by-id 'word-count specs))
             (external-config (alignment-test-spec-by-id 'external-config
                                                         specs)))
        (check-equal? (agentic-ai-lab-funflow-tutorial-alignment-spec? tutorial1)
                      #t)
        (check-equal? (.ref tutorial1 'status) 'result-covered)
        (check-equal? (.ref tutorial1 'coverage)
                      '(pure-flow runner-result))
        (check-equal? (length (.ref word-count 'proofs)) 2)
        (check-equal? (not
                       (not
                        (member 'argument-rendering
                                (.ref external-config 'coverage))))
                      #t)
        (check-equal? (not
                       (not
                        (member 'real-docker-echo-output
                                (.ref external-config 'deferred))))
                      #t)))))

;;; Late-stage gate metadata is the Stage 22 closure receipt; keep it isolated
;;; from tutorial source coverage assertions.
;; : TestSuite
(def funflow-tutorial-alignment-gate-test
  (test-suite "funflow tutorial alignment gates"
    (yuanxu-test-case "keeps late-stage proof gates visible in report metadata"
      (let* ((report (agentic-ai-lab-funflow-tutorial-alignment-report))
             (gate-ids (.ref report 'gate-ids))
             (gate-proofs (.ref report 'gate-proofs))
             (stage19 (alignment-test-gate-proof-by-id
                       'stage-19-runtime-manifest-consumer
                       gate-proofs))
             (stage20 (alignment-test-gate-proof-by-id
                       'stage-20-functional-flow-kernel-and-macro-authoring
                       gate-proofs))
             (stage21 (alignment-test-gate-proof-by-id
                       'stage-21-workflow-module-macro-authoring
                       gate-proofs))
             (stage22 (alignment-test-gate-proof-by-id
                       'stage-22-poo-tutorial-alignment-report
                       gate-proofs))
             (stage23 (alignment-test-gate-proof-by-id
                       'stage-23-user-interface-marlin-handoff-projection
                       gate-proofs)))
        (check-equal? (not
                       (not
                        (member 'stage-19-runtime-manifest-consumer
                                gate-ids)))
                      #t)
        (check-equal? (not
                       (not
                        (member 'stage-20-functional-flow-kernel-and-macro-authoring
                                gate-ids)))
                      #t)
        (check-equal? (not
                       (not
                        (member 'stage-21-workflow-module-macro-authoring
                                gate-ids)))
                      #t)
        (check-equal? (not
                       (not
                        (member 'stage-22-poo-tutorial-alignment-report
                                gate-ids)))
                      #t)
        (check-equal? (not
                       (not
                        (member
                         'stage-23-user-interface-marlin-handoff-projection
                         gate-ids)))
                      #t)
        (check-equal? (not (not stage19)) #t)
        (check-equal? (not (not stage23)) #t)
        (check-equal? (not
                       (not
                        (member "gxtest t/runtime-manifest-test.ss: runtime command manifest consumer executes stdout protocol"
                                (alignment-test-alist-ref stage19 'proofs))))
                      #t)
        (check-equal? (not
                       (not
                        (member "gxtest t/functional-flow-kernel-test.ss: functional flow kernel"
                                (alignment-test-alist-ref stage20 'proofs))))
                      #t)
        (check-equal? (length (alignment-test-alist-ref stage21 'proofs)) 2)
        (check-equal? (alignment-test-alist-ref stage22 'proofs)
                      '("gxtest t/funflow-tutorial-alignment-report-test.ss: funflow tutorial alignment report"))
        (check-equal? (alignment-test-alist-ref stage23 'proofs)
                      '("gxtest t/user-interface-cicd-test.ss: projects user config into Marlin runtime handoff ABI"
                        "gxtest t/funflow-tutorial-alignment-report-test.ss: user-interface Marlin handoff result gate"))))))

;;; Aggregate export preserves the historical test symbol while keeping parser
;;; owner spans small enough for R007.
;; : TestSuite
(def funflow-tutorial-alignment-report-test
  (test-suite "funflow tutorial alignment report"
    funflow-tutorial-alignment-report-shape-test
    funflow-tutorial-alignment-runtime-gap-test
    funflow-tutorial-alignment-index-test
    funflow-tutorial-alignment-proof-test
    funflow-tutorial-alignment-gate-test))
