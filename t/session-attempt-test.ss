;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :clan/poo/object .o .ref)
        :agentic-ai-lab/modules/session/types
        :agentic-ai-lab/modules/session/objects-attempt
        :agentic-ai-lab/modules/session/funs-attempt)
(export session-attempt-test)
(def input-ref (.o (:: @ SessionInputRef.) producer: "context" contract: "v1" identity: "projection"
  digest: "content" scope-digest: "scope" source-vector-digest: "source" query-digest: "query"
  restriction-digest: "restriction" profile-digest: "profile" receipt-ref: "receipt" consumer-session: "session" consumer-turn: 0 complete?: #t))
(def task (.o (:: @ SessionTask.) identity: "task" input: input-ref anchor-refs: '("org:property-id")))
(def (claim state expected (attempt "attempt:0"))
  (agentic-ai-lab-session-claim state expected task attempt "request" 0))
(def (running) (.ref (claim (agentic-ai-lab-session-schedule "session") 0) 'schedule))
(def session-attempt-test
  (test-suite "Session exact Attempt routing and recovery intents"
    (yuanxu-test-case "textual Session and Org anchor references preserve exact input"
      (let* ((state (running)) (a (.ref state 'active)))
        (check (agentic-ai-lab-session-schedule-shape? state) => #t)
        (check (.ref a 'session) => "session")
        (check (.ref a 'anchor-refs) => '("org:property-id"))
        (check (.ref (.ref a 'input) 'digest) => "content")
        (check (.ref (claim (agentic-ai-lab-session-schedule "session") 0) 'runtime-published?) => #f)))
    (yuanxu-test-case "claimed input is copied before source proposal mutation"
      (let* ((mutable-name (string-copy "session"))
             (proposal (.o (:: @ input-ref) consumer-session: mutable-name))
             (task-value (.o (:: @ task) input: proposal))
             (r (agentic-ai-lab-session-claim (agentic-ai-lab-session-schedule "session") 0
                    task-value "attempt" "request" 0)))
        (string-set! mutable-name 0 #\x)
        (check (.ref (.ref (.ref (.ref r 'schedule) 'active) 'input) 'consumer-session) => "session")))
    (yuanxu-test-case "wrong request, Task, Turn and input cannot complete another Attempt"
      (let* ((state (running)) (a (.ref state 'active)))
        (for-each (lambda (wrong)
          (check (.ref (agentic-ai-lab-session-complete state 1 wrong) 'reason) => 'wrong-attempt))
          (list (.o (:: @ a) request: "other") (.o (:: @ a) task: "other")
                (.o (:: @ a) turn: 1) (.o (:: @ a) generation: 0)
                (.o (:: @ a) session: "foreign") (.o (:: @ a) anchor-refs: '("other"))
                (.o (:: @ a) input: (.o (:: @ input-ref) source-vector-digest: "new"))))))
    (yuanxu-test-case "foreign consumer and Turn cannot claim input"
      (let (state (agentic-ai-lab-session-schedule "foreign"))
        (check (.ref (claim state 0) 'reason) => 'wrong-consumer))
      (check (.ref (agentic-ai-lab-session-claim (agentic-ai-lab-session-schedule "session") 0
                    task "attempt" "request" 1) 'reason) => 'wrong-consumer))
    (yuanxu-test-case "completion is once per Attempt and owner revision"
      (let* ((state (running)) (a (.ref state 'active))
             (r (agentic-ai-lab-session-complete state 1 a)) (next (.ref r 'schedule)))
        (check (.ref r 'accepted?) => #t)
        (check (.ref r 'action-authorized?) => #f)
        (check (.ref (agentic-ai-lab-session-complete next 1 a) 'reason) => 'stale-revision)
        (check (.ref (claim next 2) 'reason) => 'attempt-reuse-or-capacity)))
    (yuanxu-test-case "recovery preserves obligations and fences late completion"
      (let* ((state (running)) (a (.ref state 'active))
             (recovered (.ref (agentic-ai-lab-session-recover state 1) 'schedule))
             (again (.ref (agentic-ai-lab-session-recover recovered 2) 'schedule)))
        (check (.ref recovered 'status) => 'recovering)
        (check (.ref recovered 'generation) => 2)
        (check (.ref again 'generation) => 3)
        (check (.ref again 'obligations) => (list a))
        (check (.ref (agentic-ai-lab-session-complete recovered 2 a) 'reason) => 'wrong-attempt)
        (check (.ref (claim recovered 2 "retry") 'reason) => 'not-idle)
        (check (.ref (agentic-ai-lab-session-close recovered 2) 'reason) => 'pending-obligation)
        (check (.ref (agentic-ai-lab-session-reconcile recovered 2 (.o (:: @ a) request: "foreign")) 'reason)
          => 'wrong-obligation)))
    (yuanxu-test-case "reconciliation proposes fresh retry without accepting old completion"
      (let* ((state (running)) (a (.ref state 'active))
             (recovered (.ref (agentic-ai-lab-session-recover state 1) 'schedule))
             (r (agentic-ai-lab-session-reconcile recovered 2 a))
             (ready (.ref r 'schedule)) (retry (.ref (claim ready 3 "retry") 'schedule)))
        (check (.ref r 'durable?) => #f)
        (check (.ref retry 'generation) => 3)
        (check (.ref (agentic-ai-lab-session-complete retry 4 a) 'reason) => 'wrong-attempt)
        (check (agentic-ai-lab-session-schedule-shape? retry) => #t)))
    (yuanxu-test-case "closed Session cannot recover and exhausted coordinates cannot wrap"
      (let* ((state (agentic-ai-lab-session-schedule "session"))
             (closed (.ref (agentic-ai-lab-session-close state 0) 'schedule)))
        (check (.ref (agentic-ai-lab-session-recover closed 1) 'reason) => 'closed)
        (check (.ref (claim (.o (:: @ state) generation: 65535) 0) 'reason) => 'coordinate-exhausted)))))
