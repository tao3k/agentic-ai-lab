;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Product preparation over Core Ops/TestingScript; no second test protocol.
(import :clan/poo/object
        (only-in :std/source this-source-file)
        (only-in :std/string/misc string-trim)
        (only-in :std/encoding/json read-json JSONReadOptions)
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :yuanxu/ops/func run-script)
        (only-in :yuanxu/ops/process-script ProcessScript.)
        (only-in :yuanxu/observability/testing-script TestingScript.)
        (only-in :yuanxu/module-system/source/admission module-source-read module-source-admit-current!))

(def directory (path-directory (this-source-file)))
(def root (path-expand "../.." directory))
(def (local path) (path-expand path directory))
(def lock
  (call-with-input-file (local "dependencies.json")
    (lambda (port) (read-json port (JSONReadOptions object-as-hash: #t)))))
(def (dependency name) (hash-ref lock name))
(def observations
  (append
  (map (lambda (name) (let (path (local name)) (cons path (module-source-read path))))
    '("dependencies.json" "session.h" "worker.c" "binding.ss" "session.ss"
      "compatibility.ss" "tests/cases.ss" "tests/embedding-test.ss" "tests/qualification-test.ss" "tests/flake-cases.ss" "tests/profile-test.ss"))
  (map (lambda (name) (let (path (path-expand name root)) (cons path (module-source-read path))))
    '("modules/nix/objects.ss" "modules/nix/func.ss" "modules/nix/types.ss" "t/nix-flake-source-test.ss"))))
(def (current!) (module-source-admit-current! observations))

(def (execute command (environment (.o)))
  (current!)
  (let (receipt
         (run-script (.cc ProcessScript. 'command command 'directory root
                       'timeout 120 'environment environment)))
    (current!)
    (.get receipt output)))
(def (words text) (filter (lambda (word) (not (string-empty? word))) (string-split (string-trim text) #\space)))
(def (package-path)
  (string-join (map (lambda (name) (string-append (dependency name) "/lib/pkgconfig"))
                   '("flake-dev" "fetchers-dev" "expr-dev" "store-dev" "util-dev")) ":"))

(def (qualify backend build)
  (unless (member backend '("worker" "embedded" "embedded-preload" "profile" "product-native" "product-cli"))
    (error "unknown C API qualification backend" backend))
  (def packages (.o PKG_CONFIG_PATH: (package-path)))
  (def flags (words (execute '("pkg-config" "--cflags" "nix-flake-c") packages)))
  (def libraries (words (execute '("pkg-config" "--libs" "nix-flake-c") packages)))
  (def library-directory (string-trim (execute '("pkg-config" "--variable=libdir" "nix-flake-c") packages)))
  (def worker? (equal? backend "worker"))
  (def profiling? (equal? backend "profile"))
  (def product? (member backend '("product-native" "product-cli")))
  (def test-file (local (cond (worker? "tests/qualification-test.ss")
                             ((equal? backend "product-native") "tests/product-test.ss")
                             ((equal? backend "product-cli") "../../t/nix-flake-source-test.ss")
                             (profiling? "tests/profile-test.ss")
                             (else "tests/embedding-test.ss"))))
  (if worker?
    (execute (append '("/usr/bin/clang" "-O2") flags
                (list (string-append "-I" directory) (local "worker.c")) libraries
                (list "-o" (path-expand "worker" build))))
    (execute (list "gxc" "-:max-heap=2G,debug=q" "-d" build
                  "-cc-options" (string-join (append flags (list (string-append "-I" directory))) " ")
                  "-ld-options" (string-join libraries " ") (local "binding.ss"))
      (.o COMPILER_PATH: "/usr/bin" CPATH: "" LIBRARY_PATH: "" SDKROOT: "")))
  (when (equal? backend "product-native")
    ;; Native absolute compiled imports keep std/make from treating this
    ;; already-built C binding as an ordinary local Scheme support root.
    (set! test-file (path-expand "product-test.ss" build))
    (call-with-output-file test-file
      (lambda (port)
        (pretty-print
          `(import :std/test :clan/poo/object
             (only-in ,(path-expand "agentic-ai-lab/bindings/nix-c-api/binding.ssi" build)
               call-with-flake-evaluator)
             (only-in ,(path-expand "t/nix-flake-source-test.ss" root) nix-flake-source-suite)) port)
        (pretty-print '(export product-test) port)
        (pretty-print
          '(def (with-owned-evaluator procedure)
             (def escaped #f)
             (def result
               (call-with-flake-evaluator
                 (lambda (scope)
                   (check-equal? (.ref/cached scope 'handle) #f)
                   (set! escaped scope)
                   (procedure scope))))
             (check-exception
               (.call escaped .instantiate "closed" "closed" (.o) (.o) "nix") error?)
             result) port)
        (pretty-print '(def product-test (nix-flake-source-suite with-owned-evaluator)) port))))
  (def profile-cache (path-expand "nix-cache" build))
  (when profiling? (create-directory profile-cache))
  (def package-start (real-time))
  (def profile-package
    (and profiling?
      (string-trim
        (execute (list (dependency "cli") "--extra-experimental-features" "nix-command flakes" "eval" "--impure" "--raw" "--expr"
                   (string-append "(import " (path-expand "t/fixtures/nixpkgs.nix" root) ").outPath"))
          (.o XDG_CACHE_HOME: profile-cache)))))
  (when profiling?
    (displayln "NIX-PROFILE-PREPARATION package-set-seconds=" (- (real-time) package-start))
    (force-output))
  (def cli-output (string-trim (execute (list (dependency "cli") "--version"))))
  (unless (string-prefix? "nix (Nix) " cli-output) (error "unexpected Nix version output" cli-output))
  (def cli-version (substring cli-output 10 (string-length cli-output)))
  (def loadpath (string-append build ":" root ":" (getenv "GERBIL_LOADPATH" "")))
  (def test-environment
    (.o GERBIL_LOADPATH: loadpath
        AGENTIC_AI_LAB_NIX_C_API_ROOT: root
        AGENTIC_AI_LAB_NIX_C_API_CLI: (dependency "cli")
        AGENTIC_AI_LAB_NIX_C_API_CLI_VERSION: cli-version
        AGENTIC_AI_LAB_NIX_C_API_WORKER: (path-expand "worker" build)))
  (when profiling?
    (set! test-environment
      (.+ test-environment
        (.o XDG_CACHE_HOME: profile-cache
            AGENTIC_AI_LAB_NIX_PROFILE_METRICS: "1"
            AGENTIC_AI_LAB_NIX_PROFILE_PACKAGE_SET: profile-package))))
  (def test-command '("gxtest" "-:max-heap=2G,debug=q"))
  (when (member backend '("embedded-preload" "profile" "product-native" "product-cli"))
    (let* ((installed (string-trim (execute '("which" "gerbil"))))
           (actual (string-trim (execute (list "realpath" installed))))
           (prefix (path-directory (path-strip-trailing-directory-separator (path-directory actual))))
           (runtime (path-expand "current" prefix)))
      (set! test-command (list (path-expand "bin/gxtest" runtime) "-:max-heap=2G,debug=q"))
      (set! test-environment
        (.+ test-environment
          (.o GERBIL_PREFIX: prefix GERBIL_HOME: runtime
              GAMBOPT: (string-append "~~=" runtime ",~~bin=" runtime "/bin,~~lib=" runtime "/lib")
              DYLD_INSERT_LIBRARIES: (path-expand "libnixflakec.dylib" library-directory))))))
  (when product?
    ;; Both controls use this Just-owned TestingScript/Harness gate and the
    ;; resolved native binary: Homebrew's shell launcher drops DYLD preload
    ;; before Nix can initialize. Limits and exact Harness checks are unchanged.
    (set! test-environment (.+ test-environment (.o NIX_CONFIG: "pure-eval = true"))))
  ;; Core owns marker validation, fixture cleanup, return currentness and limits.
  (.def (Test @ TestingScript.)
    case-count: (cond (product? 1) (worker? 3) (profiling? 1) (else 4))
    required-lines: (cond (product? '("ASSERT-OK failed-eval-did-not-write-lock"))
                          (worker? '()) (profiling? '("ASSERT-OK profile-controls-complete"))
                          (else '("ASSERT-OK failed-lock-never-written")))
    source: (.o spec: (list test-file) source-root: root admit-current: current!)
    command: (append test-command (list "-v" "5" test-file))
    log: (and profiling? (getenv "AGENTIC_AI_LAB_NIX_PROFILE_LOG" #f))
    environment: test-environment
    profile: =>.+ (.o max-duration-milliseconds: 120000 max-idle-milliseconds: 60000))
  (display (.get (.call Test .run) output)))

(def (main mode)
  (if (equal? mode "dependencies")
    (display (execute (list "nix-store" "--realise" (dependency "expr")
                          (dependency "store") (dependency "util") (dependency "flake"))))
    (call-with-temporary-directory "agentic-ai-lab-nix-api" (cut qualify mode <>))))

;; gxi invokes main after loading the script; never invoke it again here.
