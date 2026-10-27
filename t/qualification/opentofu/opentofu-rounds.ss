;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Native operational coordination; std/test remains the assertion authority.
(import :clan/poo/object "./objects.ss"
        :std/cli/getopt
        (only-in :yuanxu/profile-composition/selection-syntax use-module)
        (only-in :std/error Error? Error-message)
        (only-in :std/source this-source-file)
        (only-in :std/misc/ports read-all-as-string read-all-as-lines)
        (only-in :std/text/pregexp pregexp-match)
        (only-in :std/string/misc string-trim)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :yuanxu/module-system/source/admission module-source-admit-current!)
        (only-in :yuanxu/module-system/source/build unique-build-inputs)
        (only-in :yuanxu/observability/testing-script admit-testing-result)
        (only-in "../../../init.ss" agentic-ai-lab.init.exports)
        :std/encoding/json)
(export main aggregate snapshots publication-observations assert-control)
(def root (path-normalize (path-expand "../../.." (path-directory (this-source-file)))))
(def (json-file path)
  (parameterize ((current-json-read-options (JSONReadOptions key-as-symbol: #t object-as-hash: #t)))
    (call-with-input-file path read-json)))
(def (canonical-directory path)
  (path-strip-trailing-directory-separator (path-normalize path)))
(def (write-json-file path value)
  (call-with-output-file (list path: path truncate: #t)
    (lambda (port) (write-json port value) (newline port))))
(def (snapshots observations)
  ;; These are original native publication observations, not a guessed source
  ;; roster. The existing source guard authenticates bytes and absent inputs.
  (module-source-admit-current! observations)
  (map (lambda (entry)
         (cons (car entry)
           (and (cdr entry) (hex-encode (sha256 (string->utf8 (cdr entry)))))))
    (list-sort (lambda (left right) (string<? (car left) (car right))) observations)))
(def (publication-observations tests build)
  ;; Suite bytes and compiler support have distinct native owners. Preserve
  ;; both sets through the existing conflict-checking observation projection.
  (unique-build-inputs
    (append (.get tests source source-inputs) (.get build source-inputs))))
(def (sources-current? tests build initial)
  (with-catch (lambda (_) #f)
    (lambda ()
      ((.get tests source admit-current))
      ((.get build admit-current))
      (equal? (snapshots (publication-observations tests build)) initial))))
(def (stats values)
  (let* ((ordered (list-sort < values)) (n (length ordered)) (middle (quotient n 2)))
    (hash (min (car ordered)) (max (car (last-pair ordered)))
          (median (if (odd? n) (list-ref ordered middle)
                    (/ (+ (list-ref ordered (- middle 1)) (list-ref ordered middle)) 2.))))))
(def (aggregate rounds)
  (let (labels (map (cut hash-ref <> 'phase) (hash-ref (car rounds) 'phases)))
    (unless (every (lambda (round) (equal? labels (map (cut hash-ref <> 'phase) (hash-ref round 'phases)))) rounds)
      (error "measurement phase set changed between rounds"))
    (list->hash-table
      (map (lambda (label index)
             (let* ((rows (map (lambda (round) (list-ref (hash-ref round 'phases) index)) rounds))
                    (value (hash (samples (length rows))
                                 (seconds (stats (map (cut hash-ref <> 'seconds) rows))))))
               (for-each
                 (lambda (field)
                   (when (every (cut hash-key? <> field) rows)
                     (hash-put! value field (stats (map (cut hash-ref <> field) rows)))))
                 '(nix-seconds native-seconds source-check-seconds))
               (for-each (lambda (field) (when (every (cut hash-key? <> field) rows)
                                          (hash-put! value field (map (cut hash-ref <> field) rows))))
                 '(instantiate realize type-reads type-compiles source-checks source-reads
                   source-read-requests source-stats source-query-hits source-query-misses))
               (cons (string->symbol label) value)))
           labels (iota (length labels))))))
(def (tool-text script)
  (string-trim (.get (.call script .run) output)))
(def (load-sample started)
  (let (match (pregexp-match "load averages?:[ ]*([0-9.]+)[, ]+([0-9.]+)[, ]+([0-9.]+)"
                            (tool-text (.get Ops tools HostLoad))))
    (unless match (error "cannot observe host load"))
    (hash (seconds (- (real-time) started))
          (load_average (map string->number (cdr match))))))
(def (time-field lines prefix)
  (cond ((find (cut string-prefix? prefix <>) lines)
         => (lambda (line) (string->number (string-trim (substring line (string-length prefix) (string-length line))))))
        (else #f)))
;; A script is specialized once with argv, logging and environment. Its .run
;; and the public run function share run-script; sampling cannot decide admission.
(def (observe-control script arguments host-path)
  (let ((started (real-time)) (samples '()) (stopped? #f))
    (def sampler
      (spawn (lambda () (let loop ()
                         (unless stopped?
                           (set! samples (cons (load-sample started) samples))
                           (thread-sleep! 1) (loop))))))
    (dynamic-wind void
      (lambda ()
        (use-module Ops as ops
          (with-slots (run) ops (run script arguments))))
      (lambda ()
        (set! stopped? #t) (thread-join! sampler)
        (let (lines (if (file-exists? (.get script log))
                       (call-with-input-file (.get script log) read-all-as-lines) '()))
          (write-json-file host-path
            (hash (wall_seconds (- (real-time) started))
                  (waited_child_user_seconds (time-field lines "user "))
                  (waited_child_system_seconds (time-field lines "sys "))
                  (load_samples (reverse samples))
                  (scope "host load; /usr/bin/time waited-for test cohort, excluding Nix daemon workers"))))))))
(def (assert-control result log test)
  (def text (call-with-input-file log read-all-as-string))
  ;; Core owns process status, exact Module/Harness completion and every native
  ;; error marker. This operational summary only counts admitted assertions.
  (admit-testing-result (.cc result 'output text)
    (list (path-expand test root)))
  (length (filter (cut string-prefix? "ASSERT-OK" <>)
            (string-split text #\newline))))
(def (qualify options)
  (let* ((output (hash-get options 'output)) (round-count (hash-ref options 'rounds))
         (flake (hash-get options 'selected-flake)) (artifact (hash-get options 'flake-artifact)))
    (unless (and output (integer? round-count) (<= 3 round-count 20))
      (error "provide --output and 3..20 serial rounds"))
    (when (file-exists? output) (error "qualification output must be fresh" output))
    (create-directory* output)
    ;; Select actual Suite inputs through the existing init owner. Its compiler
    ;; projection owns imported support, package headers and native C inputs.
    ;; Each external Nix Source retains its own transitive currentness checks
    ;; inside the actual Cases; this summary does not impersonate that owner.
    (def tests
      (.call (.get agentic-ai-lab.init.exports tests) .for-files
        (map (cut path-expand <> root)
          (append '("t/opentofu-selected-graph-test.ss")
            (if artifact '("t/nix-flake-source-test.ss") '())))))
    (def build (.get tests build))
    ((.get build admit-current))
    (let* ((initial (snapshots (publication-observations tests build))) (rounds '()) (flake-rounds '())
           (report (hash (status "incomplete") (requested_rounds round-count)
                         (runtime "default Gerbil; native Ops scripts invoke heap-fenced Just tests")
                         (source_sha256 (list->hash-table initial))
                         (source_scope "native test publication inputs; actual Nix Cases own external transitive data")
                         (cpu_count (string->number (tool-text (.get Ops tools CPUCount))))
                         (nix_version (tool-text (.get Ops tools NixVersion)))
                         (nixpkgs (tool-text (.get Ops tools PackageSet)))
                         (cold "fresh Scheme process/scope; populated Nix store, not download cold")
                         (hot "five cached receiver accesses; independent currentness is measured separately")
                         (process_scope "Nix CLI starts at native process boundary; not daemon worker totals")
                         (rounds '()) (flake_rounds '())))
           (receipt (path-expand "summary.json" output)))
      (def (current!) (unless (sources-current? tests build initial) (error "qualification source changed")))
      (def (round! index flake-test?)
        (let* ((prefix (string-append (if flake-test? "flake-round-" "round-") (number->string index)))
               (metrics (path-expand (string-append prefix ".json") output))
               (log (path-expand (string-append prefix ".log") output))
               (host (path-expand (string-append prefix "-host.json") output))
               (base-env (.o NIX_PATH: (string-append "nixpkgs=" (hash-ref report 'nixpkgs))))
               ;; Reuse inputs already owned by the actual native Cases. These
               ;; are data bindings, not another test selector or argv protocol.
               (input-env
                 (cond (flake-test?
                        (.cc base-env 'AGENTIC_AI_LAB_OPENTOFU_FLAKE_ARTIFACT artifact))
                       (flake
                        (.cc base-env 'AGENTIC_AI_LAB_OPENTOFU_GRAPH_FLAKE flake))
                       (else base-env)))
               (env (if flake-test?
                      (.cc input-env 'AGENTIC_AI_LAB_NIX_FLAKE_METRICS metrics)
                      (.cc input-env 'AGENTIC_AI_LAB_OPENTOFU_GRAPH_METRICS metrics
                        'AGENTIC_AI_LAB_OPENTOFU_GRAPH_TRACE
                        (path-expand (string-append prefix ".jsonl") output))))
               (base (if flake-test? (.get Ops tests FlakeSource)
                                    (.get Ops tests SelectedGraph)))
               (script (.cc base 'directory root 'environment env 'log log))
               (_log-recorded (hash-put! report 'last_control_log log))
               (result (observe-control script '() host))
               (assertions (assert-control result log (if flake-test? "t/nix-flake-source-test.ss" "t/opentofu-selected-graph-test.ss")))
               (value (json-file metrics)))
          (hash-put! value 'round index) (hash-put! value 'assertions assertions)
          (hash-put! value 'host (json-file host))
          (displayln (if flake-test? "FLAKE-ROUND-OK " "ROUND-OK ") index "/" round-count " assertions=" assertions)
          (force-output) value))
      (dynamic-wind void
        (lambda ()
          (with-catch
            (lambda (exception)
              (hash-put! report 'status "failed")
              (hash-put! report 'error (if (Error? exception) (Error-message exception)
                                         "native qualification exception; see retained log"))
              (hash-put! report 'source_unchanged (sources-current? tests build initial))
              (write-json-file receipt report)
              (raise exception))
            (lambda ()
              (for-each (lambda (index)
                          (current!)
                          (set! rounds (append rounds (list (round! index #f))))
                          (hash-put! report 'rounds rounds) (write-json-file receipt report)
                          (when artifact
                            (set! flake-rounds (append flake-rounds (list (round! index #t))))
                            (hash-put! report 'flake_rounds flake-rounds)))
                        (iota round-count 1))
              (current!) (hash-put! report 'source_unchanged #t)
              (hash-put! report 'aggregate (aggregate rounds))
              (when artifact (hash-put! report 'flake_aggregate (aggregate flake-rounds)))
              (hash-put! report 'status "passed"))))
        (lambda () (write-json-file receipt report)))
      (displayln "ROUNDS-OK " receipt))))
(def (main . arguments)
  (call-with-getopt qualify arguments program: "opentofu-rounds"
    help: "Run native POO Ops declarations serially; preserve Just watchdogs and all Scheme assertions."
    (option 'output "--output" value: path-expand)
    (option 'rounds "--rounds" value: string->number default: 3)
    (option 'selected-flake "--selected-flake" value: canonical-directory)
    (option 'flake-artifact "--flake-artifact" value: canonical-directory)))
