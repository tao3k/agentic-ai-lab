;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Opt-in product qualification; importing this file starts no evaluator.
(import :clan/poo/object (only-in :std/ffi C-include def-C-type def-C-lambda))
(export call-with-nix-session call-with-flake-session session-query session-calls session-apply! session-result session-timing)
(C-include "\"session.h\"")
(def-C-type session "pf_nix_session")
(def-C-type session-pointer (pointer session))
(def-C-lambda session-open (char-string char-string) session-pointer "pf_nix_open")
(def-C-lambda flake-prepare (char-string char-string) session-pointer "pf_nix_flake_prepare")
(def-C-lambda flake-override (session-pointer char-string char-string char-string) int "pf_nix_flake_override")
(def-C-lambda flake-select (session-pointer char-string) int "pf_nix_flake_select")
(def-C-lambda session-close (session-pointer) void "pf_nix_close")
(def-C-lambda session-call (session-pointer char-string) int "pf_nix_query")
(def-C-lambda native-apply (session-pointer char-string) int "pf_nix_apply")
(def-C-lambda native-result (session-pointer char-string) int "pf_nix_result")
(def-C-lambda phase-seconds (session-pointer int int) double "pf_nix_seconds")
(def-C-lambda phase-calls (session-pointer int) unsigned-int "pf_nix_phase_calls")
(def-C-lambda session-output (session-pointer) char-string "___return(___arg1->output);")
(def-C-lambda session-error (session-pointer) char-string "___return(___arg1->error);")
(def-C-lambda session-calls (session-pointer) unsigned-int "___return(___arg1->calls);")

(def (call-with-nix-session expression directory procedure)
  (with-session (session-open expression directory) procedure))

(def (with-session session procedure)
    (unless session (error "Nix C API allocation failed"))
    (dynamic-wind void
      (lambda ()
        (when (session-error session) (error "Nix C API initialization failed" (session-error session)))
        (procedure session))
      (lambda () (session-close session))))

(def (session-query session input)
  (unless (= (session-call session input) 1)
    (error "Nix C API evaluation failed" (session-error session)))
  (session-output session))

;; Explicit lifetime: imports neither initialize Nix nor launch an evaluator.
;; `inputs` is the ordinary POO mapping used by the product Flake Source.
(def (call-with-flake-session reference directory attribute inputs procedure)
  (with-session (flake-prepare reference directory)
    (lambda (session)
      (for-each
        (lambda (name)
          (unless (= (flake-override session (symbol->string name) (.ref inputs name) directory) 1)
            (error "Nix flake input rejected" name (session-error session))))
        (.all-slots inputs))
      (unless (= (flake-select session attribute) 1)
        (error "Nix strict flake lock/selection rejected" (session-error session)))
      (procedure session))))

;; Diagnostic projection only; the ordinary query surface is unchanged.
(def (session-apply! session input)
  (unless (= (native-apply session input) 1)
    (error "Nix C API application failed" (session-error session))))
(def (session-result session attribute)
  (unless (= (native-result session attribute) 1)
    (error "Nix C API result projection failed" attribute (session-error session)))
  (session-output session))
(def (session-timing session phase)
  (let (index (case phase
                 ((initialize) 0) ((store) 1) ((state) 2) ((settings) 3)
                 ((lock) 4) ((outputs) 5) ((apply) 6) ((result) 7)
                 (else (error "unknown Nix timing phase" phase))))
    ;; Freeze scalar observations now; do not leave C pointers in lazy slots.
    (let ((wall-seconds (phase-seconds session index 0))
          (cpu-seconds (phase-seconds session index 1))
          (count (phase-calls session index)))
      (.o wall: wall-seconds cpu: cpu-seconds calls: count))))
