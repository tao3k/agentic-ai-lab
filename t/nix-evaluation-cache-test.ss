;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Nix owns persistence. Traces distinguish evaluation from store availability.
(import :std/test :clan/poo/object
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :std/misc/process run-process)
        (only-in :std/misc/ports read-all-as-string)
        (only-in :std/encoding/json read-json)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :yuanxu/module-system/source/admission current-module-source-observer
                 current-module-process-trace-budget)
        (only-in :agentic-ai-lab/modules/nix/objects NixFlakeSource.
                 agentic-ai-lab-nix-flake-admit-generation))
(export nix-evaluation-cache-test)

(def (write-input path text)
  (call-with-output-file (list path: path truncate: #t) (cut display text <>)))

(def nix-evaluation-cache-test
  (test-suite "Nix-owned flake evaluation cache boundaries"
    (yuanxu-test-case "exact nested attributes do not probe package-prefix alternatives"
      (call-with-temporary-directory "nix-exact-attribute"
        (lambda (root)
          (write-input (path-expand "flake.nix" root)
            (string-append
              "{ outputs = { self }: { packages.aarch64-darwin.default = "
              "builtins.trace \"core-exact-package-body\" (builtins.derivation { "
              "name = \"exact-attribute\"; system = \"aarch64-darwin\"; "
              "builder = \"/bin/sh\"; }); }; }"))
          (.def (Source @ NixFlakeSource.)
            reference: (string-append "path:" (path-normalize root))
            attribute: "packages.aarch64-darwin.default")
          (def expected #f)
          (def summaries '())
          (def previous (current-module-source-observer))
          (def (observe key amount)
            (when (and (pair? key) (eq? (car key) 'package-process-observation))
              (set! summaries (cons (cdr key) summaries)))
            (when previous (previous key amount)))
          (def (query)
            (call-with-output-string
              (lambda (port)
                (parameterize ((current-error-port port)
                               (current-module-source-observer observe)
                               (current-module-process-trace-budget (box 1)))
                  (let (actual (.call Source .instantiate))
                    (if expected (check-equal? actual expected)
                      (set! expected actual)))))))
          (def first (query))
          (def second (query))
          (check-equal? (and (string-contains first "core-exact-package-body") #t) #t)
          (check-equal? (and (string-contains second "core-exact-package-body") #t) #f)
          (check-equal? (length summaries) 2)
          (def cold-summary (cadr summaries))
          (check-equal? (> (cdr (assq 'nix-gc-root-requests cold-summary)) 0) #t)
          (check-equal? (> (cdr (assq 'package-store-validity-requests cold-summary)) 0) #t)
          ;; Inspect the already captured native records; extra Case counter
          ;; categories would consume the finite observation budget.
          (check-equal? (and (string-contains first "getting root value") #t) #t)
          (check-equal? (string-contains second "getting root value") #f)
          (check-equal? (and (string-contains second "using cached string attribute") #t) #t)
          ;; Disabling observation still keeps native progress records, and
          ;; neither a summary nor a currentness approval is retained globally.
          (def silent
            (call-with-output-string
              (lambda (port)
                (parameterize ((current-error-port port)
                               (current-module-source-observer #f)
                               (current-module-process-trace-budget #f))
                  (check-equal? (.call Source .instantiate) expected)))))
          (check-equal? (and (string-contains silent "@nix ") #t) #t)
          (check-equal? (length summaries) 2))))
    (yuanxu-test-case "native fingerprints do not equate unchanged outputs with unchanged inputs"
      (call-with-temporary-directory "nix-input-identity"
        (lambda (root)
          ;; Explicit source metadata is a controlled native input here, not a
          ;; production normalization. A consumer can observe lastModified.
          (write-input (path-expand "flake.nix" root)
            (string-append
              ;; A native content cache may outlive a temporary directory. Give
              ;; each fixture distinct input bytes rather than deleting caches
              ;; or assuming that another directory implies a cold fingerprint.
              "{ description = \"" (path-strip-directory root) "\"; "
              "outputs = { self }: let make = name: attrs: builtins.derivation ({ "
              "inherit name; system = \"aarch64-darwin\"; builder = \"/bin/sh\"; } // attrs); "
              "in { stable = builtins.trace \"core-input-identity-body\" (make \"stable-input\" {}); "
              "metadata = make \"source-metadata\" { stamp = toString self.lastModified; }; }; }"))
          (def (query stamp attribute)
            (run-process
              (list "nix" "--extra-experimental-features" "nix-command flakes"
                    "path-info" "--derivation" "--no-update-lock-file"
                    (string-append "path:" (path-normalize root)
                                   "?lastModified=" stamp "#." attribute))
              stdin-redirection: #f stderr-redirection: #t
              coprocess: read-all-as-string check-status: #t))
          (def (traced? text)
            (and (string-contains text "core-input-identity-body") #t))
          (def (derivation text)
            (find (cut string-prefix? "/nix/store/" <>) (string-split text #\newline)))
          (def cold (query "1" "stable"))
          (check-equal? (traced? cold) #t)
          (check-equal? (traced? (query "1" "stable")) #f)
          (def changed-metadata (query "2" "stable"))
          (check-equal? (traced? changed-metadata) #t)
          (check-equal? (derivation changed-metadata) (derivation cold))
          (check-equal? (traced? (query "2" "stable")) #f)
          ;; The earlier fingerprint's native cache is still reusable. There
          ;; is no global eviction and no Scheme result/currentness cache.
          (check-equal? (traced? (query "1" "stable")) #f)
          (check-equal?
            (equal? (derivation (query "1" "metadata"))
                    (derivation (query "2" "metadata"))) #f)
          ;; Whole-tree hashing also invalidates on an unconsumed file. The
          ;; output is unchanged; that alone cannot grant admission authority.
          (write-input (path-expand "unconsumed.nix" root) "{ unrelated = true; }")
          (def changed-tree (query "2" "stable"))
          (check-equal? (traced? changed-tree) #t)
          (check-equal? (derivation changed-tree) (derivation cold))
          (check-equal? (traced? (query "2" "stable")) #f))))
    (yuanxu-test-case "explicit immutable path resolution retains native source hashing cache"
      (call-with-temporary-directory "nix-store-input"
        (lambda (root)
          (def input (path-expand "source" root))
          (create-directory input)
          (write-input (path-expand "value" input) (path-strip-directory root))
          (def (native arguments)
            (run-process arguments stdin-redirection: #f stderr-redirection: #f
              coprocess: read-all-as-string check-status: #t))
          (def stored
            (find (cut string-prefix? "/nix/store/" <>)
              (string-split (native (list "nix-store" "--add" input)) #\newline)))
          (def metadata
            (call-with-input-string
              (native (list "nix" "--extra-experimental-features" "nix-command flakes"
                            "path-info" "--json" stored))
              (lambda (port) (read-json port key-as-symbol: #f object-as-hash: #t))))
          (def hash (hash-ref (hash-ref metadata stored) "narHash"))
          (write-input (path-expand "flake.nix" root)
            (string-append
              "{ inputs.catalog = { type = \"path\"; path = \"" stored "\"; "
              "narHash = \"" hash "\"; flake = false; }; "
              "outputs = { self, catalog }: let value = builtins.derivation { "
              "name = \"immutable-source-input\"; system = \"aarch64-darwin\"; "
              "builder = \"/bin/sh\"; source = toString catalog; }; "
              "in { packages.aarch64-darwin = { direct = value; resolved = value; }; }; }"))
          (native (list "nix" "--extra-experimental-features" "nix-command flakes"
                        "flake" "lock" (string-append "path:" (path-normalize root))))
          (def lock (path-expand "flake.lock" root))
          (def lock-before (call-with-input-file lock read-all-as-string))
          (.def (Direct @ NixFlakeSource.)
            reference: (string-append "path:" (path-normalize root))
            attribute: "packages.aarch64-darwin.direct")
          (.def (Resolved @ Direct)
            attribute: "packages.aarch64-darwin.resolved"
            inputs: (.o catalog: stored))
          (def expected #f)
          (def (query source)
            (call-with-output-string
              (lambda (port)
                (parameterize ((current-error-port port)
                               (current-module-process-trace-budget (box 1)))
                  (let (value (.call source .instantiate))
                    (if expected (check-equal? value expected)
                      (set! expected value)))))))
          (def direct (query Direct))
          (def resolved (query Resolved))
          (check-equal? (and (string-contains direct " is uncacheable") #t) #t)
          (check-equal? (string-contains resolved " is uncacheable") #f)
          (check-equal? (and (string-contains resolved "source path '")
                           (string-contains resolved " cache hit in ") #t) #t)
          (check-equal? (and (string-contains resolved "getting root value") #t) #t)
          (check-equal? (and (string-contains resolved "performing daemon worker op: 11") #t) #t)
          (check-equal? (string-contains (query Resolved) "getting root value") #f)
          (check-equal? (call-with-input-file lock read-all-as-string) lock-before))))
    (yuanxu-test-case "derived-path cache differs from eval and invalidates changed inputs"
      (call-with-temporary-directory "nix-evaluation-cache"
        (lambda (root)
          (def value (path-expand "value.nix" root))
          (write-input value "builtins.trace \"core-eval-cache-body\" \"before\"")
          (write-input (path-expand "flake.nix" root)
            (string-append
              "{ outputs = { self }: {\n"
              "  cached = import ./value.nix;\n"
              "  applied = args: import ./value.nix;\n"
              "  package = builtins.derivation {\n"
              "    name = \"core-eval-cache\"; system = \"aarch64-darwin\";\n"
              "    builder = \"/bin/sh\"; value = import ./value.nix;\n"
              "  };\n"
              "}; }\n"))
          (def (evaluate attribute (options '()))
            ;; Capture native trace and result together. No new runner, cache,
            ;; dependencies, realization or timing-based cache inference.
            (run-process
              (append
                (list "nix" "--extra-experimental-features" "nix-command flakes"
                      "eval" "--raw" "--no-update-lock-file"
                      (string-append "path:" (path-normalize root) "#" attribute))
                options)
              stdin-redirection: #f stderr-redirection: #t
              coprocess: read-all-as-string check-status: #t))
          (def (traced? text) (and (string-contains text "core-eval-cache-body") #t))
          (def cold (evaluate "cached"))
          (def warm (evaluate "cached"))
          (check-equal? (traced? cold) #t)
          ;; nix eval forces a Value rather than reading a cached scalar. Do not
          ;; infer an evaluation-cache hit merely from a pure flake reference.
          (check-equal? (traced? warm) #t)
          (check-equal? (and (string-contains warm "before") #t) #t)
          ;; Existing parameterized Flake Sources use --apply, which likewise
          ;; evaluates the function body in each fresh evaluator process.
          (check-equal? (traced? (evaluate "applied" '("--apply" "f: f {}"))) #t)
          (check-equal? (traced? (evaluate "applied" '("--apply" "f: f {}"))) #t)
          (check-equal? (traced? (evaluate "cached" '("--no-eval-cache"))) #t)
          (def (derivation (options '()))
            (run-process
              (append
                (list "nix" "--extra-experimental-features" "nix-command flakes"
                      "derivation" "show" "--no-update-lock-file"
                      (string-append "path:" (path-normalize root) "#package"))
                options)
              stdin-redirection: #f stderr-redirection: #t
              coprocess: read-all-as-string check-status: #t))
          (check-equal? (traced? (derivation)) #t)
          (check-equal? (traced? (derivation)) #f)
          (check-equal? (traced? (derivation '("--no-eval-cache"))) #t)
          (write-input value "builtins.trace \"core-eval-cache-body\" \"after\"")
          (def changed (evaluate "cached"))
          (check-equal? (traced? changed) #t)
          (check-equal? (and (string-contains changed "after") #t) #t)
          (check-equal? (traced? (derivation)) #t)
          (check-equal? (traced? (derivation)) #f))))
    (yuanxu-test-case "explicit path input overrides retain native cache and transitive invalidation"
      (call-with-temporary-directory "nix-selected-input"
        (lambda (root)
          (def input (path-expand "input" (path-normalize root)))
          (def publication (path-expand "publication" (path-normalize root)))
          (create-directory input)
          (create-directory publication)
          (write-input (path-expand "value.nix" input)
            "builtins.trace \"core-input-body\" \"before\"")
          (write-input (path-expand "flake.nix" publication)
            (string-append
              "{ inputs.selection = { url = \"path:" input "\"; flake = false; };\n"
              "outputs = { self, selection }: { package = builtins.derivation {\n"
              "name = \"selected-input\"; system = \"aarch64-darwin\"; builder = \"/bin/sh\";\n"
              "value = import (selection + \"/value.nix\"); }; }; }"))
          (def prefix '("nix" "--extra-experimental-features" "nix-command flakes"))
          (run-process (append prefix (list "flake" "lock" (string-append "path:" publication)))
            stdin-redirection: #f stderr-redirection: #f check-status: #t)
          (def lock (path-expand "flake.lock" publication))
          (def lock-before (call-with-input-file lock read-all-as-string))
          (def (query)
            (run-process
              (append prefix
                (list "path-info" "--derivation" "--no-update-lock-file"
                      "--override-input" "selection" (string-append "path:" input)
                      (string-append "path:" publication "#package")))
              stdin-redirection: #f stderr-redirection: #t
              coprocess: read-all-as-string check-status: #t))
          (def (traced? text) (and (string-contains text "core-input-body") #t))
          (check-equal? (traced? (query)) #t)
          (check-equal? (traced? (query)) #f)
          (.def (Source @ NixFlakeSource.)
            reference: (string-append "path:" publication)
            attribute: "package"
            inputs: (.o selection: input))
          (def expected (.call Source .instantiate))
          (check-equal? (.call Source .instantiate) expected)
          (def form (.call Source .guard-form expected))
          (check-equal? (car (reverse form)) (list 'quote (list (cons 'selection input))))
          (write-input (path-expand "value.nix" input)
            "builtins.trace \"core-input-body\" \"after\"")
          (check-exception
            (agentic-ai-lab-nix-flake-admit-generation
              (.get Source reference) "package" expected "nix"
              '() (.get Source source-inputs) (list (cons 'selection input)))
            error?)
          ;; The public guard has populated Nix's cache for the changed input.
          (check-equal? (traced? (query)) #f)
          (check-equal? (equal? expected (.call Source .instantiate)) #f)
          (write-input (path-expand "value.nix" input)
            "builtins.trace \"core-input-body\" \"third\"")
          (check-equal? (traced? (query)) #t)
          (check-equal? (traced? (query)) #f)
          (check-equal? (call-with-input-file lock read-all-as-string) lock-before)
          ;; An explicitly overridden data input does not authorize unrelated
          ;; implicit dependency updates. Only native Nix enforces this gate.
          (def flake (path-expand "flake.nix" publication))
          (def text (call-with-input-file flake read-all-as-string))
          (write-input flake
            (string-append
              "{ inputs.unexpected = { url = \"path:" input "\"; flake = false; };"
              (substring text 1 (string-length text))))
          (check-exception (query) error?)
          (check-equal? (call-with-input-file lock read-all-as-string) lock-before))))))
