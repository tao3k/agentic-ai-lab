#!/usr/bin/env -S gerbil interactive
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Lab qualification preparation; Core remains an ordinary library dependency.
;;; Standard Make owns library compilation and the existing Lab test tool.
(import (for-syntax
          (only-in :std/source this-source-file)
          (only-in :tao3k/yuanxu/module-system/building/source-package register-module-build-source!)))
(begin-syntax
  ;; Reuse the package source gateway before native import discovery. The
  ;; adapter package must work before any Root library has been installed.
  (register-module-build-source!
    (path-expand "../../.." (path-directory (this-source-file))) 'agentic-ai-lab))
(import (only-in :gerbil/expander core-import-module expander-context-id)
        :std/make
        (only-in :clan/poo/object .o)
        (only-in :std/source this-source-file)
        (only-in :tao3k/yuanxu/module-system/building/source-package register-module-build-source!)
        (only-in :tao3k/yuanxu/module-system/building/source-closure for-each-build-module)
        (only-in :tao3k/yuanxu/module-system/source/static-inputs module-static-compiler-inputs)
        (only-in :tao3k/yuanxu/module-system/building/artifacts call-with-static-compiler-inputs))
;; The compiler resolves public application imports through its package prefix.
;; Register application sources, while keeping Core and the SDK compiled.
(def root (path-normalize (path-expand "../../.." (path-directory (this-source-file)))))
(register-module-build-source! root 'agentic-ai-lab)
;; The adapter consumes Core's test support as source-owned prerequisites.
;; These are deliberately absent from the installed production library.
(register-module-build-source! (path-expand "core" root) (quote tao3k/yuanxu))
(def output (path-expand "lib" (getenv "GERBIL_PATH")))
(def seen (make-hash-table-eq))
;; The existing Core traversal selects roots; std/make owns all compilation.
(def sources '())
(def (selected-source context)
  (let (identity (expander-context-id context))
    (and (symbol? identity)
      (let (name (symbol->string identity))
        (cond
         ((string=? "agentic-ai-lab/services" name) "services.ss")
         ((string=? "agentic-ai-lab/nix-contracts" name) "nix-contracts.ss")
         ((string=? "agentic-ai-lab/opentofu-contracts" name) "opentofu-contracts.ss")
         ((string=? "agentic-ai-lab/bindings/nix-c-api/derivation-session" name)
          "bindings/nix-c-api/derivation-session.ss")
         ((or (string-prefix? "agentic-ai-lab/modules/nix/" name)
              (string-prefix? "agentic-ai-lab/modules/services/" name)
              (string-prefix? "agentic-ai-lab/t/qualification/nix/" name)
              (string-prefix? "agentic-ai-lab/t/qualification/build-publication/" name))
          (string-append
            (substring name (string-length "agentic-ai-lab/") (string-length name)) ".ss"))
         ((or (string-prefix? "tao3k/yuanxu/t/qualification/service-publication/" name)
              (string-prefix? "tao3k/yuanxu/t/qualification/testing/" name)
              (string-prefix? "tao3k/yuanxu/t/qualification/build-publication/" name))
          (string-append "core/" (substring name 7 (string-length name)) ".ss"))
         (else #f))))))
(def owned-identities '())
(def (collect-source context)
  (let (source (selected-source context))
    ;; File imports and package imports can name the same source. Keep
    ;; one target while retaining the native dependency traversal order.
    (when (and source (not (member source sources)))
      (set! owned-identities (cons (expander-context-id context) owned-identities))
      (set! sources (cons source sources)))))
(def tool-contexts '())
(for-each-build-module
  (core-import-module (path-expand "t/qualification/nix/tools.ss" root))
  (lambda (context)
    (collect-source context)
    (set! tool-contexts (cons context tool-contexts)))
  seen)
(for-each
  (lambda (relative)
    (for-each-build-module (core-import-module (path-expand relative root))
      collect-source seen))
  '("modules/nix/objects.ss" "modules/services/opentofu/objects.ss"
    "core/t/qualification/service-publication/fixtures.ss"
    "core/t/qualification/build-publication/projection.ss"
    "core/t/qualification/build-publication/store.ss"))
;; std/make's output paths use the package prefix. Compile each package with
;; its real source root so SDK staleness checks inspect the emitted artifacts.
(def ordered-sources (reverse sources))
(make (map (lambda (source) (substring source 5 (string-length source)))
           (filter (cut string-prefix? "core/" <>) ordered-sources))
  srcdir: (path-expand "core" root) libdir: output prefix: "yuanxu")
(make (filter (lambda (source) (not (string-prefix? "core/" source))) ordered-sources)
  srcdir: root libdir: output prefix: "agentic-ai-lab")
(def link-inputs (module-static-compiler-inputs (reverse tool-contexts) owned-identities))
(call-with-static-compiler-inputs (.o static-inputs: link-inputs)
  (lambda ()
    (make (list (list exe: "t/qualification/nix/tools" bin: "build-publication-tools"
                      "-ld-options" (pkg-config-libs "libcrypto" "libssl")))
      srcdir: root libdir: output prefix: "agentic-ai-lab")))
(displayln "NIX-ADAPTER-BUILD-OK")
