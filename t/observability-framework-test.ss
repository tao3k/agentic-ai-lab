;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Real Module admission -> Agentic AI Lab observation -> explanation -> gerbil-poo debug.
(import (only-in :std/test test-suite check-equal? check-exception)
        (only-in :std/test/base current-test-case)
        (only-in :clan/poo/object .o .cc .ref .slot? .call CyclicSlot? CyclicSlot-path)
        (only-in :clan/poo/mop element? validate TypeError?)
        :yuanxu/observability/debug
        (only-in :agentic-ai-lab/testing-api
                 yuanxu-test-case
                 yuanxu-test-case/with
                 yuanxu-testing-case-profile-prototype
                 yuanxu-testing-case-profile?
                 yuanxu-default-testing-case-profile)
        (only-in :yuanxu/observability/types
                 YuanxuObservationContract
                 YuanxuAdmissionObservationContract
                 YuanxuObservabilityDiagnosticContract
                 YuanxuDebugDurationReceiptContract)
        (only-in :yuanxu/observability/objects
                 yuanxu-observation-identity
                 yuanxu-observation-provenance
                 yuanxu-observation-context
                 yuanxu-observe-admission-evidence
                 yuanxu-observe-contract-admission
                 yuanxu-observation-explain
                 yuanxu-observation-summary
                 yuanxu-observability-diagnostic-record)
        (only-in :yuanxu/object-types/contracts
                 yuanxu-contract-admit yuanxu-predicate-contract)
        (only-in :yuanxu/module-system/schema/relations
                 SemanticImports. yuanxu-semantic-identity
                 yuanxu-empty-imports yuanxu-empty-capabilities
                 yuanxu-empty-profiles)
        :yuanxu/module-system/authoring/roles
        (only-in :agentic-ai-lab/modules/module-authoring/semantic-module UserConfigSourceRole. agentic-ai-lab-user-root-module-authoring-profile))
(export observability-framework-test)

(def (framework-id name) (yuanxu-observation-identity 'test name 'v1))
(def (framework-context (budget 256))
  (yuanxu-observation-context
   (framework-id 'event) (framework-id 'module) (framework-id 'generation)
   (list (framework-id 'parent))
   (yuanxu-observation-provenance
    (framework-id 'module-admission) (framework-id 'gerbil-poo) 'admission)
   detail-budget: budget))
(def (framework-module)
  (yuanxu-semantic-module (yuanxu-semantic-identity 'test 'module)))
(def (framework-contains? text value) (if (string-contains text value) #t #f))

(def +framework-case-profile+
  (.o (:: @ yuanxu-testing-case-profile-prototype)
      identity: 'testing/framework-case
      max-duration-milliseconds: 2000))

(def +framework-timeout-case-profile+
  (.o (:: @ yuanxu-testing-case-profile-prototype)
      identity: 'testing/framework-timeout
      sample-interval-milliseconds: 1
      max-duration-milliseconds: 20))

(def +framework-memory-case-profile+
  (.o (:: @ yuanxu-testing-case-profile-prototype)
      identity: 'testing/framework-memory
      heap-limit-bytes: 0
      sample-interval-milliseconds: 1))

(def +framework-retained-allocation-case-profile+
  (.o (:: @ yuanxu-testing-case-profile-prototype)
      identity: 'testing/retained-allocation
      live-growth-limit-bytes: 8388608
      sample-interval-milliseconds: 10
      collect-before-sample?: #t
      max-duration-milliseconds: 2000))

(def observability-framework-test
  (test-suite "Agentic AI Lab observability over gerbil-poo"
    (let (harness-thread (current-thread))
      (yuanxu-test-case "default POO Case preserves native assertions"
        (check-equal? (eq? (current-thread) harness-thread) #t)
        (check-equal? (not (current-test-case)) #f)
        (check-equal? (yuanxu-testing-case-profile?
                       yuanxu-default-testing-case-profile) #t)
        (check-equal? (+ 1 2) 3)))

    (yuanxu-test-case/with +framework-case-profile+
                             "POO Case may override its duration slot"
      (check-equal? (.ref +framework-case-profile+
                         'max-duration-milliseconds) 2000)
      (check-equal? (+ 2 3) 5))

    (yuanxu-test-case "POO Case rejects an invalid heap limit slot"
      (check-equal?
       (yuanxu-testing-case-profile?
        (.cc yuanxu-default-testing-case-profile
             heap-limit-bytes: -1))
       #f))

    (yuanxu-test-case "duration receipt has a native POO contract"
      (let (proto (.ref YuanxuDebugDurationReceiptContract 'proto))
        (check-equal?
         (element? YuanxuDebugDurationReceiptContract
                   (.o (:: @ proto)
                       phase: 'test
                       policy-label: 'test
                       limit-milliseconds: 20
                       elapsed-milliseconds: 20
                       accepted?: #f
                       reason: 'duration-exceeded))
         #t)))

    (yuanxu-test-case "POO Case stops a non-returning worker at its duration slot"
      (let (captured #f)
        (with-catch
         (lambda (failure) (set! captured failure))
         (lambda ()
           (.call +framework-timeout-case-profile+ .run
                  +framework-timeout-case-profile+
                  "duration override"
                  (lambda ()
                    (let loop ()
                      (thread-sleep! 0.01)
                      (loop))))))
        (check-equal? (YuanxuDebugDurationAnomaly? captured) #t)
        (check-equal?
         (.ref (YuanxuDebugDurationAnomaly-receipt captured) 'reason)
         'duration-exceeded)))

    (yuanxu-test-case "POO Case stops a worker at its memory policy override"
      (let (captured #f)
        (with-catch
         (lambda (failure) (set! captured failure))
         (lambda ()
           (.call +framework-memory-case-profile+ .run
                  +framework-memory-case-profile+
                  "memory override"
                  (lambda ()
                    (let loop ()
                      (thread-sleep! 0.01)
                      (loop))))))
        (check-equal? (YuanxuDebugMemoryAnomaly? captured) #t)))

    (yuanxu-test-case "retained allocation crosses a real Case memory budget"
      (let ((captured #f)
            (allocated 0))
        (with-catch
         (lambda (failure) (set! captured failure))
         (lambda ()
           (.call +framework-retained-allocation-case-profile+ .run
                  +framework-retained-allocation-case-profile+
                  "retained allocation"
                  (lambda ()
                    (let loop ((retained '()) (count 0))
                      (when (< count 64)
                        (let (next (cons (make-u8vector 1048576 7) retained))
                          (set! allocated (+ allocated 1048576))
                          (thread-sleep! 0.002)
                          (loop next (+ count 1)))))))))
        (check-equal? (YuanxuDebugMemoryAnomaly? captured) #t)
        (check-equal?
         (.ref (YuanxuDebugMemoryAnomaly-receipt captured) 'reason)
         'live-growth-limit-exceeded)
        (check-equal?
         (> (.ref (YuanxuDebugMemoryAnomaly-receipt captured)
                  'live-growth-bytes)
            8388608)
         #t)
        (check-equal? (>= allocated 1048576) #t)
        (check-equal? (< allocated 67108864) #t)))

    (yuanxu-test-case "isolated worker remains usable after memory rejection"
      (check-equal? (+ 20 22) 42))

    (yuanxu-test-case "real successful Module admission preserves correlation without raw subject"
      (let* ((context (framework-context)) (module (framework-module))
             (event (yuanxu-observe-contract-admission context SemanticModuleContract module))
             (facts (.ref event 'evidence)) (summary (yuanxu-observation-summary event)))
        (check-equal? (element? YuanxuObservationContract event) #t)
        (check-equal? (element? YuanxuAdmissionObservationContract event) #t)
        (check-equal? (element? SemanticModuleContract event) #f)
        (check-equal? (.slot? module 'identity) #t)
        (check-equal? (.slot? module 'imports) #t)
        (check-equal? (.slot? module 'capabilities) #t)
        (check-equal? (.slot? module 'profiles) #t)
        (check-equal? (.slot? module 'authoring) #t)
        (check-equal? (eq? (.ref event 'source) (.ref context 'source)) #t)
        (check-equal? (eq? (.ref event 'generation) (.ref context 'generation)) #t)
        (check-equal? (eq? (.ref event 'causes) (.ref context 'causes)) #t)
        (check-equal? (eq? (.ref event 'provenance) (.ref context 'provenance)) #t)
        (check-equal? (.ref facts 'accepted?) #t)
        (check-equal? (.slot? facts 'candidate) #f)
        (check-equal? (.slot? facts 'context) #f)
        (check-equal? (.ref summary 'failure-count) 0)))

    (yuanxu-test-case "missing and invalid responsibilities have native explanation paths"
      (let* ((context (framework-context))
             (missing (.o (:: @ SemanticModule.)
                          imports: (yuanxu-empty-imports)
                          capabilities: (yuanxu-empty-capabilities)
                          profiles: (yuanxu-empty-profiles)))
             (event (yuanxu-observe-contract-admission context SemanticModuleContract missing))
             (explanation (yuanxu-observation-explain event))
             (failure (car (.ref explanation 'failures))))
        (check-equal? (.ref explanation 'accepted?) #f)
        (check-equal? (.ref failure 'path) '(identity))
        (check-equal? (.ref failure 'code) 'missing-responsibility))
      (let* ((bad (.cc (framework-module) 'imports 'raw-list))
             (event (yuanxu-observe-contract-admission
                     (framework-context) SemanticModuleContract bad))
             (failure (car (.ref (yuanxu-observation-explain event) 'failures))))
        (check-equal? (.ref failure 'path) '(imports))
        (check-equal? (.ref failure 'code) 'prototype-mismatch)))

    (yuanxu-test-case "native ancestry rejection is not disguised as a field failure"
      (let* ((event (yuanxu-observe-contract-admission
                     (framework-context) SemanticModuleContract (.o identity: 'lookalike)))
             (failure (car (.ref (yuanxu-observation-explain event) 'failures))))
        (check-equal? (.ref failure 'path) '())
        (check-equal? (.ref failure 'code) 'prototype-mismatch)))

    (yuanxu-test-case "existing diagnostic API feeds the same observation framework"
      (let* ((diagnostic (yuanxu-observability-diagnostic-record
                          'error 'contract 'validator #f #f 'domain-denied
                          "synthetic diagnostic text" 'author))
             (good (yuanxu-observe-contract-admission
                    (framework-context) YuanxuObservabilityDiagnosticContract diagnostic))
             (bad (yuanxu-observe-contract-admission
                   (framework-context) YuanxuObservabilityDiagnosticContract
                   (.cc diagnostic 'severity 42)))
             (explanation (yuanxu-observation-explain bad)))
        (check-equal? (.ref (yuanxu-observation-summary good) 'accepted?) #t)
        (check-equal? (.ref explanation 'accepted?) #f)
        (check-equal? (.ref explanation 'contract) 'observability/diagnostic)
        (check-equal? (.ref (car (.ref explanation 'failures)) 'code)
                      'yuanxu.contract.obligation-failure)))

    (yuanxu-test-case "nested responsibility rejection retains the full path"
      (let* ((module (framework-module))
             (bad (.cc module 'identity (.cc (.ref module 'identity) 'name 42)))
             (event (yuanxu-observe-contract-admission
                     (framework-context) SemanticModuleContract bad))
             (failure (car (.ref (yuanxu-observation-explain event) 'failures))))
        (check-equal? (.ref failure 'path) '(identity name))
        (check-equal? (.ref failure 'contract) 'semantic-symbol)
        (check-equal? (.ref failure 'code) 'expected-symbol)))

    (yuanxu-test-case "source-owned obligation code survives without a central code registry"
      (let* ((contract (yuanxu-predicate-contract
                        'domain-specific symbol? (lambda (_c _x) '(domain-policy-denied))))
             (event (yuanxu-observe-contract-admission (framework-context) contract 'value))
             (explanation (yuanxu-observation-explain event))
             (failure (car (.ref explanation 'failures))))
        (check-equal? (.ref failure 'code) 'domain-policy-denied)
        (check-equal? (.ref explanation 'obligation-count) 1)
        (check-equal? (.ref explanation 'classification-accepted?) #t)))

    (yuanxu-test-case "bounded detail inspection cannot change the semantic verdict"
      (let* ((bad (.cc (framework-module) 'imports 'invalid))
             (event (yuanxu-observe-contract-admission
                     (framework-context 0) SemanticModuleContract bad))
             (summary (yuanxu-observation-summary event)))
        (check-equal? (.ref summary 'accepted?) #f)
        (check-equal? (.ref summary 'detail-complete?) #f)
        (check-equal? (.ref summary 'inspected-count) 0)
        (check-equal? (.ref summary 'failure-count) 0)))

    (yuanxu-test-case "observation and explanation never evaluate lazy imports"
      (let* ((lazy-imports (.o (:: @ SemanticImports.)
                              (contributions (error "inspection forced imports"))))
             (module (yuanxu-semantic-module
                      (yuanxu-semantic-identity 'test 'lazy) imports: lazy-imports))
             (event (yuanxu-observe-contract-admission
                     (framework-context) SemanticModuleContract module))
             (port (open-output-string)))
        (check-equal? (.ref (yuanxu-observation-explain event) 'accepted?) #t)
        (check-equal? (.ref (yuanxu-observation-debug event port trace?: #t) 'accepted?) #t)))

    (yuanxu-test-case "producer is evaluated once and native explanation can be refined"
      (let* ((count 0)
             (contract (yuanxu-predicate-contract
                        'counted symbol? (lambda (_candidate _context) (set! count (1+ count)) '())))
             (event (yuanxu-observe-contract-admission (framework-context) contract 'value))
             (specialized (.o (:: @ event) (.explain 'domain-specific-explanation))))
        (yuanxu-observation-explain event)
        (yuanxu-observation-summary event)
        (check-equal? count 1)
        (check-equal? (yuanxu-observation-explain specialized) 'domain-specific-explanation)
        (check-equal? (element? YuanxuObservationContract specialized) #t)))

    (yuanxu-test-case "forged verdicts and incomplete producer metadata are rejected"
      (let* ((receipt (yuanxu-contract-admit SemanticModuleContract 'invalid #f))
             (event (yuanxu-observe-admission-evidence (framework-context) receipt)))
        (check-exception
         (yuanxu-observe-admission-evidence (framework-context) (.cc receipt 'accepted? #t)) TypeError?)
        (check-exception
         (yuanxu-observe-admission-evidence (framework-context) (.cc receipt 'contract-identity 'forged)) TypeError?)
        (check-exception
         (validate YuanxuAdmissionObservationContract
                   (.cc event 'evidence (.cc (.ref event 'evidence) 'accepted? #t))) TypeError?)
        (check-exception
         (validate YuanxuAdmissionObservationContract
                   (.cc event 'evidence (.cc (.ref event 'evidence) 'failures '()))) TypeError?)
        (check-exception
         (yuanxu-observe-contract-admission (.o) SemanticModuleContract (framework-module)) TypeError?)))

    (yuanxu-test-case "cyclic supplied evidence is incomplete inspection, not a Module cycle verdict"
      (let* ((contract (yuanxu-predicate-contract 'denied symbol? (lambda (_c _x) '(denied))))
             (receipt (yuanxu-contract-admit contract 'value #f))
             (cyclic (.o (:: self receipt) responsibility: 'cycle
                         (responsibility-evidence (list self))))
             (event (yuanxu-observe-admission-evidence (framework-context) cyclic))
             (summary (yuanxu-observation-summary event)))
        (check-equal? (.ref summary 'accepted?) #f)
        (check-equal? (.ref summary 'detail-complete?) #f)
        (check-equal? (.ref summary 'inspected-count) 1)))

    (yuanxu-test-case "upstream debug receives aggregates, never private candidate or custom renderer"
      (let* ((canary "SYNTHETIC-FRAMEWORK-PRIVATE-CANARY")
             (event (yuanxu-observe-contract-admission
                     (framework-context) SemanticModuleContract canary evaluation-context: canary))
             (specialized (.o (:: @ event)
                              (.summary (error canary))
                              (.explain canary)))
             (port (open-output-string)))
        (check-equal? (.ref (yuanxu-observation-debug specialized port trace?: #t) 'accepted?) #f)
        (let (output (get-output-string port))
          (check-equal? (framework-contains? output "admission-observation") #t)
          (check-equal? (framework-contains? output ">>>") #t)
          (check-equal? (framework-contains? output canary) #f)
          (check-equal? (framework-contains? output "generation") #f))))

    (yuanxu-test-case "invalid debug input fails closed before any output"
      (let ((port (open-output-string)))
        (check-exception (yuanxu-observation-debug "SYNTHETIC-PRIVATE" port)
                         YuanxuObservationProjectionError?)
        (check-equal? (get-output-string port) "")))

    (yuanxu-test-case "bounded call tracing rejects a shadowed core procedure before invocation"
      (let* ((policy (yuanxu-debug-call-policy 'tool-policy 8))
             (shadowed-values '(not a procedure))
             (port (open-output-string))
             (captured
              (with-exception-catcher
               (lambda (failure) failure)
               (lambda ()
                 (call-with-agentic-ai-lab-debug-trace
                  policy 'unique-symbols-return shadowed-values '(seen values)
                  port: port)))))
        (check-equal? (YuanxuDebugCallAnomaly? captured) #t)
        (check-equal?
         (.ref (YuanxuDebugCallAnomaly-receipt captured) 'operator-kind)
         'pair)
        (check-equal?
         (.ref (YuanxuDebugCallAnomaly-receipt captured) 'reason)
         'non-procedure-operator)
        (check-equal? (framework-contains? (get-output-string port)
                                           "non-procedure-operator") #t)
        (check-equal? (framework-contains? (get-output-string port)
                                           "not a procedure") #f)))

    (yuanxu-test-case "bounded call tracing preserves multiple values through upstream trace"
      (let* ((policy (yuanxu-debug-call-policy 'multiple-values 8))
             (port (open-output-string))
             (result
              (call-with-values
                (lambda ()
                  (call-with-agentic-ai-lab-debug-trace
                   policy 'return-pair
                   (lambda (left right) (values left right))
                   '(left right)
                   port: port))
                list)))
        (check-equal? result '(left right))
        (let (output (get-output-string port))
          (check-equal? (framework-contains? output "yuanxu-debug-call") #t)
          (check-equal? (framework-contains? output "call-returned") #t))))

    (yuanxu-test-case "bounded call tracing rejects a repeated call identity before recursion"
      (let* ((policy (yuanxu-debug-call-policy 'cycle 8))
             (port (open-output-string))
             (captured #f))
        (with-catch
         (lambda (failure) (set! captured failure))
         (lambda ()
           (call-with-agentic-ai-lab-debug-trace
            policy 'cycle-edge
            (lambda ()
              (call-with-agentic-ai-lab-debug-trace
               policy 'cycle-edge (lambda () 'unreachable) '()
               port: port))
            '()
            port: port)))
        (check-equal? (YuanxuDebugCallAnomaly? captured) #t)
        (check-equal?
         (.ref (YuanxuDebugCallAnomaly-receipt captured) 'reason)
         'recursive-call-cycle)))

    (yuanxu-test-case "bounded call tracing preserves exceptions and enforces depth"
      (let* ((policy (yuanxu-debug-call-policy 'bounded 1))
             (private-marker (list 'synthetic-private-exception-canary))
             (exception-port (open-output-string))
             (captured
              (with-exception-catcher
               (lambda (failure) failure)
               (lambda ()
                 (call-with-agentic-ai-lab-debug-trace
                  policy 'raises
                  (lambda () (raise private-marker))
                  '()
                  port: exception-port))))
             (depth-port (open-output-string))
             (depth-failure
              (with-exception-catcher
               (lambda (failure) failure)
               (lambda ()
                 (call-with-agentic-ai-lab-debug-trace
                  policy 'outer
                  (lambda ()
                    (call-with-agentic-ai-lab-debug-trace
                     policy 'inner (lambda () 'unreachable) '()
                     port: depth-port))
                  '()
                  port: depth-port)))))
        (check-equal? (eq? captured private-marker) #t)
        (check-equal?
         (framework-contains? (get-output-string exception-port)
                              "synthetic-private-exception-canary")
         #f)
        (check-equal? (YuanxuDebugCallAnomaly? depth-failure) #t)
        (check-equal?
         (.ref (YuanxuDebugCallAnomaly-receipt depth-failure) 'reason)
         'maximum-call-depth-exceeded)))

    (yuanxu-test-case "slot policy receipts reject forged cycle verdicts"
      (let* ((policy (yuanxu-debug-slot-policy 'slot-receipt 4))
             (admitted
              (yuanxu-debug-slot-receipt
               policy 'configuration 'project-id 0 '() 'admitted))
             (cycle
              (yuanxu-debug-slot-receipt
               policy 'configuration 'project-id 1
               '((configuration . project-id))
               'rejected-cycle)))
        (check-equal? (element? YuanxuDebugSlotPolicyContract policy) #t)
        (check-equal? (element? YuanxuDebugSlotReceiptContract admitted) #t)
        (check-equal? (.ref cycle 'accepted?) #f)
        (check-equal? (.ref cycle 'reason) 'recursive-slot-resolution)
        (check-exception
         (validate YuanxuDebugSlotPolicyContract
                   (.cc policy 'maximum-depth 0))
         TypeError?)
        (check-exception
         (validate YuanxuDebugSlotReceiptContract
                   (.cc admitted 'accepted? #f))
         TypeError?)))

    (yuanxu-test-case "slot guard preserves lazy caching and redacts resolved values"
      (let* ((evaluations 0)
             (private-value "SYNTHETIC-PRIVATE-SLOT-VALUE")
             (source
              (.o payload:
                  (begin
                    (set! evaluations (1+ evaluations))
                    private-value)))
             (policy (yuanxu-debug-slot-policy 'slot-cache 4))
             (port (open-output-string))
             (guarded
              (yuanxu-debug-poo
               policy 'configuration source port: port emit?: #t)))
        (check-equal? (.ref guarded 'payload) private-value)
        (check-equal? (.ref guarded 'payload) private-value)
        (check-equal? evaluations 1)
        (let (output (get-output-string port))
          (check-equal? (framework-contains? output "yuanxu-debug-slot") #t)
          (check-equal? (framework-contains? output "slot-resolved") #t)
          (check-equal? (framework-contains? output private-value) #f))))

    (yuanxu-test-case "slot guard batch admits one policy over independent lazy caches"
      (let* ((policy (yuanxu-debug-slot-policy 'slot-batch 4))
             (guarded
              (yuanxu-debug-poos
               policy 'batch
               (list (.o payload: 1) (.o payload: 2) (.o payload: 3))
               emit?: #f)))
        (check-equal? (map (lambda (object) (.ref object 'payload)) guarded)
                      '(1 2 3))))

    (yuanxu-test-case "slot guard propagates exceptions without disclosing them"
      (let* ((canary "SYNTHETIC-PRIVATE-SLOT-FAILURE")
             (failure (list canary))
             (source (.o payload: (raise failure)))
             (policy (yuanxu-debug-slot-policy 'slot-exception 4))
             (port (open-output-string))
             (guarded
              (yuanxu-debug-poo
               policy 'configuration source port: port emit?: #t))
             (captured
              (with-exception-catcher
               (lambda (value) value)
               (lambda () (.ref guarded 'payload))))
             (output (get-output-string port)))
        (check-equal? (eq? captured failure) #t)
        (check-equal? (framework-contains? output "slot-resolution-raised") #t)
        (check-equal? (framework-contains? output canary) #f)))

    (yuanxu-test-case "slot guard preserves the native finite lazy-cycle failure"
      (let* ((policy (yuanxu-debug-slot-policy 'slot-cycle 4))
             (port (open-output-string))
             (source (.o project-id: project-id))
             (guarded
              (yuanxu-debug-poo
               policy 'configuration source port: port emit?: #t))
             (captured
              (with-exception-catcher
               (lambda (failure) failure)
               (lambda () (.ref guarded 'project-id)))))
        (check-equal? (CyclicSlot? captured) #t)
        (check-equal? (map cdr (CyclicSlot-path captured))
                      '(project-id project-id))
        (check-equal? (andmap (lambda (edge) (eq? (car edge) guarded))
                              (CyclicSlot-path captured)) #t)
        (check-equal?
         (framework-contains? (get-output-string port)
                              "slot-resolution-raised")
         #t)
        (check-equal? (framework-contains? (get-output-string port) "CyclicSlot") #f)))

    (yuanxu-test-case "equal slot names on distinct receivers are not cycles"
      (let* ((policy (yuanxu-debug-slot-policy 'receiver-identity 4))
             (inner-source (.o value: 'inner))
             (inner
              (yuanxu-debug-poo
               policy 'inner inner-source emit?: #f))
             (outer-source (.o value: (.ref inner 'value)))
             (outer
              (yuanxu-debug-poo
               policy 'outer outer-source emit?: #f)))
        (check-equal? (.ref outer 'value) 'inner)))

    (yuanxu-test-case "slot guard enforces depth across dependent slots"
      (let* ((policy (yuanxu-debug-slot-policy 'slot-depth 1))
             (source
              (.o (:: @ [] second)
                  first: second
                  second: 'done))
             (guarded
              (yuanxu-debug-poo
               policy 'dependency source emit?: #f))
             (captured
              (with-exception-catcher
               (lambda (failure) failure)
               (lambda () (.ref guarded 'first))))
             (receipt (YuanxuDebugSlotAnomaly-receipt captured)))
        (check-equal? (YuanxuDebugSlotAnomaly? captured) #t)
        (check-equal? (.ref receipt 'slot) 'second)
        (check-equal? (.ref receipt 'active-path)
                      '((dependency . first)))
        (check-equal? (.ref receipt 'reason)
                      'maximum-slot-depth-exceeded)))

    (yuanxu-test-case "memory policy comparison is a pure native POO receipt"
      (let* ((policy
              (yuanxu-debug-memory-policy
               'unit heap-limit-bytes: 1000 live-growth-limit-bytes: 50))
             (before (yuanxu-debug-memory-sample 'unit 100 200 80 70 10))
             (within (yuanxu-debug-memory-sample 'unit 120 240 100 90 10))
             (growing (yuanxu-debug-memory-sample 'unit 180 400 160 140 20))
             (good (yuanxu-debug-memory-receipt policy before within))
             (bad (yuanxu-debug-memory-receipt policy before growing)))
        (check-equal? (element? YuanxuDebugMemoryPolicyContract policy) #t)
        (check-equal? (element? YuanxuDebugMemoryReceiptContract good) #t)
        (check-equal? (.ref good 'accepted?) #t)
        (check-equal? (.ref good 'live-growth-bytes) 20)
        (check-equal? (.ref bad 'accepted?) #f)
        (check-equal? (.ref bad 'reason) 'live-growth-limit-exceeded)))

    (yuanxu-test-case "effectful memory span emits only bounded scalar diagnostics"
      (let* ((limit 1152921504606846976)
             (policy
              (yuanxu-debug-memory-policy
               'native-span heap-limit-bytes: limit
               live-growth-limit-bytes: limit))
             (port (open-output-string)))
        (call-with-values
          (lambda ()
            (call-with-agentic-ai-lab-debug-memory-span
             policy 'native-span (lambda () 'completed) port: port emit?: #t))
          (lambda (value receipt)
            (check-equal? value 'completed)
            (check-equal? (.ref receipt 'accepted?) #t)
            (check-equal? (framework-contains?
                           (get-output-string port) "debug-memory-observation")
                          #t)))))

    (yuanxu-test-case "native memory monitor samples a running Scheme operation"
      (let* ((limit 1152921504606846976)
             (policy
              (yuanxu-debug-memory-policy
               'native-monitor heap-limit-bytes: limit
               live-growth-limit-bytes: limit
               sample-interval-milliseconds: 1))
             (port (open-output-string)))
        (call-with-values
          (lambda ()
            (call-with-agentic-ai-lab-debug-memory-monitor
             policy
             'native-monitor
             (lambda () (thread-sleep! 0.01) 'completed)
             port: port
             emit?: #t))
          (lambda (value receipt)
            (check-equal? value 'completed)
            (check-equal? (.ref receipt 'accepted?) #t)
            (check-equal? (.ref receipt 'phase) 'native-monitor)
            (check-equal? (framework-contains?
                           (get-output-string port) "debug-memory-observation")
                          #t)))))

    (yuanxu-test-case "native memory monitor stops a non-returning debug worker"
      (let* ((policy
              (yuanxu-debug-memory-policy
               'native-monitor-rejected
               heap-limit-bytes: 0
               live-growth-limit-bytes: 0
               sample-interval-milliseconds: 1))
             (captured #f))
        (with-catch
         (lambda (failure) (set! captured failure))
         (lambda ()
           (call-with-agentic-ai-lab-debug-memory-monitor
            policy
            'native-monitor-rejected
            (lambda ()
              (let loop ()
                (thread-sleep! 0.01)
                (loop))))))
        (check-equal? (YuanxuDebugMemoryAnomaly? captured) #t)
        (check-equal?
         (.ref (YuanxuDebugMemoryAnomaly-receipt captured) 'phase)
         'native-monitor-rejected)
        (check-equal?
         (.ref (YuanxuDebugMemoryAnomaly-receipt captured) 'reason)
         'heap-limit-exceeded)))

    (yuanxu-test-case "native memory monitor propagates finite POO cycle detection"
      (let* ((initial (yuanxu-debug-memory-snapshot 'poo-self-slot-cycle))
             (policy
              (yuanxu-debug-memory-policy
               'poo-self-slot-cycle
               heap-limit-bytes: (+ (.ref initial 'heap-size-bytes) 67108864)
               live-growth-limit-bytes: 8388608
               sample-interval-milliseconds: 1))
             (cycle (.o project-id: project-id))
             (captured #f))
        (with-catch
         (lambda (failure) (set! captured failure))
         (lambda ()
           (call-with-agentic-ai-lab-debug-memory-monitor
            policy
            'poo-self-slot-cycle
            (lambda ()
              (.ref cycle 'project-id)))))
        (check-equal? (CyclicSlot? captured) #t)
        (check-equal? (map cdr (CyclicSlot-path captured))
                      '(project-id project-id))
        (check-equal? (andmap (lambda (edge) (eq? (car edge) cycle))
                              (CyclicSlot-path captured)) #t)))

    (yuanxu-test-case "fail-closed checkpoint preserves its typed receipt"
      (let* ((policy
              (yuanxu-debug-memory-policy
               'rejected heap-limit-bytes: 0 live-growth-limit-bytes: 0))
             (baseline (yuanxu-debug-memory-snapshot 'rejected))
             (captured #f))
        (with-catch
         (lambda (failure) (set! captured failure))
         (lambda ()
           (yuanxu-debug-memory-checkpoint policy baseline 'rejected)))
        (check-equal? (YuanxuDebugMemoryAnomaly? captured) #t)
        (check-equal?
         (.ref (YuanxuDebugMemoryAnomaly-receipt captured) 'reason)
         'heap-limit-exceeded)))))
