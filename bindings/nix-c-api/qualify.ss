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
  (map (lambda (name) (let (path (local name)) (cons path (module-source-read path))))
    '("dependencies.json" "session.h" "worker.c" "binding.ss" "session.ss"
      "compatibility.ss" "tests/cases.ss" "tests/embedding-test.ss" "tests/qualification-test.ss" "tests/flake-cases.ss")))
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
  (unless (member backend '("worker" "embedded" "embedded-preload"))
    (error "unknown C API qualification backend" backend))
  (def packages (.o PKG_CONFIG_PATH: (package-path)))
  (def flags (words (execute '("pkg-config" "--cflags" "nix-flake-c") packages)))
  (def libraries (words (execute '("pkg-config" "--libs" "nix-flake-c") packages)))
  (def library-directory (string-trim (execute '("pkg-config" "--variable=libdir" "nix-flake-c") packages)))
  (def worker? (equal? backend "worker"))
  (def test-file (local (if worker? "tests/qualification-test.ss" "tests/embedding-test.ss")))
  (if worker?
    (execute (append '("/usr/bin/clang" "-O2") flags
                (list (string-append "-I" directory) (local "worker.c")) libraries
                (list "-o" (path-expand "worker" build))))
    (execute (list "gxc" "-:max-heap=2G,debug=q" "-d" build
                  "-cc-options" (string-join (append flags (list (string-append "-I" directory))) " ")
                  "-ld-options" (string-join libraries " ") (local "binding.ss"))
      (.o COMPILER_PATH: "/usr/bin" CPATH: "" LIBRARY_PATH: "" SDKROOT: "")))
  (def cli-output (string-trim (execute (list (dependency "cli") "--version"))))
  (unless (string-prefix? "nix (Nix) " cli-output) (error "unexpected Nix version output" cli-output))
  (def cli-version (substring cli-output 10 (string-length cli-output)))
  (def loadpath (string-append build ":" root ":" (getenv "GERBIL_LOADPATH" "")))
  (def test-environment
    (.o GERBIL_LOADPATH: loadpath
        POO_FLOW_NIX_C_API_ROOT: root
        POO_FLOW_NIX_C_API_CLI: (dependency "cli")
        POO_FLOW_NIX_C_API_CLI_VERSION: cli-version
        POO_FLOW_NIX_C_API_WORKER: (path-expand "worker" build)))
  (def test-command '("gxtest" "-:max-heap=2G,debug=q"))
  (when (equal? backend "embedded-preload")
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
  ;; Core owns marker validation, fixture cleanup, return currentness and limits.
  (.def (Test @ TestingScript.)
    case-count: (if worker? 3 4)
    required-lines: (if worker? '() '("ASSERT-OK failed-lock-never-written"))
    source: (.o spec: (list test-file) source-root: root admit-current: current!)
    command: (append test-command (list "-v" "5" test-file))
    environment: test-environment
    profile: =>.+ (.o max-duration-milliseconds: 120000 max-idle-milliseconds: 60000))
  (display (.get (.call Test .run) output)))

(def (main mode)
  (if (equal? mode "dependencies")
    (display (execute (list "nix-store" "--realise" (dependency "expr")
                          (dependency "store") (dependency "util") (dependency "flake"))))
    (call-with-temporary-directory "poo-flow-nix-api" (cut qualify mode <>))))

;; gxi invokes main after loading the script; never invoke it again here.
