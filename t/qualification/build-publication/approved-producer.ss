;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Qualification driver: production selection/publishing, temporary sources.
(import :clan/poo/object
        (only-in :yuanxu/t/qualification/service-publication/fixtures ServicesFixture write-source)
        (only-in :yuanxu/module-system/source/link yuanxu-load-modules)
        (only-in :yuanxu/module-system/building/artifacts
          call-with-build-artifact-issuance run-build-artifact-process build-artifact-handoff)
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :std/encoding/json write-json)
        (only-in :yuanxu/t/qualification/build-publication/projection probe-projection probe-build)
        (only-in :yuanxu/t/qualification/build-publication/store store-add)
        (only-in :yuanxu/ops/progress call-with-execution-progress execution-progress!))
(export main)
;; Both the interpreter and the compiled SDK executable pass only user arguments.
(def (main workspace)
  (call-with-execution-progress 60000 600000
    (lambda (_frame)
      (.call ServicesFixture .prepare (.o root: workspace))
      (execution-progress! 'publication-stages 1)
      (def owner (path-expand "modules/building/release" workspace))
      (write-source (path-expand "config.ss" owner)
        "(def Config (.o expression: \"release.nix\"))\n")
      (write-source (path-expand "objects.ss" owner)
        (string-append
          "(import (only-in :std/source this-source-file) (only-in :agentic-ai-lab/modules/nix/objects NixSource.) (only-in \"./config.ss\" Config))\n(export ReleaseSource)\n"
          "(.def (ReleaseSource @ NixSource.) expression: "
          "(path-expand (.get Config expression) (path-directory (this-source-file)))\n"
          ;; A publisher bootstraps before its first approved packet exists.
          ;; The explicit unavailable state is fixture policy, not an exception
          ;; swallowed by the production recovery or currentness boundary.
          " .available?: (lambda () (not (equal? (call-with-input-file expression read-line) \"null\"))))\n"))
      (write-source (path-expand "types.ss" owner)
        "(import (only-in :yuanxu/object-types/contracts yuanxu-predicate-contract))\n(export ScopeContract)\n(def ScopeContract (yuanxu-predicate-contract 'release/scope (lambda (v) (and (object? v) (.slot? v 'Source))) (lambda (_v _c) '())))\n")
      (write-source (path-expand "interface.ss" owner)
        "(.def Release identity: 'building/release core: (.o requires: (.o) build-publication: ReleaseSource scope-contract: ScopeContract exports: (.o Source: ReleaseSource)) features: (.o))\n")
      (write-source (path-expand "init.ss" workspace)
        "(yuanxu! mode: explicit (closed-package disable: #t) :services (postgresql) (gitea) (unused disable: #t) :applications (gitea-postgresql) :building (release))\n")
      (write-source (path-expand "probe.ss" workspace) "(export answer) (def answer 42)\n")
      ;; Declare generated package inputs before selecting the source directory.
      ;; Publication must not add directory members to an already observed epoch.
      (for-each (lambda (name) (write-source (path-expand name owner) "null\n"))
                '("release.nix" "release-name.nix" "omitted-release.nix"))
      (def selection (yuanxu-load-modules (path-expand "init.ss" workspace)))
      (.get selection build-graph)
      (execution-progress! 'publication-stages 2)
      (def package-name (cadr (call-with-input-file (path-expand "gerbil.pkg" workspace) read)))
      (def probe-name (string->symbol (string-append (symbol->string package-name) "/probe")))
      (def libdir (path-expand "lib" workspace))
      (def projection (probe-projection selection workspace probe-name))
      (def compile-main (probe-build workspace libdir))
      (call-with-build-artifact-issuance projection libdir (cut compile-main "compile"))
      (execution-progress! 'publication-stages 3)
      (def record-path (path-expand
        (find (cut string-prefix? ".yuanxu-build-issuance-" <>)
          (directory-files (list path: libdir ignore-hidden: #f))) libdir))
      (def transcript (run-build-artifact-process projection libdir
        (list "just" "-f" "t/qualification/nix/Justfile" "publication-worker" workspace libdir (symbol->string probe-name) "persist" record-path)))
      (execution-progress! 'publication-stages 4)
      (def prefix "CORE-STORE-ROOT ")
      (def root-line (find (cut string-prefix? prefix <>) (string-split transcript #\newline)))
      (unless root-line (error "release publication did not complete"))
      (def packet-root (substring root-line (string-length prefix) (string-length root-line)))
      (def retained-packet (build-artifact-handoff (.get projection build-graph) libdir))
      (def omitted-observation (car (.get projection build-graph compiler-inputs)))
      (write-source (path-expand "release-name.nix" owner) "\"core-approved-publication\"\n")
      ;; The ordinary selected Module publishes Source. New processes discover its
      ;; Nix output from persistent policy; no release path is supplied on their CLI.
      ;; The realized qualification fixture already supplies a store-pinned
      ;; shell/coreutils closure. A copy derivation needs neither a package-set
      ;; evaluation nor stdenv. Its unique local packet has no binary-cache owner;
      ;; realize locally while retaining the real policy and store checks.
      (def tools-literal
        (call-with-output-string (cut write-json <> (getenv "AGENTIC_AI_LAB_NIX_TEST_TOOLS"))))
      (def (release-recipe packet-directory)
        (string-append "let raw = builtins.fromJSON " tools-literal "; "
          ;; JSON paths have no Nix string context. Restore the qualified Store
          ;; dependencies so sandboxed builds receive both shell and utilities.
          "tools = raw // { shell = builtins.storePath raw.shell; "
          "tools = builtins.storePath raw.tools; }; in "
          "builtins.derivation { name = import ./release-name.nix; "
          "preferLocalBuild = true; allowSubstitutes = false; "
          "inherit (tools) system; builder = tools.shell + \"/bin/bash\"; "
          "packet = " packet-directory "/issuance.ss; "
          "args = [ \"-euc\" \"${tools.tools}/bin/mkdir $out; "
          "${tools.tools}/bin/cp $packet $out/issuance.ss\" ]; }\n"))
      (write-source (path-expand "release.nix" owner) (release-recipe packet-root))
      ;; Deliberately broken PUBLISHER output: valid store data and selected recipe,
      ;; but not enough observations to admit the actual selected Graph.
      (call-with-temporary-directory "core-omitted-publication"
        (lambda (directory)
          (def packet retained-packet)
          (def omitted omitted-observation)
          (def remaining
            (filter (lambda (row) (not (equal? (car row) (car omitted)))) (list-ref packet 2)))
          (unless (< (length remaining) (length (list-ref packet 2)))
            (error "omission control did not remove a real selected observation" omitted))
          (def incomplete
            (cons (car packet) (cons (cadr packet)
              (cons remaining (cdddr packet)))))
          (call-with-output-file (path-expand "issuance.ss" directory) (cut write incomplete <>))
          (write-source (path-expand "omitted-release.nix" owner) (release-recipe (store-add directory)))))
      (execution-progress! 'publication-stages 5)
      (displayln "APPROVED-SOURCE-PUBLISHED")
)))
