;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in "./progress.ss" make-nix-progress-reader) :clan/poo/object
        (only-in :std/misc/process run-process)
        (only-in :yuanxu/ops/func run-script)
        (only-in :yuanxu/ops/progress execution-idle-seconds execution-total-seconds)
        (only-in :std/string/misc string-subst)
        (only-in :std/encoding/json write-json)
        (only-in :yuanxu/module-system/source/admission module-source-type module-source-read
                 current-module-source-observer current-module-process-trace-budget)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode))
(export agentic-ai-lab-nix-flake-source-inputs agentic-ai-lab-nix-flake-instantiate current-nix-process-observer current-nix-process-completion-observer agentic-ai-lab-nix-instantiate agentic-ai-lab-nix-realize agentic-ai-lab-nix-source-inputs call-with-nix-derivation-query)
(export agentic-ai-lab-nix-verify-store)
;; Optional build-tool observability at the actual process boundary. No cache or
;; Provider-specific instrumentation; default execution has no observer.
(def current-nix-process-observer (make-parameter #f))
(def current-nix-process-completion-observer (make-parameter #f))
;; A check evaluates the same function/arguments but must not register the same
;; derivation again. This is a process mode, not a currentness/evidence cache.
;; Keep dispatch through Source.instantiate so specialized Sources retain their
;; own identity rules (Flake Sources already use nix eval).
(def nix-derivation-query? (make-parameter #f))
(def (call-with-nix-derivation-query thunk)
  (parameterize ((nix-derivation-query? #t)) (thunk)))
(def (observed-nix-command argv)
  ;; Logging only: preserve the original command/mode and never issue an extra
  ;; cache probe, preload a result, or change execution/currentness policy.
  (let ((budget (current-module-process-trace-budget))
        (command (if (member "--log-format" argv) argv
                   (append argv '("--log-format" "internal-json" "--verbose")))))
    (if (and budget (> (unbox budget) 0))
      (begin
        (set-box! budget (- (unbox budget) 1))
        (append command '("--debug")))
      command)))
(def (run-nix-process argv check?)
  ;; Reuse Ops ownership, progress decoding and descendant cleanup. Structured
  ;; Nix stderr remains visible to a supervising TestingScript even with emit off.
  (def observer (current-module-source-observer))
  ;; Bounded counters, not a path registry or an evaluation/result cache. The
  ;; protocol logs requests, not RPC completion: do not invent service timings.
  (def counts (and observer (make-hash-table-eq)))
  (def (record-native record)
    (when (equal? (hash-get record 'action) "msg")
      (let* ((text (hash-get record 'msg))
             (category
               (cond
                ((not (string? text)) #f)
                ((equal? text "performing daemon worker op: 1") 'package-store-validity-requests)
                ((equal? text "performing daemon worker op: 11") 'nix-gc-root-requests)
                ((equal? text "performing daemon worker op: 7") 'nix-store-add-requests)
                ((equal? text "performing daemon worker op: 26") 'nix-store-info-requests)
                ((string-prefix? "instantiated '" text) 'nix-derivation-instantiations)
                ((string-prefix? "evaluating file '" text) 'nix-file-evaluations)
                (else #f))))
        (hash-put! counts 'nix-message-records (+ 1 (or (hash-get counts 'nix-message-records) 0)))
        (when category (hash-put! counts category (+ 1 (or (hash-get counts category) 0)))))))
  (dynamic-wind void
    (lambda ()
      (run-script
        (.o command: argv directory: #f environment: (.o)
            timeout: execution-total-seconds idle-timeout: execution-idle-seconds
            progress: (lambda () (make-nix-progress-reader observe: (and observer record-native)))
            log: #f check-status: check?)
        output-port: (current-error-port)))
    (lambda ()
      (when observer
        (observer (cons 'package-process-observation (hash->list counts)) 1)))))
(def (call-with-package-process-observation argv thunk)
  (let ((observer (current-nix-process-completion-observer))
        (source-observer (current-module-source-observer))
        ;; Liveness decoding must not depend on observation emission. Native
        ;; activity records are required even when no Case observer is active.
        (command (observed-nix-command argv)))
    (if (not (or observer source-observer)) (thunk command)
      (let ((started (real-time)) (completed? #f)
            ;; Closed process modes, never argv/path payloads. Distinguish a
            ;; cached store check from actual realization in the existing trace.
            (operation
              (cond ((member "--check-validity" argv) 'store-validity)
                    ((member "--realise" argv) 'store-realize)
                    ((member "--read-write-mode" argv) 'derivation-registration)
                    ((or (member "--eval" argv) (member "--derivation" argv)) 'derivation-query)
                    (else 'flake-query))))
        (dynamic-wind
          (lambda ()
            (when source-observer
              (source-observer (list 'package-process-start operation) 1)))
          (lambda ()
            (let (value (thunk command))
              (set! completed? #t) value))
          (lambda ()
            (when source-observer
              (source-observer (list 'package-process-end operation) 1))
            (when observer (observer argv (- (real-time) started) completed?))))))))
(def (store-path-command argv lookup?: (lookup? #f))
  (when (current-nix-process-observer) ((current-nix-process-observer) argv))
  (let* ((status #f)
         (result
          (call-with-package-process-observation argv
            (lambda (command)
              (let (receipt (run-nix-process command (not lookup?)))
                (set! status (.get receipt status))
                (find (cut string-prefix? "/nix/store/" <>)
                      (string-split (.get receipt output) #\newline)))))))
    ;; Only construction's optional cache lookup may miss. A currentness query
    ;; keeps the original strict process failure; it never retries in write mode.
    (if (and lookup? (not (zero? status))) #f
      (begin
        (unless (and (string? result) (string-prefix? "/nix/store/" result))
          (error "invalid Nix artifact response" result))
        result))))

(def (nix-store-path-valid? executable path)
  (def argv (list executable "--check-validity" path))
  (def status #f)
  (when (current-nix-process-observer) ((current-nix-process-observer) argv))
  (call-with-package-process-observation argv
    (lambda (command)
      (set! status (.get (run-nix-process command #f) status))))
  (let ((valid? (zero? status)) (observer (current-module-source-observer)))
    (when observer
      (observer (list 'package-store-validity (if valid? 'hit 'miss)) 1))
    valid?))

(def (agentic-ai-lab-nix-verify-store executable path)
  (unless (and (string? path) (string-prefix? "/nix/store/" path)
               (not (string-index (substring path 11 (string-length path)) #\/))
               (eq? (module-source-type path) 'directory))
    (error "approved release must be an exact Nix store directory" path))
  (for-each
    (lambda (operation)
      (def argv (list executable operation path))
      (when (current-nix-process-observer) ((current-nix-process-observer) argv))
      (call-with-package-process-observation argv (cut run-nix-process <> #t)))
    '("--check-validity" "--verify-path")))

(def (agentic-ai-lab-nix-instantiate executable expression arguments
                                   (store-command (lambda () "nix-store")))
  ;; Nix owns the cache. Always evaluate the CURRENT expression/arguments first;
  ;; do not reuse a Scheme result or assume our source list closes Nix imports.
  (def command
    (append (list executable "--eval" "--raw" "--attr" "drvPath")
      (list expression)
      (foldr append '()
        (map (lambda (name)
               (list "--argstr" (symbol->string name) (.ref arguments name)))
             (.all-slots arguments)))))
  (if (nix-derivation-query?)
    (store-path-command command)
    (let (candidate (store-path-command command lookup?: #t))
      (if (and candidate (nix-store-path-valid? (store-command) candidate))
        candidate
        ;; Missing store state (or evaluation requiring writable construction)
        ;; falls back to the original registration operation, not to acceptance.
        (let (registered
               (store-path-command (append command '("--read-write-mode"))))
          (when (and candidate (not (equal? candidate registered)))
            (error "Nix source changed during derivation registration" candidate registered))
          registered)))))
(def (nix-string text)
  ;; JSON and Nix differ at interpolation. Escape data, never concatenate data
  ;; into Nix syntax without quoting (including ordinary ${...} config values).
  (string-append "\""
    (string-subst
      (string-subst
        (string-subst (string-subst text "\\" "\\\\") "\"" "\\\"")
        "$" "\\$")
      "\n" "\\n") "\""))
(def (agentic-ai-lab-nix-flake-instantiate executable reference attribute
        (arguments (.o)) (inputs (.o)))
  ;; Nix's --override-input implies virtual/no-write locking. In that mode,
  ;; --no-update-lock-file alone can accept unrelated missing lock entries.
  ;; Authenticate the unmodified root lock without overrides first. This is
  ;; an independent check, not a remembered verdict or a fallback write.
  (when (pair? (.all-slots inputs))
    (let (command (list executable "--extra-experimental-features" "nix-command flakes"
                   "flake" "metadata" "--json" "--no-update-lock-file" reference))
      (when (current-nix-process-observer) ((current-nix-process-observer) command))
      (call-with-package-process-observation command (cut run-nix-process <> #t))))
  (let* ((applied? (pair? (.all-slots arguments)))
         ;; A fully qualified output is an exact path, not a package shorthand.
         ;; Native prefix probing can seal/replace ancestor cache rows on Nix
         ;; 2.34 and cause a second full evaluation for identical inputs. The
         ;; leading dot selects Nix's existing exact-attribute route. Keep short
         ;; names and applied-function evaluation unchanged.
         (exact? (and (not applied?)
                      (or (string-prefix? "packages." attribute)
                          (string-prefix? "legacyPackages." attribute))))
         (installable (string-append reference "#" (if exact? "." "") attribute))
         (json (and applied?
                (call-with-output-string
                  (lambda (port)
                    (write-json port (list->hash-table (.alist/sort arguments))))))))
    (store-path-command
      (append
        (list executable "--extra-experimental-features" "nix-command flakes"
              ;; Overrides permit virtual changes. The separate root check
              ;; above rejects unrelated unlocked inputs before this operation.
              ;; Derived-path consumers use Nix's persistent attribute cursor.
              ;; `eval --raw ...drvPath` forces a fresh Value even on a cache hit.
              (if applied? "eval" "path-info")
              (if applied? "--raw" "--derivation")
              "--no-update-lock-file" installable)
        (foldr append '()
          (map (lambda (name)
                 (list "--override-input" (symbol->string name)
                   ;; Equivalent directory spellings must share Nix's key.
                   (string-append "path:"
                     (path-strip-trailing-directory-separator
                       (path-normalize (.ref inputs name))))))
               (.all-slots inputs)))
        (if applied?
          (list "--apply" (string-append "function: (function (builtins.fromJSON "
                                         (nix-string json) ")).drvPath"))
          '())))))
(def (agentic-ai-lab-nix-flake-source-inputs reference)
  ;; No tree scan. Native Nix checks transitive derivation dependencies. Remote
  ;; roots have no local byte observations; transport/pinning remains upstream.
  (let (root (cond ((string-prefix? "path:/" reference) (substring reference 5 (string-length reference)))
                  ((string-prefix? "/" reference) reference) (else #f)))
    (if root
      (map (lambda (name)
             (let (path (path-expand name root))
               (cons path (and (module-source-type path) (module-source-read path)))))
           '("flake.nix" "flake.lock"))
      '())))
(def (agentic-ai-lab-nix-realize executable derivation)
  (store-path-command (list executable "--realise" derivation)))

;; Project already-observed Core source bytes; no extra filesystem scan.
(def (agentic-ai-lab-nix-source-inputs observations)
  (list->vector
   (map (lambda (row)
          (list->hash-table
           (list (cons 'path (car row))
                 (cons 'present (if (cdr row) #t #f))
                 (cons 'sha256 (if (cdr row)
                                 (hex-encode (sha256 (string->utf8 (cdr row)))) "")))))
        observations)))
