;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later


(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        (only-in :clan/poo/object .call .cc .get .o .ref .slot?)
        (only-in :yuanxu/ops/process-script ProcessScript.)
        (only-in :yuanxu/observability/debug
                 YuanxuDebugMemoryAnomaly?
                 YuanxuDebugMemoryAnomaly-receipt)
        (only-in :asp-gerbil-scheme/testing-api
                 +asp-testing-interface+
                 testing-interface-profile-enabled?
                 testing-interface-call-with-operation
                 testing-interface-run-test-batch!)
        (only-in :agentic-ai-lab/dev/testing-api
                 +agentic-ai-lab-testing-interface+
                 +agentic-ai-lab-testing-import-footprint-profile+
                 agentic-ai-lab-native-observability-enabled?
                 agentic-ai-lab-testing-observability-profile-prototype
                 yuanxu-testing-case-profile-prototype
                 make-agentic-ai-lab-testing-observability-profile
                 agentic-ai-lab-testing-observability-profile-source-load-paths
                 agentic-ai-lab-testing-observability-extension))

(export testing-observability-extension-test)

(def +testing-trace-profile+
  (.o (:: @ agentic-ai-lab-testing-observability-profile-prototype)
      identity: 'testing/trace-qualification
      trace-enabled?: #t))

(def testing-observability-extension-test
  (test-suite "Agentic AI Lab native testing observability extension"
    (yuanxu-test-case "the public Agentic AI Lab interface owns the ASP extension once"
      (check (.slot? +agentic-ai-lab-testing-interface+ 'around-operation) => #t)
      (check (testing-interface-profile-enabled?
              +agentic-ai-lab-testing-interface+
              'import-footprint)
             => #t))

    (yuanxu-test-case "source roots are owned by the POO testing profile"
      (let (profile
            (make-agentic-ai-lab-testing-observability-profile
             'testing/source-root 1/100))
        (check-equal?
         (agentic-ai-lab-testing-observability-profile-source-load-paths profile)
         '("."))))

    (yuanxu-test-case "default testing profile does not spawn batch heartbeats"
      (let (port (open-output-string))
        (parameterize ((current-error-port port))
          (testing-interface-call-with-operation
           (agentic-ai-lab-testing-observability-extension
            +asp-testing-interface+)
           'native-test-batch
           (lambda () (thread-sleep! 0.02))))
        (check (and (string-contains
                     (get-output-string port) "operation-heartbeat") #t)
               => #f)))

    (yuanxu-test-case "shared worker Case memory override retains typed rejection"
      (let* ((profile
             (.o (:: @ yuanxu-testing-case-profile-prototype)
                  identity: 'testing/shared-memory-rejection
                  heap-limit-bytes: 0
                  sample-interval-milliseconds: 1))
             (captured #f))
        (with-catch
         (lambda (failure) (set! captured failure))
         (lambda ()
           (.call profile .run profile "shared memory rejection"
                  (lambda ()
                    (let loop ()
                      (thread-sleep! 0.01)
                      (loop))))))
        (check (YuanxuDebugMemoryAnomaly? captured) => #t)
        (check (.ref (YuanxuDebugMemoryAnomaly-receipt captured) 'reason)
               => 'heap-limit-exceeded)))

    (yuanxu-test-case "registry footprint policy is declared only through POO slots"
      (check (.ref +agentic-ai-lab-testing-import-footprint-profile+
                   'heavyOwners)
             => '())
      (check (.ref +agentic-ai-lab-testing-import-footprint-profile+
                   'largeClosureModuleCount)
             ? (lambda (value) (and (integer? value) (> value 0))))
      (check (< (.ref +agentic-ai-lab-testing-import-footprint-profile+
                      'maxSharedClosureModules)
                (.ref +agentic-ai-lab-testing-import-footprint-profile+
                      'largeClosureModuleCount))
             => #t)
      (check (.ref +agentic-ai-lab-testing-import-footprint-profile+
                   'action)
             => 'reject))

    (yuanxu-test-case "the default POO profile avoids duplicate trace output"
      (let ((port (open-output-string))
            (admission-visible-inside? #f))
        (parameterize ((current-error-port port))
          (check
           (testing-interface-call-with-operation
            (agentic-ai-lab-testing-observability-extension
             +asp-testing-interface+)
            'native-test-batch
            (lambda ()
              (set! admission-visible-inside?
                    (and (string-contains
                          (get-output-string port)
                          "call-admitted")
                         #t))
              'completed))
           => 'completed))
        (check (agentic-ai-lab-native-observability-enabled?) => #t)
        (check admission-visible-inside? => #f)
        (check (and (string-contains
                     (get-output-string port)
                     "call-returned")
                    #t)
               => #f)))
    (yuanxu-test-case "long operations emit bounded POO heartbeat and elapsed receipts"
      (let (port (open-output-string))
        (parameterize
            ((current-error-port port))
          (testing-interface-call-with-operation
           (agentic-ai-lab-testing-observability-extension
            +asp-testing-interface+
            (make-agentic-ai-lab-testing-observability-profile
             'testing/fast-heartbeat 0.01))
           'native-test-batch
           (lambda () (thread-sleep! 0.03))))
        (let (output (get-output-string port))
          (check (and (string-contains output "operation-heartbeat") #t)
                 => #t)
          (check (and (string-contains output "elapsed-nanoseconds") #t)
                 => #t))))
    (yuanxu-test-case "enablement is a composable POO profile slot"
      (let ((enabled-inside? #t)
            (profile
             (.o (:: @ (make-agentic-ai-lab-testing-observability-profile
                         'testing/quiet 1))
                 (enabled? #f))))
        (check
         (testing-interface-call-with-operation
          (agentic-ai-lab-testing-observability-extension
           +asp-testing-interface+ profile)
          'native-test-batch
          (lambda ()
            (set! enabled-inside?
                  (agentic-ai-lab-native-observability-enabled?))
            'completed))
         => 'completed)
        (check enabled-inside? => #f)))
    (yuanxu-test-case "the native batch emits POO receipts and upstream elapsed timing"
      (let (port (open-output-string))
        (parameterize ((current-output-port port)
                       (current-error-port port))
          (check
           (testing-interface-run-test-batch!
            (agentic-ai-lab-testing-observability-extension
             +asp-testing-interface+ +testing-trace-profile+)
            '("t/scenarios/testing-observability/native-batch-test.ss"))
           => (void)))
        (let (output (get-output-string port))
          (check (and (string-contains output "call-admitted") #t) => #t)
          (check (and (string-contains output "call-returned") #t) => #t)
          (check (and (string-contains output "phase=batch-start") #t) => #t)
          (check (and (string-contains output
                                       "phase=batch-complete elapsedNs=")
                      #t)
                 => #t))))
    (yuanxu-test-case "failed native batches retain POO and ASP elapsed terminals"
      (def missing "t/scenarios/testing-observability/missing-test.ss")
      (check-equal? (file-exists? missing) #f)
      (def result
        (.call
          (.cc ProcessScript.
            'command (list "gxi" "-:max-heap=1G,debug=q"
                           "dev/fixtures/testing-missing-batch.ss" missing)
            'timeout 30 'check-status #f)
          .run))
      (check-equal? (.get result status) 70)
      (def output (.get result output))
      (for-each
        (lambda (required)
          (check-equal? (and (string-contains output required) #t) #t))
        (list "call-raised" "elapsed-nanoseconds"
              "phase=batch-failed elapsedNs="
              "gerbil/tools/gxtest#collect-files" "No such file or directory"
              missing))
      (check-equal? (and (string-contains output "phase=batch-complete") #t) #f))))
