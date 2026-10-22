;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Opt-in product qualification; importing this file starts no evaluator.
(import :clan/poo/object (only-in :std/ffi C-include def-C-type def-C-lambda))
(export call-with-nix-session call-with-flake-session session-query session-calls)
(C-include "\"session.h\"")
(def-C-type session "pf_nix_session")
(def-C-type session-pointer (pointer session))
(def-C-lambda session-open (char-string char-string) session-pointer "pf_nix_open")
(def-C-lambda flake-prepare (char-string char-string) session-pointer "pf_nix_flake_prepare")
(def-C-lambda flake-override (session-pointer char-string char-string char-string) int "pf_nix_flake_override")
(def-C-lambda flake-select (session-pointer char-string) int "pf_nix_flake_select")
(def-C-lambda session-close (session-pointer) void "pf_nix_close")
(def-C-lambda session-call (session-pointer char-string) int "pf_nix_query")
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
