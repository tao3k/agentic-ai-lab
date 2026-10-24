;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Private version inputs over the existing reader and selected-package owners.
(import (only-in :agentic-ai-lab/modules/nix/progress make-nix-progress-reader) :clan/poo/object
        (only-in :std/source this-source-file)
        (only-in :std/encoding/json read-json)
        (only-in :std/io/tempfile make-temporary-file-name clear-temporary-file!)
        (only-in :yuanxu/ops/func run-script)
        (only-in :yuanxu/ops/process-script ProcessScript.)
        (only-in :yuanxu/ops/progress execution-idle-seconds execution-total-seconds)
        (only-in :yuanxu/module-system/interface yuanxu-load-modules)
        (only-in :yuanxu/ops/selected-packages SelectedPackages.)
        (only-in :agentic-ai-lab/modules/nix/objects NixFlakeSource.)
        (only-in :yuanxu/module-system/source/admission module-source-read)
        (only-in :yuanxu/module-system/source/reader module-publication-reader)
        (only-in :yuanxu/module-system/source/directory module-directory-context))
(export Workspace prepare-aws-selection! realize-aws-selection write-aws-version!)
(.def Workspace
  .acquire: (lambda ()
              (let (root (make-temporary-file-name "aws-context-publication-"))
                (create-directory root) root))
  .release: (lambda (root)
              (clear-temporary-file! root)
              (when (file-exists? root) (error "AWS fixture cleanup did not remove its workspace"))))
(def repository (path-normalize (path-expand "../../.." (path-directory (this-source-file)))))
(def (write-source path text)
  (create-directory* (path-directory path))
  (call-with-output-file (list path: path truncate: #t) (cut display text <>)))
(def (write-aws-version! project version)
  (unless (member version '("parent" "child")) (error "unknown AWS fixture version" version))
  (write-source (path-expand "version.nix" project)
    (call-with-output-string (cut write version <>))))
(.def (NixSetup @ ProcessScript.)
  timeout: execution-total-seconds idle-timeout: execution-idle-seconds
  progress: make-nix-progress-reader)
(def (prepare-aws-selection! root (phase void))
  (def project (path-expand "project" (path-normalize root)))
  (def catalog (path-expand "providers.nix" project))
  (def version (path-expand "version.nix" project))
  (write-aws-version! project "parent")
  (write-source catalog
    (string-append
      "{ pkgs }: let\n"
      "  package = args: import ./aws-package.nix ({ inherit pkgs; } // args);\n"
      "  schema = provider: pkgs.callPackage ./provider-schema.nix { inherit provider; };\n"
      "  versions = {\n"
      "    parent = schema (package { version = \"5.99.0\"; hash = { aarch64-darwin = \"sha256:d77fc7e17730eb40cde656e67fc206e9d7ca2a346d9e1819e6f3bd71289207e2\"; x86_64-linux = \"sha256:ac8e1fb974569f0c5fdc09f5991fb8b0e79ccf4086799bf64715317f3a27a7fd\"; }; });\n"
      "    child = schema (package {});\n"
      "  };\n"
      "in { aws = versions.${import ./version.nix}; }\n"))
  ;; A bounded, explicit publication closure, not a snapshot of Core or a
  ;; hand-maintained cache. Nix owns hashing the entire published local tree.
  ;; Original maintained inputs remain guarded as well as their published bytes.
  (def closure-inputs
    (map (lambda (row)
           (let* ((path (path-expand (car row) repository))
                  (text (module-source-read path)))
             (write-source (path-expand (cdr row) project) text)
             (cons path text)))
         '(("t/fixtures/opentofu/aws-5.100.0/package.nix" . "aws-package.nix")
           ("modules/services/opentofu/nix/provider-schema.nix" . "provider-schema.nix")
           ("modules/services/opentofu/nix/provider-artifacts.nix" . "provider-artifacts.nix")
           ("modules/services/opentofu/nix/selected-provider-artifacts-flake.nix" . "selected-provider-artifacts-flake.nix"))))
  (phase 'closure-published)
  ;; Resolve the existing locked package set once. Never use <nixpkgs> or impure
  ;; imports inside the published final derivation.
  (def package-set
    (find (cut string-prefix? "/nix/store/" <>)
      (string-split
        (.get (run-script (.cc NixSetup 'command
                       '("nix-instantiate" "--find-file" "nixpkgs"
                         "--log-format" "internal-json" "--verbose"))
                 output-port: (current-error-port)) output) #\newline)))
  (unless (and (string-prefix? "/nix/store/" package-set) (file-exists? package-set))
    (error "AWS qualification requires the existing locked package set" package-set))
  (phase 'package-set-resolved)
  ;; Pin the existing immutable store input with Nix's own NAR metadata. A bare
  ;; path input makes flake lock rescan/copy the entire package set each time.
  ;; This is a native store query, not a maintained hash or a Scheme cache.
  (def metadata
    (call-with-input-string
      (.get (run-script (.cc NixSetup 'command
               (list "nix" "--extra-experimental-features" "nix-command flakes"
                     "path-info" "--offline" "--json" package-set))
               stderr-redirection: #f) output)
      (lambda (port) (read-json port key-as-symbol: #f object-as-hash: #t))))
  (unless (and (hash-table? metadata) (= (hash-length metadata) 1)
               (hash-table? (hash-get metadata package-set)))
    (error "Nix store metadata did not identify one package set"))
  (def nar-hash (hash-get (hash-ref metadata package-set) "narHash"))
  (unless (and (string? nar-hash) (string-prefix? "sha256-" nar-hash))
    (error "Nix store metadata lacks the immutable NAR identity"))
  (phase 'package-set-identified)
  ;; Nix's path-input fast path requires the store basename to be exactly
  ;; "source". A prefixed source name is recopied even with a pinned NAR hash.
  ;; builtins.path checks the native content-addressed store identity first;
  ;; the known hash permits reuse without rescanning an existing canonical tree.
  (def canonical-package-set
    (find (cut string-prefix? "/nix/store/" <>)
      (string-split
        (.get (run-script (.cc NixSetup 'command
                 (list "nix" "--extra-experimental-features" "nix-command flakes"
                       "eval" "--raw" "--expr"
                       (string-append "builtins.path { path = " (object->string package-set)
                         "; name = \"source\"; sha256 = " (object->string nar-hash) "; }")))
                 output-port: (current-error-port)) output) #\newline)))
  (unless (and canonical-package-set (file-exists? canonical-package-set))
    (error "Nix did not publish the canonical immutable package set"))
  (phase 'package-set-published)
  (write-source (path-expand "demand/selection.json" project) "{\"providers\":[]}")
  (def system
    (call-with-input-string
      (.get (run-script (.cc NixSetup 'command
                '("nix-instantiate" "--eval" "--json" "--expr" "builtins.currentSystem"))) output)
      read-json))
  (write-source (path-expand "flake.nix" project)
    (string-append
      "{ inputs.nixpkgs = { type = \"path\"; path = \"" canonical-package-set "\";\n"
      "    narHash = \"" nar-hash "\"; flake = false; };\n"
      "  inputs.selection = { url = \"path:./demand\"; flake = false; };\n"
      "  outputs = { self, nixpkgs, selection }: let\n"
      "    pkgs = import nixpkgs { system = \"" system "\"; };\n"
      "    artifacts = import ./selected-provider-artifacts-flake.nix {\n"
      "      inherit pkgs; schemas = import ./providers.nix { inherit pkgs; };\n"
      "    };\n"
      "  in { packages." system ".default = builtins.trace \"aws-final-package-evaluated\"\n"
      "    ((artifacts { selection = builtins.readFile (selection + \"/selection.json\"); }).overrideAttrs (_: {\n"
      "      name = if builtins.pathExists ./profile-options.nix\n"
      "             then import ./profile-options.nix else \"opentofu-artifacts\";\n"
      "    })); }; }\n"))
  (run-script (.cc NixSetup 'command
           (list "nix" "--extra-experimental-features" "nix-command flakes"
                 "flake" "lock" (string-append "path:" project)
                 "--log-format" "internal-json" "--verbose"))
    output-port: (current-error-port))
  (phase 'lock-published)
  (write-source (path-expand "gerbil.pkg" project)
    "(package: qualification prelude: :yuanxu/module-system/source/module-prelude)\n")
  (def init (path-expand "init.ss" project))
  (write-source init
    (call-with-output-string
      (lambda (port)
        (write `(yuanxu! mode: explicit source: ,(path-expand "modules" repository)
                  (aws @ ,(path-expand "scenarios/aws" repository))
                  (nix @ ,(path-expand "modules/nix" repository))
                  (funflow @ ,(path-expand "core/modules/funflow" repository))
                  (json-schema @ ,(path-expand "core/modules/json-schema" repository))
                  :services (opentofu @ ,(path-expand "modules/services/opentofu" repository))) port))))
  (.cc (.o) 'project project 'init init 'reader (module-publication-reader)
    'closure-inputs closure-inputs 'package-set canonical-package-set 'system system))
(def (realize-aws-selection fixture directory (phase void))
  (def init (.get fixture init))
  ;; Existing source-context customization hook, as used by the selected-Graph
  ;; controls. Configure the actual publication, never replace its declaration.
  (def project (path-directory init))
  (def catalog-path (path-expand "providers.nix" project))
  (def version-path (path-expand "version.nix" project))
  (.def (Source @ NixFlakeSource.)
    reference: (string-append "path:" project)
    attribute: (string-append "packages." (.get fixture system) ".default")
    ;; Resolve the SAME immutable input through Nix's path fetcher. On 2.34,
    ;; the final/narHash shortcut loses this path accessor's fingerprint;
    ;; explicit resolution retains Nix's own source-to-hash cache. The locked
    ;; declaration above and all native GC/source guards remain in place.
    inputs: (.o nixpkgs: (.get fixture package-set))
    source-inputs: (append (.get fixture closure-inputs)
                    (map (lambda (path) (cons path (module-source-read path)))
                         (list (path-expand "flake.nix" project)
                               (path-expand "flake.lock" project)
                               catalog-path version-path))))
  ;; The fixture owns one unchanged source snapshot, not a new compiler world
  ;; per package version. Only the selected Nix input/Graph changes. The reader
  ;; continues to guard all source bytes; its scopes and admissions are not reused.
  (def reader (.get fixture reader))
  (def (configure scope)
    (.cc scope 'config (.cc (.get scope config) 'source Source 'selection-input 'selection)))
  (def (read-publication source)
    (def published (.call reader read source))
    (if (not (eq? (.get published identity) 'services/opentofu)) published
      (let (baseline (.get published core))
        (.cc published 'core
          (.o (:: @ baseline)
            link: (lambda (dependencies) (configure (.call baseline link dependencies)))
            configuration-build:
            (let (build (.get baseline configuration-build))
              (.cc build 'module (configure (.get build module)))))))))
  (def context (module-directory-context init read-publication))
  (phase 'source-context)
  (def selection
    (yuanxu-load-modules
      (.cc context 'publication-inputs (.get reader inputs)
        'publication-preparation (.get reader preparation)
        'current? (lambda (generation)
                    (.call reader admit-current)
                    (.call context current? generation)))))
  ;; Demand the same Graph that SelectedPackages consumes. This separates pure
  ;; source preparation from Nix effects without constructing another Graph.
  ;; Native Funflow/Ops imports currently require eligible Module owners in
  ;; this explicit source policy; keep them until that distinction is modeled.
  (.get selection build-graph)
  (phase 'build-graph)
  (def packages
    (.call (.cc SelectedPackages.
             selection: selection
             directory: directory)
      .run))
  (phase 'packages-realized)
  (def result (.call selection .with-packages packages))
  (phase 'scopes-linked)
  result)
