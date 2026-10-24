;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test :clan/poo/object
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :std/misc/process run-process)
        (only-in :std/misc/ports read-all-as-string)
        (only-in :agentic-ai-lab/modules/nix/objects NixSource. NixFlakeSource.)
        (only-in :std/encoding/json read-json write-json)
        (only-in :agentic-ai-lab/modules/nix/func current-nix-process-observer current-nix-process-completion-observer)
        (only-in :std/text/pregexp pregexp-match)
        (only-in :std/string/misc string-subst)
        (only-in :gerbil/expander eval-syntax current-expander-context make-top-context syntax->list)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :yuanxu/observability/debug YuanxuDebugDurationAnomaly? YuanxuDebugMemoryAnomaly?)
        (only-in :yuanxu/object-types/contracts yuanxu-validation-evidence-accepted?)
        (only-in :yuanxu/modules/json-schema/json-schema-source yuanxu-json-schema-source->json-like)
        (only-in :yuanxu/modules/json-schema/functional yuanxu-contract-object-ref)
        (only-in :yuanxu/modules/json-schema/json-schema-validate yuanxu-json-schema-validation-diagnostic-metadata)
        (only-in :yuanxu/module-system/interface yuanxu-load-modules)
        (only-in :yuanxu/module-system/source/admission module-source-read current-module-source-observer)
        (only-in :yuanxu/module-system/source/reader module-publication-reader)
        (only-in :yuanxu/module-system/source/directory module-directory-context)
        (only-in "./qualification/opentofu/objects.ss" Ops))
(export opentofu-selected-graph-test)
(def SelectedPackages. (.get Ops prototypes SelectedPackages))
(def (assert label value)
  (unless value (error "assertion failed" label))
  (displayln "ASSERT-OK " label) (force-output))
(def (rejects? pattern thunk)
  (with-catch
    (lambda (exception)
      (when (or (YuanxuDebugDurationAnomaly? exception) (YuanxuDebugMemoryAnomaly? exception))
        (raise exception))
      (let* ((text (call-with-output-string (cut display-exception exception <>)))
             (matched (pregexp-match pattern text)))
        (unless matched (displayln "UNEXPECTED-REJECTION " text))
        (and matched #t)))
    (lambda () (thunk) #f)))
(def (write-source path text)
  (create-directory* (path-directory path))
  (call-with-output-file (list path: path truncate: #t) (cut display text <>)))
;; Upstream package configuration is a native derivation of the one real
;; publication. The existing source-context hook retains its reader observations.
;; No alternative declaration, copied module implementation or runtime Loader.
(def (configured-modules init upstream-source)
  (def reader (module-publication-reader))
  (def (configure scope)
    (.cc scope 'config (.cc (.get scope config) 'source upstream-source)))
  (def (read-publication source)
    (let* ((published (.call reader read source))
           (baseline (.get published core)))
      (if (not (eq? (.get published identity) 'services/opentofu)) published
        (.cc published 'core
          (.o (:: @ baseline)
            link: (lambda (dependencies) (configure (.call baseline link dependencies)))
            configuration-build:
            (let (build (.get baseline configuration-build))
              (.cc build 'module (configure (.get build module)))))))))
  (def context (module-directory-context init read-publication))
  (yuanxu-load-modules
    (.cc context
      'publication-inputs (.get reader inputs)
      'current? (lambda (generation)
                  (.call reader admit-current)
                  (.call context current? generation)))))
(def (derivation-inputs value)
  (run-process (list "nix-store" "--query" "--references" (.get value derivation))
               stdin-redirection: #f stderr-redirection: #f
               coprocess: read-all-as-string check-status: #t))
(def (configuration null?)
  (string-append
    "(def Config (.o resource: (.o aws_security_group: (.o web: (.o name: \"web\"))"
    (if null? " null_resource: (.o smoke: (.o triggers: (.o release: \"smoke\")))" "")
    ")))"))
;; Internal inspection only: package keys are consumer-qualified by Core.
(def (package-id artifact)
  (.get (car (.get artifact build-graph external-packages)) identity))
(def (package-result artifact)
  (.ref (.get artifact packages) (package-id artifact)))
(def (script-check path)
  (parameterize ((current-expander-context (make-top-context)))
    (for-each eval-syntax (syntax->list (read-syntax-from-file path)))
    ((eval-syntax 'main) "check")))
(def (run-selected-packages selection directory)
  (.call (.cc SelectedPackages. 'selection selection 'directory directory) .run))
;; Compare fresh scope publication and repeated accesses with the SAME store
;; inputs. Cold means a cold Scheme scope, never a flushed Nix store.
(def processes (make-hash-table))
(def source-observations (make-hash-table))
(def nix-seconds 0.)
(def (trace-row row)
  (when (getenv "AGENTIC_AI_LAB_OPENTOFU_GRAPH_TRACE" #f)
    (call-with-output-file
      (list path: (getenv "AGENTIC_AI_LAB_OPENTOFU_GRAPH_TRACE") append: #t)
      (lambda (port) (write-json port (list->hash-table row)) (newline port)))))
(def flake-root (getenv "AGENTIC_AI_LAB_OPENTOFU_GRAPH_FLAKE" #f))
(def evaluator (if flake-root "nix" "nix-instantiate"))
(def measurements '())
(def (process-count name) (hash-ref processes name 0))
(def (count-total counts index)
  (foldl (lambda (row total) (+ total (list-ref row index))) 0 counts))
(def (measure label thunk expected-instantiations
        types: (types (lambda (_result) '())))
  (let* ((before-instantiate (process-count evaluator))
         (before-realize (process-count 'realize))
         (before-register (process-count 'register))
         (before-validity (process-count 'store-validity))
         (before-types (types #f))
         (before-nix nix-seconds)
         (before-source (hash->list source-observations))
         (start (real-time))
         (result (thunk))
         (after-types (types result))
         (elapsed (- (real-time) start))
         (row (list (cons 'phase label)
                    (cons 'seconds elapsed)
                    (cons 'type-reads (- (count-total after-types 2) (count-total before-types 2)))
                    (cons 'type-compiles (- (count-total after-types 1) (count-total before-types 1)))
                    (cons 'instantiate (- (process-count evaluator) before-instantiate))
                    (cons 'realize (- (process-count 'realize) before-realize))
                    (cons 'register (- (process-count 'register) before-register))
                    (cons 'store-validity (- (process-count 'store-validity) before-validity))
                    (cons 'nix-seconds (- nix-seconds before-nix))
                    (cons 'native-seconds (- elapsed (- nix-seconds before-nix)))))
         (row (append row
                (map (lambda (key)
                       (cons (string->symbol (string-append "source-" (symbol->string key)))
                         (- (hash-ref source-observations key 0)
                            (cond ((assq key before-source) => cdr) (else 0)))))
                     '(checks check-seconds reads read-requests stats query-hits query-misses)))))
    (displayln "PERF " row)
    (trace-row row)
    ;; Cold construction may add one writable registration after a readonly
    ;; lookup. Record that work separately; currentness checks may never do it.
    (assert (string-append label "-registration-budget")
      (<= (cdr (assq 'register row)) (if (string-suffix? "-build" label) 1 0)))
    (assert (string-append label "-store-validity-budget")
      (<= (cdr (assq 'store-validity row)) (if (string-suffix? "-build" label) 1 0)))
    (assert (string-append label "-process-budget")
      (= (cdr (assq 'instantiate row))
         (+ expected-instantiations (cdr (assq 'register row)))))
    (assert (string-append label "-realization-budget")
      (= (cdr (assq 'realize row)) (if (string-suffix? "-build" label) 1 0)))
    (let (expected-types (cond ((equal? label "aws-build") 1)
                               ((equal? label "aws-null-build") 2) (else 0)))
      (assert (string-append label "-type-budget")
        (and (= (cdr (assq 'type-reads row)) expected-types)
             (= (cdr (assq 'type-compiles row)) expected-types))))
    (set! measurements (cons (list->hash-table row) measurements))
    result))
(def (type-counts scope owners)
  (map (lambda (owner)
         (let* ((provider (.get (.ref (.get scope modules) owner) provider))
                (artifact (.get provider artifact))
                (name (if (eq? owner 'aws) 'aws_security_group 'null_resource)))
           (list owner (.call provider .contract-compile-count)
                 (.call artifact .entry-read-count name 'resource)))) owners))
(def (run-selected-graph-control invalid-only?)
      (parameterize ((current-module-source-observer
                      (lambda (kind amount)
                        (hash-update! source-observations kind (cut + <> amount) 0)))
                     (current-nix-process-completion-observer
                       (lambda (argv seconds completed?)
                         (set! nix-seconds (+ nix-seconds seconds))
                         (trace-row (list (cons 'kind "nix-process")
                                          (cons 'executable (car argv))
                                          (cons 'seconds seconds)
                                          (cons 'completed completed?)))))
                     (current-nix-process-observer
                       (lambda (argv)
                         (when (getenv "AGENTIC_AI_LAB_NIX_ARGV_TRACE" #f)
                           (call-with-output-file
                             (list path: (getenv "AGENTIC_AI_LAB_NIX_ARGV_TRACE") append: #t)
                             (lambda (port) (write-json port (list->vector argv)) (newline port))))
                         (hash-update! processes (path-strip-directory (car argv)) 1+ 0)
                         (cond
                          ((member "--realise" argv) (hash-update! processes 'realize 1+ 0))
                          ((member "--read-write-mode" argv) (hash-update! processes 'register 1+ 0))
                          ((member "--check-validity" argv) (hash-update! processes 'store-validity 1+ 0))))))
      (call-with-temporary-directory (if flake-root "opentofu-${literal}-\"λ-graph" "opentofu-selected-graph")
        (lambda (root)
          (def lock-text (and flake-root (module-source-read (path-expand "flake.lock" flake-root))))
          (def owner (path-expand "modules/app/infrastructure" root))
          (def config (path-expand "config.ss" owner))
          (def upstream (path-expand "modules/services/opentofu" (current-directory)))
          (def maintained (path-expand "modules/services/opentofu" (current-directory)))
          (def real-catalog (path-expand "t/fixtures/opentofu/family-schemas.nix" (current-directory)))
          (def catalog-path (path-expand "catalog.nix" root))
          (def provider-source (path-expand "providers.nix" (or flake-root root)))
          (def provider-text
            (if flake-root (module-source-read provider-source)
              (string-append "{ pkgs }: import " (call-with-output-string (cut write real-catalog <>)) " { inherit pkgs; }")))
          (write-source catalog-path "{ pkgs }: import ./providers.nix { inherit pkgs; }")
          (write-source provider-source provider-text)
          (write-source (path-expand "gerbil.pkg" root)
                        (string-append "(package: " (symbol->string (gensym 'opentofu-graph-)) ")"))
          (def init (path-expand "init.ss" root))
          (write-source init
            (call-with-output-string
              (lambda (port)
                (write `(yuanxu! mode: explicit
                          (json-schema @ ,(path-expand "modules/json-schema" (current-directory)))
                          (nix @ ,(path-expand "modules/nix" (current-directory)))
                          (funflow @ ,(path-expand "modules/funflow" (current-directory)))
                          :services (opentofu @ ,upstream)
                          :app (infrastructure) :unused (bomb disable: #t)) port))))
          (write-source (path-expand "types.ss" owner)
                        "(import :clan/poo/object (only-in :yuanxu/object-types/contracts yuanxu-predicate-contract)) (def Scope (yuanxu-predicate-contract 'scope object? (lambda (_v _c) '()))) (export Scope)")
          (write-source (path-expand "objects.ss" owner)
                        "(import :clan/poo/object) (def Defaults (.o)) (export Defaults)")
          (write-source config (if invalid-only?
            (string-subst (configuration #t) "name: \"web\"" "name: 42")
            (configuration #f)))
          (def upstream-source
            (if flake-root
              (.cc NixFlakeSource.
                'reference (string-append "path:" (path-normalize flake-root))
                'attribute "lib.providerArtifacts")
              (let ((expression-path (path-expand "nix/selected-provider-artifacts.nix" maintained))
                    (collector-path (path-expand "nix/provider-artifacts.nix" maintained))
                    (checker (path-expand "modules/nix/source-inputs.nix" (current-directory))))
                (.o (:: @ NixSource.)
                  expression: expression-path
                  arguments: (.o catalog: catalog-path collector: collector-path)
                  source-inputs:
                  (map (lambda (path) (cons path (module-source-read path)))
                       (list expression-path catalog-path collector-path checker))))))
          (write-source (path-expand "types.ss" owner)
            (string-append "(import (only-in :agentic-ai-lab/modules/services/opentofu/types OpenTofuScopeContract)) "
                           (string-subst (module-source-read (path-expand "types.ss" owner)) "(export Scope)" "(export Scope OpenTofuScopeContract)")))
          (write-source (path-expand "interface.ss" owner)
            "(.def Infrastructure identity: 'app/infrastructure core: (.o requires: (.o Tofu: (.o module-id: 'services/opentofu contract: OpenTofuScopeContract)) scope-contract: Scope exports: (.o config: Config)) features: (.o))")
          (write-source (path-expand "modules/unused/bomb/interface.ss" root)
                        "(((disabled module must not parse")
          (write-source (path-expand "modules/unused/bomb/build.ss" root)
                        "(((disabled build must not parse")
          (if invalid-only?
            (assert 'invalid-config-rejected-before-build-return
              (rejects? "configuration admission rejected"
                (lambda () (run-selected-packages
                  (configured-modules init upstream-source)
                  (path-expand "invalid" root)))))
            (let ()
          (def parent-view (configured-modules init upstream-source))
          (assert 'maintained-publisher-source
            (equal? (path-normalize (.get (.call (.get parent-view context) locate 'services/opentofu) value))
                    (path-normalize (path-expand "interface.ss" maintained))))
          (assert 'maintained-build-role-source
            (equal? (path-normalize (.get (.call parent-view prepare-publication 'services/opentofu) build-source))
                    (path-normalize (path-expand "build.ss" maintained))))
          (def public-scope (.get parent-view modules services opentofu))
          (assert 'scope-published-before-build (object? public-scope))
          (assert 'scope-does-not-force-source (not (.ref/cached (.get public-scope config source) 'source-inputs)))
          (assert 'scope-does-not-start-nix (= (process-count evaluator) 0))
          (assert 'core-source-is-not-copied
            (not (file-exists? (path-expand "modules/services/opentofu" root))))
          (assert 'selected-dependency-order
            (equal? (.get parent-view dependency-order)
                    '(json-schema nix ops funflow services/opentofu app/infrastructure)))
          (let* ((records (.get parent-view selected-records))
                 (json-schema (find (lambda (record) (eq? (.get record identity) 'json-schema)) records))
                 (nix (find (lambda (record) (eq? (.get record identity) 'nix)) records))
                 (tofu (find (lambda (record) (eq? (.get record identity) 'services/opentofu)) records)))
            (assert 'json-schema-contract-identity-shared
              (eq? (.get json-schema publication core scope-contract)
                   (.get tofu publication core requires JsonSchema contract)))
            (assert 'nix-contract-identity-shared
              (eq? (.get nix publication core scope-contract)
                   (.get tofu publication core requires Nix contract))))
          (def parent-graph (.get parent-view build-graph))
          (assert 'external-package-in-selected-graph (= (length (.get parent-graph external-packages)) 1))
          (assert 'consumer-has-no-build-role (not (file-exists? (path-expand "build.ss" owner))))
          (assert 'upstream-build-owner
            (eq? (.get (car (.get parent-graph external-packages)) build-owner) 'services/opentofu))
          (assert 'downstream-configuration-owner
            (eq? (.get (car (.get parent-graph external-packages)) configuration-owner) 'app/infrastructure))
          (assert 'config-observed (assoc (path-normalize config) (.get parent-graph source-inputs)))
          (def parent (measure "aws-build" (lambda () (run-selected-packages parent-view (path-expand "parent" root))) 2
            types: (lambda (result) (if result (type-counts (.get (package-result result) scope) '(aws)) '()))))
          (def parent-package (package-result parent))
          (def parent-scope (.get parent-package scope))
          (def parent-contract (.get parent-scope types configuration))
          (assert 'build-returned-admitted-parent
            (= (.call (.get parent-scope modules aws provider) .contract-compile-count) 1))
          (assert 'parent-admitted (measure "aws-first-admission" (lambda () (yuanxu-validation-evidence-accepted? (.get parent-package admission))) 0
            types: (lambda (_) (type-counts parent-scope '(aws)))))
          (def parent-counts (type-counts parent-scope '(aws)))
          (measure "aws-hot-slots" (lambda ()
            (for-each (lambda (_) (.get parent-package admission) (.get parent-scope types configuration)) '(1 2 3 4 5))) 0
            types: (lambda (_) (type-counts parent-scope '(aws))))
          (assert 'hot-slots-do-not-compile-or-read (equal? parent-counts (type-counts parent-scope '(aws))))
          (measure "aws-explicit-recheck" (lambda () ((.get parent admit-current))) 1
            types: (lambda (_) (type-counts parent-scope '(aws))))
          (assert 'one-parent-type-read-and-compiled (equal? parent-counts '((aws 1 1))))
          (displayln "TYPE-COUNTS aws " parent-counts)
          (when flake-root
            (let (closure (derivation-inputs parent-package))
              (assert 'aws-schema-in-selected-derivation
                (pregexp-match "terraform-provider-aws-5[.]100[.]0-schema" closure))
              (assert 'null-and-awscc-absent-from-aws-producer-inputs
                (not (pregexp-match "terraform-provider-(null|awscc)" closure)))))
          (assert 'parent-only-aws (equal? (.all-slots (.get parent-scope modules)) '(aws)))
          (def sg (.call (.get parent-scope modules aws provider) .contract 'aws_security_group 'resource))
          (assert 'aws-version-preserved (equal? (.get sg version) "5.100.0"))
          (assert 'aws-schema-source-preserved
            (equal? (.get sg schema-digest) "7e4fc064120609e23bc317629f1308d72891b7241993fbf68be523f03b6c633c"))
          (assert 'request-has-source-revision
            (let (wire (call-with-input-file (path-expand (string-append "parent/external/" (symbol->string (package-id parent)) "/selection.json") root) read-json))
              (and (yuanxu-contract-object-ref (yuanxu-json-schema-source->json-like wire) 'configuration-source #f)
                   (yuanxu-contract-object-ref (yuanxu-json-schema-source->json-like wire) 'configuration-sha256 #f))))
          (write-source config (configuration #t))
          (assert 'stale-graph-rejected (rejects? "stale|refused" (lambda () ((.get parent-graph admit-current)))))
          (assert 'stale-artifact-rejected (rejects? "stale|refused" (lambda () ((.get parent admit-current)))))
          (assert 'stale-generated-script-rejected (rejects? "stale selected build input" (lambda () (script-check (.get parent guard-entry)))))
          (assert 'stale-build-refused-before-handoff
            (rejects? "stale|refused" (lambda () (run-selected-packages parent-view (path-expand "stale" root)))))
          (assert 'nix-source-itself-rejects-stale-demand
            (rejects? "process exited|stale" (lambda () (.call (.get parent-package source) .instantiate))))
          (def child-view (configured-modules init upstream-source))
          (def child (measure "aws-null-build" (lambda () (run-selected-packages child-view (path-expand "child" root))) 2
            types: (lambda (result) (if result (type-counts (.get (package-result result) scope) '(aws null)) '()))))
          (def child-package (package-result child))
          (def child-scope (.get child-package scope))
          (assert 'rebuilt-from-final-config
            (equal? (list-sort string<? (map symbol->string (.all-slots (.get child-scope modules)))) '("aws" "null")))
          (assert 'build-returned-admitted-child
            (every (lambda (owner) (= (.call (.get (.ref (.get child-scope modules) owner) provider) .contract-compile-count) 1)) '(aws null)))
          (assert 'child-admitted (measure "aws-null-first-admission" (lambda () (yuanxu-validation-evidence-accepted? (.get child-package admission))) 0
            types: (lambda (_) (type-counts child-scope '(aws null)))))
          (def child-counts (type-counts child-scope '(aws null)))
          (measure "aws-null-hot-slots" (lambda ()
            (for-each (lambda (_) (.get child-package admission) (.get child-scope types configuration)) '(1 2 3 4 5))) 0
            types: (lambda (_) (type-counts child-scope '(aws null))))
          (assert 'child-hot-slots-do-not-compile-or-read (equal? child-counts (type-counts child-scope '(aws null))))
          (assert 'two-child-types-read-and-compiled (equal? child-counts '((aws 1 1) (null 1 1))))
          (assert 'unselected-aws-type-uncompiled
            (not (.call (.get child-scope modules aws provider) .contract-cached? 'aws_instance 'resource)))
          (measure "aws-null-explicit-recheck" (lambda () ((.get child admit-current))) 1
            types: (lambda (_) (type-counts child-scope '(aws null))))
          (displayln "TYPE-COUNTS aws-null " child-counts)
          (assert 'both-final-resources-admitted
            (= (length (.get child-package admission classification children)) 2))
          (def effective (.get child-package configuration))
          (def invalid
            (.cc effective 'resource (.cc (.get effective resource) 'aws_security_group
                                      (.o web: (.o name: 42)))))
          (def rejected (.call (.get child-scope types configuration) .admit invalid #f))
          (assert 'generated-contract-still-rejects-invalid-field
            (not (yuanxu-validation-evidence-accepted? rejected)))
          (assert 'complete-error-path-preserved
            (find (lambda (diagnostic)
                    (equal? (cdr (assoc 'path (yuanxu-json-schema-validation-diagnostic-metadata diagnostic)))
                            '(resource aws_security_group web name)))
                  (.get rejected diagnostics)))
          (when flake-root
            (let (closure (derivation-inputs child-package))
              (assert 'null-added-to-selected-derivation
                (pregexp-match "terraform-provider-null-3[.]2[.]4-schema" closure))
              (assert 'awscc-still-absent-from-child-producer-inputs
                (not (pregexp-match "terraform-provider-awscc" closure))))
            (assert 'aws-schema-store-output-reused
              (equal? (path-normalize (.get parent-scope modules aws config provider-artifact))
                      (path-normalize (.get child-scope modules aws config provider-artifact)))))
          (assert 'new-provider-version (equal? (.get child-scope modules null provider version) "3.2.4"))
          (assert 'child-contract-is-a-distinct-receiver
            (not (eq? parent-contract (.get child-scope types configuration))))
          (assert 'parent-contract-cache-isolated (eq? parent-contract (.get parent-scope types configuration)))
          (assert 'parent-has-no-null (not (.slot? (.get parent-scope modules) 'null)))
          (assert 'awscc-excluded (not (.slot? (.get child-scope modules) 'awscc)))
          ;; A later independent first admission must not reuse a build-stage
          ;; validity receipt. Restore exact bytes to continue the Nix control.
          (write-source config (configuration #f))
          (assert 'late-first-admission-rejects-stale-source
            (rejects? "stale|refused" (lambda () (.get (.cc child-package) admission))))
          (write-source config (configuration #t))
          (assert 'current-child-accepted (begin ((.get child admit-current)) #t))
          ;; The Nix Source guard detects transitive catalog changes without a
          ;; second Scheme/Nix dependency parser or manual dependency file list.
          (write-source provider-source
            (string-append "{ pkgs }: let p = (" provider-text
                           ") { inherit pkgs; }; in p // { null = p.aws; }"))
          (assert 'transitive-nix-change-rejected
            (rejects? "stale external package derivation" (lambda () ((.get child admit-current)))))
          (assert 'generated-guard-rejects-transitive-nix-change
            (rejects? "stale external package derivation" (lambda () (script-check (.get child guard-entry)))))
          (write-source provider-source provider-text)
          (def selection (path-expand (string-append "child/external/" (symbol->string (package-id child)) "/selection.json") root))
          (write-source selection "{\"providers\":[\"aws\"]}")
          (assert 'tampered-demand-rejected
            (rejects? "stale selected build input" (lambda () ((.get child admit-current)))))
          (assert 'generated-guard-rejects-tampered-demand
            (rejects? "stale selected build input" (lambda () (script-check (.get child guard-entry)))))
          ;; The entry was written before lazy realization. Tampering during
          ;; that effect must be detected by the FINAL publication boundary.
          (def original-observer (current-nix-process-observer))
          (def interrupted-output (path-expand "interrupted" root))
          (assert 'entry-mutation-during-realization-rejected
            (parameterize ((current-nix-process-observer
                            (lambda (argv)
                              (original-observer argv)
                              (when (and (equal? (path-strip-directory (car argv)) "nix-store")
                                         (member "--realise" argv))
                                (write-source (path-expand "guard.ss" interrupted-output) "tampered")))))
              (rejects? "stale selected build input"
                (lambda () (run-selected-packages child-view interrupted-output)))))
          (when flake-root
            (let* ((flake (path-expand "flake.nix" flake-root))
                   (text (module-source-read flake)))
              (write-source (path-expand "flake.nix" (string-append flake-root "-unlocked"))
                "{ outputs = { self }: {}; }")
              (write-source flake
                (string-subst (string-subst text "outputs = { self, nixpkgs }:"
                                          "outputs = { self, nixpkgs, ... }:") "\n{\n"
                  (string-append "\n{\n  inputs.unlocked.url = \"path:"
                    (string-append flake-root "-unlocked") "\";\n")))
              (assert 'implicit-flake-lock-update-rejected
                (rejects? "process exited|lock"
                  (lambda () (.call (.cc NixFlakeSource.
                    'reference (.get child-package source reference)
                    'attribute (.get child-package source attribute)
                    'arguments (.get child-package source arguments)) .instantiate))))
              (assert 'rejected-evaluation-did-not-change-lock
                (equal? lock-text (module-source-read (path-expand "flake.lock" flake-root))))
              (write-source flake text)
              (delete-file (path-expand "flake.nix" (string-append flake-root "-unlocked")))
              (delete-directory (string-append flake-root "-unlocked")))
            (assert 'flake-lock-unchanged-across-config-generations
              (equal? lock-text (module-source-read (path-expand "flake.lock" flake-root)))))
          (when (getenv "AGENTIC_AI_LAB_OPENTOFU_GRAPH_METRICS" #f)
            (call-with-output-file (list path: (getenv "AGENTIC_AI_LAB_OPENTOFU_GRAPH_METRICS") truncate: #t)
              (lambda (port) (write-json port (list->hash-table (list (cons 'phases (list->vector (reverse measurements))) (cons 'parent-types (list->vector (map list->vector parent-counts))) (cons 'child-types (list->vector (map list->vector child-counts)))))))))
          (assert 'tampered-demand-kept-for-diagnosis
            (equal? (module-source-read selection) "{\"providers\":[\"aws\"]}"))))))))

(def opentofu-selected-graph-test
  (test-suite "opentofu-selected-graph-test"
    (yuanxu-test-case "selected graph builds packages and preserves parent cache"
      (run-selected-graph-control #f))
    (yuanxu-test-case "invalid final configuration prevents build success"
      (run-selected-graph-control #t))))
