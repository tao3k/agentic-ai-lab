;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Exercise extension executors and inert external requests through real Types.
(import :std/test
        (only-in :clan/poo/mop TypeError?)
        (only-in :clan/poo/type String Integer)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :yuanxu/modules/funflow/control-plane/task
                 task-input-contract task-output-contract task-executor)
        (only-in :agentic-ai-lab/modules/custom-task/funs make-custom-repeat-task)
        (only-in :agentic-ai-lab/modules/text/funs make-word-count-task)
        (only-in :agentic-ai-lab/modules/docker/funs make-docker-task)
        (only-in :agentic-ai-lab/modules/agent-sandbox/api make-agent-sandbox-task))
(export task-signature-test)
(def task-signature-test
  (test-suite "Extension native Task boundaries"
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
        (list docker sandbox)))))
