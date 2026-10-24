;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Real Nix provider publications -> Core admission -> local Null execution.
(import :std/test :clan/poo/object
        (only-in :std/source this-source-file)
        (only-in :std/io/tempfile make-temporary-file-name)
        (only-in :agentic-ai-lab/modules/services/opentofu/execution opentofu-execution)
        (only-in :std/text/pregexp pregexp-match)
        (only-in :std/encoding/json read-json)
        (only-in :std/list/walist waref)
        (only-in :std/misc/ports read-all-as-string)
        (only-in :yuanxu/object-types/contracts yuanxu-validation-evidence-accepted?)
        (only-in :yuanxu/module-system/source/link yuanxu-load-modules)
        (only-in :yuanxu/module-system/source/admission module-source-read)
        (only-in :yuanxu/ops/objects ProcessScript.))
(export opentofu-admission-execution-test test-cleanup!)

(def completed #f)
(def (test-cleanup!)
  (unless completed (error "real provider admission/execution did not complete"))
  (displayln "OPENTOFU-ADMISSION-EXECUTION: completed"))
(def Script ProcessScript.)
(def test-source (this-source-file))
(def core-root (path-expand ".." (path-directory test-source)))

(def (assert label accepted)
  (unless accepted (error "integration assertion failed" label))
  (displayln "ASSERT-OK " label) (force-output))
(def (write-text path text)
  (call-with-output-file (list path: path truncate: #t) (cut display text <>)))
(def (rejects? message thunk)
  (with-catch
    (lambda (exception)
      (pregexp-match message
        (call-with-output-string (cut display-exception exception <>))))
    (lambda () (thunk) #f)))
(def (run-step base root name args)
  (.def (step @ base)
    command: (append (.get base command) args)
    log: (path-expand (string-append name ".log") root)
    check-status: #f)
  (def result (.call step .run))
  (assert (string->symbol (string-append name "-status")) (zero? (.get result status)))
  (call-with-input-file (.get step log) read-all-as-string))
(def (output-path text)
  (or (find (cut string-prefix? "/nix/store/" <>)
        (reverse (string-split text #\newline)))
      (error "Nix did not return a store output")))

;; Copy maintained Module sources, changing only the package-realization input.
;; The real directory reader, publication admission and Graph prepare all roles.
(def (copy-module source target)
  (create-directory* target)
  (for-each (lambda (name) (copy-file (path-expand name source) (path-expand name target)))
    '("types.ss" "config.ss" "func.ss" "objects.ss" "interface.ss")))
(def (select-provider! config-file directory)
  (write-text config-file
    (call-with-output-string
      (lambda (port)
        (for-each (lambda (form) (write form port) (newline port))
          `((import :clan/poo/object) (export Config)
            (def Config (.o provider-directory: ,directory))))))))
(def (empty-state? workspace)
  (let* ((state (call-with-input-file (path-expand "terraform.tfstate" workspace) read-json))
         (resources (waref state "resources" #f)))
    (or (null? resources) (and (vector? resources) (zero? (vector-length resources))))))

(def opentofu-admission-execution-test
  (test-suite "Real provider publication and local Ops execution"
    (test-case "Null local execution and credential-free AWS backend validation"
      (def root (make-temporary-file-name "opentofu-admission-execution-"))
      (create-directory root)
      (displayln "LOCAL-ARTIFACTS " root) (force-output)
      (.def (PackageSet @ Script)
        command: '("nix-instantiate" "--find-file" "nixpkgs") timeout: 30)
      (def pkgs
        (car (string-split (.get (.call PackageSet .run) output) #\newline)))
      (.def (Packages @ Script)
        command: '("nix-build" "--no-out-link") timeout: 60)
      (def expression
        (string-append "let pkgs = import " pkgs " {}; in import "
          (path-expand "t/fixtures/opentofu/admission-packages.nix" core-root)
          " { inherit pkgs; }"))
      (def package-root (output-path (run-step Packages root "nix-packages" (list "--expr" expression))))
      (def project (path-expand "project" root))
      ;; AWS Profile admission and updates are owned by its init-selected atomic
      ;; suite. This gate owns only local execution and backend validation.
      (def null-directory (path-expand "modules/null" project))
      (def validation-directory (path-expand "modules/aws-validation" project))
      (copy-module (path-expand "scenarios/null" core-root) null-directory)
      (copy-module (path-expand "scenarios/aws-validation" core-root) validation-directory)
      (write-text (path-expand "gerbil.pkg" project)
        "(package: qualification prelude: :yuanxu/module-system/source/module-prelude)\n")
      (def init (path-expand "init.ss" project))
      (write-text init "(yuanxu! mode: explicit source: \"./modules\" (null) (aws-validation))\n")
      (select-provider! (path-expand "config.ss" null-directory) (path-expand "null" package-root))
      (select-provider! (path-expand "config.ss" validation-directory) (path-expand "child" package-root))
      (def execution-view (yuanxu-load-modules init))

      ;; Actual Scenario sources own defaults; the framework owns rendering and Ops.
      (def null-work (path-expand "null-work" root))
      (create-directory null-work)
      (def Null (opentofu-execution execution-view 'null 'Scenario))
      ;; Parent resource was demanded before the user's scalar replacement.
      (assert 'null-parent-cached
        (equal? (.get Null resource triggers message) "hello from Agentic AI Lab"))
      (assert 'null-parent-graph-cached
        (equal? (.get Null graph order) '(init validate plan apply output)))
      (.def (Hello @ Null) message: "hello from the user ${literal} %{literal}")
      (def executed (.call Hello .run null-work))
      (assert 'null-input-admitted
        (yuanxu-validation-evidence-accepted? (.get executed evidence)))
      (assert 'null-exact-effective-input
        (eq? (.get executed value resource) (.get Hello resource)))
      (assert 'local-exec-actually-ran
        (if (pregexp-match "local-exec.*hello from the user"
              (.get executed steps apply output)) #t #f))
      (assert 'null-output
        (equal? (.get executed output) "hello from the user ${literal} %{literal}"))
      (assert 'null-destroyed
        (zero? (.get executed steps destroy status)))
      (assert 'null-parent-unchanged
        (equal? (.get Null resource triggers message) "hello from Agentic AI Lab"))
      (assert 'nonempty-workspace-refused
        (rejects? "workspace must be empty" (lambda () (.call Hello .run null-work))))

      (def failed-work (path-expand "null-failed-output" root))
      (create-directory failed-work)
      (.def (FailedOutput @ Hello)
        tasks: =>.+ (.o output: =>.+ (.o arguments: '("not-an-opentofu-command"))))
      (assert 'output-failure-propagated
        (rejects? "Ops script failed" (lambda () (.call FailedOutput .run failed-work))))
      (assert 'real-null-cleanup-after-failure (empty-state? failed-work))

      ;; Fault injection only: change a real selected source after apply returns.
      ;; The maintained task still performs the actual apply through Ops.
      (def changing-view (yuanxu-load-modules init))
      (def Changing (opentofu-execution changing-view 'null 'Scenario))
      (def changed-work (path-expand "null-source-change" root))
      (create-directory changed-work)
      (def original-config (module-source-read (path-expand "modules/null/config.ss" project)))
      (def apply-task (.get Changing tasks apply))
      (def changed-tasks
        (.cc (.get Changing tasks) 'apply
          (.cc apply-task '.run
            (lambda ()
              (def applied (.call (.cc apply-task 'directory changed-work) .run))
              (write-text (path-expand "modules/null/config.ss" project)
                (string-append original-config "\n;; changed during execution\n"))
              applied))))
      (def SourceChange (.cc Changing 'tasks changed-tasks))
      (dynamic-wind void
        (lambda ()
          (assert 'source-change-blocks-next-node
            (rejects? "stale|changed|refused"
              (lambda () (.call SourceChange .run changed-work))))
          (assert 'real-null-cleanup-after-source-change (empty-state? changed-work)))
        (lambda () (write-text (path-expand "modules/null/config.ss" project) original-config)))

      (def aws-work (path-expand "aws-validation-work" root))
      (create-directory aws-work)
      (def AWSValidation
        (opentofu-execution execution-view 'aws-validation 'Scenario))
      (def Profile (.get AWSValidation profile))
      (.def (Validation @ AWSValidation) instance_type: "t3.medium")
      (.def (TypoProfile @ Profile) instance_typ: "t3.medium")
      (.def (TypoValidation @ AWSValidation) profile: TypoProfile)
      (assert 'aws-typo-refused-before-render
        (rejects? "admission refused" (lambda () (.call TypoValidation .run aws-work))))
      (assert 'aws-typo-workspace-untouched (null? (directory-files aws-work)))
      (def validated (.call Validation .run aws-work))
      (assert 'aws-validation-only
        (eq? (.get validated kind) 'configuration-validated))
      (assert 'aws-final-value
        (equal? (.get validated value resource instance_type) "t3.medium"))
      (assert 'aws-provider-validated
        (if (pregexp-match "Success!" (.get validated steps validate output)) #t #f))
      (assert 'aws-no-apply (not (.slot? (.get validated steps) 'apply)))
      (assert 'aws-no-state (not (file-exists? (path-expand "terraform.tfstate" aws-work))))
      (assert 'aws-local-apply-refused
        (rejects? "AWS example only permits" (lambda () (.call (.cc Validation 'selected '(apply)) .run aws-work))))
      (set! completed #t))))
