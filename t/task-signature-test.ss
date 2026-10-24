;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Exercise extension executors and inert external requests through real Types.
(import :std/test
        (only-in :clan/poo/mop Type TypeError? validate)
        (only-in :clan/poo/type String)
        (only-in :clan/poo/number Integer)
        (only-in :agentic-ai-lab/modules/services/types Services)
        (only-in :agentic-ai-lab/modules/workflow/runtime/runtime-v0-native native-abi-version)
        (only-in :agentic-ai-lab/modules/workflow/runtime/semantic semantic-call)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :yuanxu/modules/funflow/control-plane/task
                 task-input-contract task-output-contract task-executor)
        (only-in :agentic-ai-lab/modules/custom-task/funs make-custom-repeat-task)
        (only-in :agentic-ai-lab/modules/text/funs make-word-count-task)
        (only-in :agentic-ai-lab/modules/docker/funs make-docker-task)
        (only-in :agentic-ai-lab/modules/agent-sandbox/api make-agent-sandbox-task)
        (only-in :agentic-ai-lab/modules/workflow/flows-builders
                 make-ccompilation-store-workflow make-tensorflow-workflow make-makefile-tool-workflow)
        (only-in :yuanxu/modules/funflow/control-plane/flow flow-input-contract flow-output-contract)
        (only-in :agentic-ai-lab/modules/search-engine/funs agentic-ai-lab-search-stage agentic-ai-lab-search-chain)
        (only-in :agentic-ai-lab/modules/search-engine/objects agentic-ai-lab-search-acquisition-role))
(export task-signature-test)
(def task-signature-test
  (test-suite "Extension native Task boundaries"
    (yuanxu-test-case "installed FFI facades load through their complete native import closure"
      (check-equal? (procedure? native-abi-version) #t)
      (check-equal? (procedure? semantic-call) #t))
    (yuanxu-test-case "the installed shared Services boundary is a native Type"
      (check-eq? (validate Type Services) Services))
    (yuanxu-test-case "local executors enforce actual input and output Types"
      (def repeat (make-custom-repeat-task 'repeat "." 2 String String))
      (check-equal? ((task-executor repeat) "a") "a..")
      (check-exception ((task-executor repeat) 1) TypeError?)
      (def wrong-result (make-custom-repeat-task 'repeat "." 2 String Integer))
      (check-exception ((task-executor wrong-result) "a") TypeError?)
      (def words (make-word-count-task 'words String String))
      (check-equal? ((task-executor words) "one one") "one: 2")
      (check-exception ((task-executor words) 1) TypeError?)
      (check-exception (make-word-count-task 'words 'text String) TypeError?))
    (yuanxu-test-case "external tasks retain Types while remaining inert"
      (def docker (make-docker-task 'docker "busybox" "echo" '("ok") '() 'stdout String String))
      (def sandbox
        (make-agent-sandbox-task 'sandbox 'nono 'nono "echo" '("ok") '() "."
                                '() '() '() '() 'stdout '() String String))
      (for-each
        (lambda (task)
          (check-eq? (task-input-contract task) String)
          (check-eq? (task-output-contract task) String)
          (check-equal? (task-executor task) #f))
        (list docker sandbox)))
    (yuanxu-test-case "workflow composition consumes caller-selected boundary Types"
      ;; These are type-composition controls; no Docker or makefile effect runs.
      (for-each
        (lambda (build)
          (def flow (build 'typed String Integer String))
          (check-eq? (flow-input-contract flow) String)
          (check-eq? (flow-output-contract flow) String))
        (list make-ccompilation-store-workflow make-tensorflow-workflow make-makefile-tool-workflow)))
    (yuanxu-test-case "Search delegates actual Type edge admission to Core"
      (def stage
        (agentic-ai-lab-search-stage 'source 'acquire '() String Integer
                                    agentic-ai-lab-search-acquisition-role))
      (def wrong
        (agentic-ai-lab-search-stage 'other 'acquire '() String String
                                    agentic-ai-lab-search-acquisition-role))
      (check-exception (agentic-ai-lab-search-chain 'wrong (list stage wrong)) error?)
      (check-exception
        (agentic-ai-lab-search-stage 'source 'acquire '() 'source 'result
                                    agentic-ai-lab-search-acquisition-role) TypeError?))))
