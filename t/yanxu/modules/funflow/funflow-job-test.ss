;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test (only-in :clan/poo/object .get .ref/cached .call .slot? .cc .def .o)
        :tao3k/yuanxu/syntax/path-slots
        :tao3k/agentic-ai-lab/modules/funflow/objects
        (only-in :tao3k/agentic-ai-lab/modules/funflow/config Config)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/types FunflowScopeContract)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/signatures validate)
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case))
(export funflow-job-test)
(.def (Deployment @ Job.)
  name: 'deployment
  tasks:
  (.o init: (.o (:: @ Task.) command: '("printf" "init"))
      validate: (.o (:: @ Task.) needs: '(init) command: '("printf" "validated"))
      deploy: (.o (:: @ Task.) needs: '(validate) command: '("printf" "deployed"))
      unused: (error "unselected task must remain lazy"))
  selected: '(deploy))
(def funflow-job-test
  (test-suite "Core Funflow declarative Job to Ops"
    (yuanxu-test-case "public Scope admits its actual Job configuration"
      (def scope
        (validate FunflowScopeContract
          (.o (:: @ FunflowModule.) config: Config)))
      (check-equal? (.get scope config selected) '())
      (check-equal? (.get scope config finalizers) '()))
    (yuanxu-test-case "Graph projection is inert and orders the selected dependency closure"
      (check-equal? (.get Deployment graph order) '(init validate deploy))
      (check-equal? (.ref/cached (.get Deployment tasks) 'unused) #f))
    (yuanxu-test-case "ready tasks retain FIFO order across independent branches"
      (.def (Parallel @ Deployment)
        tasks: =>.+
        (.o audit: (.o (:: @ Task.) command: '("printf" "audit"))
            report: (.o (:: @ Task.) needs: '(audit) command: '("printf" "report")))
        selected: '(deploy report))
      (check-equal? (.get Parallel graph order) '(init audit validate report deploy)))
    (yuanxu-test-case "parent Graph cached before child refinement uses final tasks"
      (def parent (.get Deployment graph))
      (.def (Release @ Deployment) tasks.deploy: =>.+ (.o command: '("printf" "release")))
      (call-with-temporary-directory "funflow-job"
        (lambda (workspace)
          (def receipt (.call Release .run workspace))
          (check-equal? (.get receipt steps validate output) "validated")
          (check-equal? (.get receipt steps deploy output) "release")
          (check-equal? (.get Deployment tasks deploy command) '("printf" "deployed"))
          (check-equal? (.ref/cached (.get Release tasks) 'unused) #f))))
    (yuanxu-test-case "failed validation prevents deployment"
      (call-with-temporary-directory "funflow-failure"
        (lambda (workspace)
          (def marker (path-expand "deployed" workspace))
          (.def (Rejected @ Deployment)
            tasks.validate: =>.+ (.o command: '("false"))
            tasks.deploy: =>.+ (.o command: (list "touch" marker)))
          (check-exception (.call Rejected .run workspace) error?)
          (check-equal? (file-exists? marker) #f))))
    (yuanxu-test-case "cycle, missing dependency and invalid command fail before effects"
      (.def (Cycle @ Deployment) tasks.init: =>.+ (.o needs: '(deploy)))
      (.def (Missing @ Deployment) tasks.deploy: =>.+ (.o needs: '(absent)))
      (.def (Invalid @ Deployment) tasks.deploy: =>.+ (.o command: '("printf" 1)))
      (.def (Unchecked @ Deployment) tasks.validate: =>.+ (.o check-status: #f))
      (.def (NotRunnable @ Deployment)
        tasks.deploy: =>.+ (.cc (.get Deployment tasks deploy) '.run #f))
      (for-each (lambda (job) (check-exception (.call job .run ".") error?))
                (list Cycle Missing Invalid Unchecked NotRunnable)))
    (yuanxu-test-case "finalizer runs after attempted deployment, including process failure"
      (.def (Recovering @ Deployment)
        finalizers: '(cleanup)
        tasks: =>.+
        (.o deploy: =>.+ (.o command: '("false"))
            cleanup: (.o (:: @ Task.) after-start: 'deploy command: '("touch" "cleaned"))))
      (call-with-temporary-directory "funflow-finalizer"
        (lambda (workspace)
          (check-exception (.call Recovering .run workspace) error?)
          (check-equal? (file-exists? (path-expand "cleaned" workspace)) #t)))
      (.def (EarlyFailure @ Recovering)
        tasks.validate: =>.+ (.o command: '("false")))
      (call-with-temporary-directory "funflow-no-finalizer"
        (lambda (workspace)
          (check-exception (.call EarlyFailure .run workspace) error?)
          (check-equal? (file-exists? (path-expand "cleaned" workspace)) #f))))))
