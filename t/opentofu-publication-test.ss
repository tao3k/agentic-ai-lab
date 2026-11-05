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
        (only-in :yuanxu/module-system/source/admission module-source-read current-module-source-observer)
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
    (yuanxu-test-case "runtime method names are paths, receivers and arguments remain expressions"
      (.def Source .prepare: (lambda (value) value))
      (.def Adapter .prepare: (lambda (value) (.call Source .prepare value)))
      (assert 'runtime-call-correspondence (= (.call Adapter .prepare 42) 42))
      (assert 'method-name-is-not-free-reference
        (not (yuanxu-poo-slot-authoring-self-reference?
               '.prepare '(lambda (value) (.call Source .prepare value)))))
      (assert 'receiver-reference-still-checked
        (yuanxu-poo-slot-authoring-self-reference? '.prepare '(.call .prepare another)))
      (assert 'argument-reference-still-checked
        (yuanxu-poo-slot-authoring-self-reference? '.prepare '(.call Source another .prepare))))
    (yuanxu-test-case "identity reuse requires exact bytes and runtime package resolution"
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
          (let* ((project (path-directory (path-strip-trailing-directory-separator
                                           (path-directory (this-source-file)))))
                 (maintained (path-expand "modules" project))
                (init (path-expand "init.ss" root))
                (starts 0))
            (def (write-init consumer? (review? #f) (schema-disabled? #f))
              (write-source init
                (call-with-output-string
                  (lambda (port)
                    (write `(yuanxu!
                              :load-modules ,(path-expand "core/modules" project)
                              mode: explicit rename: Core
                              (json-schema disable: ,schema-disabled?) (funflow)
                              :load-modules ,(path-normalize maintained)
                              mode: explicit (nix) :services (opentofu)
                              ,@(if (or review? consumer?)
                                  `(:load-modules "./modules" mode: explicit rename: App
                                    :app ,@(if review? '((review)) '())
                                    ,@(if consumer? '((infrastructure)) '()))
                                  '())) port)))))
            (create-directory* (path-expand "modules" root))
            (write-source (path-expand "gerbil.pkg" root)
              (string-append "(package: " (symbol->string (gensym 'opentofu-publication-)) ")"))
            (let (review (path-expand "modules/app/review" root))
                (write-source (path-expand "types.ss" review)
                  "(import :clan/poo/mop) (def ReviewScope (.cc Type. identity: 'app/review .element?: object?)) (export ReviewScope)")
                (write-source (path-expand "objects.ss" review) "(def Defaults (.o)) (export Defaults)")
                (write-source (path-expand "config.ss" review) "(def Config (.o revision: 1))")
                (write-source (path-expand "interface.ss" review)
                  "(.def Review identity: 'app/review core: (.o requires: (.o OpenTofuInterface: (.o module-id: 'services/opentofu view: 'interface) JsonSchema: (.o module-id: 'json-schema)) scope-contract: ReviewScope exports: (.o schema: (.get OpenTofuInterface requires JsonSchema) baseline: JsonSchema revision: (.get Config revision))) features: (.o))"))
            (let (consumer (path-expand "modules/app/infrastructure" root))
                (write-source (path-expand "types.ss" consumer)
                  "(import (only-in :agentic-ai-lab/opentofu-contracts OpenTofuScopeContract)) (export OpenTofuScopeContract)")
                (write-source (path-expand "objects.ss" consumer)
                  "(import :clan/poo/object) (def Defaults (.o)) (export Defaults)")
                (write-source (path-expand "config.ss" consumer) "(def Config (.o))")
                (write-source (path-expand "interface.ss" consumer)
                  "(.def Infrastructure identity: 'app/infrastructure core: (.o requires: (.o Tofu: (.o module-id: 'services/opentofu contract: OpenTofuScopeContract)) scope-contract: OpenTofuScopeContract exports: (.o config: Config)) features: (.o))"))
            (write-init #f #t)
            (parameterize ((current-nix-process-observer (lambda (_argv) (set! starts (1+ starts)))))
              (def next-view #f)
              (def cross-generation-identities #f)
              (let* ((view (yuanxu-load-modules init))
                     (scope (.get (.call view .selected-record 'services/opentofu) scope)))
                (assert 'scope-without-artifact (not (.ref/cached scope 'modules)))
                (assert 'default-source-unconfigured (not (.get scope config source)))
                (assert 'runtime-schema-function
                  (equal? (.call (.get scope schema) type "string") '((type . "string"))))
                (def refused
                  (.call (.get scope types config) .admit
                    (.cc (.get scope config) 'source "path:/not-a-source") #f))
                (check-equal? (yuanxu-validation-evidence-accepted? refused) #f)
                (check-equal? (TypeError? (.get refused cause)) #t)
                (check-equal? (.get refused candidate source) "path:/not-a-source")
                (check-equal?
                  (ormap (lambda (issue) (equal? (.get issue path) '(source)))
                    (.get refused diagnostics)) #t)
                (assert 'builder-alone-does-not-prepare (null? (.get view build-graph external-packages)))
                (assert 'scope-and-selection-start-no-nix (zero? starts))
                (let (prepared (.call view prepare-publication 'services/opentofu))
                  (assert 'physical-core-interface-source
                    (equal? (path-normalize (.get prepared source value))
                            (path-normalize (path-expand "services/opentofu/interface.ss" maintained))))
                  (assert 'private-core-helper-observed
                    (find (lambda (input)
                            (equal? (path-strip-directory (.get input path)) "aws-hash.ss"))
                          (.get prepared source-dependencies))))
                (let* ((review (.call view .selected-record 'app/review))
                       (review-schema (.get review scope schema))
                       (review-edge (.get review dependency-records OpenTofuInterface))
                       (record (.call view .selected-record 'services/opentofu))
                       (edge (.get record dependency-records JsonSchema)))
                  (assert 'review-receives-opentofu-schema
                    (and (eq? review-schema (.get record interface requires JsonSchema))
                         (eq? review-schema (.get edge scope))
                         (eq? (.get edge provider) (.call view .selected-record 'json-schema))))
                  (assert 'review-does-not-request-packages
                    (null? (.get view build-graph external-packages)))
                  (let (schema-source (path-expand "core/modules/json-schema/interface.ss" project))
                    (assert 'json-schema-has-one-build-entry
                      (= 1 (length (filter
                                     (lambda (entry) (equal? (.get entry path) schema-source))
                                     (.get view build-graph entries))))))
                  (check-equal? (.get review scope revision) 1)
                  (def old-schema (.get edge provider scope))
                  (def hot-compile (.get old-schema compile))
                  ((.get edge provider admit-construction-current))
                  ((.get review-edge admit-current))
                  (assert 'review-starts-no-nix (zero? starts))
                  (write-source (path-expand "modules/app/review/config.ss" root)
                    "(def Config (.o revision: 2))")
                  (check-exception ((.get review-edge admit-current)) error?)
                  (check-exception (.call view .selected-record 'app/review) error?)
                  (displayln "MVP-STALE-SOURCE-REFUSED") (force-output)
                  (write-init #t #t)
                  (displayln "MVP-REFRESH-BEGIN") (force-output)
                  (let ((calls (make-hash-table)) (imports 0))
                    (parameterize
                        ((current-module-source-observer
                          (lambda (event count)
                            (when (and (pair? event) (eq? (car event) 'link-stage-start))
                              (let (stage (cadr event))
                                (hash-put! calls stage (+ count (or (hash-get calls stage) 0)))))
                            (when (and (pair? event) (eq? (car event) 'compiler-source-import-start))
                              (set! imports (+ imports count)))
                            (when (and (pair? event) (eq? (car event) 'reader-context-not-transferred))
                              (displayln "MVP-TRANSFER " event)))))
                      (def next (.call view .refresh))
                      (displayln "MVP-REFRESH-RETURN") (force-output)
                      (set! next-view next)
                      (def next-review (.call next .selected-record 'app/review))
                      (def next-schema-record (.call next .selected-record 'json-schema))
                      (def next-schema (.get next-schema-record scope))
                      (check-equal? (.get next-review scope revision) 2)
                      (displayln "MVP-REUSE calls=" (hash->list calls) " source-imports=" imports)
                      (displayln "MVP-IDENTITY construction="
                        (eq? (car (object-supers old-schema)) (car (object-supers next-schema)))
                        " admitted=" (eq? old-schema next-schema)
                        " hot=" (eq? hot-compile (.get next-schema compile)))
                      (check-equal? (eq? (car (object-supers old-schema))
                                        (car (object-supers next-schema))) #t)
                      ;; Keep strict identity checks until after the refusal
                      ;; controls so one failing identity does not hide them.
                      (set! cross-generation-identities
                        (list (eq? old-schema next-schema)
                              (eq? hot-compile (.get next-schema compile))))
                      (assert 'review-has-new-generation-evidence
                        (not (eq? (.get review scope-evidence) (.get next-review scope-evidence))))
                      (assert 'json-schema-has-new-generation-evidence
                        (not (eq? (.get edge provider scope-evidence)
                                  (.get next-schema-record scope-evidence))))
                      (assert 'successor-schema-is-third-party-baseline
                        (eq? next-schema (.get next-review scope baseline)))
                      (assert 'successor-schema-is-published-edge
                        (eq? (.get next-review scope schema)
                             (.get (.call next .selected-record 'services/opentofu) interface requires JsonSchema)))
                      (for-each
                        (lambda (id)
                          (check-equal? (hash-get calls (list 'scope-factory id)) 1)
                          (check-equal? (hash-get calls (list 'scope-admission id)) 1))
                        '(json-schema services/opentofu app/review))
                      (assert 'successor-json-schema-build-entry-once
                        (= 1 (length (filter
                          (lambda (entry)
                            (equal? (.get entry path)
                              (path-expand "core/modules/json-schema/interface.ss" project)))
                          (.get next build-graph entries)))))))))
              (let (successor next-view)
                (def review (.call successor .selected-record 'app/review))
                (assert 'successor-admits-revised-review
                  (and (= (.get review scope revision) 2)
                       (eq? (.get review scope schema)
                            (.get (.call successor .selected-record 'services/opentofu)
                                  interface requires JsonSchema))))
                (def graph (.get successor build-graph))
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
                (assert 'missing-source-starts-no-nix (zero? starts))
                (write-init #t #t #t)
                (check-exception
                  (.call (.call successor .refresh) .selected-record 'app/review) error?)
                (assert 'disabled-provider-cannot-transfer #t)
                (check-equal? cross-generation-identities '(#t #t))))))))))
