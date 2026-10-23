;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test :clan/poo/object
        (only-in :yuanxu/t/qualification/build-publication/projection write-artifact-bytes)
        (only-in :yuanxu/ops/func run-script)
        (only-in :yuanxu/ops/config Config)
        (only-in :yuanxu/ops/progress execution-progress! make-test-progress-reader)
        (only-in :yuanxu/observability/testing-fixture yuanxu-test-fixture)
        (only-in :yuanxu/t/qualification/service-publication/fixtures DirectoryFixture)
        (only-in :std/encoding/json write-json)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :std/misc/ports read-all-as-u8vector))
(export approved-build-recovery-test test-cleanup!)
(def observations '())
(def completed 0)
(def (bytes path) (call-with-input-file path read-all-as-u8vector))
(def (with-replaced-products root record action)
  (def lib (path-expand "lib" root))
  (def unit (string-append
    (symbol->string (cadr (call-with-input-file (path-expand "gerbil.pkg" root) read))) "/probe~0.o1"))
  (def binary (path-expand unit lib))
  (def original (bytes binary))
  (def old-record (bytes record))
  (def data (call-with-input-file record read))
  (dynamic-wind
    (lambda ()
      (write-artifact-bytes binary #u8(0))
      (call-with-output-file (list path: record truncate: #t)
        (cut write (list (car data) (cadr data)
          (map (lambda (row) (if (equal? (car row) binary)
            (cons binary (hex-encode (sha256 #u8(0)))) row)) (caddr data))) <>)))
    action (lambda () (write-artifact-bytes binary original) (write-artifact-bytes record old-record))))
(def approved-build-recovery-test
  (test-suite "Restart restores approval from selected Module Source"
    (yuanxu-test-fixture "no caller-supplied release pin survives the issuer"
      (fixture DirectoryFixture)
      (with-slots (root) fixture
        (def processes 0)
        (def (run arguments)
          (def output (.get (run-script (.cc Config command: arguments timeout: 120
                                            progress: make-test-progress-reader)
                            output-port: (current-error-port)) output))
          (set! processes (+ processes 1))
          (execution-progress! 'approved-processes processes)
          output)
        (check-equal? (not (not (string-contains
          (run (list "just" "-f" "t/qualification/nix/Justfile" "approved-producer" root)) "APPROVED-SOURCE-PUBLISHED"))) #t)
        ;; Capture the sole original record BEFORE warm workers create their
        ;; own records. This path is fault injection input, never approval.
        (def record (path-expand
          (find (cut string-prefix? ".yuanxu-build-issuance-" <>)
            (directory-files (list path: (path-expand "lib" root) ignore-hidden: #f)))
          (path-expand "lib" root)))
        (for-each
          (lambda (control)
            (def label (car control))
            (def expected (cdr control))
            (def source (path-expand "probe.ss" root))
            (def original (and (equal? label "cold-source") (call-with-input-file source read-line)))
            (def policy (path-expand "modules/building/release/release.nix" root))
            (def original-policy (and (equal? label "cold-omitted") (bytes policy)))
            (def output
              (dynamic-wind
                (lambda ()
                  (when original-policy
                    (write-artifact-bytes policy (bytes (path-expand "omitted-release.nix" (path-directory policy)))))
                  (when original
                    (call-with-output-file (list path: source truncate: #t)
                      (cut display "(export answer) (def answer 99)\n" <>))))
                (lambda ()
                  (def action (cut run (list "just" "-f" "t/qualification/nix/Justfile" "approved-worker" root label)))
                  (if (equal? label "cold-joint") (with-replaced-products root record action) (action)))
                (lambda ()
                  (when original-policy (write-artifact-bytes policy original-policy))
                  (when original
                    (call-with-output-file (list path: source truncate: #t)
                      (cut display (string-append original "\n") <>))))))
            (def prefix (if (equal? label "joint") "STORE-ATTACK-RESULT " "STORE-RESULT "))
            (def line (find (cut string-prefix? prefix <>) (string-split output #\newline)))
            (unless line (error "worker omitted actual approval result" label))
            (def actual (call-with-input-string (substring line (string-length prefix) (string-length line)) read))
            (check-equal? actual expected)
            (set! observations (cons (vector label actual) observations)))
          '(("warm" . #t) ("joint" . #f) ("policy-change" . #f)
            ("warm-policy-change" . #f) ("core-source" . #f) ("cold-source" . #f)
            ("cold-joint" . #f) ("cold-omitted" . #f)))
        (set! completed (+ completed 1))))))
(def (test-cleanup!)
  (unless (= completed 1) (error "approved recovery coverage incomplete" completed))
  (when (getenv "CORE_APPROVED_TRACE" #f)
    (call-with-output-file (list path: (getenv "CORE_APPROVED_TRACE") truncate: #t)
      (cut write-json <> (list->vector (reverse observations)))))
  (displayln "CORE-APPROVED-RECOVERY-OK"))
