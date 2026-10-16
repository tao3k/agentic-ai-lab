;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test (only-in :core/observability/testing-case poo-flow-test-case)
        (only-in :clan/poo/object .o .ref)
        :poo-flow/modules/ai-agentic-context/objects
        :poo-flow/modules/ai-agentic-context/funs-features
        :poo-flow/modules/ai-agentic-context/session-host
        :poo-flow/modules/ai-agentic-context/use-host
        :poo-flow/modules/temporal-causality/truth-maintenance/support/policy-host
        :poo-flow/modules/temporal-causality/truth-maintenance/support/policy
        (only-in :poo-flow/modules/temporal-causality/time/objects poo-flow-temporal-instant)
        :poo-flow/modules/query/semantic/context-restriction)
(export ai-agentic-context-session-host-test)
(def (at n) (poo-flow-temporal-instant "time" "clock" n "host" 'observed))
(def policy (poo-flow-temporal-support-policy "policy" "revision" (at 0) (at 8)))
(def contract (poo-flow-context-use-contract "actor" "task" "context-policy" '() '() #t))
(def (grant generation enabled)
  (poo-flow-context-use-grant "grant" generation "manifest" "admission" contract "policy"
    (.ref policy 'semantic-digest) '(display) enabled))
(def scope (.o (:: @ AiAgenticContextScope.) bundle: "bundle" organization: "org" epoch: 1
  project: "project" worktree: "worktree" source-cut: "cut:0" actor: "actor" task: "task"
  destination: "provider" session: "session" turn: 0))
(def source "* TODO Work\n:PROPERTIES:\n:ID: work\n:END:\n")
(def changed "* TODO Changed\n:PROPERTIES:\n:ID: work\n:END:\n")
(def restriction (poo-flow-context-restriction "domain" '("actor") '("provider") '("org") 0 8))
(def (setup)
  (let* ((grants (poo-flow-context-use-host)) (policies (poo-flow-temporal-support-policy-host))
         (host (poo-flow-ai-agentic-context-session-host grants policies #f)))
    (poo-flow-temporal-support-policy-host-refresh! policies policy 0 (at 1))
    (poo-flow-context-use-host-refresh! grants (grant 1 #t))
    (poo-flow-ai-agentic-context-session-host-enroll! host 0 source scope restriction
      (poo-flow-ai-agentic-context-profile #f) 0 '("work") "grant" 1)
    (values host grants policies)))
(def (claim host revision cut)
  (poo-flow-ai-agentic-context-session-host-claim! host "session" revision cut "attempt" "request"))
(def ai-agentic-context-session-host-test
  (test-suite "Serialized native Context Session claim owner"
    (poo-flow-test-case "claim commits once at exact owner and source revisions"
      (let-values (((host grants policies) (setup)))
        (let (r (claim host 0 0))
          (check (.ref r 'accepted?) => #t)
          (check (.ref r 'runtime-published?) => #t)
          (check (.ref r 'provider-disclosed?) => #f)
          (check (.ref r 'provider-result-admitted?) => #f)
          (check (.ref (.ref r 'schedule) 'revision) => 1))
        (check (.ref (claim host 0 0) 'reason) => 'stale-revision)
        (check (.ref (claim host 1 0) 'reason) => 'not-idle)))
    (poo-flow-test-case "valid source refresh fences old claim and preserves pending Attempt"
      (let-values (((host grants policies) (setup)))
        (claim host 0 0)
        (let* ((r (poo-flow-ai-agentic-context-session-host-refresh! host "session" 0 1 changed
                      (.o (:: @ scope) source-cut: "cut:1")))
               (schedule (.ref r 'schedule)))
          (check (.ref schedule 'revision) => 2)
          (check (.ref schedule 'generation) => 2)
          (check (.ref schedule 'active) => #f)
          (check (length (.ref schedule 'obligations)) => 1)
          (check (.ref (car (.ref schedule 'obligations)) 'identity) => "attempt")
          (check (.ref (claim host 2 0) 'reason) => 'stale-source)
          (check (.ref (claim host 2 1) 'reason) => 'not-idle))))
    (poo-flow-test-case "anchor deletion blocks current input while publishing source invalidation"
      (let-values (((host grants policies) (setup)))
        (claim host 0 0)
        (let (r (poo-flow-ai-agentic-context-session-host-refresh! host "session" 0 1 "* TODO No ID\n"
                    (.o (:: @ scope) source-cut: "cut:1")))
          (check (.ref r 'runtime-published?) => #t)
          (check (.ref r 'reason) => 'source-blocked)
          (check (.ref r 'task) => #f)
          (check (length (.ref (.ref r 'schedule) 'obligations)) => 1)
          (check (.ref (claim host 2 1) 'reason) => 'source-blocked))))
    (poo-flow-test-case "source refresh CAS and fixed Scope reject substitution before mutation"
      (let-values (((host grants policies) (setup)))
        (check-exception (poo-flow-ai-agentic-context-session-host-refresh! host "session" 1 2 changed scope) true)
        (check-exception (poo-flow-ai-agentic-context-session-host-refresh! host "session" 0 1 changed
                          (.o (:: @ scope) destination: "foreign")) true)
        (check (.ref (poo-flow-ai-agentic-context-session-host-current host "session") 'source-generation) => 0)
        (check (.ref (claim host 0 0) 'accepted?) => #t)))
    (poo-flow-test-case "grant generation revocation and current policy expiry deny publication"
      (let-values (((host grants policies) (setup)))
        (poo-flow-context-use-host-refresh! grants (grant 2 #t))
        (check (.ref (claim host 0 0) 'reason) => 'current-grant-denied)
        (poo-flow-context-use-host-refresh! grants (grant 3 #f))
        (check (.ref (claim host 0 0) 'reason) => 'current-grant-denied))
      (let-values (((host grants policies) (setup)))
        (poo-flow-temporal-support-policy-host-refresh! policies policy 1 (at 8))
        (check (.ref (claim host 0 0) 'reason) => 'current-grant-denied)))
    (poo-flow-test-case "Context restriction is rechecked at the current Host clock"
      (let* ((grants (poo-flow-context-use-host)) (policies (poo-flow-temporal-support-policy-host))
             (host (poo-flow-ai-agentic-context-session-host grants policies #f))
             (short (poo-flow-context-restriction "domain" '("actor") '("provider") '("org") 0 3)))
        (poo-flow-temporal-support-policy-host-refresh! policies policy 0 (at 1))
        (poo-flow-context-use-host-refresh! grants (grant 1 #t))
        (poo-flow-ai-agentic-context-session-host-enroll! host 0 source scope short
          (poo-flow-ai-agentic-context-profile #f) 0 '("work") "grant" 1)
        (poo-flow-temporal-support-policy-host-refresh! policies policy 1 (at 4))
        (check (.ref (claim host 0 0) 'reason) => 'current-grant-denied)))
    (poo-flow-test-case "returned snapshots cannot mutate internal active input or scheduling state"
      (let-values (((host grants policies) (setup)))
        (let* ((r (claim host 0 0)) (active (.ref (.ref r 'schedule) 'active)))
          (string-set! (.ref active 'identity) 0 #\x)
          (string-set! (.ref (.ref active 'input) 'digest) 0 #\x)
          (let (current (poo-flow-ai-agentic-context-session-host-current host "session"))
            (check (.ref (.ref (.ref current 'schedule) 'active) 'identity) => "attempt")
            (check (substring (.ref (.ref (.ref (.ref current 'schedule) 'active) 'input) 'digest) 0 7) => "sha256:")))))
    (poo-flow-test-case "foreign threads cannot mutate any participating Host"
      (let-values (((host grants policies) (setup)))
        (let (results (thread-join! (thread-start! (make-thread (lambda ()
          (map (lambda (operation) (with-catch (lambda (exception) 'refused)
                                    (lambda () (operation) 'accepted)))
            (list (lambda () (claim host 0 0))
                  (lambda () (poo-flow-context-use-host-refresh! grants (grant 2 #f)))
                  (lambda () (poo-flow-temporal-support-policy-host-refresh! policies policy 1 (at 8))))))))))
          (check results => '(refused refused refused)))
        (check (.ref (claim host 0 0) 'accepted?) => #t)))))
