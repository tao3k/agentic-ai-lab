;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Exercise extension executors and inert external requests through real Types.
(import :std/test
        (only-in :clan/poo/mop Fun Type Any TypeError? validate)
        (only-in :clan/poo/type String Unit)
        (only-in :clan/poo/number Integer)
        (only-in :agentic-ai-lab/services Services)
        (only-in :agentic-ai-lab/modules/workflow/runtime/runtime-v0-native native-abi-version)
        (only-in :agentic-ai-lab/modules/workflow/runtime/semantic semantic-call)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :yuanxu/modules/funflow/control-plane/task
                 make-pure-task task-input-contract task-output-contract task-executor)
        (only-in :agentic-ai-lab/modules/custom-task/funs make-custom-repeat-task)
        (only-in :agentic-ai-lab/modules/text/funs make-word-count-task)
        (only-in :agentic-ai-lab/modules/docker/funs make-docker-task)
        (only-in :agentic-ai-lab/modules/agent-sandbox/api make-agent-sandbox-task)
        (only-in :agentic-ai-lab/modules/workflow/flows-builders
                 make-ccompilation-store-workflow make-tensorflow-workflow make-makefile-tool-workflow)
        (only-in :yuanxu/modules/funflow/control-plane/flow flow-input-contract flow-output-contract)
        (only-in :agentic-ai-lab/modules/search-engine/funs
                 agentic-ai-lab-search-stage agentic-ai-lab-search-chain agentic-ai-lab-search-node-flow)
        (only-in :agentic-ai-lab/modules/search-engine/objects agentic-ai-lab-search-acquisition-role)
        (only-in :yuanxu/modules/funflow/control-plane/runtime-protocol AdapterResult))
(export task-signature-test)
(def task-signature-test
  (test-suite "Extension native Task boundaries"
    (yuanxu-test-case "installed FFI facades load through their complete native import closure"
      (check-equal? (procedure? native-abi-version) #t)
      (check-equal? (procedure? semantic-call) #t))
    (yuanxu-test-case "the installed shared Services boundary is a native Type"
      (check-eq? (validate Type Services) Services))
    (yuanxu-test-case "local executors enforce actual input and output Types"
      (def repeat (make-custom-repeat-task 'repeat "." 2))
      (check-equal? ((task-executor repeat) "a") "a..")
      (check-exception ((task-executor repeat) 1) TypeError?)
      (def wrong-result (make-pure-task 'wrong-result (Fun Integer <- String) (lambda (value) value)))
      (check-exception ((task-executor wrong-result) "a") TypeError?)
      (def words (make-word-count-task 'words))
      (check-equal? ((task-executor words) "one one") "one: 2")
      (check-exception ((task-executor words) 1) TypeError?)
      (check-exception (make-pure-task 'labels '(text -> text) values) TypeError?))
    (yuanxu-test-case "external tasks retain Types while remaining inert"
      (def docker (make-docker-task 'docker "busybox" "echo" '("ok") '() 'stdout (Fun AdapterResult <- String)))
      (def sandbox
        (make-agent-sandbox-task 'sandbox 'nono 'nono "echo" '("ok") '() "."
                                '() '() '() '() 'stdout '() (Fun AdapterResult <- String)))
      (for-each
        (lambda (task)
          (check-eq? (task-input-contract task) String)
          (check-eq? (task-output-contract task) AdapterResult)
          (check-equal? (task-executor task) #f))
        (list docker sandbox)))
    (yuanxu-test-case "workflow composition retains concrete module-owned Function Types"
      ;; No Docker or makefile effect runs while composing these native values.
      (for-each
        (lambda (build input-type)
          (def flow (build 'typed))
          (check-eq? (flow-input-contract flow) input-type)
          (check-eq? (flow-output-contract flow) AdapterResult))
        (list make-ccompilation-store-workflow make-tensorflow-workflow make-makefile-tool-workflow)
        (list Integer Unit Any)))
    (yuanxu-test-case "Search evidence domains remain distinct from callable Types"
      (def stage
        (agentic-ai-lab-search-stage 'source 'acquire '() 'source 'result
                                    agentic-ai-lab-search-acquisition-role))
      (def wrong
        (agentic-ai-lab-search-stage 'other 'acquire '() 'other 'result
                                    agentic-ai-lab-search-acquisition-role))
      (def flow (agentic-ai-lab-search-node-flow stage))
      (check-eq? (flow-input-contract flow) Any)
      (check-eq? (flow-output-contract flow) AdapterResult)
      (check-exception (agentic-ai-lab-search-chain 'wrong (list stage wrong)) error?))))
