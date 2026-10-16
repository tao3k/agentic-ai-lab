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
        (only-in :poo-flow/modules/agent-sandbox/api
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
        (only-in :poo-flow/modules/agent-sandbox/config
                 poo-flow-sandbox-profile->profile)
        (only-in :poo-flow/modules/nono-sandbox/c-binding
                 +nono-c-binding-live-test-receipt-schema+
                 nono-c-binding-dry-run
                 nono-c-binding-live-test))

(export (import: "./module-system-live-case-object")
        poo-flow-module-system-live-case-profile
        poo-flow-module-system-live-case-command
        poo-flow-module-system-live-case-request
        poo-flow-module-system-live-case-planned-workspace
        poo-flow-module-system-live-case-stage-project-copy
        poo-flow-module-system-live-case-runtime-manifest
        poo-flow-module-system-live-case-receipt
        poo-flow-module-system-live-case-test-suite)

;;; Host probes are best-effort support for building the nono command. A failed
;;; probe returns an explicit default instead of changing the case semantics.
;; : (-> [String] String String)
(def (poo-flow-module-system-live-case-host-command-output command default)
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
(def (poo-flow-module-system-live-case-host-platform)
  (let (output
        (poo-flow-module-system-live-case-host-command-output
         '("sh" "-c" "uname -s | tr -d '\\n'")
         ""))
    (if (string=? output "Darwin") 'macos 'unsupported)))

;; : (-> MaybeString Boolean)
(def (poo-flow-module-system-live-case-non-empty-string? value)
  (and (string? value)
       (> (string-length value) 0)))

;;; Boundary: module system live case path join is the policy-visible edge for
;;; module-system, test harness behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> String String String)
(def (poo-flow-module-system-live-case-path-join left right)
  (cond
   ((not (poo-flow-module-system-live-case-non-empty-string? left)) right)
   ((not (poo-flow-module-system-live-case-non-empty-string? right)) left)
   ((char=? (string-ref left (- (string-length left) 1)) #\/)
    (string-append left right))
   (else
    (string-append left "/" right))))

;;; Workspace roots are data, not framework policy. The framework only supplies a
;;; safe fallback shape when the downstream case omits optional path fields.
;; : (-> POOObject String)
(def (poo-flow-module-system-live-case-root-path live-case)
  (let* ((root-env
          (poo-flow-module-system-live-case-section-ref
           live-case
           'isolation
           'root-env
           "TMPDIR"))
         (base
          (if (string? root-env)
            (getenv root-env "/tmp")
            "/tmp"))
         (root
          (poo-flow-module-system-live-case-section-ref
           live-case
           'isolation
           'root
           (string-append
            "poo-flow-live-case/"
            (symbol->string
             (poo-flow-module-system-live-case-name live-case))))))
    (poo-flow-module-system-live-case-path-join base root)))

;; : (-> POOObject String)
(def (poo-flow-module-system-live-case-planned-workspace live-case)
  (poo-flow-module-system-live-case-path-join
   (poo-flow-module-system-live-case-root-path live-case)
   (poo-flow-module-system-live-case-section-ref
    live-case
    'isolation
    'workspace
    "workspace")))

;; : (-> POOObject String)
(def (poo-flow-module-system-live-case-home-path live-case)
  (poo-flow-module-system-live-case-path-join
   (poo-flow-module-system-live-case-planned-workspace live-case)
   (poo-flow-module-system-live-case-section-ref
    live-case
    'isolation
    'home
    ".home")))

;;; This quote helper is only used for framework-assembled literals. The user
;;; case contributes structured fields, not shell fragments.
;; : (-> ShellLiteral ShellQuotedLiteral)
(def (poo-flow-module-system-live-case-shell-quote value)
  (string-append "'" value "'"))

;;; Boundary: module system live case shell join is the policy-visible edge for
;;; module-system, test harness behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> [ShellLiteral] ShellCommandFragment)
(def (poo-flow-module-system-live-case-shell-join values)
  (cond
   ((null? values) "")
   ((null? (cdr values))
    (poo-flow-module-system-live-case-shell-quote (car values)))
   (else
    (string-append
     (poo-flow-module-system-live-case-shell-quote (car values))
     " "
     (poo-flow-module-system-live-case-shell-join (cdr values))))))

;;; Boundary: module system live case env clear join is the policy-visible edge
;;; for module-system, test harness behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> [EnvironmentVariableName] ShellCommandFragment)
(def (poo-flow-module-system-live-case-env-clear-join keys)
  (cond
   ((null? keys) "")
   ((null? (cdr keys))
    (string-append (car keys) "="))
   (else
    (string-append
     (car keys)
     "= "
     (poo-flow-module-system-live-case-env-clear-join (cdr keys))))))

;;; Boundary: module system live case rsync exclude join is the policy-visible
;;; edge for module-system, test harness behavior, keeping validation, lookup,
;;; or projection responsibilities centralized for callers.
;; : (-> [RsyncExcludePattern] ShellCommandFragment)
(def (poo-flow-module-system-live-case-rsync-exclude-join values)
  (cond
   ((null? values) "")
   (else
    (string-append
     " --exclude "
     (poo-flow-module-system-live-case-shell-quote (car values))
     (poo-flow-module-system-live-case-rsync-exclude-join (cdr values))))))

;;; Staging is framework-owned, but every concrete path and exclude rule is read
;;; from the downstream case object. This keeps src/testing generic while still
;;; proving the project is copied before sandbox execution.
;; : (-> POOObject MaybeWorkspacePath)
(def (poo-flow-module-system-live-case-stage-project-copy live-case)
  (let* ((root (poo-flow-module-system-live-case-root-path live-case))
         (workspace (poo-flow-module-system-live-case-planned-workspace
                     live-case))
         (home (poo-flow-module-system-live-case-home-path live-case))
         (source
          (poo-flow-module-system-live-case-section-ref
           live-case
           'isolation
           'source
           "."))
         (exclude
          (poo-flow-module-system-live-case-section-ref
           live-case
           'isolation
           'exclude
           '()))
         (command-string
          (string-append
           "set -eu; rm -rf "
           (poo-flow-module-system-live-case-shell-quote root)
           "; mkdir -p "
           (poo-flow-module-system-live-case-shell-quote workspace)
           "; rsync -a --delete"
           (poo-flow-module-system-live-case-rsync-exclude-join exclude)
           " "
           (poo-flow-module-system-live-case-shell-quote source)
           "/ "
           (poo-flow-module-system-live-case-shell-quote workspace)
           "/; mkdir -p "
           (poo-flow-module-system-live-case-shell-quote home)
           "; printf %s "
           (poo-flow-module-system-live-case-shell-quote workspace))))
    (let (workspace-or-failure
          (with-catch
           (lambda (_) #f)
           (lambda ()
             (run-process
              (list "sh" "-lc" command-string)
              stderr-redirection: #t))))
      (if (string? workspace-or-failure) workspace-or-failure #f))))

;; : (-> Unit String)
(def (poo-flow-module-system-live-case-gxpkg-wrapper-dir)
  (poo-flow-module-system-live-case-host-command-output
   '("sh" "-lc"
     "p=$(command -v gxpkg 2>/dev/null) && d=$(dirname \"$p\") && printf %s \"$d\"")
   "/usr/local/bin"))

;; : (-> Unit String)
(def (poo-flow-module-system-live-case-gxpkg-path)
  (poo-flow-module-system-live-case-host-command-output
   '("sh" "-lc"
     "p=$(command -v gxpkg 2>/dev/null) && printf %s \"$p\"")
   "gxpkg"))

;;; gxpkg may be a wrapper script; nono needs read access to the resolved Gerbil
;;; tree as well as the wrapper directory that launches it.
;; : (-> Unit String)
(def (poo-flow-module-system-live-case-gerbil-toolchain-dir)
  (poo-flow-module-system-live-case-host-command-output
   '("sh" "-lc"
     "p=$(command -v gxpkg 2>/dev/null); real=$(awk '/^exec / {print $2; exit}' \"$p\" 2>/dev/null); real=${real#\\\"}; real=${real%\\\"}; case \"$real\" in */.data/gerbil/*) printf %s \"${real%%/.data/gerbil/*}/.data/gerbil\" ;; *) d=$(dirname \"$(dirname \"$real\")\"); printf %s \"$d\" ;; esac")
   #f))

;; : (-> Unit String)
(def (poo-flow-module-system-live-case-git-config-dir)
  (poo-flow-module-system-live-case-host-command-output
   '("sh" "-lc"
     "d=${XDG_CONFIG_HOME:-$HOME/.config}/git; if [ -e \"$d\" ]; then printf %s \"$d\"; fi")
   #f))

;; : (-> Unit String)
(def (poo-flow-module-system-live-case-build-path)
  (poo-flow-module-system-live-case-host-command-output
   '("sh" "-lc"
     "printf %s /usr/bin:/bin:/usr/sbin:/sbin:$(dirname \"$(command -v gxpkg 2>/dev/null || printf /usr/bin/gxpkg)\")")
   "/usr/bin:/bin:/usr/sbin:/sbin"))

;;; Command program resolution is intentionally narrow. The framework knows how
;;; to locate gxpkg; other programs must be explicit declaration literals.
;; : (-> POOObject String)
(def (poo-flow-module-system-live-case-command-program live-case)
  (let (program
        (poo-flow-module-system-live-case-section-ref
         live-case
         'command
         'program
         "gxpkg"))
    (if (string=? program "gxpkg")
      (poo-flow-module-system-live-case-gxpkg-path)
      program)))

;;; The build script intentionally uses env -i. The downstream case chooses
;;; which variables to clear, while the framework supplies a small toolchain
;;; PATH so the sandbox cannot inherit the caller's ambient environment.
;; : (-> POOObject String String)
(def (poo-flow-module-system-live-case-build-script live-case workspace)
  (let* ((program
          (poo-flow-module-system-live-case-command-program live-case))
         (program-args
          (poo-flow-module-system-live-case-section-ref
           live-case
           'command
           'args
           '()))
         (clear-env
          (poo-flow-module-system-live-case-section-ref
           live-case
           'environment
           'clear-env
           '()))
         (home
          (poo-flow-module-system-live-case-home-path live-case)))
    (string-append
     "POO_FLOW_ISOLATED_WORKSPACE="
     (poo-flow-module-system-live-case-shell-quote workspace)
     "; export POO_FLOW_ISOLATED_WORKSPACE; "
     "cd \"$POO_FLOW_ISOLATED_WORKSPACE\" && "
     "env -i HOME="
     (poo-flow-module-system-live-case-shell-quote home)
     " PATH="
     (poo-flow-module-system-live-case-shell-quote
      (poo-flow-module-system-live-case-build-path))
     " "
     (poo-flow-module-system-live-case-env-clear-join clear-env)
     " "
     (poo-flow-module-system-live-case-shell-quote program)
     " "
     (poo-flow-module-system-live-case-shell-join program-args))))

;;; Boundary: module system live case read args is the policy-visible edge for
;;; module-system, test harness behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> [String] [String] [String])
(def (poo-flow-module-system-live-case-read-args/rev paths args-rev)
  (cond
   ((null? paths) (reverse args-rev))
   ((poo-flow-module-system-live-case-non-empty-string? (car paths))
    (poo-flow-module-system-live-case-read-args/rev
     (cdr paths)
     (cons (car paths)
           (cons "--read" args-rev))))
   (else
    (poo-flow-module-system-live-case-read-args/rev (cdr paths) args-rev))))

;; : (-> [String] [String])
(def (poo-flow-module-system-live-case-read-args paths)
  (poo-flow-module-system-live-case-read-args/rev paths '()))

;; : (-> POOObject [String])
(def (poo-flow-module-system-live-case-read-paths live-case)
  (append
   (list (poo-flow-module-system-live-case-gxpkg-wrapper-dir)
         (poo-flow-module-system-live-case-gerbil-toolchain-dir)
         (poo-flow-module-system-live-case-git-config-dir))
   (poo-flow-module-system-live-case-section-ref
    live-case
    'nono
    'read-paths
    '())))

;;; Boundary: module system live case network args is the policy-visible edge
;;; for module-system, test harness behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> POOObject [String])
(def (poo-flow-module-system-live-case-network-args live-case)
  (case (poo-flow-module-system-live-case-section-ref
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
(def (poo-flow-module-system-live-case-audit-args live-case)
  (case (poo-flow-module-system-live-case-section-ref
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
(def (poo-flow-module-system-live-case-nono-run-command live-case workspace)
  (append
   '("nono" "run" "--silent")
   (list "--allow" workspace)
   (poo-flow-module-system-live-case-read-args
    (poo-flow-module-system-live-case-read-paths live-case))
   (poo-flow-module-system-live-case-network-args live-case)
   (poo-flow-module-system-live-case-audit-args live-case)
   '("--" "sh" "-lc")
   (list (poo-flow-module-system-live-case-build-script live-case
                                                         workspace))))

;;; The outer command is shell-shaped because nono is still a process boundary.
;;; The user case contributes only structured command fields, never raw shell.
;; : (-> POOObject String [String])
(def (poo-flow-module-system-live-case-command live-case workspace)
  (list
   "sh"
   "-lc"
   (string-append
    "cd "
    (poo-flow-module-system-live-case-shell-quote workspace)
    " && exec "
    (poo-flow-module-system-live-case-shell-join
     (poo-flow-module-system-live-case-nono-run-command live-case
                                                         workspace)))))

;;; `:inherits` is the POO supers list. Build a profile-only view so the live
;;; case's own kind/name metadata cannot shadow the sandbox profile contract.
;; : (-> POOObject AgentSandboxProfile)
(def (poo-flow-module-system-live-case-profile live-case)
  (poo-flow-sandbox-profile->profile
   (make-object
    supers: (poo-flow-module-system-live-case-supers live-case)
    slots: '())))

;;; Profile declarations use user-facing network rows such as
;;; `(allowlisted "github.com")`; runtime manifests need the alist form consumed
;;; by backend validators. This is a projection of inherited profile policy, not
;;; a case-local policy declaration.
;; : (-> POOObject AgentSandboxProfile NetworkPolicy)
(def (poo-flow-module-system-live-case-runtime-network-policy live-case profile)
  (let (policy (poo-flow-module-system-live-case-section-ref
                live-case
                'nono
                'network-policy
                (poo-flow-module-system-live-case-section-ref
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
(def (poo-flow-module-system-live-case-request live-case workspace)
  (let ((profile
         (poo-flow-module-system-live-case-profile live-case)))
    (agent-sandbox-request
     profile
     (command "sh")
     (args (list "-lc"
                 (poo-flow-module-system-live-case-build-script live-case
                                                                 workspace)))
     (workdir workspace)
     (mounts (list (list (cons 'path workspace)
                         (cons 'kind 'directory)
                         (cons 'mode 'read-write)
                         (cons 'purpose 'isolated-project-workspace))))
     (network-policy
      (poo-flow-module-system-live-case-runtime-network-policy live-case
                                                               profile))
     (capabilities '((allow-commands . ("sh" "gxpkg"))))
     (resource-policy '((timeout-ms . 600000)))
     (metadata (list (cons 'check 'module-system-live-case)
                     (cons 'case
                           (poo-flow-module-system-live-case-name
                            live-case))
                     (cons 'supers
                           (poo-flow-module-system-live-case-super-names
                            live-case))
                     (cons 'project-isolated? #t)
                     (cons 'host-project-mounted? #f)
                     (cons 'environment-policy
                           (poo-flow-module-system-live-case-section-ref
                            live-case
                            'environment
                            'policy
                            'whitelist))
                     (cons 'workspace workspace))))))

;;; The manifest mirrors the command receipt. It is intentionally reportable
;;; before execution so failing live cases still expose isolation facts.
;; : (-> POOObject String AgentSandboxRuntimeManifest)
(def (poo-flow-module-system-live-case-runtime-manifest live-case workspace)
  (agent-sandbox-request->runtime-manifest
   (poo-flow-module-system-live-case-request live-case workspace)))

;;; Live cases are opt-in. The default test path proves declaration and receipt
;;; shape without performing a real sandbox build.
;; : (-> POOObject Boolean)
(def (poo-flow-module-system-live-case-enabled? live-case)
  (let (env-name
        (poo-flow-module-system-live-case-section-ref
         live-case
         'environment
         'enabled-env
         #f))
    (and (string? env-name)
         (string=? (getenv env-name "") "1"))))

;; : (-> POOObject String LiveCaseReceiptFacts)
(def (poo-flow-module-system-live-case-isolation-facts live-case workspace)
  (list (cons 'case
              (poo-flow-module-system-live-case-name live-case))
        (cons 'project-isolated? #t)
        (cons 'host-project-mounted? #f)
        (cons 'environment-policy
              (poo-flow-module-system-live-case-section-ref
               live-case
               'environment
               'policy
               'whitelist))
        (cons 'workspace workspace)))

;;; Skipped receipts keep the same schema as live receipts so CI and agents can
;;; inspect disabled/non-macOS/missing-tool states without special casing.
;; : (-> POOObject AgentSandboxRuntimeManifest [String] Symbol String LiveCaseReceipt)
(def (poo-flow-module-system-live-case-skip-receipt live-case
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
   (poo-flow-module-system-live-case-isolation-facts live-case workspace)))

;; : (-> POOObject LiveCaseReceipt String LiveCaseReceipt)
(def (poo-flow-module-system-live-case-receipt-with-isolation live-case
                                                               receipt
                                                               workspace)
  (append receipt
          (poo-flow-module-system-live-case-isolation-facts live-case
                                                            workspace)))

;;; Receipts are the observability boundary for live cases: disabled, skipped,
;;; staging-failed, and executed cases all return the same inspection shape.
;; : (-> POOObject LiveCaseReceipt)
(def (poo-flow-module-system-live-case-receipt live-case)
  (let* ((planned-workspace
          (poo-flow-module-system-live-case-planned-workspace live-case))
         (planned-command
          (poo-flow-module-system-live-case-command live-case
                                                     planned-workspace))
         (runtime-manifest
          (poo-flow-module-system-live-case-runtime-manifest
           live-case
           planned-workspace)))
    (cond
     ((not (poo-flow-module-system-live-case-enabled? live-case))
      (poo-flow-module-system-live-case-skip-receipt
       live-case
       runtime-manifest
       planned-command
       'live-case-disabled
       planned-workspace))
     ((not (eq? (poo-flow-module-system-live-case-host-platform) 'macos))
      (poo-flow-module-system-live-case-skip-receipt
       live-case
       runtime-manifest
       planned-command
       'non-macos-host
       planned-workspace))
     (else
      (let (workspace
            (poo-flow-module-system-live-case-stage-project-copy live-case))
        (if workspace
          (let ((command-value
                 (poo-flow-module-system-live-case-command live-case
                                                            workspace))
                (manifest
                 (poo-flow-module-system-live-case-runtime-manifest
                  live-case
                  workspace)))
            (poo-flow-module-system-live-case-receipt-with-isolation
             live-case
             (nono-c-binding-live-test manifest command-value)
             workspace))
          (poo-flow-module-system-live-case-skip-receipt
           live-case
           runtime-manifest
           planned-command
           'project-copy-failed
           planned-workspace)))))))

;;; The suite checks the separation of concerns first, then runs the case
;;; through the generic framework. Profile metadata must stay free of live-case
;;; path and command decisions.
;; : (-> POOObject TestSuite)
(def (poo-flow-module-system-live-case-test-suite live-case)
  (test-suite "poo-flow module-system live case"
    (test-case "case is declared as a downstream module-system case"
      (let* ((profile
              (poo-flow-module-system-live-case-profile live-case))
             (metadata-value
              (agent-sandbox-profile-metadata profile)))
        (check-equal? (poo-flow-module-system-live-case? live-case) #t)
        (check-equal? (agent-sandbox-profile-backend-kind profile) 'nono)
        (check-equal? (poo-flow-module-system-live-case-super-names live-case)
                      '(ci/build))
        (check-equal? (poo-flow-module-system-live-case-alist-ref
                       metadata-value
                       'live-case
                       #f)
                      #f)
        (check-equal? (poo-flow-module-system-live-case-section-ref
                       live-case
                       'isolation
                       'mode
                       #f)
                      'project-copy)
        (check-equal? (poo-flow-module-system-live-case-section-ref
                       live-case
                       'isolation
                       'project-mount
                       #f)
                      'isolated-copy)
        (check-equal? (poo-flow-module-system-live-case-section-ref
                       live-case
                       'environment
                       'policy
                       #f)
                      'whitelist)
        (check-equal? (poo-flow-module-system-live-case-section-ref
                       live-case
                       'command
                       'program
                       #f)
                      "gxpkg")
        (check-equal? (poo-flow-module-system-live-case-section-ref
                       live-case
                       'command
                       'args
                       #f)
                      '("build"))))
    (test-case "framework starts the module-system case"
      (let ((receipt
             (poo-flow-module-system-live-case-receipt live-case)))
        (check-equal? (poo-flow-module-system-live-case-alist-ref
                       receipt
                       'schema
                       #f)
                      +nono-c-binding-live-test-receipt-schema+)
        (check-equal? (poo-flow-module-system-live-case-alist-ref
                       receipt
                       'ok?
                       #f)
                      #t)
        (check-equal? (poo-flow-module-system-live-case-alist-ref
                       receipt
                       'case
                       #f)
                      (poo-flow-module-system-live-case-name live-case))
        (check-equal? (poo-flow-module-system-live-case-alist-ref
                       receipt
                       'runtime-executed
                       #t)
                      #f)
        (check-equal? (poo-flow-module-system-live-case-alist-ref
                       receipt
                       'would-apply?
                       #t)
                      #f)
        (check-equal? (poo-flow-module-system-live-case-alist-ref
                       receipt
                       'project-isolated?
                       #f)
                      #t)
        (check-equal? (poo-flow-module-system-live-case-alist-ref
                       receipt
                       'host-project-mounted?
                       #t)
                      #f)
        (check-equal? (poo-flow-module-system-live-case-alist-ref
                       receipt
                       'environment-policy
                       #f)
                      'whitelist)
        (check-equal? (member "." (poo-flow-module-system-live-case-alist-ref
                                   receipt
                                   'command
                                   '()))
                      #f)
        (if (poo-flow-module-system-live-case-alist-ref
             receipt
             'enabled?
             #f)
          (begin
            (check-equal? (poo-flow-module-system-live-case-alist-ref
                           receipt
                           'skipped?
                           #t)
                          #f)
            (check-equal? (poo-flow-module-system-live-case-alist-ref
                           receipt
                           'status
                           1)
                          0))
          (begin
            (check-equal? (poo-flow-module-system-live-case-alist-ref
                           receipt
                           'skipped?
                           #f)
                          #t)
            (check-equal? (and (memq
                                (poo-flow-module-system-live-case-alist-ref
                                 receipt
                                 'skip-reason
                                 #f)
                                '(live-case-disabled
                                  non-macos-host
                                  nono-not-found-on-path
                                  project-copy-failed))
                               #t)
                          #t)))))))
