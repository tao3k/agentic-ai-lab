;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test test-suite check-equal?)
        (only-in :std/misc/ports read-all-as-string)
        (only-in :clan/poo/object .o .get .ref/cached)
        (only-in :gerbil/expander core-import-module module-context-path)
        :yuanxu/init
        "../init.ss"
        (only-in :agentic-ai-lab/modules/building/build-config
                 agentic-ai-lab-default-build-observability-policy)
        (only-in :agentic-ai-lab/modules/building/build-projection
                 agentic-ai-lab-make-observed-package-spec-projector
                 agentic-ai-lab-observe-build-projection
                 agentic-ai-lab-build-elapsed-milliseconds)
        (only-in :yuanxu/observability/output
                 yuanxu-write-observation-line!))

(export build-projection-observability-test)

(def (contains? text fragment)
  (and (string-contains text fragment) #t))

(def build-projection-observability-test
  (test-suite "POO PackageSpec projection observability"
    (yuanxu-test-case "native package init entries coexist without forcing either graph"
      (yuanxu-write-observation-line! "init-entry source=%s"
        (module-context-path (core-import-module ':yuanxu/init)))
      (check-equal? (eq? yuanxu.init.exports agentic-ai-lab.init.exports) #f)
      (check-equal? (.ref/cached yuanxu.init.exports 'Modules) #f)
      (check-equal? (.ref/cached agentic-ai-lab.init.exports 'Core) #f)
      (check-equal? (.ref/cached (.get yuanxu.init.exports tests) 'selected-graph) #f)
      (check-equal? (.ref/cached (.get agentic-ai-lab.init.exports tests) 'selected-graph) #f))
    (yuanxu-test-case "native package catalog reaches the supplied projector unchanged"
      (let ((projected? #f)
            (port (open-output-string))
            (package-spec (.o)))
        (parameterize ((current-output-port port))
          ((agentic-ai-lab-make-observed-package-spec-projector
            (lambda (_package-spec)
              (set! projected? #t)
              '("modules/workflow/control-plane/api.ss" "modules/module-authoring/module-descriptor.ss"))
            agentic-ai-lab-default-build-observability-policy)
           package-spec))
        (let (output (get-output-string port))
          (check-equal? projected? #t)
          (check-equal? (contains? output "phase=spec-input") #f)
          (check-equal? (contains? output "phase=spec-projected") #t)
          (check-equal? (contains? output "target-count=2") #t)
          (check-equal? (contains? output "phase=executor-handoff") #t)
          (check-equal? (contains? output "phase=executor-active") #f))))

    (yuanxu-test-case "package build delegates selection and execution to Core and std/make"
      (let ((source (call-with-input-file "build.ss" read-all-as-string))
            (projection (call-with-input-file "build-spec.ss" read-all-as-string)))
        (check-equal? (contains? source ":asp-gerbil-scheme/") #f)
        (check-equal? (contains? source ":yuanxu/module-system/building/script") #t)
        ;; Core passes its admitted value into the unchanged SDK macro.
        (check-equal? (contains? source "(defbuild-script (modules-spec retained-spec))") #t)
        (check-equal? (contains? source "std-make-run") #f)
        (check-equal? (contains? projection "package-library-spec") #t)))

    (yuanxu-test-case "Bazel stages one package surface without owning the module graph"
      (let ((root-build
             (call-with-input-file "BUILD.bazel" read-all-as-string)))
        (check-equal? (contains? root-build
                                 "name = \"gerbil_package_sources\"")
                      #t)
        (check-equal? (contains? root-build "\"*.ss\"") #t)
        (check-equal? (contains? root-build "scheme_build_sources") #f)
        (check-equal? (contains? root-build "\"testing-api.ss\"") #f)
        (check-equal? (contains? root-build
                                 "srcs = [\":gerbil_package_sources\"]")
                      #t)
        (check-equal? (contains? root-build
                                 "build_script = \":build.ss\"")
                      #t)))

    (yuanxu-test-case "performance suite consumes the public POO testing interface"
      (let (performance-source
            (call-with-input-file "dev/performance-tests.ss" read-all-as-string))
        (check-equal?
         (contains?
          performance-source
          "+agentic-ai-lab-testing-interface+")
         #t)
        (check-equal?
         (contains? performance-source "+asp-testing-interface+")
         #f)))

    (yuanxu-test-case "Just test launch is fail-closed before Profile loading"
      (let ((environment (call-with-input-file "dev/just/environment.just" read-all-as-string))
            (testing (call-with-input-file "dev/just/testing.just" read-all-as-string))
            (driver (call-with-input-file "t/qualification/testing/specialized.ss" read-all-as-string)))
        (check-equal? (contains? environment "env_var_or_default(\"GERBIL_TEST_MAX_HEAP\", \"1G\")") #t)
        (check-equal? (contains? environment "env_var_or_default(\"GERBIL_TEST_DEBUG\", \"q\")") #t)
        (check-equal? (contains? testing "gxi {{ gerbil_test_runtime_options }} t/qualification/testing/specialized.ss package") #t)
        (check-equal? (contains? driver "(list \"gerbil\" vm \"env\" \"gxi\" vm \"./dev/unit-tests.ss\")") #t)
        (check-equal? (contains? testing ".devenv/devenv-profile-exec") #f)
        (check-equal? (contains? testing "rm -rf") #f)))

    (yuanxu-test-case "unit tests inherit the Agentic AI Lab default testing policy"
      (let (source (call-with-input-file "dev/unit-tests.ss" read-all-as-string))
        (check-equal?
         (contains? source ":agentic-ai-lab/dev/testing-api")
         #t)
        (check-equal?
         (contains? source "+agentic-ai-lab-testing-interface+")
         #t)
        (check-equal? (contains? source "+asp-testing-interface+") #f)
        (check-equal? (contains? source "maxHeapMiB: 1024") #f)))

    (yuanxu-test-case "default policy measures catalog size without an invented limit"
      (let (port (open-output-string))
        (parameterize ((current-output-port port))
          (agentic-ai-lab-observe-build-projection
           agentic-ai-lab-default-build-observability-policy 601 3))
        (let (output (get-output-string port))
          (check-equal? (string-prefix? "\n[agentic-ai-lab]" output) #t)
          (check-equal? (contains? output "phase=spec-projected") #t)
          (check-equal? (contains? output "target-count=601") #t)
          (check-equal? (contains? output "reason=target-count") #f))))

    (yuanxu-test-case "derived POO policy overrides the budget without environment state"
      (let ((port (open-output-string))
            (policy
             (.o (:: @ agentic-ai-lab-default-build-observability-policy)
                 (id 'build-projection/test)
                 (target-budget 700))))
        (parameterize ((current-output-port port))
          (agentic-ai-lab-observe-build-projection policy 257 3))
        (let (output (get-output-string port))
          (check-equal? (contains? output "phase=spec-projected") #t)
          (check-equal? (contains? output "phase=spec-budget-exceeded") #f))))

    (yuanxu-test-case "derived POO policy can admit against measured package evidence"
      (let ((port (open-output-string))
            (policy
             (.o (:: @ agentic-ai-lab-default-build-observability-policy)
                 (id 'build-projection/qualification)
                 (target-budget 256)
                 (target-budget-action 'observe))))
        (parameterize ((current-output-port port))
          (agentic-ai-lab-observe-build-projection policy 257 3))
        (let (output (get-output-string port))
          (check-equal? (contains? output "phase=spec-budget-exceeded") #t)
          (check-equal? (contains? output "reason=target-count") #t)
          (check-equal? (contains? output "budget=256") #t))))

    (yuanxu-test-case "concurrent Owner receipts remain complete line records"
      (let* ((worker-count 12)
             (records-per-worker 40)
             (port (open-output-string))
             (workers
              (map (lambda (worker-id)
                     (spawn
                      (lambda ()
                        (parameterize ((current-output-port port))
                          (let loop ((sequence 0))
                            (when (< sequence records-per-worker)
                              (yuanxu-write-observation-line!
                               "[agentic-ai-lab-test] worker=%a sequence=%a"
                               worker-id sequence)
                              (loop (+ sequence 1))))))))
                   (iota worker-count))))
        (for-each thread-join! workers)
        (let* ((output (get-output-string port))
               (lines (string-split output #\newline))
               (records (filter (lambda (line) (not (string=? line ""))) lines)))
          (check-equal? (length records) (* worker-count records-per-worker))
          (check-equal?
           (andmap (lambda (line)
                     (and (string-prefix? "[agentic-ai-lab-test] worker=" line)
                          (contains? line " sequence=")))
                   records)
           #t))))

    (yuanxu-test-case "Owner elapsed time is sampled from the wall clock"
      (let (started-jiffy (current-jiffy))
        (thread-sleep! 0.03)
        (check-equal?
         (>= (agentic-ai-lab-build-elapsed-milliseconds started-jiffy) 20)
         #t)))))
