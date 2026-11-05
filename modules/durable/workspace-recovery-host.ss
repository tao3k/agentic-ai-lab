;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; workspace recovery deployment and operator commands over the normal host API.
(import :clan/poo/object
        :std/encoding/json
        :agentic-ai-lab/modules/ai-agentic-context/interface
        :agentic-ai-lab/modules/ai-agentic-context/session-host
        :agentic-ai-lab/modules/ai-agentic-context/use-host
        :agentic-ai-lab/modules/ai-agentic-context/durable-owner
        :agentic-ai-lab/modules/ai-agentic-context/runtime-service
        :agentic-ai-lab/modules/ai-agentic-context/workspace-endpoint
        :agentic-ai-lab/modules/query/semantic/context-restriction
        :agentic-ai-lab/modules/authorization/providers/cedar/interface
        :agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
        :agentic-ai-lab/modules/temporal-causality/time/objects
        :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy
        :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy-host)
(export durable-workspace-recovery-host)

(def (text path) (call-with-input-file path (lambda (port) (read-line port #f))))
(def (jref value key) (hash-ref value key))
(def (snapshot-from path epoch)
  (let* ((boot (parameterize ((current-json-read-options (JSONReadOptions object-as-hash: #t)))
                 (string->json (text path))))
         (p (jref boot "provenance")))
    (agentic-ai-lab-cedar-authority-snapshot
      (agentic-ai-lab-cedar-authority-context
        (jref boot "authority_id") (jref boot "runtime_context_id") (jref boot "runtime_generation")
        (jref boot "runtime_bundle_digest") epoch
        (jref boot "policy_revision") (jref boot "revocation_epoch"))
      (agentic-ai-lab-cedar-proof-binding
        (jref p "composition_identity") (jref p "profile_identities")
        (jref p "profile_origin_digest") (jref boot "profile_bundle_digest")
        (jref boot "independent_bundle_digest") (jref boot "capability_contract_digest")
        (jref p "governance_assessment_digest") (jref p "subject_snapshot_digest")
        (jref p "certification_names"))
      (map (lambda (rule) (agentic-ai-lab-cedar-policy (jref rule "identity") (jref rule "source")))
           (jref boot "policies"))
      (agentic-ai-lab-cedar-schema (jref boot "schema_json"))
      (agentic-ai-lab-cedar-entities (jref boot "entities_json"))
      (map (lambda (c) (agentic-ai-lab-cedar-runtime-capability (jref c "action") (jref c "event_kind")))
           (jref boot "capabilities")))))

(def (durable-workspace-recovery-host journal-file workspace source-path operation . issuer-arguments)
  (def root (path-expand workspace))
  (def effect-id "workspace-edit")
  (def attempt #f)
  (def endpoint #f)
  (def epoch #f)
  (def (instant coordinate)
    (agentic-ai-lab-temporal-instant (number->string coordinate)
      "doc19" coordinate "doc19-clock" 'observed))
  (def (initialize journal)
    (set! epoch (journal-epoch journal))
    (let* ((grants (agentic-ai-lab-context-use-host))
           (policies (agentic-ai-lab-temporal-support-policy-host))
           (policy (agentic-ai-lab-temporal-support-policy "doc19" "revision-1" (instant 1) (instant 60)))
           (host (agentic-ai-lab-ai-agentic-context-session-host grants policies #f))
           (scope (.o (:: @ AiAgenticContextScope.) bundle: "doc19" organization: "org" epoch: 1
                     project: "doc19" worktree: root source-cut: "doc19-source" actor: "actor"
                     task: "task" destination: "provider" session: "doc19-session" turn: 0))
           (saved (journal-input journal effect-id)))
      (agentic-ai-lab-temporal-support-policy-host-refresh! policies policy 1 (instant 1))
      (agentic-ai-lab-context-use-host-refresh! grants
        (agentic-ai-lab-context-use-grant "doc19-grant" 1 "doc19" "doc19-source"
          (agentic-ai-lab-context-use-contract "actor" "task" "doc19" '() '() #t)
          "doc19" (.ref policy 'semantic-digest) '(display) #t))
      (if saved
        (set! attempt (.ref (.ref (.ref saved 'payload) 'body) 'attempt))
        (begin
          (agentic-ai-lab-ai-agentic-context-session-host-enroll! host 1 (text source-path) scope
            (agentic-ai-lab-context-restriction "doc19" '("actor") '("provider") '("org") 0 60)
            (agentic-ai-lab-ai-agentic-context-profile #f) 0 '("work") "doc19-grant" 1)
          (let (claim (agentic-ai-lab-ai-agentic-context-session-host-claim!
                         host "doc19-session" 0 1 "doc19-attempt" "doc19-request"))
            (unless (.ref claim 'accepted?) (error "workspace recovery original Attempt refused"))
            (set! attempt (.ref (.ref claim 'schedule) 'active)))))
      (set! endpoint (context-workspace-text-endpoint
        (.o workspace: root path: "notes.txt" scope-digest: (.ref (.ref attempt 'input) 'scope-digest)
            ;; The operator owns a private workspace with one active writer.
            .with-writer: (lambda (self action) (action))
            .retry-premises: (lambda (self original predecessor)
              (let* ((effect (.ref (.ref original 'body) 'effect))
                     (original-before (.ref effect 'before)))
                (.o current-permission?: (pair? issuer-arguments)
                    repeat-safe?: (and (not predecessor)
                                       (equal? original-before (text (path-expand "notes.txt" root))))))))))
      (let (issuer
             (and (pair? issuer-arguments)
                  (apply (lambda (executable socket artifact snapshot-path)
                    (agentic-ai-lab-cedar-open-workspace-host
                      (if (equal? operation "interrupt-dispatch")
                        (.o (:: @ endpoint)
                            .dispatch-retry!: (lambda (self command original handoff)
                              (displayln "issuer-consumed-before-write=#t")
                              (force-output)
                              (exit 73)))
                        endpoint)
                      (.o issuer-executable: executable runtime-socket: socket runtime-artifact: artifact
                          snapshot: (snapshot-from snapshot-path epoch)
                          subject: (.o principal: "User::\"alice\"" action: "Action::\"run\""
                                       resource: "Job::\"demo\"" context: (.o approved: #t blocked: #f))
                          .handoff-coordinates: (lambda (self request)
                            (.o sequence: 1 semantic-root: (journal-hash "doc19-runtime-root")
                                execution-root: (journal-hash "doc19-execution-root"))))))
                    issuer-arguments)))
        (let ((host-value host) (grants-value grants) (policies-value policies))
          (.o host: host-value grants: grants-value policies: policies-value
              proof-resolver: (lambda (registration) #f) query-provider: #f
              recovery: (.o composition: "doc19-workspace" effect-host: issuer
                           policy: (.o revision: 1 outcome-interpreter: (lambda (evidence) 'unknown)
                                       retry-policy: (lambda (evidence outcome) #t)))
              .close!: (lambda (self) (when issuer (.call issuer .close! issuer))))))))
  (let (service (context-start-durable-service
                  (.o journal-path: journal-file clock: (.o domain: "doc19" origin: 1 tick-seconds: 60.)
                      .initialize: (lambda (self journal) (initialize journal)))))
    (dynamic-wind void
      (lambda ()
        (cond
         ((member operation '("reserve" "write" "complete" "interrupt-write"))
          (let* ((readback (.call endpoint .read! endpoint))
                 (before-value (.ref readback 'bytes))
                 (intent (context-durable-workspace-command effect-id attempt
                           (.o workspace: root path: "notes.txt" before: before-value
                               desired: (string-append before-value "Added line.\n")
                               requirements: '(writer-reconciliation whole-change task-acceptance)))))
            (if (equal? operation "reserve")
              (displayln "reserved=" (.ref (context-service-prepare-workspace! service intent endpoint) 'accepted?))
              (let (worker (context-service-start-workspace! service intent endpoint))
                (unless worker (error "Original handoff already reserved"))
                (.call worker .await worker)
                (displayln "workspace-written=#t")
                (when (equal? operation "interrupt-write")
                  (force-output)
                  (exit 73))
                (when (equal? operation "complete")
                  (.call worker .commit! worker "workspace-result")
                  (displayln "result-committed=#t"))))))
         ((member operation '("assess" "retry" "retry-audit" "interrupt-dispatch"))
          (let* ((assessment (string-append "doc19-assessment:" (number->string epoch)))
                 (receipt (context-service-assess-workspace! service assessment effect-id epoch endpoint))
                 (decision (.ref receipt 'decision))
                 (packed (context-service-workspace-recovery-projection service assessment)))
            (displayln "outcome=" (.ref decision 'recorded-outcome)
                       " eligible=" (.ref decision 'retry-eligible?)
                       " receipt=" (journal-hash packed))
            (when (member operation '("retry" "retry-audit" "interrupt-dispatch"))
              (let* ((digest-value (journal-hash packed))
                     (suffix (number->string epoch))
                     (command (context-service-workspace-retry-command
                                (string-append "doc19-retry:" suffix)
                                effect-id assessment digest-value epoch))
                     (token (context-service-issue-workspace-retry! service command)))
                (displayln "dispatched=" (context-service-retry-workspace! service command token))
                (when (equal? operation "retry-audit")
                  (displayln "historical-dispatch=" (context-service-retry-workspace! service command token))
                  (for-each
                    (lambda (candidate)
                      (let (request (context-service-workspace-retry-command
                                      (string-append "doc19-" (car candidate) ":" suffix)
                                      effect-id assessment (cdr candidate) epoch))
                        (displayln (car candidate) "-dispatch="
                          (context-service-retry-workspace! service request token))))
                    (list (cons "duplicate" digest-value) (cons "substituted" "substituted-receipt"))))))))
         (else (error "Unknown workspace recovery operator command" operation))))
      (lambda () (context-service-close! service)))))
