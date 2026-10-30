;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Phase measurements are qualification projections, not a configuration DSL.
(import :std/test :clan/poo/object "./cases.ss"
        :agentic-ai-lab/bindings/nix-c-api/binding
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :std/misc/process run-process)
        (only-in :std/misc/ports read-all-as-string)
        (only-in :std/string/misc string-trim)
        (only-in :std/encoding/json json->string)
        (only-in :yuanxu/module-system/source/admission module-source-read))
(export profile-test)

(def (cli arguments cache)
  (run-process (append (list "/usr/bin/env" (string-append "XDG_CACHE_HOME=" cache)
                            nix "--extra-experimental-features" "nix-command flakes") arguments)
    stdin-redirection: #f stderr-redirection: #f coprocess: read-all-as-string check-status: #t))
(def (eval-databases cache)
  (let (directory (path-expand "nix" cache))
    (if (file-exists? directory)
      (foldl (lambda (name result)
               (if (string-prefix? "eval-cache-" name)
                 (append result
                   (map (cut path-expand <> (path-expand name directory))
                     (directory-files (path-expand name directory))))
                 result)) '() (directory-files directory))
      '())))
(def (phases session round mode)
  (for-each
    (lambda (phase)
      (let (row (session-timing session phase))
        (assert 'nonnegative-native-phase
          (and (>= (.get row wall) 0) (>= (.get row cpu) 0)))
        (displayln "NIX-PHASE round=" round " mode=" mode " phase=" phase
                   " wall=" (.get row wall) " cpu=" (.get row cpu) " calls=" (.get row calls)
                   " incremental-gc=" (.get row incremental-gc) " metrics=" (.get row metrics))))
    '(initialize store state settings lock outputs apply result)))

(def (force-result session round attribute label)
  (let* ((before (session-timing session 'result))
         (value (timed 'profile-stage round label (cut session-result session attribute)))
         (after (session-timing session 'result)))
    (displayln "NIX-FORCE round=" round " phase=" label
               " wall=" (- (.get after wall) (.get before wall))
               " cpu=" (- (.get after cpu) (.get before cpu))
               " incremental-gc=" (.get after incremental-gc)
               " metrics=" (map - (.get after metrics) (.get before metrics)))
    (force-output)
    value))

(def profile-test
  (test-suite "Flake first-demand attribution and CLI persistent-cache controls"
    (test-case "three matched rounds, baseline versus explicit lazy force points"
      (call-with-temporary-directory "agentic-ai-lab-nix-profile"
        (lambda (temporary)
          (displayln "NIX-METRIC-FIELDS thread-cpu-seconds full-gc-milliseconds gc-cycles allocated-bytes minor-faults major-faults input-blocks output-blocks voluntary-switches involuntary-switches")
          (def base (path-normalize temporary))
          (def directory (path-expand "project" base))
          (def cache (getenv "XDG_CACHE_HOME"))
          (create-directory directory)
          (def reference (string-append "path:" directory))
          (def flake (path-expand "flake.nix" directory))
          (def lock (path-expand "flake.lock" directory))
          (def stamp (path-expand "stamp.nix" directory))
          (def policy-directory (path-expand "policy" base))
          (create-directory policy-directory)
          (def policy-source (path-expand "flake.nix" policy-directory))
          (write-input policy-source "{ outputs = { self }: {}; }")
          (write-input stamp "1")
          ;; Prepared once by the existing product qualification owner. Both
          ;; backends inherit the same fresh cache directory before startup.
          (def package-set (getenv "AGENTIC_AI_LAB_NIX_PROFILE_PACKAGE_SET"))
          (assert 'prepared-package-is-store-path
            (and (string-prefix? "/nix/store/" package-set) (file-exists? package-set)))
          (write-input flake
            (string-append "{ inputs.policy.url = \"path:" policy-directory "\"; "
              "outputs = { self, policy }: { lib = (" (provider-exports directory)
              ") // { prepared = " (provider-exports directory (json->string package-set)) "; }; }; }"))
          (cli (list "flake" "lock" reference) cache)
          (def observations
            (append (observe-inputs directory)
                    (list (cons flake (module-source-read flake))
                          (cons lock (module-source-read lock))
                          (cons policy-source (module-source-read policy-source)))))
          (def aws (demand AwsOnly))
          (def both (demand AwsNull))
          (def (cli-query input option (attribute "lib.providerArtifacts") (checks observations))
            (checked-query checks
              (lambda ()
                (cli (list "eval" "--impure" "--raw" "--no-update-lock-file"
                           "--option" "eval-cache" option
                           "--apply" (string-append "f: f " (json->string input))
                           (string-append reference "#" attribute)) cache))))
          (def cold-probe
            (call-with-flake-session reference directory "lib.diagnostic" (.o)
              (lambda (session)
                (checked-query observations
                  (lambda ()
                    (session-apply! session aws)
                    (assert 'native-cold-source-is-prepared-path
                      (equal? (force-result session 0 "source" "cold-source-resolution") package-set))
                    (force-result session 0 "imports" "cold-imports-whnf")
                    (force-result session 0 "package" "cold-package-whnf")
                    (let (receipt (force-result session 0 "receipt" "cold-derive-and-residual"))
                      (phases session 0 'first-native)
                      receipt))))))
          (def (round number)
            (def (cli-round)
              (let* ((parent (timed 'profile-cli number 'aws-cold (cut cli-query aws "true")))
                     (hot (timed 'profile-cli number 'aws-hot (cut cli-query aws "true")))
                     (child (timed 'profile-cli number 'null-cold (cut cli-query both "true")))
                     (child-hot (timed 'profile-cli number 'null-hot (cut cli-query both "true")))
                     (no-cache (timed 'profile-cli number 'aws-cache-off (cut cli-query aws "false"))))
                (assert 'cli-hot-same (equal? parent hot))
                (assert 'cli-child-hot-same (equal? child child-hot))
                (assert 'cli-cache-toggle-same (equal? parent no-cache))
                (assert 'impure-cli-no-persistent-eval-db (null? (eval-databases cache)))
                (cons parent child)))
            (def (prepared-round)
              (call-with-flake-session reference directory "lib.prepared.providerArtifacts" (.o)
                (lambda (session)
                  (def (query input) (checked-query observations (cut session-query session input)))
                  (def parent (timed 'profile-prepared number 'aws-cold (cut query aws)))
                  (assert 'prepared-input-aws-hot-identical
                    (equal? (timed 'profile-prepared number 'aws-hot (cut query aws)) parent))
                  (def child (timed 'profile-prepared number 'null-cold (cut query both)))
                  (assert 'prepared-input-null-hot-identical
                    (equal? (timed 'profile-prepared number 'null-hot (cut query both)) child))
                  (phases session number 'prepared-input)
                  (cons parent child))))
            (def early-cli (and (even? number) (cli-round)))
            (def early-prepared (and (even? number) (prepared-round)))
            (def baseline
              (call-with-flake-session reference directory "lib.providerArtifacts" (.o)
                (lambda (session)
                  (def (query input)
                    (checked-query observations (cut session-query session input)))
                  (.def (Parent receiver [])
                    candidate: AwsOnly
                    plan: (query (demand candidate))
                    .preview: (lambda () (checked-query observations (lambda () plan))))
                  (def parent (timed 'profile-api number 'aws-cold (cut query aws)))
                  (assert 'api-hot-same
                    (equal? parent (timed 'profile-api number 'aws-hot (cut query aws))))
                  (assert 'parent-plan-same (equal? parent (.call Parent .preview)))
                  (.def (Child @ Parent) candidate: AwsNull)
                  (def child (timed 'profile-api number 'null-cold (cut query both)))
                  (assert 'api-child-hot-same
                    (equal? child (timed 'profile-api number 'null-hot (cut query both))))
                  (assert 'child-plan-same (equal? child (.call Child .preview)))
                  (assert 'parent-still-aws (equal? parent (.call Parent .preview)))
                  (assert 'one-store-per-session (= (.get (session-timing session 'store) calls) 1))
                  (assert 'one-state-per-session (= (.get (session-timing session 'state) calls) 1))
                  (assert 'one-lock-per-session (= (.get (session-timing session 'lock) calls) 1))
                  (phases session number 'baseline)
                  (cons parent child))))
            (def controls (or early-cli (cli-round)))
            (assert 'cold-probe-same-receipt (equal? cold-probe (car baseline)))
            (assert 'matched-baseline-parent (equal? (car baseline) (car controls)))
            (assert 'matched-baseline-child (equal? (cdr baseline) (cdr controls)))
            (def prepared (or early-prepared (prepared-round)))
            (assert 'prepared-input-aws-identical (equal? (car prepared) (car baseline)))
            (assert 'prepared-input-null-identical (equal? (cdr prepared) (cdr baseline)))
            (assert 'prepared-cli-aws-identical
              (equal? (timed 'profile-prepared-cli number 'aws-cold
                        (cut cli-query aws "true" "lib.prepared.providerArtifacts")) (car baseline)))
            (assert 'prepared-cli-null-identical
              (equal? (timed 'profile-prepared-cli number 'null-cold
                        (cut cli-query both "true" "lib.prepared.providerArtifacts")) (cdr baseline)))
            ;; Negative cost control: rebuilding only because the candidate
            ;; gains Null repeats imports. It must yield the SAME receipt.
            (call-with-flake-session reference directory "lib.providerArtifacts" (.o)
              (lambda (session)
                (assert 'fresh-child-matches-reused-session
                  (equal? (timed 'profile-fresh-child number 'null-cold
                            (lambda ()
                              (checked-query observations (cut session-query session both))))
                          (cdr baseline)))
                (phases session number 'fresh-child)))
            ;; Fresh state; native values from one application share the real
            ;; Nix import/constructor thunks. Each stage reports wall/CPU.
            (call-with-flake-session reference directory "lib.diagnostic" (.o)
              (lambda (session)
                (def force-stage (cut force-result session number <> <>))
                (def (staged input label)
                  (checked-query observations
                    (lambda ()
                      (session-apply! session input)
                      (assert 'imports-ready
                        (equal? (force-stage "imports" (string-append label "-imports-whnf")) "ready"))
                      (assert 'package-ready
                        (equal? (force-stage "package" (string-append label "-package-whnf")) "ready"))
                      (force-stage "receipt" (string-append label "-derive-and-residual")))))
                (assert 'staged-aws-identical (equal? (staged aws "aws-cold") (car baseline)))
                (assert 'staged-aws-hot-identical (equal? (staged aws "aws-hot") (car baseline)))
                (assert 'staged-null-identical (equal? (staged both "null-cold") (cdr baseline)))
                (assert 'staged-null-hot-identical (equal? (staged both "null-hot") (cdr baseline)))
                (phases session number 'staged)
                (admit AwsOnly (car baseline))
                (admit AwsNull (cdr baseline))
                (when (= number 3)
                  ;; Cost reuse is not currentness authority. The product's
                  ;; local Flake header observations cover flake.nix/flake.lock,
                  ;; not arbitrary imported files. Model precisely that subset
                  ;; here; this is a negative control, never an accepted path.
                  (let (headers (filter (lambda (row) (member (car row) (list flake lock))) observations))
                    (write-input stamp "2")
                    (let (count (session-calls session))
                      (assert 'staged-source-change-refused (rejected? (cut staged both "stale")))
                      (assert 'stale-before-native-call (= count (session-calls session))))
                    (let* ((cached
                            (checked-query headers
                              (lambda ()
                                (session-apply! session both)
                                (session-result session "receipt"))))
                           (fresh (cli-query both "true" "lib.providerArtifacts" headers)))
                      (assert 'headers-only-reuse-retains-stale-import (= (field cached 'stamp) 1))
                      (assert 'fresh-evaluation-observes-import-change (= (field fresh 'stamp) 2))
                      (assert 'same-lock-does-not-prove-current-imports (not (equal? cached fresh)))))))))
          (round 1) (round 2) (round 3)
          ;; A pure scalar positive control proves cache-directory discovery is
          ;; working; it is not a claim that --apply results are persistent.
          (def pure (path-expand "pure" base))
          (create-directory pure)
          (write-input (path-expand "flake.nix" pure) "{ outputs = { self }: { answer = 42; }; }")
          (cli (list "flake" "lock" (string-append "path:" pure)) cache)
          (assert 'pure-scalar-value
            (equal? (string-trim
                      (cli (list "eval" "--json" "--no-update-lock-file"
                                 (string-append "path:" pure "#answer")) cache)) "42"))
          (assert 'pure-control-creates-eval-db (pair? (eval-databases cache)))
          (displayln "NIX-PROFILE-CACHE impure-eval-dbs=0 pure-control-eval-dbs="
                     (length (eval-databases cache)))
          (assert 'profile-controls-complete #t))))))
