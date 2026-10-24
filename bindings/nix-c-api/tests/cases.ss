;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Real provider demand/evaluation comparison, not a replacement publication API.
(import :std/test :clan/poo/object
        (only-in :std/encoding/json json->string string->json JSONReadOptions)
        (only-in :std/misc/process run-process)
        (only-in :std/misc/ports read-all-as-string)
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :yuanxu/module-system/source/admission
                 module-source-read module-source-admit-current!)
        (only-in :agentic-ai-lab/modules/services/opentofu/objects OpenTofuScope.)
        (only-in :yuanxu/object-types/contracts yuanxu-validation-evidence-accepted?)
        "../compatibility.ss")
(export nix-api-suite root nix demand field admit provider-expression
        write-input assert rejected? timed checked-query observe-inputs AwsOnly AwsNull
        provider-exports)

(def root (getenv "AGENTIC_AI_LAB_NIX_C_API_ROOT"))
(def nix (getenv "AGENTIC_AI_LAB_NIX_C_API_CLI"))
(def cli-calls 0)
(def (native-cli expression (registration? #f))
  (set! cli-calls (1+ cli-calls))
  ;; Match the existing expression Source's nix-instantiate evaluation mode.
  ;; `nix eval` defaults to pure evaluation and is a different protocol.
  (run-process (append (list (path-expand "nix-instantiate" (path-directory nix))
                             "--eval" "--raw" "--expr" expression)
                      (if registration? '("--read-write-mode") '()))
    stdin-redirection: #f stderr-redirection: #f
    coprocess: read-all-as-string check-status: #t))
(def (write-input path text)
  (call-with-output-file (list path: path truncate: #t) (cut display text <>)))
(def (assert label condition)
  (unless condition (error "Nix C API qualification failed" label))
  (displayln "ASSERT-OK " label))
(def (rejected? thunk)
  (with-catch
    (lambda (failure)
      (let (message (call-with-output-string (cut display-exception failure <>)))
        (and (string-contains message "stale selected build input") #t)))
    (lambda () (thunk) #f)))
(def (timed backend round phase thunk)
  (let* ((start (real-time)) (result (thunk)) (seconds (- (real-time) start)))
    (displayln "NIX-API-TIMING " backend " round=" round
               " phase=" phase " seconds=" seconds)
    ;; Flush actual completed work; a stalled call still hits the idle limit.
    (force-output)
    result))

(.def AwsOnly
  provider: (.o aws: (list (.o region: "us-east-1")))
  resource: (.o aws_security_group: (.o web: (.o name: "web"))))
(.def (AwsNull @ AwsOnly)
  provider: =>.+ (.o null: (list (.o)))
  resource: =>.+ (.o null_resource: (.o smoke: (.o triggers: (.o release: "smoke")))))
(def (demand candidate)
  ;; Existing object layer, not a hand-maintained provider list.
  (json->string
    (hash (providers (list->vector
                      (.get (.call OpenTofuScope. .build-inputs candidate) providers))))))
(def read-options
  (JSONReadOptions key-as-symbol: #t object-as-hash: #t array-as-vector: #t))
(def (field json name) (hash-ref (string->json json read-options) name))
(def (admit candidate evaluated)
  ;; Same generated Contracts and lazy artifact reader as the current CLI route.
  (.def (Module @ OpenTofuScope.)
    config: =>.+ (.o artifact: (field evaluated 'output)))
  (let (evidence (.call (.get Module types configuration) .admit candidate #f))
    (assert 'real-provider-contract-admitted (yuanxu-validation-evidence-accepted? evidence))
    ;; Merely binding the unused catalog must not force awscc.
    (assert 'awscc-not-selected (not (.has? (.get Module modules) awscc)))
    evidence))

(def (provider-environment directory (package-set #f))
  (string-append
    (if package-set
      (string-append "let pkgs = import " package-set " {}; ")
      (string-append "let source = import " (path-expand "t/fixtures/nixpkgs.nix" root)
                     "; pkgs = import source.outPath {}; "))
    "catalog = import " (path-expand "t/fixtures/opentofu/family-schemas.nix" root)
    " { inherit pkgs; }; "
    "schemas = catalog // { awscc = throw \"unselected awscc forced\"; }; "
    "makePackage = selection: pkgs.callPackage "
    (path-expand "modules/services/opentofu/nix/provider-artifacts.nix" root)
    " { inherit schemas selection; }; "
    "receipt = selection: package: builtins.toJSON { "
    "derivation = package.drvPath; output = package.outPath; "
    "providers = selection.providers; version = builtins.nixVersion; "
    "stamp = import " (path-expand "stamp.nix" directory) "; }; "))

(def (provider-expression directory)
  (string-append (provider-environment directory)
    "in input: let selection = builtins.fromJSON input; "
    "in receipt selection (makePackage selection)"))

;; Both exports share the exact same environment, constructor and receipt.
;; WHNF probes are explicit force points, not a claim to exhaust lazy imports.
(def (provider-exports directory (package-set #f))
  (string-append (provider-environment directory package-set)
    "in { providerArtifacts = input: let selection = builtins.fromJSON input; "
    "in receipt selection (makePackage selection); "
    "diagnostic = input: let selection = builtins.fromJSON input; "
    "package = makePackage selection; in { "
    (if package-set "" "source = builtins.toString source.outPath; ")
    "imports = builtins.seq pkgs.callPackage (builtins.seq schemas \"ready\"); "
    "package = builtins.seq package \"ready\"; "
    "receipt = receipt selection package; }; }"))

;; This bounded expression fixture has an explicit complete import closure.
;; Reuse the production currentness checker; do not claim automatic FFI input
;; discovery or flake fingerprint support from this experiment.
(def (observe-inputs directory)
  (map (lambda (path) (cons path (module-source-read path)))
    (cons (path-expand "stamp.nix" directory)
      (map (cut path-expand <> root)
        '("t/fixtures/nixpkgs.nix"
          "t/fixtures/opentofu/family-schemas.nix"
          "t/fixtures/opentofu/hashicorp-package.nix"
          "t/fixtures/opentofu/aws-5.100.0/package.nix"
          "modules/services/opentofu/nix/provider-schema.nix"
          "modules/services/opentofu/nix/provider-artifacts.nix")))))
(def (checked-query observations query)
  (module-source-admit-current! observations)
  (let (result (query))
    (module-source-admit-current! observations)
    result))

(def (nix-api-suite call-with-nix-session session-query session-calls)
  (test-suite "Installed Gerbil / matched Nix C API and CLI"
    (test-case "minimum-version compatibility, not equality with the receipt version"
      (assert 'older-version-refused (not (supported-version? "2.33.99")))
      (assert 'minimum-version-accepted (supported-version? "2.34"))
      (assert 'zero-patch-accepted (supported-version? "2.34.0"))
      (assert 'patch-does-not-set-floor (supported-version? "2.34.3"))
      (assert 'newer-patch-accepted (supported-version? "2.34.5"))
      (assert 'newer-minor-accepted (supported-version? "2.35.0"))
      (assert 'newer-major-accepted (supported-version? "3.0.0"))
      (assert 'not-lexicographic (not (supported-version? "2.9.99")))
      (assert 'malformed-version-refused (not (supported-version? "unknown")))
      (assert 'cli-minimum-supported (supported-version? (getenv "AGENTIC_AI_LAB_NIX_C_API_CLI_VERSION"))))
    (test-case "simple evaluator initialization before provider work"
      (displayln "NIX-API-PHASE before-simple-session") (force-output)
      (call-with-temporary-directory "agentic-ai-lab-nix-api-init"
        (lambda (directory)
          (call-with-nix-session "input: builtins.nixVersion" directory
            (lambda (session)
              (assert 'simple-c-api-version
                (supported-version? (session-query session "")))))))
      (displayln "NIX-API-PHASE after-simple-session") (force-output))
    (test-case "three rounds: real AWS then Null, shared evaluator and receiver isolation"
      (call-with-temporary-directory "agentic-ai-lab-nix-api"
        (lambda (directory)
          (write-input (path-expand "stamp.nix" directory) "1")
          (def expression (provider-expression directory))
          (def observations (observe-inputs directory))
          (def aws (demand AwsOnly))
          (def aws-null (demand AwsNull))
          (def (cli input (registration? #f))
            (checked-query observations
              (lambda () (native-cli (string-append "(" expression ") " (json->string input)) registration?))))
          (def (measure-cli number)
            (let* ((parent (timed 'cli number 'aws-cold (cut cli aws)))
                   (parent-hot (timed 'cli number 'aws-hot (cut cli aws)))
                   (child (timed 'cli number 'null-cold (cut cli aws-null)))
                   (child-hot (timed 'cli number 'null-hot (cut cli aws-null))))
              (assert 'cli-aws-hot-equal (equal? parent parent-hot))
              (assert 'cli-null-hot-equal (equal? child child-hot))
              (cons parent child)))
          (def (round number)
            (displayln "NIX-API-PHASE round=" number) (force-output)
            ;; Alternate backend order without clearing shared Nix/OS caches.
            (def early-cli (and (even? number) (measure-cli number)))
            (def started (real-time))
            (call-with-nix-session expression directory
              (lambda (session)
                (displayln "NIX-API-TIMING c-api round=" number
                           " phase=session-open seconds=" (- (real-time) started))
                (force-output)
                (def (query input)
                  (checked-query observations (lambda () (session-query session input))))
                (.def (Parent receiver [])
                  candidate: AwsOnly
                  plan: (query (demand candidate))
                  .preview: (lambda ()
                              (checked-query observations (lambda () plan))))
                ;; Time identical backend boundaries; test the extra POO plan
                ;; projections separately rather than charging only C for them.
                (def parent (timed 'c-api number 'aws-cold (cut query aws)))
                (assert 'c-api-warm-equal
                  (equal? parent (timed 'c-api number 'aws-hot (cut query aws))))
                (assert 'parent-plan-matches-backend (equal? (.call Parent .preview) parent))
                ;; A cached POO plan must not become a shared child result.
                (.def (Child @ Parent) candidate: AwsNull)
                (def child (timed 'c-api number 'null-cold (cut query aws-null)))
                (assert 'c-api-null-hot-equal
                  (equal? child (timed 'c-api number 'null-hot (cut query aws-null))))
                (assert 'child-plan-matches-backend (equal? (.call Child .preview) child))
                (assert 'six-calls-including-two-plan-projections (= (session-calls session) 6))
                (assert 'parent-cache-isolated (equal? (.call Parent .preview) parent))
                (assert 'child-adds-null (equal? (field child 'providers) '#("aws" "null")))
                (assert 'parent-keeps-aws (equal? (field parent 'providers) '#("aws")))
                (assert 'derivation-changes
                  (not (equal? (field parent 'derivation) (field child 'derivation))))
                (def cli-values (or early-cli (measure-cli number)))
                (def cli-parent (car cli-values))
                (def cli-child (cdr cli-values))
                (assert 'matched-parent-result (equal? parent cli-parent))
                (assert 'matched-child-result (equal? child cli-child))
                (assert 'registration-mode-preserves-result
                  (equal? parent
                    (timed 'cli number 'aws-registration
                      (lambda () (cli aws #t)))))
                (assert 'c-api-minimum-supported (supported-version? (field child 'version)))
                (assert 'matched-cli-and-c-api-version
                  (equal? (field child 'version) (getenv "AGENTIC_AI_LAB_NIX_C_API_CLI_VERSION")))
                (admit AwsOnly parent)
                (admit AwsNull child)
                (displayln "NIX-API-COUNTS round=" number
                           " sessions=1 parses=1 measured-api-calls=4 total-api-calls=" (session-calls session)
                           " cli-readonly-evaluations=4 cli-registration-evaluations=1")
                ;; Measure the actual evaluator hazard, then verify the unchanged
                ;; production source guard rejects it even on a warm POO slot.
                (when (= number 3)
                  (write-input (path-expand "stamp.nix" directory) "2")
                  (assert 'unguarded-evaluator-import-is-stale
                    (= (field (session-query session aws) 'stamp) 1))
                  (assert 'warm-parent-source-change-refused
                    (rejected? (lambda () (.call Parent .preview))))
                  (assert 'child-source-change-refused
                    (rejected? (cut query aws-null)))
                  (assert 'cli-source-change-refused (rejected? (cut cli aws-null)))
                  (assert 'native-guard-fails-before-api (= (session-calls session) 7))
                  (call-with-nix-session expression directory
                    (lambda (fresh)
                      (assert 'new-session-reads-new-source
                        (= (field (session-query fresh aws) 'stamp) 2))))))))
          (round 1)
          (round 2)
          (round 3)
          (assert 'fifteen-cli-evaluations-including-three-registration-controls (= cli-calls 15)))))))
