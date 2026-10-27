;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Actual store construction and fresh registration checks, with no cache edits.
(import :std/test :clan/poo/object
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :std/misc/ports read-all-as-string)
        (only-in :std/encoding/json read-json JSONReadOptions current-json-read-options)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :agentic-ai-lab/modules/nix/objects NixSource.)
        (only-in :agentic-ai-lab/modules/nix/func
                 agentic-ai-lab-nix-realize current-nix-process-observer))
(export nix-output-reuse-test)

(def (fixture-source root multiple?)
  (def tools
    (parameterize ((current-json-read-options
                     (JSONReadOptions key-as-symbol: #f object-as-hash: #t)))
      (call-with-input-string (getenv "AGENTIC_AI_LAB_NIX_TEST_TOOLS") read-json)))
  (def expression (path-expand "package.nix" root))
  (call-with-output-file expression
    (lambda (port)
      (display
        (string-append
          "builtins.derivation { name = \"native-output-reuse\"; "
          "system = builtins.currentSystem; salt = builtins.toString ./.; "
          "builder = \"" (hash-ref tools "shell") "/bin/bash\"; "
          (if multiple? "outputs = [ \"out\" \"dev\" ]; " "")
          "args = [ \"-euc\" ''printf native-output > \"$out\""
          (if multiple? "; printf native-dev > \"$dev\"" "")
          "'' ]; }") port)))
  (.cc NixSource. 'expression expression))

(def (calls-with calls flag) (filter (cut member flag <>) calls))
(def nix-output-reuse-test
  (test-suite "Native Nix output registration reuse"
    (yuanxu-test-case "cold output builds; repeated warm calls recheck the native store"
      (call-with-temporary-directory "nix-output-reuse"
        (lambda (root)
          (def source (fixture-source root #f))
          (def derivation (.call source .instantiate))
          (def calls '())
          (parameterize ((current-nix-process-observer
                          (lambda (command) (set! calls (cons command calls)))))
            (def output (.call source .realize derivation))
            (check-equal? (call-with-input-file output read-all-as-string) "native-output")
            (check-equal? (length (calls-with calls "--realise")) 1)
            (set! calls '())
            (check-equal? (.call source .realize derivation) output)
            (check-equal? (.call source .realize derivation) output)
            (check-equal? (length calls) 4)
            (check-equal? (length (calls-with calls "--outputs")) 2)
            (check-equal? (length (calls-with calls "--check-validity")) 2)
            (check-equal? (calls-with calls "--realise") '())
            ;; An existing output cannot override a current refusal. The
            ;; observer is the existing fault boundary, not a replacement tool.
            (parameterize ((current-nix-process-observer
                            (lambda (command)
                              (when (member "--check-validity" command)
                                (error "registration withdrawn during lookup")))))
              (check-exception (.call source .realize derivation) error?))
            (check-exception (agentic-ai-lab-nix-realize "/usr/bin/false" derivation) error?)))))
    (yuanxu-test-case "multiple outputs retain native realization on cold and warm calls"
      (call-with-temporary-directory "nix-multiple-outputs"
        (lambda (root)
          (def source (fixture-source root #t))
          (def derivation (.call source .instantiate))
          (def calls '())
          (parameterize ((current-nix-process-observer
                          (lambda (command) (set! calls (cons command calls)))))
            (def output (.call source .realize derivation))
            (check-equal? (file-exists? output) #t)
            (set! calls '())
            (check-equal? (.call source .realize derivation) output)
            (check-equal? (length (calls-with calls "--outputs")) 1)
            (check-equal? (length (calls-with calls "--realise")) 1)))))))
