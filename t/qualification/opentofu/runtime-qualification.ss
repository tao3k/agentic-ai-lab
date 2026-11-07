;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Explicit qualification through just test-file. Directory discovery omits it.
(import :std/test :clan/poo/object
        (only-in :gerbil/runtime/loader list-modules)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :std/misc/ports read-all-as-u8vector)
        (only-in :std/misc/process run-process)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :yuanxu/module-system/source/admission call-with-module-source-operation-measurement)
        (only-in :yuanxu/modules/funflow/objects Job. Task.)
        (only-in :yuanxu/modules/funflow/func run-job)
        (only-in :agentic-ai-lab/modules/nix/func current-nix-process-completion-observer)
        (only-in :agentic-ai-lab/modules/services/opentofu/execution NullExecution.)
        (only-in "./service.ss" call-with-service empty-state? rejects? write-source))
(export runtime-qualification-test)

(def (path-command name)
  (run-process (list "which" name) coprocess: read-line))

(def (measure recipe workspace round paired?)
  (def nix-count 0)
  (def incomplete-count 0)
  (def evaluator-count 0)
  (def evaluator-seconds 0.)
  (def cli-seconds 0.)
  (def started (real-time))
  (def cpu-started (cpu-time))
  (def result
    (parameterize
        ((current-nix-process-completion-observer
           (lambda (command seconds completed?)
             ;; This observer also runs while a failing process unwinds.
             ;; Keep the original process diagnostic.
             (unless completed? (set! incomplete-count (+ incomplete-count 1)))
             (set! nix-count (+ nix-count 1))
             (if (equal? command '(native-fresh-evalstate))
               (begin
                 (set! evaluator-count (+ evaluator-count 1))
                 (set! evaluator-seconds (+ evaluator-seconds seconds)))
               (set! cli-seconds (+ cli-seconds seconds))))))
      (.call recipe .run workspace)))
  (def wall (- (real-time) started))
  (def cpu (- (cpu-time) cpu-started))
  (def steps (.get result steps))
  (def commands '(init validate plan apply output destroy))
  (check-equal? (length (.all-slots steps)) (length commands))
  (def durations
    (map (lambda (name)
           (def step (.ref steps name))
           (check-equal? (.get step status) 0)
           (cons name (.get step seconds)))
         commands))
  (check-equal? nix-count 14)
  (check-equal? incomplete-count 0)
  (check-equal? evaluator-count (if paired? 13 0))
  (check-equal? (.get result output) "selected ${literal} %{literal}")
  (check-equal? (empty-state? workspace) #t)
  (newline)
  (write (list 'OPENTOFU-RUNTIME round
               (cons 'wall wall) (cons 'scheme-cpu cpu)
               (cons 'nix-checks nix-count) (cons 'evaluator-checks evaluator-count)
               (cons 'nix-seconds (+ evaluator-seconds cli-seconds))
               (cons 'evaluator-seconds evaluator-seconds)
               (cons 'nix-cli-seconds cli-seconds)
               (cons 'tofu-steps durations)))
  (newline)
  (force-output)
  wall)

(def (measure-dispatch workspace child?)
  (def receipt (.o status: 0 wait-status: 0 seconds: 0. output: "" log: #f))
  (def process (.cc Task. 'command (list (path-command "true")) 'timeout 20))
  (def task (if child? process (.cc process '.run (lambda () receipt))))
  (def job
    (.cc Job. 'selected '(output) 'finalizers '(destroy)
         'tasks (.o init: task validate: (.cc task 'needs '(init))
                    plan: (.cc task 'needs '(validate)) apply: (.cc task 'needs '(plan))
                    output: (.cc task 'needs '(apply)) destroy: (.cc task 'after-start 'apply))))
  (for-each
    (lambda (round)
      (def wall (real-time))
      (def cpu (cpu-time))
      (def result (run-job job workspace))
      (def elapsed (- (real-time) wall))
      (def used (- (cpu-time) cpu))
      (check-equal? (length (.all-slots (.get result steps))) 6)
      (check-equal? (.get result steps destroy status) 0)
      (write (list 'OPENTOFU-DISPATCH (if child? 'ops-process 'scheme)
                   round (cons 'wall elapsed) (cons 'scheme-cpu used)))
      (newline))
    '(1 2 3)))

(def (measure-sources recipe workspace paired?)
  (defvalues (_wall counts)
    (call-with-module-source-operation-measurement
      (lambda () (measure recipe workspace 'source-accounting paired?))))
  (write (cons 'OPENTOFU-SOURCES
    (map (lambda (key) (cons key (hash-get counts (list 'source key))))
         '(stats reads source-comparisons source-comparison-hits read-windows))))
  (newline)
  (write (cons 'OPENTOFU-SOURCE-SPANS
    (filter-map
      (lambda (stage)
        (let (seconds (hash-get counts stage))
          (and seconds (list stage (hash-get counts (list 'calls stage)) seconds))))
      '(link-current reader-current source-read metadata-replay metadata-checkpoints
        native-configuration-request prepared-batch-closed prepared-batch-open
        prepared-batch-observed prepared-batch-checkpoint compiler-metadata-reader
        compiler-metadata-inputs compiler-metadata-preflight publication-admission))))
  (newline)
  (write (list 'OPENTOFU-METADATA-VISITS (hash-get counts '(visits metadata-replay))))
  (newline)
  ;; The replay span is inclusive of its checkpoints. CPU and GC attribution
  ;; belong to this diagnostic run, outside the three qualification samples.
  (write (cons 'OPENTOFU-REPLAY-ACCOUNTING
    (map (lambda (metric)
           (cons metric (hash-get counts (list metric 'metadata-replay))))
         '(cpu-user cpu-system gc-wall collections minor-faults major-faults wall-cpu-gap))))
  (newline)
  (def reader-sites '())
  (hash-for-each
    (lambda (key calls)
      (match key
        (['calls ['reader-current phase]]
         (let (stage (cadr key))
           (set! reader-sites
             (cons (list phase calls (hash-get counts (list 'read-attempts stage)))
                   reader-sites))))
        (else (void))))
    counts)
  (write (cons 'OPENTOFU-READER-SITES
    (list-sort (lambda (left right)
                 (string<? (symbol->string (car left)) (symbol->string (car right))))
               reader-sites)))
  (newline))

(def (measure-current-boundaries recipe workspace paired?)
  ;; Keep the compiled execution and real guards. These wrappers attribute
  ;; inclusive work at the public boundaries, in a separate diagnostic round.
  (def counts (make-hash-table))
  (def (account name guard)
    (lambda ()
      (def started (real-time))
      (defvalues (value operations)
        (call-with-module-source-operation-measurement guard accounting?: #f))
      (def (work key) (hash-ref operations key 0))
      (hash-update! counts name
        (lambda (previous)
          (map + previous
            (list 1 (work '(calls native-configuration-request))
                    (work '(calls metadata-replay)) (work '(source reads))
                    (- (real-time) started))))
        '(0 0 0 0 0.))
      value))
  (def publication (.get recipe publication))
  (def context (.get publication context))
  (def measured
    (.cc recipe
      'publication
      (.cc publication
        'context (.cc context 'admit-current
                      (account 'context (.get context admit-current)))
        'package-current (account 'publication-package (.get publication package-current)))
      'package-current (account 'execution-package (.get recipe package-current))))
  (measure measured workspace 'boundary-accounting paired?)
  (write (cons 'OPENTOFU-CURRENT-BOUNDARIES
               (map (lambda (name) (cons name (hash-ref counts name)))
                    '(context publication-package execution-package))))
  (newline)
  (force-output))

(def (check-task-before-evaluator recipe workspace config-directory)
  (def detached-command (list (path-command "false")))
  (.def (Detached @ recipe)
    tasks: =>.+ (.o output: =>.+ (.o command: detached-command)))
  (def config (path-expand "nix.conf" config-directory))
  (write-source config (string-append "include " (path-expand "absent.conf" config-directory) "\n"))
  (def original (getenv "NIX_USER_CONF_FILES" #f))
  ;; A worker started before preflight would fail to read its required
  ;; configuration and mask the detached-task diagnosis.
  (dynamic-wind
    (lambda () (setenv "NIX_USER_CONF_FILES" config))
    (lambda ()
      (check-equal? (rejects? "selected execution and engine"
                      (lambda () (.call Detached .run workspace))) #t))
    (lambda ()
      (if original (setenv "NIX_USER_CONF_FILES" original) (setenv "NIX_USER_CONF_FILES"))))
  (check-equal? (directory-files workspace) '())
  (displayln "OPENTOFU-PREFLIGHT-BEFORE-EVALUATOR-OK"))

(def (check-current-after-destroy recipe workspace config original)
  (def destroy-task (.get recipe tasks destroy))
  (def destroyed? #f)
  (.def (Changed execution [recipe])
    tasks: =>.+
    (.o destroy:
      (.cc destroy-task 'owner execution '.run
        (lambda ()
          (let (receipt (.call (.cc destroy-task 'owner execution 'directory workspace) .run))
            (check-equal? (.get receipt status) 0)
            (set! destroyed? #t)
            (write-source config (string-append original "\n;; changed after destroy\n"))
            receipt)))))
  (dynamic-wind void
    (lambda ()
      (check-equal? (rejects? "stale|changed|refused" (lambda () (.call Changed .run workspace))) #t)
      (check-equal? destroyed? #t)
      (check-equal? (empty-state? workspace) #t))
    (lambda () (write-source config original)))
  (displayln "OPENTOFU-RETURN-CURRENTNESS-OK"))

(def runtime-qualification-test
  (test-suite "Compiled OpenTofu runtime qualification"
    (yuanxu-test-case "same admitted Null receiver, three runs"
      ;; Resolve the selected PATH once, outside .run. Both comparison
      ;; processes use the installed CLI from the same Nix package set.
      (def executable (path-command "nix-instantiate"))
      (unless (and (string? executable) (string-prefix? "/nix/store/" executable))
        (error "runtime qualification requires a Nix store nix-instantiate on PATH"))
      (def paired? (file-exists? (path-expand "nix-derivation-worker" (path-directory executable))))
      (call-with-service
        (lambda (fixture)
          (def prepared (.call fixture .prepare))
          (def selected (.get prepared recipe))
          (def provider (.get selected provider))
          (def publication (.get selected publication))
          (def recipe
            (.cc NullExecution. 'provider provider 'publication publication
                 'package-current (.get selected package-current)
                 'message "selected ${literal} %{literal}"))
          (def loaded-modules (list-modules))
          (def loaded (assoc "agentic-ai-lab/modules/services/opentofu/execution~0" loaded-modules))
          (def library (path-normalize (path-expand "lib/" (gerbil-path))))
          (unless (and loaded (string? (cdr loaded))
                       (string-prefix? library (path-normalize (cdr loaded)))
                       (string-suffix? ".o1" (cdr loaded)))
            (error "runtime qualification requires the compiled execution product in GERBIL_PATH" loaded))
          (write (list 'OPENTOFU-RUNTIME-INPUT (cdr loaded)
                       (hex-encode (sha256 (call-with-input-file (cdr loaded) read-all-as-u8vector)))
                       (.get provider source value) (.get provider version) executable))
          (newline)
          (for-each
            (lambda (entry)
              (def product (assoc (cdr entry) loaded-modules))
              (unless (and product (string? (cdr product)) (string-suffix? ".o1" (cdr product)))
                (error "runtime qualification requires a compiled prerequisite" (cdr entry) product))
              (write (list (car entry) (cdr product)
                           (hex-encode (sha256 (call-with-input-file (cdr product) read-all-as-u8vector)))))
              (newline))
            '((OPENTOFU-RUNTIME-OBSERVATIONS . "yuanxu/module-system/source/observations~0")
              (OPENTOFU-RUNTIME-POO . "clan/poo/object~0")
              (OPENTOFU-RUNTIME-READ-ROUTE . "clan/poo/read-route~0")))
          (def walls
            (map (lambda (round)
                   (measure recipe (.call fixture .workspace (number->string round)) round paired?))
                 '(1 2 3)))
          (measure-sources recipe (.call fixture .workspace "source-accounting") paired?)
          (measure-current-boundaries recipe (.call fixture .workspace "boundary-accounting") paired?)
          (def dispatch (.call fixture .workspace "dispatch"))
          (measure-dispatch dispatch #f)
          (measure-dispatch dispatch #t)
          (when paired?
            (check-task-before-evaluator recipe (.call fixture .workspace "invalid-task")
                                         (.call fixture .workspace "invalid-nix-config"))
            (check-current-after-destroy recipe (.call fixture .workspace "return-currentness")
                                         (.get fixture config) (.get fixture original))
            (check-equal? (andmap (cut < <> 3.) walls) #t)))
        ;; Preparation reports real completed work. Each timed run installs
        ;; its own observer, with the same accounting and timing boundaries.
        instantiate: executable))))
