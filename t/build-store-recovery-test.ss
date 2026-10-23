;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; The orchestrator retains a selected store path, NEVER a Core issuance map.
(import :std/test :clan/poo/object
        (only-in :yuanxu/t/qualification/build-publication/projection write-artifact-bytes)
        (only-in :std/string/path path-force-extension)
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :std/misc/ports read-all-as-u8vector)
        (only-in :std/encoding/json write-json)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :yuanxu/ops/func run-script)
        (only-in :yuanxu/ops/config Config)
        (only-in :yuanxu/observability/testing-fixture yuanxu-test-fixture)
        (only-in :yuanxu/ops/progress execution-progress!)
        (only-in :yuanxu/t/qualification/service-publication/fixtures DirectoryFixture write-source)
        :yuanxu/t/qualification/build-publication/store)
(export build-store-recovery-test test-cleanup!)
(def observations '())
(def completed 0)
(def (observed-result output (prefix "STORE-RESULT "))
  (def line (find (cut string-prefix? prefix <>) (string-split output #\newline)))
  (unless line (error "worker did not report its actual decision"))
  (call-with-input-string (substring line (string-length prefix) (string-length line)) read))
(def (execute argv)
  (.get (run-script (.cc Config command: argv timeout: 120)
                    output-port: (current-error-port)) output))
(def (bytes path) (call-with-input-file path read-all-as-u8vector))
(def build-store-recovery-test
 (test-suite "Core recovery from a selected Nix publication"
  (yuanxu-test-fixture "issuer exits; restarted readers preserve release association"
   (fixture DirectoryFixture)
   (with-slots (root) fixture
    (def completed-processes 0)
    (def (run argv)
      (begin0 (execute argv)
        ;; Native progress uses monotone totals. Repeating phase=1 is correctly
        ;; deduplicated; only a genuinely completed checked process advances.
        (set! completed-processes (+ completed-processes 1))
        (execution-progress! 'completed-recovery-processes completed-processes)))
    (def output (run (list "just" "-f" "t/qualification/nix/Justfile" "store-producer" root)))
    (def prefix "CORE-STORE-ROOT ")
    (def line (find (cut string-prefix? prefix <>) (string-split output #\newline)))
    (unless line (error "producer did not publish a store root"))
    (def selected (substring line (string-length prefix) (string-length line)))
    ;; At this point BOTH issuer processes have exited and no handoff pipe is
    ;; alive. Only the selected release pin and Nix's registered bytes persist.
    (def identity (string-append
      (symbol->string (cadr (call-with-input-file (path-expand "gerbil.pkg" root) read))) "/probe"))
    (def lib (path-expand "lib" root))
    (def packet (call-with-input-file (path-expand "issuance.ss" selected) read))
    (def record (list-ref packet 5))
    (def binary (path-expand (string-append identity "~0.o1") lib))
    (def (worker label mode candidate marker accepted?)
      (def actual (run (list "just" "-f" "t/qualification/nix/Justfile" "store-worker" root lib identity mode record selected candidate)))
      (check-equal? (not (not (string-contains actual marker))) #t)
      (def decision (observed-result actual
        (if (equal? mode "joint") "STORE-ATTACK-RESULT " "STORE-RESULT ")))
      (check-equal? decision accepted?)
      (set! observations (cons (vector label decision) observations))
      (displayln "STORE-CONTROL-COMPLETED " label))
    (worker "restart-one" "warm" selected "HANDOFF-WARM-OK" #t)
    (worker "restart-two" "warm" selected "HANDOFF-WARM-OK" #t)
    (worker "hot-joint" "joint" selected "HANDOFF-JOINT-REFUSED" #f)
    (def static-path (path-expand
      (path-force-extension
        (string-append "static/" (string-join (string-split identity #\/) "__")) ".scm") lib))
    (def static-bytes (bytes static-path))
    (dynamic-wind
      (cut delete-file static-path)
      (cut worker "missing-static" "recover-reject" selected
        "STORE-REFUSED build-required: selected compiler static output is missing" #f)
      (cut put static-path static-bytes))
    (call-with-temporary-directory "core-linked-issuance"
      (lambda (directory)
        (create-symbolic-link record (path-expand "issuance.ss" directory))
        (def linked (store-add directory))
        (store-verify linked)
        (def actual (run (list "just" "-f" "t/qualification/nix/Justfile" "store-worker" root lib identity "recover-reject"
                              record linked linked)))
        (check-equal? (not (not (string-contains actual
          "STORE-REFUSED stored Core issuance must be a regular file"))) #t)
        (def decision (observed-result actual))
        (check-equal? decision #f)
        (set! observations (cons (vector "symlink" decision) observations))))
    (def original (bytes binary))
    (def old-record (bytes record))
    (def record-data (call-with-input-file record read))
    (dynamic-wind
      (lambda ()
        (write-artifact-bytes binary #u8(0))
        (call-with-output-file (list path: record truncate: #t)
          (lambda (port)
            (write (list (car record-data) (cadr record-data)
              (map (lambda (row) (if (equal? (car row) binary)
                (cons binary (hex-encode (sha256 #u8(0)))) row)) (caddr record-data))) port))))
      (lambda ()
        (worker "mutable-joint" "recover-reject" selected
                "STORE-REFUSED Core build issuance record changed" #f)
        ;; A coherently forged packet can itself be valid Nix data. Register it
        ;; rather than claiming Nix alone forbids every malicious publication.
        (call-with-temporary-directory "core-substitute-release"
          (lambda (directory)
            (def forged (list (car packet) (cadr packet) (caddr packet) lib
              (map (lambda (row) (if (equal? (car row) binary)
                (cons binary (hex-encode (sha256 #u8(0)))) row)) (list-ref packet 4))
              record (hex-encode (sha256 (bytes record)))))
            (call-with-output-file (path-expand "issuance.ss" directory) (cut write forged <>))
            (def substitute (store-add directory))
            (store-verify substitute)
            (worker "other-store" "recover-reject" substitute
                    "STORE-REFUSED Nix release differs from selected publication" #f)
            ;; Deliberately omit trusted release selection, holding everything
            ;; else equal. This negative control MUST accept: integrity != origin.
            (def actual (run (list "just" "-f" "t/qualification/nix/Justfile" "store-worker" root lib identity "unanchored"
                                  record substitute substitute)))
            (check-equal? (not (not (string-contains actual "UNANCHORED-ACCEPTED"))) #t)
            (def decision (observed-result actual))
            (check-equal? decision #t)
            (set! observations (cons (vector "unanchored" decision) observations)))))
      (lambda () (write-artifact-bytes binary original) (write-artifact-bytes record old-record)))
    ;; Last destructive source control: no timestamp reset and no later warm
    ;; compilation that could produce an additional native object generation.
    (def source (path-expand "probe.ss" root))
    (def source-bytes (bytes source))
    (dynamic-wind
      (cut write-source source "(export answer) (def answer 99)\n")
      (cut worker "source-change" "recover-reject" selected
        "STORE-REFUSED Core build handoff does not match selected projection" #f)
      (cut put source source-bytes))
    (set! completed (+ completed 1))))))
(def (test-cleanup!)
  (check-equal? completed 1)
  (let (trace (getenv "CORE_BUILD_STORE_TRACE" #f))
    (when trace
      (call-with-output-file (list path: trace truncate: #t)
        (lambda (port) (write-json port (list->vector (reverse observations)))))))
  (displayln "CORE-STORE-RECOVERY: restarted readers, joint substitution and source refusal"))
