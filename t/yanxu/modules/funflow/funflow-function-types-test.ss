;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test :clan/poo/object
        (only-in :std/error Error?)
        (only-in :clan/poo/type TypeError?)
        (only-in :clan/poo/table table-styles)
        (only-in :clan/poo/table/rationaldict RationalDict)
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/api
        (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case))
(export funflow-function-types-test)

(def (local-run flow input)
  (run-result-value
    (runner-run (make-runner (make-local-eager-strategy) (make-request-only-adapter)) flow input)))

(def funflow-function-types-test
  (test-suite "Funflow runtime Function submission through runtime handoff"
    (yuanxu-test-case "submitted operation checks arguments before its body and output before the next step"
      (def entered 0)
      (def downstream 0)
      (def bad (flow-arr 'bad (Fun Integer <- Integer)
                 (lambda (_value) (set! entered (+ entered 1)) "wrong result")))
      (def next (flow-arr 'next (Fun Integer <- Integer)
                  (lambda (value) (set! downstream (+ downstream 1)) value)))
      (check-exception (local-run bad "wrong argument") TypeError?)
      (check-equal? entered 0)
      (check-exception (local-run (flow-then 'pipeline bad next) 1) TypeError?)
      (check-equal? entered 1)
      (check-equal? downstream 0))
    (yuanxu-test-case "composition rejects mismatched real Types during declaration"
      (def number (flow-arr 'number (Fun Integer <- Integer) identity))
      (def text (flow-arr 'text (Fun String <- String) identity))
      (check-exception (flow-then 'invalid number text) Error?)
      (check-equal? (local-run (flow-then 'valid number number) 8) 8))
    (yuanxu-test-case "direct and derived Flow values retain the actual route signature"
      (def task (make-pure-task 'identity (Fun Integer <- Integer) identity))
      (check-exception (make-flow 'wrong (list task) (Fun String <- Integer)) TypeError?)
      (def source (task-flow 'source task))
      (check (element? (FlowOf Integer String) source) => #f)
      (def changed (.cc source signature: (Fun String <- Integer)))
      (check-exception (local-run changed 1) TypeError?))
    (yuanxu-test-case "derived Category callbacks are runtime checked functions"
      (def category (.cc default-flow-category 'arr (lambda (_name _signature _body) 7)))
      (check-exception (flow-category-arr category 'invalid (Fun Integer <- Integer) identity) TypeError?))
    (yuanxu-test-case "recovery validates the selected result without swallowing Type errors"
      (def runner (make-runner (make-local-eager-strategy) (make-request-only-adapter)))
      (def failed (throw-string-flow 'failed "recover" (Fun Integer <- Integer)))
      (check-equal? (runner-run-value-or-recover runner failed 1 Integer (lambda (_failure) 7)) 7)
      (check-exception
        (runner-run-value-or-recover runner failed 1 Integer (lambda (_failure) "wrong")) TypeError?)
      (def entered 0)
      (def bad (flow-arr 'bad (Fun Integer <- Integer) (lambda (_input) "wrong")))
      (check-exception
        (runner-run-value-or-recover runner bad 1 Integer
          (lambda (_failure) (set! entered (+ entered 1)) 7)) TypeError?)
      (check-equal? entered 0))
    (yuanxu-test-case "a returned callback retains its runtime Function boundary"
      (def entered 0)
      (def callback (Fun Integer <- Integer))
      (def factory
        (flow-arr 'factory (Fun callback <- Integer)
          (lambda (offset)
            (lambda (value) (set! entered (+ entered 1)) (+ value offset)))))
      (def operation (local-run factory 3))
      (check-exception (operation "wrong") TypeError?)
      (check-equal? entered 0)
      (check-equal? (operation 4) 7))
    (yuanxu-test-case "runtime Sum retains a returned checked callback"
      (def entered 0)
      (def source
        (flow-arr 'factory (Fun (Fun Integer <- Integer) <- Integer)
          (lambda (offset)
            (lambda (value) (set! entered (+ entered 1)) (+ offset value)))))
      (def result (local-run (try-flow 'attempt source) 3))
      (check (try-right? result) => #t)
      (def callback (try-result-value result))
      (check-exception (callback "wrong") TypeError?)
      (check-equal? entered 0)
      (check-equal? (callback 4) 7))
    (yuanxu-test-case "DAG type descriptions contain data rather than private catalog tokens"
      (def source (flow-arr 'identity (Fun Integer <- Integer) identity))
      (def report (flow->dag-receipt (try-flow 'attempt source)))
      (check-equal? (read (open-input-string (object->string report))) report))
    (yuanxu-test-case "opaque Types retain identity and external fanout uses actual adapter results"
      (def first (.cc Type. sexp: 'Opaque '.element? integer?))
      (def second (.cc Type. sexp: 'Opaque '.element? string?))
      (check (type-flows? first second) => #f)
      (check (type-flows? first Any) => #t)
      (def left (external-flow 'left 'submit '() (Fun AdapterResult <- Integer)))
      (def right (external-flow 'right 'submit '() (Fun AdapterResult <- Integer)))
      (def result (local-run (flow-fanout 'both left right) 1))
      (check-equal? (length result) 2)
      (check (every adapter-result? result) => #t))
    (yuanxu-test-case "conditional and cache callbacks use their actual signatures"
      (def entered 0)
      (def conditional
        (conditional-flow 'choose (Fun Integer <- Integer)
          (lambda (_value) 'truthy)
          (lambda (value) (set! entered (+ entered 1)) value) identity))
      (check-exception (local-run conditional 1) TypeError?)
      (check-equal? entered 0)
      (def cached
        (cached-pure-flow 'cached (Fun Integer <- Integer) String
          (lambda (_value) 7) identity))
      (check-exception (local-run cached 1) TypeError?))
    (yuanxu-test-case "Kleisli validates returned Flow signatures before executing the selected body"
      (def entered 0)
      (def source (flow-arr 'source (Fun Integer <- Integer) identity))
      (def bound
        (flow-bind 'bound source Integer
          (lambda (_value)
            (flow-arr 'wrong (Fun String <- Integer)
              (lambda (_input) (set! entered (+ entered 1)) "wrong")))))
      (check-exception (local-run bound 1) Error?)
      (check-equal? entered 0)
      (check-equal?
        (local-run (flow-bind 'valid source Integer
                     (lambda (offset) (flow-arr 'add (Fun Integer <- Integer) (cut + offset <>)))) 4)
        8))
    (yuanxu-test-case "a POO override is admitted as the actual Task value"
      (def entered 0)
      (def original (make-pure-task 'original (Fun Integer <- Integer) identity))
      (def changed (.cc original 'executor
                      (lambda (_input) (set! entered (+ entered 1)) "wrong")))
      (def flow (task-flow 'derived changed))
      (check-exception (local-run flow 1) TypeError?)
      (check-equal? entered 1))
    (yuanxu-test-case "runtime adapter validates its real request and returned result"
      (def entered 0)
      (def (bad _request) (set! entered (+ entered 1)) 7)
      (def adapter (make-runtime-adapter 'invalid '(external) bad bad bad bad))
      (check-exception (adapter-submit adapter "wrong request") TypeError?)
      (check-equal? entered 0)
      (def remote (external-flow 'remote 'submit '() (Fun AdapterResult <- Integer)))
      (check-exception
        (runner-run (make-runner (make-local-eager-strategy) adapter) remote 1) TypeError?)
      (check-equal? entered 1))
    (yuanxu-test-case "runtime decoder failure retains its original Type error"
      (def command
        (make-process-runtime-command 'decode "/bin/echo" '("value")
          (lambda (_envelope _stdout) 7)))
      (def result
        (runtime-command-result command
          (list (cons 'schema +runtime-request-schema+) (cons 'request-id 'request))))
      (check-equal? (adapter-result-status result) 'failed)
      (check (TypeError? (runtime-alist-ref (adapter-result-error result) 'error #f)) => #t))
    (yuanxu-test-case "all 25 runtime table style transfers retain admitted Function identity"
      (def callback (local-run (flow-arr 'identity (Fun (Fun Integer <- Integer) <- Integer)
                               (lambda (offset) (cut + offset <>))) 2))
      (def table (RationalDict (Fun Integer <- Integer)))
      (def styles (table-styles table))
      (def admitted (validate table (.call table .<-list (list (cons 1 callback)))))
      (def retained (.call table .ref admitted 1))
      (for-each
        (lambda (source-name)
          (for-each
            (lambda (target-name)
              (def source (.ref styles source-name))
              (def target (.ref styles target-name))
              (def owned (.call source .ap admitted))
              (def next (.call source .convert owned
                          (case target-name
                            ((Pure) 'pure) ((Mutable) 'mutable) ((Linear) 'linear)
                            ((Posh) 'posh) ((Classy) 'classy))))
              (def snapshot (.call target .unap next))
              (check-eq? snapshot admitted)
              (check-eq? (.call table .ref snapshot 1) retained)
              (check-equal? (retained 3) 5)
              (check-exception (retained "wrong") TypeError?))
            '(Pure Mutable Linear Posh Classy)))
        '(Pure Mutable Linear Posh Classy)))))
