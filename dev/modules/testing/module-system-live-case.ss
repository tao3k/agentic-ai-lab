;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: upstream test framework for downstream module-system live cases.
;;; Invariant: concrete cases stay under user-interface; this file only runs them.

(import (only-in :gerbil/core getenv)
        (only-in :clan/poo/object make-object)
        (only-in :std/test test-suite test-case check-equal?)
        (only-in :std/misc/process run-process)
        "./module-system-live-case-object"
        (only-in :agentic-ai-lab/modules/agent-sandbox/api
                 agent-sandbox-profile-backend-kind
                 agent-sandbox-profile-metadata
                 agent-sandbox-profile-network-policy
                 agent-sandbox-request
                 agent-sandbox-request->runtime-manifest
                 args
                 capabilities
                 command
                 metadata
                 mounts
                 resource-policy
                 workdir)
        (only-in :agentic-ai-lab/modules/agent-sandbox/config
                 agentic-ai-lab-sandbox-profile->profile)
        (only-in :agentic-ai-lab/modules/nono-sandbox/c-binding-runtime
                 +nono-c-binding-live-test-receipt-schema+
                 nono-c-binding-dry-run
                 nono-c-binding-live-test))

(export (import: "./module-system-live-case-object")
        agentic-ai-lab-module-system-live-case-profile
        agentic-ai-lab-module-system-live-case-command
        agentic-ai-lab-module-system-live-case-request
        agentic-ai-lab-module-system-live-case-planned-workspace
        agentic-ai-lab-module-system-live-case-stage-project-copy
        agentic-ai-lab-module-system-live-case-runtime-manifest
        agentic-ai-lab-module-system-live-case-receipt
        agentic-ai-lab-module-system-live-case-test-suite)

;;; Host probes are best-effort support for building the nono command. A failed
;;; probe returns an explicit default instead of changing the case semantics.
;; : (-> [String] String String)
(def (agentic-ai-lab-module-system-live-case-host-command-output command default)
  (let (output-or-failure
        (with-catch
         (lambda (_) #f)
         (lambda ()
           (run-process command stderr-redirection: #t))))
    (if (string? output-or-failure)
      output-or-failure
      default)))

;;; Boundary: module system live case host platform is the policy-visible edge
;;; for module-system, test harness behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> Unit Symbol)
(def (agentic-ai-lab-module-system-live-case-host-platform)
  (let (output
        (agentic-ai-lab-module-system-live-case-host-command-output
         '("sh" "-c" "uname -s | tr -d '\\n'")
         ""))
    (if (string=? output "Darwin") 'macos 'unsupported)))

;; : (-> MaybeString Boolean)
(def (agentic-ai-lab-module-system-live-case-non-empty-string? value)
  (and (string? value)
       (> (string-length value) 0)))

;;; Boundary: module system live case path join is the policy-visible edge for
;;; module-system, test harness behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> String String String)
(def (agentic-ai-lab-module-system-live-case-path-join left right)
  (cond
   ((not (agentic-ai-lab-module-system-live-case-non-empty-string? left)) right)
   ((not (agentic-ai-lab-module-system-live-case-non-empty-string? right)) left)
   ((char=? (string-ref left (- (string-length left) 1)) #\/)
    (string-append left right))
   (else
    (string-append left "/" right))))

;;; Workspace roots are data, not framework policy. The framework only supplies a
;;; safe fallback shape when the downstream case omits optional path fields.
;; : (-> POOObject String)
(def (agentic-ai-lab-module-system-live-case-root-path live-case)
  (let* ((root-env
          (agentic-ai-lab-module-system-live-case-section-ref
           live-case
           'isolation
           'root-env
           "TMPDIR"))
         (base
          (if (string? root-env)
            (getenv root-env "/tmp")
            "/tmp"))
         (root
          (agentic-ai-lab-module-system-live-case-section-ref
           live-case
           'isolation
           'root
           (string-append
            "agentic-ai-lab-live-case/"
            (symbol->string
             (agentic-ai-lab-module-system-live-case-name live-case))))))
    (agentic-ai-lab-module-system-live-case-path-join base root)))

;; : (-> POOObject String)
(def (agentic-ai-lab-module-system-live-case-planned-workspace live-case)
  (agentic-ai-lab-module-system-live-case-path-join
   (agentic-ai-lab-module-system-live-case-root-path live-case)
   (agentic-ai-lab-module-system-live-case-section-ref
    live-case
    'isolation
    'workspace
    "workspace")))

;; : (-> POOObject String)
(def (agentic-ai-lab-module-system-live-case-home-path live-case)
  (agentic-ai-lab-module-system-live-case-path-join
   (agentic-ai-lab-module-system-live-case-planned-workspace live-case)
   (agentic-ai-lab-module-system-live-case-section-ref
    live-case
    'isolation
    'home
    ".home")))

;;; This quote helper is only used for framework-assembled literals. The user
;;; case contributes structured fields, not shell fragments.
;; : (-> ShellLiteral ShellQuotedLiteral)
(def (agentic-ai-lab-module-system-live-case-shell-quote value)
  (string-append "'" value "'"))

;;; Boundary: module system live case shell join is the policy-visible edge for
;;; module-system, test harness behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> [ShellLiteral] ShellCommandFragment)
(def (agentic-ai-lab-module-system-live-case-shell-join values)
  (cond
   ((null? values) "")
   ((null? (cdr values))
    (agentic-ai-lab-module-system-live-case-shell-quote (car values)))
   (else
    (string-append
     (agentic-ai-lab-module-system-live-case-shell-quote (car values))
     " "
     (agentic-ai-lab-module-system-live-case-shell-join (cdr values))))))

;;; Boundary: module system live case env clear join is the policy-visible edge
;;; for module-system, test harness behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> [EnvironmentVariableName] ShellCommandFragment)
(def (agentic-ai-lab-module-system-live-case-env-clear-join keys)
  (cond
   ((null? keys) "")
   ((null? (cdr keys))
    (string-append (car keys) "="))
   (else
    (string-append
     (car keys)
     "= "
     (agentic-ai-lab-module-system-live-case-env-clear-join (cdr keys))))))

;;; Boundary: module system live case rsync exclude join is the policy-visible
;;; edge for module-system, test harness behavior, keeping validation, lookup,
;;; or projection responsibilities centralized for callers.
;; : (-> [RsyncExcludePattern] ShellCommandFragment)
(def (agentic-ai-lab-module-system-live-case-rsync-exclude-join values)
  (cond
   ((null? values) "")
   (else
    (string-append
     " --exclude "
     (agentic-ai-lab-module-system-live-case-shell-quote (car values))
     (agentic-ai-lab-module-system-live-case-rsync-exclude-join (cdr values))))))

;;; Staging is framework-owned, but every concrete path and exclude rule is read
;;; from the downstream case object. This keeps src/testing generic while still
;;; proving the project is copied before sandbox execution.
;; : (-> POOObject MaybeWorkspacePath)
(def (agentic-ai-lab-module-system-live-case-stage-project-copy live-case)
  (let* ((root (agentic-ai-lab-module-system-live-case-root-path live-case))
         (workspace (agentic-ai-lab-module-system-live-case-planned-workspace
                     live-case))
         (home (agentic-ai-lab-module-system-live-case-home-path live-case))
         (source
          (agentic-ai-lab-module-system-live-case-section-ref
           live-case
           'isolation
           'source
           "."))
         (exclude
          (agentic-ai-lab-module-system-live-case-section-ref
           live-case
           'isolation
           'exclude
           '()))
         (command-string
          (string-append
           "set -eu; rm -rf "
           (agentic-ai-lab-module-system-live-case-shell-quote root)
           "; mkdir -p "
           (agentic-ai-lab-module-system-live-case-shell-quote workspace)
           "; rsync -a --delete"
           (agentic-ai-lab-module-system-live-case-rsync-exclude-join exclude)
           " "
           (agentic-ai-lab-module-system-live-case-shell-quote source)
           "/ "
           (agentic-ai-lab-module-system-live-case-shell-quote workspace)
           "/; mkdir -p "
           (agentic-ai-lab-module-system-live-case-shell-quote home)
           "; printf %s "
           (agentic-ai-lab-module-system-live-case-shell-quote workspace))))
    (let (workspace-or-failure
          (with-catch
           (lambda (_) #f)
           (lambda ()
             (run-process
              (list "sh" "-lc" command-string)
              stderr-redirection: #t))))
      (if (string? workspace-or-failure) workspace-or-failure #f))))

;; : (-> Unit String)
(def (agentic-ai-lab-module-system-live-case-gxpkg-wrapper-dir)
  (agentic-ai-lab-module-system-live-case-host-command-output
   '("sh" "-lc"
     "p=$(command -v gxpkg 2>/dev/null) && d=$(dirname \"$p\") && printf %s \"$d\"")
   "/usr/local/bin"))

;; : (-> Unit String)
(def (agentic-ai-lab-module-system-live-case-gxpkg-path)
  (agentic-ai-lab-module-system-live-case-host-command-output
   '("sh" "-lc"
     "p=$(command -v gxpkg 2>/dev/null) && printf %s \"$p\"")
   "gxpkg"))

;;; gxpkg may be a wrapper script; nono needs read access to the resolved Gerbil
;;; tree as well as the wrapper directory that launches it.
;; : (-> Unit String)
(def (agentic-ai-lab-module-system-live-case-gerbil-toolchain-dir)
  (agentic-ai-lab-module-system-live-case-host-command-output
   '("sh" "-lc"
     "p=$(command -v gxpkg 2>/dev/null); real=$(awk '/^exec / {print $2; exit}' \"$p\" 2>/dev/null); real=${real#\\\"}; real=${real%\\\"}; case \"$real\" in */.data/gerbil/*) printf %s \"${real%%/.data/gerbil/*}/.data/gerbil\" ;; *) d=$(dirname \"$(dirname \"$real\")\"); printf %s \"$d\" ;; esac")
   #f))

;; : (-> Unit String)
(def (agentic-ai-lab-module-system-live-case-git-config-dir)
  (agentic-ai-lab-module-system-live-case-host-command-output
   '("sh" "-lc"
     "d=${XDG_CONFIG_HOME:-$HOME/.config}/git; if [ -e \"$d\" ]; then printf %s \"$d\"; fi")
   #f))

;; : (-> Unit String)
(def (agentic-ai-lab-module-system-live-case-build-path)
  (agentic-ai-lab-module-system-live-case-host-command-output
   '("sh" "-lc"
     "printf %s /usr/bin:/bin:/usr/sbin:/sbin:$(dirname \"$(command -v gxpkg 2>/dev/null || printf /usr/bin/gxpkg)\")")
   "/usr/bin:/bin:/usr/sbin:/sbin"))

;;; Command program resolution is intentionally narrow. The framework knows how
;;; to locate gxpkg; other programs must be explicit declaration literals.
;; : (-> POOObject String)
(def (agentic-ai-lab-module-system-live-case-command-program live-case)
  (let (program
        (agentic-ai-lab-module-system-live-case-section-ref
         live-case
         'command
         'program
         "gxpkg"))
    (if (string=? program "gxpkg")
      (agentic-ai-lab-module-system-live-case-gxpkg-path)
      program)))

;;; The build script intentionally uses env -i. The downstream case chooses
;;; which variables to clear, while the framework supplies a small toolchain
;;; PATH so the sandbox cannot inherit the caller's ambient environment.
;; : (-> POOObject String String)
(def (agentic-ai-lab-module-system-live-case-build-script live-case workspace)
  (let* ((program
          (agentic-ai-lab-module-system-live-case-command-program live-case))
         (program-args
          (agentic-ai-lab-module-system-live-case-section-ref
           live-case
           'command
           'args
           '()))
         (clear-env
          (agentic-ai-lab-module-system-live-case-section-ref
           live-case
           'environment
           'clear-env
           '()))
         (home
          (agentic-ai-lab-module-system-live-case-home-path live-case)))
    (string-append
     "AGENTIC_AI_LAB_ISOLATED_WORKSPACE="
     (agentic-ai-lab-module-system-live-case-shell-quote workspace)
     "; export AGENTIC_AI_LAB_ISOLATED_WORKSPACE; "
     "cd \"$AGENTIC_AI_LAB_ISOLATED_WORKSPACE\" && "
     "env -i HOME="
     (agentic-ai-lab-module-system-live-case-shell-quote home)
     " PATH="
     (agentic-ai-lab-module-system-live-case-shell-quote
      (agentic-ai-lab-module-system-live-case-build-path))
     " "
     (agentic-ai-lab-module-system-live-case-env-clear-join clear-env)
     " "
     (agentic-ai-lab-module-system-live-case-shell-quote program)
     " "
     (agentic-ai-lab-module-system-live-case-shell-join program-args))))

;;; Boundary: module system live case read args is the policy-visible edge for
;;; module-system, test harness behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> [String] [String] [String])
(def (agentic-ai-lab-module-system-live-case-read-args/rev paths args-rev)
  (cond
   ((null? paths) (reverse args-rev))
   ((agentic-ai-lab-module-system-live-case-non-empty-string? (car paths))
    (agentic-ai-lab-module-system-live-case-read-args/rev
     (cdr paths)
     (cons (car paths)
           (cons "--read" args-rev))))
   (else
    (agentic-ai-lab-module-system-live-case-read-args/rev (cdr paths) args-rev))))

;; : (-> [String] [String])
(def (agentic-ai-lab-module-system-live-case-read-args paths)
  (agentic-ai-lab-module-system-live-case-read-args/rev paths '()))

;; : (-> POOObject [String])
(def (agentic-ai-lab-module-system-live-case-read-paths live-case)
  (append
   (list (agentic-ai-lab-module-system-live-case-gxpkg-wrapper-dir)
         (agentic-ai-lab-module-system-live-case-gerbil-toolchain-dir)
         (agentic-ai-lab-module-system-live-case-git-config-dir))
   (agentic-ai-lab-module-system-live-case-section-ref
    live-case
    'nono
    'read-paths
    '())))

;;; Boundary: module system live case network args is the policy-visible edge
;;; for module-system, test harness behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> POOObject [String])
(def (agentic-ai-lab-module-system-live-case-network-args live-case)
  (case (agentic-ai-lab-module-system-live-case-section-ref
         live-case
         'nono
         'network
         'blocked)
    ((blocked block deny)
     '("--block-net"))
    (else '())))

;;; Boundary: module system live case audit args is the policy-visible edge for
;;; module-system, test harness behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> POOObject [String])
(def (agentic-ai-lab-module-system-live-case-audit-args live-case)
  (case (agentic-ai-lab-module-system-live-case-section-ref
         live-case
         'nono
         'audit
         'disabled)
    ((disabled off)
     '("--no-audit"))
    (else '())))

;;; nono receives only the isolated workspace as writable state; toolchain and
;;; git config paths are read-only support paths needed by package builds.
;; : (-> POOObject String [String])
(def (agentic-ai-lab-module-system-live-case-nono-run-command live-case workspace)
  (append
   '("nono" "run" "--silent")
   (list "--allow" workspace)
   (agentic-ai-lab-module-system-live-case-read-args
    (agentic-ai-lab-module-system-live-case-read-paths live-case))
   (agentic-ai-lab-module-system-live-case-network-args live-case)
   (agentic-ai-lab-module-system-live-case-audit-args live-case)
   '("--" "sh" "-lc")
   (list (agentic-ai-lab-module-system-live-case-build-script live-case
                                                         workspace))))

;;; The outer command is shell-shaped because nono is still a process boundary.
;;; The user case contributes only structured command fields, never raw shell.
;; : (-> POOObject String [String])
(def (agentic-ai-lab-module-system-live-case-command live-case workspace)
  (list
   "sh"
   "-lc"
   (string-append
    "cd "
    (agentic-ai-lab-module-system-live-case-shell-quote workspace)
    " && exec "
    (agentic-ai-lab-module-system-live-case-shell-join
     (agentic-ai-lab-module-system-live-case-nono-run-command live-case
                                                         workspace)))))

;;; `:inherits` is the POO supers list. Build a profile-only view so the live
;;; case's own kind/name metadata cannot shadow the sandbox profile contract.
;; : (-> POOObject AgentSandboxProfile)
(def (agentic-ai-lab-module-system-live-case-profile live-case)
  (agentic-ai-lab-sandbox-profile->profile
   (make-object
    supers: (agentic-ai-lab-module-system-live-case-supers live-case)
    slots: '())))

;;; Profile declarations use user-facing network rows such as
;;; `(allowlisted "github.com")`; runtime manifests need the alist form consumed
;;; by backend validators. This is a projection of inherited profile policy, not
;;; a case-local policy declaration.
;; : (-> POOObject AgentSandboxProfile NetworkPolicy)
(def (agentic-ai-lab-module-system-live-case-runtime-network-policy live-case profile)
  (let (policy (agentic-ai-lab-module-system-live-case-section-ref
                live-case
                'nono
                'network-policy
                (agentic-ai-lab-module-system-live-case-section-ref
                 live-case
                 'nono
                 'network
                 (agent-sandbox-profile-network-policy profile))))
    (cond
     ((null? policy) '())
     ((and (pair? policy) (pair? (car policy))) policy)
     ((pair? policy) (list (cons 'mode (car policy))))
     ((symbol? policy) (list (cons 'mode policy)))
     (else '()))))

;;; Cases inherit their selected sandbox profiles through POO supers. The case
;;; contributes runtime fields and narrow request overrides only.
;; : (-> POOObject String AgentSandboxRequest)
(def (agentic-ai-lab-module-system-live-case-request live-case workspace)
  (let ((profile
         (agentic-ai-lab-module-system-live-case-profile live-case)))
    (agent-sandbox-request
     profile
     (command "sh")
     (args (list "-lc"
                 (agentic-ai-lab-module-system-live-case-build-script live-case
                                                                 workspace)))
     (workdir workspace)
     (mounts (list (list (cons 'path workspace)
                         (cons 'kind 'directory)
                         (cons 'mode 'read-write)
                         (cons 'purpose 'isolated-project-workspace))))
     (network-policy
      (agentic-ai-lab-module-system-live-case-runtime-network-policy live-case
                                                               profile))
     (capabilities '((allow-commands . ("sh" "gxpkg"))))
     (resource-policy '((timeout-ms . 600000)))
     (metadata (list (cons 'check 'module-system-live-case)
                     (cons 'case
                           (agentic-ai-lab-module-system-live-case-name
                            live-case))
                     (cons 'supers
                           (agentic-ai-lab-module-system-live-case-super-names
                            live-case))
                     (cons 'project-isolated? #t)
                     (cons 'host-project-mounted? #f)
                     (cons 'environment-policy
                           (agentic-ai-lab-module-system-live-case-section-ref
                            live-case
                            'environment
                            'policy
                            'whitelist))
                     (cons 'workspace workspace))))))

;;; The manifest mirrors the command receipt. It is intentionally reportable
;;; before execution so failing live cases still expose isolation facts.
;; : (-> POOObject String AgentSandboxRuntimeManifest)
(def (agentic-ai-lab-module-system-live-case-runtime-manifest live-case workspace)
  (agent-sandbox-request->runtime-manifest
   (agentic-ai-lab-module-system-live-case-request live-case workspace)))

;;; Live cases are opt-in. The default test path proves declaration and receipt
;;; shape without performing a real sandbox build.
;; : (-> POOObject Boolean)
(def (agentic-ai-lab-module-system-live-case-enabled? live-case)
  (let (env-name
        (agentic-ai-lab-module-system-live-case-section-ref
         live-case
         'environment
         'enabled-env
         #f))
    (and (string? env-name)
         (string=? (getenv env-name "") "1"))))

;; : (-> POOObject String LiveCaseReceiptFacts)
(def (agentic-ai-lab-module-system-live-case-isolation-facts live-case workspace)
  (list (cons 'case
              (agentic-ai-lab-module-system-live-case-name live-case))
        (cons 'project-isolated? #t)
        (cons 'host-project-mounted? #f)
        (cons 'environment-policy
              (agentic-ai-lab-module-system-live-case-section-ref
               live-case
               'environment
               'policy
               'whitelist))
        (cons 'workspace workspace)))

;;; Skipped receipts keep the same schema as live receipts so CI and agents can
;;; inspect disabled/non-macOS/missing-tool states without special casing.
;; : (-> POOObject AgentSandboxRuntimeManifest [String] Symbol String LiveCaseReceipt)
(def (agentic-ai-lab-module-system-live-case-skip-receipt live-case
                                                     runtime-manifest
                                                     command-value
                                                     reason
                                                     workspace)
  (append
   (list (cons 'schema +nono-c-binding-live-test-receipt-schema+)
         (cons 'ok? #t)
         (cons 'enabled? #f)
         (cons 'skipped? #t)
         (cons 'skip-reason reason)
         (cons 'command command-value)
         (cons 'live-executed #f)
         (cons 'runtime-executed #f)
         (cons 'would-apply? #f)
         (cons 'dry-run (nono-c-binding-dry-run runtime-manifest)))
   (agentic-ai-lab-module-system-live-case-isolation-facts live-case workspace)))

;; : (-> POOObject LiveCaseReceipt String LiveCaseReceipt)
(def (agentic-ai-lab-module-system-live-case-receipt-with-isolation live-case
                                                               receipt
                                                               workspace)
  (append receipt
          (agentic-ai-lab-module-system-live-case-isolation-facts live-case
                                                            workspace)))

;;; Receipts are the observability boundary for live cases: disabled, skipped,
;;; staging-failed, and executed cases all return the same inspection shape.
;; : (-> POOObject LiveCaseReceipt)
(def (agentic-ai-lab-module-system-live-case-receipt live-case)
  (let* ((planned-workspace
          (agentic-ai-lab-module-system-live-case-planned-workspace live-case))
         (planned-command
          (agentic-ai-lab-module-system-live-case-command live-case
                                                     planned-workspace))
         (runtime-manifest
          (agentic-ai-lab-module-system-live-case-runtime-manifest
           live-case
           planned-workspace)))
    (cond
     ((not (agentic-ai-lab-module-system-live-case-enabled? live-case))
      (agentic-ai-lab-module-system-live-case-skip-receipt
       live-case
       runtime-manifest
       planned-command
       'live-case-disabled
       planned-workspace))
     ((not (eq? (agentic-ai-lab-module-system-live-case-host-platform) 'macos))
      (agentic-ai-lab-module-system-live-case-skip-receipt
       live-case
       runtime-manifest
       planned-command
       'non-macos-host
       planned-workspace))
     (else
      (let (workspace
            (agentic-ai-lab-module-system-live-case-stage-project-copy live-case))
        (if workspace
          (let ((command-value
                 (agentic-ai-lab-module-system-live-case-command live-case
                                                            workspace))
                (manifest
                 (agentic-ai-lab-module-system-live-case-runtime-manifest
                  live-case
                  workspace)))
            (agentic-ai-lab-module-system-live-case-receipt-with-isolation
             live-case
             (nono-c-binding-live-test manifest command-value)
             workspace))
          (agentic-ai-lab-module-system-live-case-skip-receipt
           live-case
           runtime-manifest
           planned-command
           'project-copy-failed
           planned-workspace)))))))

;;; The suite checks the separation of concerns first, then runs the case
;;; through the generic framework. Profile metadata must stay free of live-case
;;; path and command decisions.
;; : (-> POOObject TestSuite)
(def (agentic-ai-lab-module-system-live-case-test-suite live-case)
  (test-suite "agentic-ai-lab module-system live case"
    (test-case "case is declared as a downstream module-system case"
      (let* ((profile
              (agentic-ai-lab-module-system-live-case-profile live-case))
             (metadata-value
              (agent-sandbox-profile-metadata profile)))
        (check-equal? (agentic-ai-lab-module-system-live-case? live-case) #t)
        (check-equal? (agent-sandbox-profile-backend-kind profile) 'nono)
        (check-equal? (agentic-ai-lab-module-system-live-case-super-names live-case)
                      '(ci/build))
        (check-equal? (agentic-ai-lab-module-system-live-case-alist-ref
                       metadata-value
                       'live-case
                       #f)
                      #f)
        (check-equal? (agentic-ai-lab-module-system-live-case-section-ref
                       live-case
                       'isolation
                       'mode
                       #f)
                      'project-copy)
        (check-equal? (agentic-ai-lab-module-system-live-case-section-ref
                       live-case
                       'isolation
                       'project-mount
                       #f)
                      'isolated-copy)
        (check-equal? (agentic-ai-lab-module-system-live-case-section-ref
                       live-case
                       'environment
                       'policy
                       #f)
                      'whitelist)
        (check-equal? (agentic-ai-lab-module-system-live-case-section-ref
                       live-case
                       'command
                       'program
                       #f)
                      "gxpkg")
        (check-equal? (agentic-ai-lab-module-system-live-case-section-ref
                       live-case
                       'command
                       'args
                       #f)
                      '("build"))))
    (test-case "framework starts the module-system case"
      (let ((receipt
             (agentic-ai-lab-module-system-live-case-receipt live-case)))
        (check-equal? (agentic-ai-lab-module-system-live-case-alist-ref
                       receipt
                       'schema
                       #f)
                      +nono-c-binding-live-test-receipt-schema+)
        (check-equal? (agentic-ai-lab-module-system-live-case-alist-ref
                       receipt
                       'ok?
                       #f)
                      #t)
        (check-equal? (agentic-ai-lab-module-system-live-case-alist-ref
                       receipt
                       'case
                       #f)
                      (agentic-ai-lab-module-system-live-case-name live-case))
        (check-equal? (agentic-ai-lab-module-system-live-case-alist-ref
                       receipt
                       'runtime-executed
                       #t)
                      #f)
        (check-equal? (agentic-ai-lab-module-system-live-case-alist-ref
                       receipt
                       'would-apply?
                       #t)
                      #f)
        (check-equal? (agentic-ai-lab-module-system-live-case-alist-ref
                       receipt
                       'project-isolated?
                       #f)
                      #t)
        (check-equal? (agentic-ai-lab-module-system-live-case-alist-ref
                       receipt
                       'host-project-mounted?
                       #t)
                      #f)
        (check-equal? (agentic-ai-lab-module-system-live-case-alist-ref
                       receipt
                       'environment-policy
                       #f)
                      'whitelist)
        (check-equal? (member "." (agentic-ai-lab-module-system-live-case-alist-ref
                                   receipt
                                   'command
                                   '()))
                      #f)
        (if (agentic-ai-lab-module-system-live-case-alist-ref
             receipt
             'enabled?
             #f)
          (begin
            (check-equal? (agentic-ai-lab-module-system-live-case-alist-ref
                           receipt
                           'skipped?
                           #t)
                          #f)
            (check-equal? (agentic-ai-lab-module-system-live-case-alist-ref
                           receipt
                           'status
                           1)
                          0))
          (begin
            (check-equal? (agentic-ai-lab-module-system-live-case-alist-ref
                           receipt
                           'skipped?
                           #f)
                          #t)
            (check-equal? (and (memq
                                (agentic-ai-lab-module-system-live-case-alist-ref
                                 receipt
                                 'skip-reason
                                 #f)
                                '(live-case-disabled
                                  non-macos-host
                                  nono-not-found-on-path
                                  project-copy-failed))
                               #t)
                          #t)))))))
