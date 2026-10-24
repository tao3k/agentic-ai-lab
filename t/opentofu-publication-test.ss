;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test :clan/poo/object
        (only-in :clan/poo/mop TypeError?)
        (only-in :std/source this-source-file)
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :std/text/pregexp pregexp-match)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :agentic-ai-lab/modules/nix/func current-nix-process-observer)
        (only-in :yuanxu/module-system/source/admission module-source-read)
        (only-in :yuanxu/module-system/source/preparation yuanxu-prepare-module-build-source)
        (only-in :yuanxu/module-system/observability/presentation
                 yuanxu-poo-slot-authoring-self-reference?)
        (only-in :yuanxu/object-types/contracts yuanxu-validation-evidence-accepted?)
        (only-in :yuanxu/module-system/interface yuanxu-load-modules))
(export opentofu-publication-test)
(def (assert name value)
  (unless value (error "assertion failed" name))
  (displayln "ASSERT-OK " name) (force-output))
(def (write-source path text)
  (create-directory* (path-directory path))
  (call-with-output-file (list path: path truncate: #t) (cut display text <>)))
(def opentofu-publication-test
  (test-suite "Maintained OpenTofu publication and unconfigured build boundary"
    (yuanxu-test-case "native method names are paths, receivers and arguments remain expressions"
      (.def Source .prepare: (lambda (value) value))
      (.def Adapter .prepare: (lambda (value) (.call Source .prepare value)))
      (assert 'native-call-correspondence (= (.call Adapter .prepare 42) 42))
      (assert 'method-name-is-not-free-reference
        (not (yuanxu-poo-slot-authoring-self-reference?
               '.prepare '(lambda (value) (.call Source .prepare value)))))
      (assert 'receiver-reference-still-checked
        (yuanxu-poo-slot-authoring-self-reference? '.prepare '(.call .prepare another)))
      (assert 'argument-reference-still-checked
        (yuanxu-poo-slot-authoring-self-reference? '.prepare '(.call Source another .prepare))))
    (yuanxu-test-case "identity reuse requires exact bytes and native package resolution"
      (call-with-temporary-directory "opentofu-source-identity"
        (lambda (root)
          (let* ((package (path-expand "gerbil.pkg" root))
                 (path (path-expand "helpers/func.ss" root))
                 (closer (path-expand "helpers/gerbil.pkg" root))
                 (text "(def Value 42) (export Value)")
                 (package-text (string-append "(package: " (symbol->string (gensym 'source-identity-)) ")")))
            (write-source package package-text)
            (write-source path text)
            (let (input (yuanxu-prepare-module-build-source path void))
              ((.get input admit-current))
              (write-source path (string-append text "\nnamespace: changed\n"))
              (check-exception ((.get input admit-current)) error?)
              (write-source path text)
              (write-source package "(package: changed)")
              (check-exception ((.get input admit-current)) error?)
              (write-source package package-text)
              (write-source closer "(package: closer)")
              (check-exception ((.get input admit-current)) error?)
              (delete-file closer)
              ((.get input admit-current))
              (assert 'restored-bytes-and-package-resolution-current #t))))))
    (yuanxu-test-case "one real publication is inert until a consumer needs construction"
      (call-with-temporary-directory "opentofu-publication"
        (lambda (root)
          (let ((maintained (path-expand "../modules" (path-directory (this-source-file))))
                (init (path-expand "init.ss" root))
                (starts 0))
            (def (write-init consumer?)
              (write-source init
                (call-with-output-string
                  (lambda (port)
                    (write `(yuanxu! mode: explicit
                              (json-schema @ ,(path-expand "../core/modules/json-schema" maintained))
                              (nix @ ,(path-expand "nix" maintained))
                              (funflow @ ,(path-expand "../core/modules/funflow" maintained))
                              ,@(if consumer? '(:app (infrastructure)) '())
                              :services (opentofu @ ,(path-expand "services/opentofu" maintained))) port)))))
            (create-directory* (path-expand "modules" root))
            (write-source (path-expand "gerbil.pkg" root)
              (string-append "(package: " (symbol->string (gensym 'opentofu-publication-)) ")"))
            (write-init #f)
            (parameterize ((current-nix-process-observer (lambda (_argv) (set! starts (1+ starts)))))
              (let* ((view (yuanxu-load-modules init))
                     (scope (.get view modules services opentofu)))
                (assert 'scope-without-artifact (not (.ref/cached scope 'modules)))
                (assert 'default-source-unconfigured (not (.get scope config source)))
                (assert 'native-schema-function
                  (equal? (.call (.get scope schema) type "string") '((type . "string"))))
                (check-exception
                  (.call (.get scope types config) .admit
                    (.cc (.get scope config) 'source "path:/not-a-source") #f)
                  TypeError?)
                (assert 'builder-alone-does-not-prepare (null? (.get view build-graph external-packages)))
                (assert 'scope-and-selection-start-no-nix (zero? starts))
                (let (prepared (.call view prepare-publication 'services/opentofu))
                  (assert 'physical-core-interface-source
                    (equal? (path-normalize (.get prepared source value))
                            (path-normalize (path-expand "services/opentofu/interface.ss" maintained))))
                  (assert 'private-core-helper-observed
                    (find (lambda (input)
                            (equal? (path-strip-directory (.get input path)) "aws-hash.ss"))
                          (.get prepared source-dependencies)))))
              (let (consumer (path-expand "modules/app/infrastructure" root))
                (write-source (path-expand "types.ss" consumer)
                  "(import (only-in :agentic-ai-lab/modules/services/opentofu/types OpenTofuScopeContract)) (export OpenTofuScopeContract)")
                (write-source (path-expand "objects.ss" consumer)
                  "(import :clan/poo/object) (def Defaults (.o)) (export Defaults)")
                (write-source (path-expand "config.ss" consumer) "(def Config (.o))")
                (write-source (path-expand "interface.ss" consumer)
                  "(.def Infrastructure identity: 'app/infrastructure core: (.o requires: (.o Tofu: (.o module-id: 'services/opentofu contract: OpenTofuScopeContract)) scope-contract: OpenTofuScopeContract exports: (.o config: Config)) features: (.o))")
                (write-init #t)
                (def graph (.get (yuanxu-load-modules init) build-graph))
                (assert 'consumer-keeps-package-preparation-deferred
                  (not (.ref/cached graph 'external-packages)))
                (assert 'missing-source-reported
                  (with-catch
                    (lambda (exception)
                      (if (pregexp-match "build-required: OpenTofu Config.source"
                            (call-with-output-string (cut display-exception exception <>)))
                        #t
                        (raise exception)))
                    (lambda () (.get graph external-packages) #f)))
                (assert 'missing-source-starts-no-nix (zero? starts))))))))))
