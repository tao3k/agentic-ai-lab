;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Same real provider function, strict native flake locking and matched CLI.
(import :std/test :clan/poo/object "./cases.ss"
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :std/misc/process run-process)
        (only-in :std/misc/ports read-all-as-string)
        (only-in :std/encoding/json json->string read-json JSONReadOptions)
        (only-in :yuanxu/module-system/source/admission module-source-read))
(export flake-api-suite)

(def (cli-run arguments)
  (run-process (cons nix arguments) stdin-redirection: #f stderr-redirection: #f
    coprocess: read-all-as-string check-status: #t))
(def (lock-rejected? thunk)
  (with-catch
    (lambda (failure)
      (let (message (call-with-output-string (cut display-exception failure <>)))
        (and (string-contains message "lock")
             (or (string-contains message "update") (string-contains message "changes")) #t)))
    (lambda () (thunk) #f)))

(def (flake-api-suite call-with-flake-session session-query session-calls)
  (test-suite "libflake-c / CLI strict locking and receiver-local plans"
    (test-case "three rounds: AWS-only then Null, no implicit lock updates"
      (call-with-temporary-directory "agentic-ai-lab-libflake"
        (lambda (temporary)
          ;; Nix rejects symlinked path components (/var -> /private/var on macOS).
          (def directory (path-normalize temporary))
          (def reference (string-append "path:" (path-normalize directory)))
          (def flake (path-expand "flake.nix" directory))
          (def lock (path-expand "flake.lock" directory))
          (def stamp (path-expand "stamp.nix" directory))
          (def policy-directory (path-expand "policy" directory))
          (create-directory policy-directory)
          (write-input (path-expand "flake.nix" policy-directory)
            "{ outputs = { self }: { label = \"locked\"; }; }")
          (write-input stamp "1")
          (def text
            (string-append "{ inputs.policy.url = \"path:" policy-directory "\"; "
              "outputs = { self, policy }: { lib.providerArtifacts = "
              (provider-expression directory) "; }; }"))
          (write-input flake text)
          ;; Explicit package preparation is allowed to create the fixture lock.
          ;; Every measured evaluation below is check-only.
          (cli-run (list "--extra-experimental-features" "nix-command flakes"
                         "flake" "lock" reference))
          (def lock-bytes (module-source-read lock))
          ;; Overrides must themselves be locked. Derive the fixture reference
          ;; from Nix's actual lock, rather than granting unlocked inputs.
          (def locked-policy
            (let* ((document (call-with-input-string lock-bytes
                               (cut read-json <> (JSONReadOptions key-as-symbol: #t object-as-hash: #t))))
                   (entry (hash-ref (hash-ref (hash-ref document 'nodes) 'policy) 'locked)))
              (string-append "path:" (hash-ref entry 'path)
                "?narHash=" (hash-ref entry 'narHash)
                "&lastModified=" (number->string (hash-ref entry 'lastModified)))))
          (def observations
            (append (observe-inputs directory)
                    (list (cons flake (module-source-read flake))
                          (cons lock lock-bytes)
                          (cons (path-expand "flake.nix" policy-directory)
                                (module-source-read (path-expand "flake.nix" policy-directory))))))
          (def aws (demand AwsOnly))
          (def both (demand AwsNull))
          (def (cli input)
            (checked-query observations
              (lambda ()
                (cli-run
                  (list "--extra-experimental-features" "nix-command flakes"
                        "eval" "--impure" "--raw" "--no-update-lock-file"
                        "--apply" (string-append "f: f " (json->string input))
                        (string-append reference "#lib.providerArtifacts"))))))
          (def (round number)
            (def (cli-round)
              (let* ((parent (timed 'flake-cli number 'aws-cold (cut cli aws)))
                     (hot (timed 'flake-cli number 'aws-hot (cut cli aws)))
                     (child (timed 'flake-cli number 'null-cold (cut cli both)))
                     (child-hot (timed 'flake-cli number 'null-hot (cut cli both))))
                (assert 'flake-cli-parent-hot (equal? parent hot))
                (assert 'flake-cli-child-hot (equal? child child-hot))
                (cons parent child)))
            (def early-cli (and (even? number) (cli-round)))
            (def start (real-time))
            (call-with-flake-session reference directory "lib.providerArtifacts" (.o)
              (lambda (session)
                (displayln "NIX-API-TIMING libflake round=" number
                           " phase=session-open seconds=" (- (real-time) start))
                (force-output)
                (def (query input)
                  (checked-query observations (cut session-query session input)))
                (.def (Parent receiver [])
                  candidate: AwsOnly
                  plan: (query (demand candidate))
                  .preview: (lambda () (checked-query observations (lambda () plan))))
                (def parent (timed 'libflake number 'aws-cold (cut query aws)))
                (assert 'flake-api-parent-hot
                  (equal? parent (timed 'libflake number 'aws-hot (cut query aws))))
                (assert 'flake-parent-plan (equal? parent (.call Parent .preview)))
                (.def (Child @ Parent) candidate: AwsNull)
                (def child (timed 'libflake number 'null-cold (cut query both)))
                (assert 'flake-api-child-hot
                  (equal? child (timed 'libflake number 'null-hot (cut query both))))
                (assert 'flake-child-plan (equal? child (.call Child .preview)))
                (assert 'flake-parent-cache-isolated (equal? parent (.call Parent .preview)))
                (assert 'flake-parent-only-aws (equal? (field parent 'providers) '#("aws")))
                (assert 'flake-child-adds-null (equal? (field child 'providers) '#("aws" "null")))
                (def controls (or early-cli (cli-round)))
                (assert 'flake-matched-parent (equal? parent (car controls)))
                (assert 'flake-matched-child (equal? child (cdr controls)))
                (admit AwsOnly parent)
                (admit AwsNull child)
                (assert 'flake-six-api-calls (= (session-calls session) 6))
                (assert 'lock-file-unchanged (equal? lock-bytes (module-source-read lock)))
                (displayln "NIX-API-COUNTS libflake round=" number
                           " sessions=1 locks=1 api-calls=6 cli-evaluations=4")
                (when (= number 3)
                  (write-input stamp "2")
                  (assert 'flake-warm-parent-source-change-refused
                    (rejected? (lambda () (.call Parent .preview))))
                  (assert 'flake-child-source-change-refused (rejected? (cut query both)))
                  (assert 'flake-cli-source-change-refused (rejected? (cut cli both)))
                  (assert 'flake-source-refused-before-api (= (session-calls session) 6))
                  (call-with-flake-session reference directory "lib.providerArtifacts" (.o)
                    (lambda (fresh)
                      (assert 'flake-fresh-session-reads-change
                        (= (field (session-query fresh aws) 'stamp) 2))))))))
          (round 1) (round 2) (round 3)
          (assert 'reference-fragment-refused
            (with-catch
              (lambda (failure)
                (and (string-contains
                       (call-with-output-string (cut display-exception failure <>))
                       "separate attribute argument") #t))
              (lambda ()
                (call-with-flake-session (string-append reference "#wrong") directory
                  "lib.providerArtifacts" (.o) (lambda (s) (session-query s aws)))
                #f)))
          ;; Same override is accepted; it must not switch strict mode to virtual.
          (call-with-flake-session reference directory "lib.providerArtifacts"
            (.o policy: locked-policy)
            (lambda (session) (assert 'strict-same-override-accepted (string? (session-query session aws)))))
          ;; Adding a dependency requires updating the lock, even with an override.
          (write-input flake
            (string-append "{ inputs.policy.url = \"path:" policy-directory "\"; "
              "inputs.new.url = \"path:" policy-directory "\"; "
              "outputs = { self, policy, new }: { lib.providerArtifacts = "
              (provider-expression directory) "; }; }"))
          (assert 'native-strict-update-refused
            (lock-rejected?
              (lambda () (call-with-flake-session reference directory "lib.providerArtifacts" (.o)
                           (lambda (s) (session-query s aws))))))
          (assert 'native-strict-override-still-refuses-update
            (lock-rejected?
              (lambda () (call-with-flake-session reference directory "lib.providerArtifacts"
                           (.o policy: locked-policy)
                           (lambda (s) (session-query s aws))))))
          (assert 'cli-strict-update-refused
            (lock-rejected?
              (lambda () (cli-run (list "--extra-experimental-features" "nix-command flakes"
                                       "eval" "--impure" "--raw" "--no-update-lock-file"
                                       (string-append reference "#lib.providerArtifacts"))))))
          (assert 'failed-lock-never-written (equal? lock-bytes (module-source-read lock))))))))
