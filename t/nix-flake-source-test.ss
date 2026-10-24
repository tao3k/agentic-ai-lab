;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :agentic-ai-lab/modules/nix/progress make-nix-progress-reader) :std/test :clan/poo/object
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :yuanxu/ops/func run-script)
        (only-in :yuanxu/ops/process-script ProcessScript.)
        (only-in :yuanxu/ops/progress execution-total-seconds execution-idle-seconds
                 )
        (only-in :gerbil/expander eval-syntax current-expander-context make-top-context)
        (only-in :std/encoding/json write-json read-json)
        (only-in :std/text/pregexp pregexp-match)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :yuanxu/object-types/contracts yuanxu-validation-evidence-accepted?)
        (only-in :agentic-ai-lab/modules/nix/objects NixFlakeSource.)
        (only-in :agentic-ai-lab/modules/nix/types NixFlakeSourceContract)
        (only-in :agentic-ai-lab/modules/nix/func current-nix-process-observer)
        (only-in :agentic-ai-lab/modules/services/opentofu/objects OpenTofuScope.)
        (only-in :yuanxu/modules/json-schema/json-schema-source yuanxu-json-schema-source->json-like)
        (only-in :yuanxu/modules/json-schema/functional yuanxu-contract-object-ref)
        (only-in :yuanxu/module-system/source/admission module-source-read module-source-admit-current!))
(export nix-flake-source-test nix-flake-source-suite)
(def (assert label value)
  (unless value (error "assertion failed" label))
  (displayln "ASSERT-OK " label))
(def (rejects? pattern thunk)
  (with-catch
    (lambda (e) (and (pregexp-match pattern (call-with-output-string (cut display-exception e <>))) #t))
    (lambda () (thunk) #f)))
(def (write-source path text)
  (create-directory* (path-directory path))
  (call-with-output-file (list path: path truncate: #t) (cut display text <>)))
(def (counts scope owners)
  (foldl (lambda (owner total)
           (let* ((provider (.get (.ref (.get scope modules) owner) provider))
                  (name (if (eq? owner 'aws) 'aws_security_group 'null_resource)))
             (list (+ (car total) (.call (.get provider artifact) .entry-read-count name 'resource))
                   (+ (cadr total) (.call provider .contract-compile-count))))) '(0 0) owners))
(def (nix-flake-source-suite with-evaluator)
  (test-suite "Locked native flake Source with real Provider schema artifacts"
    (yuanxu-test-case "AWS-only to Null, fresh guards and receiver-local caches"
      (with-evaluator (lambda (evaluator)
      (call-with-temporary-directory "nix-flake-source"
        (lambda (root)
          (def artifacts (getenv "AGENTIC_AI_LAB_OPENTOFU_FLAKE_ARTIFACT"))
          (def nix (getenv "AGENTIC_AI_LAB_NIX_C_API_CLI" "nix"))
          (def tools-json (yuanxu-json-schema-source->json-like
                            (call-with-input-string (getenv "AGENTIC_AI_LAB_NIX_TEST_TOOLS") read-json)))
          (def package-set (yuanxu-contract-object-ref tools-json 'nixpkgs #f))
          (def package-hash (yuanxu-contract-object-ref tools-json 'nixpkgsHash #f))
          (def tools (yuanxu-contract-object-ref tools-json 'tools #f))
          (def system (yuanxu-contract-object-ref tools-json 'system #f))
          (for-each (lambda (path)
                      (unless (and (string-prefix? "/nix/store/" path) (file-exists? path))
                        (error "real package fixture required" path)))
                    (list artifacts package-set))
          (def selection (path-expand "selection.json" root))
          (def flake (path-expand "flake.nix" root))
          (def lock (path-expand "flake.lock" root))
          (def providers (path-expand "providers.nix" root))
          (def provider-text
            "{ aws = artifacts + \"/aws\"; null = artifacts + \"/null\"; }")
          (write-source providers (string-append "{ artifacts }: " provider-text))
          (write-source (path-expand "policy/flake.nix" root)
            "{ outputs = { self }: { label = \"provider-artifacts\"; }; }")
          (write-source flake
            (string-append
              "{ inputs.policy.url = \"path:./policy\"; "
              "inputs.nixpkgs = { type = \"path\"; path = \"" package-set "\"; narHash = \"" package-hash "\"; flake = false; }; "
              "inputs.artifacts = { url = \"path:" artifacts "\"; flake = false; }; "
              "outputs = { self, policy, nixpkgs, artifacts, ... }: let "
              "pkgs = import nixpkgs { system = \"" system "\"; }; shell = pkgs.bash; tools = pkgs.coreutils; "
              "providers = import ./providers.nix { inherit artifacts; }; "
              "names = builtins.fromJSON (builtins.readFile ./selection.json); "
              "links = builtins.concatStringsSep \"\\n\" (map (name: \"${tools}/bin/ln -s ${providers.${name}} $out/${name}\") names); "
              "in { packages." system ".default = builtins.derivation { "
              "name = policy.label; system = \"" system "\"; "
              "builder = \"${shell}/bin/bash\"; args = [ \"-euc\" (\"${tools}/bin/mkdir -p $out\\n\" + links) ]; }; "
              "lib.fromArguments = { name }: if name == \"configured\" then self.packages." system ".default "
              "else throw \"unexpected function argument\"; }; }"))
          (def flake-text (module-source-read flake))
          (write-source selection "[\"aws\"]")
          ;; Package setup explicitly creates the lock; runtime never updates it.
          (run-script
            (.cc ProcessScript.
              'command (list nix "--extra-experimental-features" "nix-command flakes"
                             "--log-format" "internal-json"
                             "flake" "lock" (string-append "path:" (path-normalize root)))
              'timeout execution-total-seconds 'idle-timeout execution-idle-seconds
              'progress make-nix-progress-reader)
            output-port: (current-error-port))
          (def lock-text (module-source-read lock))
          (def starts (make-hash-table))
          (def measurements '())
          (def (processes name) (hash-ref starts name 0))
          (def (evaluation-count) (if evaluator (.call evaluator .calls) (processes "nix-query")))
          (def (measure label thunk evaluations realizations types)
            (let* ((before-eval (evaluation-count)) (before-cli (processes "nix"))
                   (before-realize (processes "nix-store"))
                   (before-types (types #f)) (start (real-time)) (result (thunk))
                   (after-types (types result)) (seconds (- (real-time) start))
                   (row (list (cons 'phase label) (cons 'seconds seconds)
                              (cons 'instantiate (- (evaluation-count) before-eval))
                              (cons 'cli-processes (- (processes "nix") before-cli))
                              (cons 'backend (if evaluator "c-api" "cli"))
                              (cons 'realize (- (processes "nix-store") before-realize))
                              (cons 'type-reads (- (car after-types) (car before-types)))
                              (cons 'type-compiles (- (cadr after-types) (cadr before-types))))))
              (assert (string-append label "-process-budget")
                (and (= (cdr (assq 'instantiate row)) evaluations)
                     (= (cdr (assq 'cli-processes row)) (if evaluator 0 (* 2 evaluations)))
                     (= (cdr (assq 'realize row)) realizations)))
              (let (expected-types (cond ((equal? label "aws-first-admission") 1)
                                         ((equal? label "aws-null-first-admission") 2) (else 0)))
                (assert (string-append label "-type-budget")
                  (and (= (cdr (assq 'type-reads row)) expected-types)
                       (= (cdr (assq 'type-compiles row)) expected-types))))
              (set! measurements (cons (list->hash-table row) measurements))
              (displayln "FLAKE-PERF " row)
              result))
          (def (config null?)
            (.o resource:
                (if null?
                  (.o aws_security_group: (.o web: (.o name: "web"))
                      null_resource: (.o smoke: (.o triggers: (.o release: "smoke"))))
                  (.o aws_security_group: (.o web: (.o name: "web"))))))
          (def (source)
            (.cc NixFlakeSource. 'reference (string-append "path:" (path-normalize root))
              'evaluator evaluator
              'config (.cc (.get NixFlakeSource. config) 'nix nix)
              'attribute (string-append "packages." system ".default")
              ;; Resolve the same locked immutable path explicitly, retaining
              ;; Nix's native accessor fingerprint instead of rehashing its tree.
              'inputs (.o nixpkgs: package-set)))
          (def (build null?)
            (let* ((observed (map (lambda (path) (cons path (module-source-read path)))
                                  (list flake lock selection)))
                   (publication (.call (source) .prepare
                                  (lambda () (module-source-admit-current! observed)))))
              (let (complete
                     (.+ publication
                       (.o (:: @ [] artifact admit-current)
                         configuration: (config null?)
                         admission: (begin (admit-current)
                           (.call (.get scope types configuration) .admit configuration #f))
                         scope: (.cc OpenTofuScope. 'config
                                  (.cc (.get OpenTofuScope. config) 'artifact artifact)))))
                ((.get complete admit-current))
                complete)))
          (parameterize ((current-nix-process-observer
                          (lambda (argv)
                            (hash-update! starts (path-strip-directory (car argv)) 1+ 0)
                            (when (or (member "path-info" argv) (member "eval" argv))
                              (hash-update! starts "nix-query" 1+ 0)))))
            (assert 'flake-source-contract
              (yuanxu-validation-evidence-accepted? (.call NixFlakeSourceContract .admit (source) #f)))
            (assert 'flake-nonstring-argument-rejected
              (not (yuanxu-validation-evidence-accepted?
                     (.call NixFlakeSourceContract .admit (.cc (source) 'arguments (.o foo: 42)) #f))))
            (def parent (measure "aws-build" (lambda () (build #f)) 2 1
                          (lambda (result) (if result (counts (.get result scope) '(aws)) '(0 0)))))
            (def parent-scope (.get parent scope))
            (def parent-contract (.get parent-scope types configuration))
            (assert 'parent-admitted
              (measure "aws-first-admission"
                (lambda () (yuanxu-validation-evidence-accepted? (.get parent admission)))
                1 0 (lambda (_) (counts parent-scope '(aws)))))
            (measure "aws-hot-slots" (lambda ()
              (for-each (lambda (_) (.get parent admission) (.get parent-scope types configuration)) '(1 2 3 4 5)))
              0 0 (lambda (_) (counts parent-scope '(aws))))
            (measure "aws-explicit-recheck" (lambda () ((.get parent admit-current)))
              1 0 (lambda (_) (counts parent-scope '(aws))))
            (write-source selection "[\"aws\",\"null\"]")
            (assert 'stale-parent-rejected
              (rejects? "stale selected build input" (lambda () ((.get parent admit-current)))))
            (def child (measure "aws-null-build" (lambda () (build #t)) 2 1
                         (lambda (result) (if result (counts (.get result scope) '(aws null)) '(0 0)))))
            (def child-scope (.get child scope))
            (assert 'child-admitted
              (measure "aws-null-first-admission"
                (lambda () (yuanxu-validation-evidence-accepted? (.get child admission)))
                1 0 (lambda (_) (counts child-scope '(aws null)))))
            (measure "aws-null-hot-slots" (lambda ()
              (for-each (lambda (_) (.get child admission) (.get child-scope types configuration)) '(1 2 3 4 5)))
              0 0 (lambda (_) (counts child-scope '(aws null))))
            (measure "aws-null-explicit-recheck" (lambda () ((.get child admit-current)))
              1 0 (lambda (_) (counts child-scope '(aws null))))
            (assert 'one-input-per-selected-resource (equal? (counts child-scope '(aws null)) '(2 2)))
            (assert 'aws-version-locked (equal? (.get child-scope modules aws provider version) "5.100.0"))
            (assert 'null-version-locked (equal? (.get child-scope modules null provider version) "3.2.4"))
            (assert 'parent-cache-isolated (eq? parent-contract (.get parent-scope types configuration)))
            (when evaluator
              (assert 'native-evaluations-start-no-nix-cli (= (processes "nix") 0))
              (assert 'locked-store-input-needs-no-cli-fallback (= (.call evaluator .fallback-calls) 0))
              (assert 'native-store-and-state-created-once
                (and (= (.get (.call evaluator .timing 'store) calls) 1)
                     (= (.get (.call evaluator .timing 'state) calls) 1))))
            (assert 'parent-no-null (not (.slot? (.get parent-scope modules) 'null)))
            (assert 'awscc-unselected (not (.slot? (.get child-scope modules) 'awscc)))
            (assert 'ordinary-argument-object-applied
              (equal? (.call (.cc (source) 'attribute "lib.fromArguments"
                                'arguments (.o name: "configured")) .instantiate)
                      (.get child derivation)))
            ;; Indirect Nix dependency changes are checked by native flake eval.
            (write-source providers (string-append "{ artifacts }: let p = " provider-text "; in p // { null = p.aws; }"))
            (assert 'transitive-flake-change-rejected
              (rejects? "stale external package derivation" (lambda () ((.get child admit-current)))))
            (assert 'serialized-flake-guard-rejects-change
              (rejects? "stale external package derivation"
                (lambda ()
                  (parameterize ((current-expander-context (make-top-context)))
                    (eval-syntax '(import :agentic-ai-lab/modules/nix/objects))
                    (for-each eval-syntax (.get child guard-forms))))))
            (write-source providers (string-append "{ artifacts }: " provider-text))
            (assert 'lock-unchanged (equal? lock-text (module-source-read lock)))
            ;; Add a previously unlocked input; changing a relative input's
            ;; contents alone can legitimately keep its parent-root lock entry.
            (write-source flake
              (string-append "{ inputs.unlocked = { url = \"path:" tools "\"; flake = false; }; "
                             (substring flake-text 1 (string-length flake-text))))
            (assert 'implicit-lock-update-rejected
              (rejects? "process exited|lock" (lambda () (.call (source) .instantiate))))
            (assert 'failed-eval-did-not-write-lock (equal? lock-text (module-source-read lock))))
          (when (getenv "AGENTIC_AI_LAB_NIX_FLAKE_METRICS" #f)
            (call-with-output-file (list path: (getenv "AGENTIC_AI_LAB_NIX_FLAKE_METRICS") truncate: #t)
              (lambda (port) (write-json port (list->hash-table
                (list (cons 'phases (list->vector (reverse measurements))))))))))))))))
(def nix-flake-source-test (nix-flake-source-suite (lambda (procedure) (procedure #f))))
