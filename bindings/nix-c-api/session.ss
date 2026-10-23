;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; One explicit worker per bounded session; no process starts on import.
(import (only-in :std/misc/process run-process) "./compatibility.ss")
(export call-with-nix-session session-query session-calls session-version)
(defstruct session (port calls version))

(def (call-with-nix-session expression directory procedure)
  (let (file (path-expand "session-expression.nix" directory))
    (call-with-output-file (list path: file truncate: #t) (cut display expression <>))
    (run-process
      (list (getenv "AGENTIC_AI_LAB_NIX_C_API_WORKER") file directory)
      stderr-redirection: #f
      coprocess:
      (lambda (port)
        (let* ((ready (read-line port))
               (version (and (string? ready) (string-prefix? "READY " ready)
                             (substring ready 6 (string-length ready)))))
          (unless (supported-version? version)
            (error "Nix C API worker is below the supported version or has an invalid version" ready minimum-version))
          (let (session (make-session port 0 version))
          (try (procedure session)
            (finally (close-output-port port)))))))))

(def (session-query session input)
  (let (port (session-port session))
    (display input port)
    (newline port)
    (force-output port)
    (let (result (read-line port))
      (when (eof-object? result) (error "Nix C API worker closed before replying"))
      (session-calls-set! session (1+ (session-calls session)))
      result)))
