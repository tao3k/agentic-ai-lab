;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Actual Nix, with no provider acquisition or realization.
(import :std/test :clan/poo/object
        (only-in :std/error Error? Error-message)
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :agentic-ai-lab/modules/nix/objects NixSource. agentic-ai-lab-nix-admit-generation)
        (only-in :yuanxu/module-system/source/admission current-module-source-observer
                 current-module-process-trace-budget)
        (only-in :agentic-ai-lab/modules/nix/func current-nix-process-observer call-with-nix-derivation-query))
(export nix-derivation-query-test test-cleanup!)
;; Store registration can stream a final path without a newline. Keep native
;; harness markers on their own line without changing the captured process data.
(def (test-cleanup!) (newline))
(def (write-input path value)
  (call-with-output-file (list path: path truncate: #t) (cut display value <>)))
(def nix-derivation-query-test
  (test-suite "Derivation currentness queries do not register candidates"
    (yuanxu-test-case "fresh transitive evaluation, refusal and restored registration mode"
      (call-with-temporary-directory "nix-derivation-query"
        (lambda (root)
          (def expression (path-expand "package.nix" root))
          (def transitive (path-expand "value.nix" root))
          (def argv '())
          (def operations '())
          (def store-decisions '())
          (write-input transitive "\"before\"")
          (write-input expression
            "builtins.derivation { name = \"currentness-query\"; system = builtins.currentSystem; builder = \"/bin/sh\"; salt = builtins.toString ./.; value = import ./value.nix; optional = builtins.pathExists ./optional.nix; }")
          (def Source (.cc NixSource. 'expression expression))
          (parameterize ((current-nix-process-observer (lambda (value) (set! argv (cons value argv))))
                         (current-module-source-observer
                           (lambda (key _amount)
                             (when (and (pair? key) (eq? (car key) 'package-process-start))
                               (set! operations (cons (cadr key) operations)))
                             (when (and (pair? key) (eq? (car key) 'package-store-validity))
                               (set! store-decisions (cons (cadr key) store-decisions))))))
            (def original (.call Source .instantiate))
            (check-equal? (file-exists? original) #t)
            ;; Warm construction still evaluates Nix and checks the actual
            ;; store registration. It performs no writable registration.
            (def before-warm (length argv))
            (def operations-before-warm (length operations))
            (def decisions-before-warm (length store-decisions))
            (check-equal? (.call Source .instantiate) original)
            (def warm (take argv (- (length argv) before-warm)))
            (check-equal? (length warm) 2)
            (check-equal? (ormap (cut member "--read-write-mode" <>) warm) #f)
            (check-equal? (length (filter (cut member "--eval" <>) warm)) 1)
            (check-equal? (length (filter (cut member "--check-validity" <>) warm)) 1)
            (check-equal?
              (reverse (take operations (- (length operations) operations-before-warm)))
              '(derivation-query store-validity))
            (check-equal?
              (take store-decisions (- (length store-decisions) decisions-before-warm))
              '(hit))
            ;; The native Case adapter supplies this optional allowance. Warm
            ;; construction must exhaust it without adding probe processes.
            (when (current-module-process-trace-budget)
              (check-equal? (unbox (current-module-process-trace-budget)) 0))
            (check-equal?
              (call-with-nix-derivation-query
                (lambda ()
                  (.call (.cc Source 'config
                           (.o instantiate: "nix-instantiate"
                               realize: (error "readonly query forced the store capability")))
                    .instantiate)))
              original)
            (agentic-ai-lab-nix-admit-generation expression '() original)
            (check-equal? (and (member "--eval" (car argv)) #t) #t)
            (check-equal? (member "--read-write-mode" (car argv)) #f)
            ;; Neither transitive input was declared as a Scheme observation.
            (write-input transitive "\"after\"")
            (check-exception (agentic-ai-lab-nix-admit-generation expression '() original) error?)
            (write-input transitive "\"before\"")
            (write-input (path-expand "optional.nix" root) "{}")
            (check-exception (agentic-ai-lab-nix-admit-generation expression '() original) error?)
            ;; An exception inside the subprocess thunk must unwind query mode,
            ;; not merely a mismatch raised after a successful query returned.
            (write-input transitive "throw \"query-fixture-refused\"")
            (check-exception (agentic-ai-lab-nix-admit-generation expression '() original) error?)
            (write-input transitive "\"before\"")
            (def queried (call-with-nix-derivation-query (lambda () (.call Source .instantiate))))
            (check-equal? (file-exists? queried) #f)
            ;; Refusal cannot leave a thread-local read-only mode active.
            (def changed (.call Source .instantiate))
            (check-equal? changed queried)
            (check-equal? (and (member "--read-write-mode" (car argv)) #t) #t)
            (check-equal? (equal? changed original) #f)
            (check-equal? (file-exists? changed) #t)))))
    (yuanxu-test-case "a transitive change between cache miss and registration refuses construction"
      (call-with-temporary-directory "nix-registration-race"
        (lambda (root)
          (def expression (path-expand "package.nix" root))
          (def transitive (path-expand "value.nix" root))
          (write-input transitive "\"before\"")
          (write-input expression
            "builtins.derivation { name = \"registration-race\"; system = builtins.currentSystem; builder = \"/bin/sh\"; salt = builtins.toString ./.; value = import ./value.nix; }")
          (def Source (.cc NixSource. 'expression expression))
          (parameterize ((current-nix-process-observer
                          (lambda (argv)
                            (when (member "--read-write-mode" argv)
                              (write-input transitive "\"after\"")))))
            (check-exception (.call Source .instantiate)
              (lambda (failure)
                (and (Error? failure)
                     (equal? (Error-message failure)
                       "Nix source changed during derivation registration"))))))))))
