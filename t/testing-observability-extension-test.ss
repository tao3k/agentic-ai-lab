;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later


(import (only-in :core/observability/testing-case poo-flow-test-case)
         :std/test
        (only-in :clan/poo/object .call .o .ref .slot?)
        (only-in :core/observability/debug
                 PooFlowDebugMemoryAnomaly?
                 PooFlowDebugMemoryAnomaly-receipt)
        (only-in :asp-gerbil-scheme/testing-api
                 +asp-testing-interface+
                 testing-interface-profile-enabled?
                 testing-interface-call-with-operation
                 testing-interface-run-test-batch!)
        (only-in :poo-flow-dev/testing-api
                 +poo-flow-testing-interface+
                 +poo-flow-testing-import-footprint-profile+
                 poo-flow-native-observability-enabled?
                 poo-flow-testing-observability-profile-prototype
                 poo-flow-testing-case-profile-prototype
                 make-poo-flow-testing-observability-profile
                 poo-flow-testing-observability-profile-source-load-paths
                 poo-flow-testing-observability-extension))

(export testing-observability-extension-test)

(def +testing-trace-profile+
  (.o (:: @ poo-flow-testing-observability-profile-prototype)
      identity: 'testing/trace-qualification
      trace-enabled?: #t))

(def testing-observability-extension-test
  (test-suite "POO Flow native testing observability extension"
    (poo-flow-test-case "the public POO Flow interface owns the ASP extension once"
      (check (.slot? +poo-flow-testing-interface+ 'around-operation) => #t)
      (check (testing-interface-profile-enabled?
              +poo-flow-testing-interface+
              'import-footprint)
             => #t))

    (poo-flow-test-case "source roots are owned by the POO testing profile"
      (let (profile
            (make-poo-flow-testing-observability-profile
             'testing/source-root 1/100))
        (check-equal?
         (poo-flow-testing-observability-profile-source-load-paths profile)
         '("."))))

    (poo-flow-test-case "default testing profile does not spawn batch heartbeats"
      (let (port (open-output-string))
        (parameterize ((current-error-port port))
          (testing-interface-call-with-operation
           (poo-flow-testing-observability-extension
            +asp-testing-interface+)
           'native-test-batch
           (lambda () (thread-sleep! 0.02))))
        (check (and (string-contains
                     (get-output-string port) "operation-heartbeat") #t)
               => #f)))

    (poo-flow-test-case "shared worker Case memory override retains typed rejection"
      (let* ((profile
             (.o (:: @ poo-flow-testing-case-profile-prototype)
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
        (check (PooFlowDebugMemoryAnomaly? captured) => #t)
        (check (.ref (PooFlowDebugMemoryAnomaly-receipt captured) 'reason)
               => 'heap-limit-exceeded)))

    (poo-flow-test-case "registry footprint policy is declared only through POO slots"
      (check (.ref +poo-flow-testing-import-footprint-profile+
                   'heavyOwners)
             => '())
      (check (.ref +poo-flow-testing-import-footprint-profile+
                   'largeClosureModuleCount)
             ? (lambda (value) (and (integer? value) (> value 0))))
      (check (< (.ref +poo-flow-testing-import-footprint-profile+
                      'maxSharedClosureModules)
                (.ref +poo-flow-testing-import-footprint-profile+
                      'largeClosureModuleCount))
             => #t)
      (check (.ref +poo-flow-testing-import-footprint-profile+
                   'action)
             => 'reject))

    (poo-flow-test-case "the default POO profile avoids duplicate trace output"
      (let ((port (open-output-string))
            (admission-visible-inside? #f))
        (parameterize ((current-error-port port))
          (check
           (testing-interface-call-with-operation
            (poo-flow-testing-observability-extension
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
        (check (poo-flow-native-observability-enabled?) => #t)
        (check admission-visible-inside? => #f)
        (check (and (string-contains
                     (get-output-string port)
                     "call-returned")
                    #t)
               => #f)))
    (poo-flow-test-case "long operations emit bounded POO heartbeat and elapsed receipts"
      (let (port (open-output-string))
        (parameterize
            ((current-error-port port))
          (testing-interface-call-with-operation
           (poo-flow-testing-observability-extension
            +asp-testing-interface+
            (make-poo-flow-testing-observability-profile
             'testing/fast-heartbeat 0.01))
           'native-test-batch
           (lambda () (thread-sleep! 0.03))))
        (let (output (get-output-string port))
          (check (and (string-contains output "operation-heartbeat") #t)
                 => #t)
          (check (and (string-contains output "elapsed-nanoseconds") #t)
                 => #t))))
    (poo-flow-test-case "enablement is a composable POO profile slot"
      (let ((enabled-inside? #t)
            (profile
             (.o (:: @ (make-poo-flow-testing-observability-profile
                         'testing/quiet 1))
                 (enabled? #f))))
        (check
         (testing-interface-call-with-operation
          (poo-flow-testing-observability-extension
           +asp-testing-interface+ profile)
          'native-test-batch
          (lambda ()
            (set! enabled-inside?
                  (poo-flow-native-observability-enabled?))
            'completed))
         => 'completed)
        (check enabled-inside? => #f)))
    (poo-flow-test-case "the native batch emits POO receipts and upstream elapsed timing"
      (let (port (open-output-string))
        (parameterize ((current-output-port port)
                       (current-error-port port))
          (check
           (testing-interface-run-test-batch!
            (poo-flow-testing-observability-extension
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
    (poo-flow-test-case "failed native batches retain POO and ASP elapsed terminals"
      (let ((port (open-output-string))
            (raised? #f))
        (parameterize ((current-output-port port)
                       (current-error-port port))
          (with-catch
           (lambda (_failure) (set! raised? #t))
           (lambda ()
             (testing-interface-run-test-batch!
              (poo-flow-testing-observability-extension
               +asp-testing-interface+ +testing-trace-profile+)
              '("t/scenarios/testing-observability/missing-test.ss")))))
        (let (output (get-output-string port))
          (check raised? => #t)
          (check (and (string-contains output "call-raised") #t) => #t)
          (check (and (string-contains output "elapsed-nanoseconds") #t)
                 => #t)
          (check (and (string-contains output
                                       "phase=batch-failed elapsedNs=")
                      #t)
                 => #t))))))
