;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Actual Context/Session/journal decisions through the production service.
(import (only-in :clan/poo/object .o .ref)
        (only-in :agentic-ai-lab/t/qualification/context-temporal/evaluator/fixtures
                 authority-fixture clock-original-context push-join! context-source
                 context-scope clock-check-originals!)
        (prefix-in :agentic-ai-lab/t/context-durable-owner originals.)
        :agentic-ai-lab/modules/ai-agentic-context/runtime-service
        :agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
        :agentic-ai-lab/modules/temporal-causality/runtime/policy-clock
        :agentic-ai-lab/modules/ai-agentic-context/durable-owner
        :agentic-ai-lab/modules/ai-agentic-context/use-host
        :agentic-ai-lab/modules/ai-agentic-context/funs-projection
        (only-in :agentic-ai-lab/modules/ai-agentic-context/funs-features
                 agentic-ai-lab-ai-agentic-context-profile)
        (only-in :agentic-ai-lab/modules/query/semantic/context-restriction
                 agentic-ai-lab-context-restriction)
        (only-in :agentic-ai-lab/modules/ai-agentic-context/session-host
                 agentic-ai-lab-ai-agentic-context-session-host-propagations))
(export service-probe service-fixture service-fixture-close! service-fixture-grant-digest)
(def (ensure value message) (unless value (error message)))
(def (rejected? operation) (with-catch (lambda (_) #t) (lambda () (operation) #f)))

(def (service-fixture path)
  (let* ((fixture #f) (journal #f) (restored? #f)
         (clock
           (policy-clock-owner
             (lambda ()
               (set! journal (journal-open path))
               (originals.originals! journal path)
               (set! restored? (if (journal-get journal "context") #t #f))
               (let* ((ctx (clock-original-context))
                      (value (authority-fixture #t ctx 1000000 (not restored?)))
                      (adapter (context-durable-adapter journal (.ref value 'host)
                                 (.ref value 'grants) (.ref value 'policies)
                                 (lambda (_) (.ref value 'proof)))))
                 (set! fixture value)
                 (journal-evidence! journal "original-ascent" (originals.proof-evidence ctx))
                 (journal-evidence! journal "original-org" context-source)
                 (values (context-service-resource (.ref value 'host) (.ref value 'grants)
                           (.ref value 'policies) adapter) (.ref value 'policies) adapter)))
             "txn" 1 3600. 0. 1 #f #f))
         (service (context-runtime-service clock)))
    (unless restored?
    (for-each (lambda (pair)
      (context-service-bind-observation! service (car pair) (cdr pair)
        (policy-clock-call! clock (lambda (_) (push-join! fixture (cdr pair))))))
      '(("obs-A" . "session") ("obs-C" . "session-c"))))
    (let ((service-value service) (clock-value clock) (journal-value journal) (fixture-value fixture) (restored-value restored?))
      (.o restored?: restored-value service: service-value clock: clock-value journal: journal-value fixture: fixture-value))))
(def (service-fixture-grant-digest value)
  (policy-clock-call! (.ref value 'clock) (lambda (_)
    (.ref (agentic-ai-lab-context-use-host-current (.ref (.ref value 'fixture) 'grants) "grant")
          'semantic-digest))))
(def (service-fixture-close! value)
  ;; Endpoint ownership is independent: close its actual test worker before
  ;; retiring Context. Disposal never fabricates a Session terminal.
  (policy-clock-call! (.ref value 'clock) (lambda (_)
    (unless (.ref value 'restored?) (push-join! (.ref value 'fixture) "session-b"))
    ;; Startup rollback may close an opened service before its first command.
    ;; Original evidence must still match, but no propagation event may be
    ;; invented merely to satisfy the scenario-only audit helper.
    (journal-evidence! (.ref value 'journal) "original-ascent"
      (originals.proof-evidence (.ref (.ref value 'fixture) 'context)))
    (journal-evidence! (.ref value 'journal) "original-org" context-source)
    (when (pair? (agentic-ai-lab-ai-agentic-context-session-host-propagations
                   (.ref (.ref value 'fixture) 'host)))
      (clock-check-originals! (.ref value 'fixture)))))
  (context-service-close! (.ref value 'service))
  (ensure (journal-closed? (.ref value 'journal)) "Service journal did not close"))

(def (service-probe path)
  ;; The catalog optimization must neither share caller-mutable ID lists nor
  ;; turn a prior Context projection into authority for changed source bytes.
  (let* ((profile (agentic-ai-lab-ai-agentic-context-profile #f))
         (restriction (agentic-ai-lab-context-restriction
                        "domain" '("actor") '("provider") '("org") 0 8))
         (original (agentic-ai-lab-ai-agentic-context-org-project
                     context-scope context-source restriction profile)))
    (ensure (equal? (.ref original 'semantic-digest)
              (.ref (agentic-ai-lab-ai-agentic-context-org-replay
                      context-source original context-scope) 'semantic-digest))
            "Catalog projection changed the native replay digest")
    (ensure (rejected? (lambda ()
      (agentic-ai-lab-ai-agentic-context-org-replay
        (string-append context-source "\nchanged bytes\n") original context-scope)))
      "Catalog metadata cached a source verdict")
    (set-car! (.ref original 'feature-ids) 'foreign-feature)
    (ensure (equal? (.ref (agentic-ai-lab-ai-agentic-context-org-project
                           context-scope context-source restriction profile) 'feature-ids)
                    '(ai-agentic-context/core))
            "Caller mutation corrupted the private catalog IDs")
    (ensure (rejected? (lambda ()
      (agentic-ai-lab-ai-agentic-context-org-replay context-source original context-scope)))
      "Altered Feature IDs survived native replay"))
  ;; An acquired owner must close even before its first business command.
  ;; Recovery may preserve pending Attempts; it must not invent a terminal.
  (let (empty (service-fixture (string-append path ".empty")))
    (service-fixture-close! empty))
  (let* ((empty (service-fixture (string-append path ".empty")))
         (snapshot (context-service-dispatch! (.ref empty 'service)
                     (context-service-command "empty-restart" 'inspect "session-c" 0 0 2 #f))))
    (ensure (= (.ref snapshot 'terminal-count) 0) "Closing before work invented a terminal")
    (service-fixture-close! empty))
  (let* ((value (service-fixture path)) (service (.ref value 'service)))
    (def (command id operation sid revision observation)
      (context-service-dispatch! service (context-service-command id operation sid revision 0 1 observation)))
    (let (first (command "complete-C" 'result "session-c" 2 "obs-C"))
      (ensure (.ref first 'native-result-published?) "Service did not publish the actual Session terminal")
      (ensure (.ref (command "complete-C" 'result "session-c" 2 "obs-C") 'historical?) "Duplicate lost original decision")
      (ensure (eq? (.ref (command "complete-C" 'result "session" 2 "obs-A") 'reason) 'identity-conflict)
              "Same retry ID accepted different Session bytes"))
    (let* ((revoke (context-service-grant-command "revoke" "grant" (service-fixture-grant-digest value) 1))
           (answer (context-service-dispatch! service revoke)))
      (ensure (.ref answer 'accepted?) "Native grant CAS did not apply")
      (ensure (.ref (context-service-dispatch! service revoke) 'historical?) "Grant retry reconstructed a new proposal"))
    (ensure (not (.ref (command "old-A" 'result "session" 2 "obs-A") 'accepted?)) "Revoked result revived")
    (let ((a (command "inspect-A" 'inspect "session" 0 #f))
          (b (command "inspect-B" 'inspect "session-b" 0 #f))
          (c (command "inspect-C" 'inspect "session-c" 0 #f)))
      (ensure (and (eq? (.ref a 'context-state) 'invalidated) (eq? (.ref b 'context-state) 'invalidated))
              "Cross-Session invalidation missing")
      (ensure (and (eq? (.ref c 'context-state) 'admitted) (= (.ref c 'terminal-count) 1))
              "Unaffected terminal changed")
      (ensure (.ref (command "cancel-A" 'cancel "session" (.ref a 'revision) #f) 'accepted?)
              "Actual Session cancellation was refused"))
    (let (a (command "inspect-before-recover" 'inspect "session" 0 #f))
      (ensure (.ref (command "recover-A" 'recover "session" (.ref a 'revision) #f) 'accepted?)
              "Actual Session recovery was refused"))
    (ensure (not (.ref (command "late-A" 'result "session" 2 "obs-A") 'accepted?)) "Recovery revived old result")
    (ensure (eq? (.ref (context-service-dispatch! service
                       (context-service-command "stale-epoch" 'cancel "session" 0 0 2 #f)) 'reason) 'stale-owner)
            "Old owner cut accepted")
    (ensure (eq? (.ref (command "unknown" 'inspect "absent" 0 #f) 'reason) 'unknown-session)
            "Unknown Session was invented")
    (service-fixture-close! value)
    (ensure (rejected? (lambda () (command "after-close" 'inspect "session" 0 #f))) "Closed service accepted input")
    (let* ((reopened (service-fixture path)) (again (.ref reopened 'service))
           (snapshot (context-service-dispatch! again
                       (context-service-command "restart-inspect" 'inspect "session-c" 0 0 2 #f)))
           (old (context-service-dispatch! again
                  (context-service-command "restart-old-result" 'result "session" 2 0 2 "obs-A"))))
      (ensure (= (.ref snapshot 'terminal-count) 1) "Restart lost the original terminal")
      (ensure (eq? (.ref old 'reason) 'unknown-observation) "Restart recreated an observation seal")
      (service-fixture-close! reopened))
    (displayln "CONTEXT-SERVICE actual-terminal=1 duplicate=historical substitution=refused revoke=propagated unaffected=retained recovery=no-revival owner=joined")
    (displayln "CONTEXT-SERVICE zero-event-close=joined zero-event-restart-terminals=0")
    (displayln "MODULE-OK t/context-service-test.ss")
    (displayln "HARNESS-OK context-service")
    (displayln "OK")))
