;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; ASP owns paid-batch selection, single-attempt measurement and Scheme receipts.
(import (only-in :asp-gerbil-scheme/benchmark-api benchmark-elapsed-ms)
        (only-in :std/misc/process run-process/batch)
        (only-in :std/misc/ports read-all-as-u8vector)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :poo-flow/modules/workflow/runtime/scheme-wire scheme-wire-read))
(export main main-with-cases)
(def (file-digest path)
  (hex-encode (sha256 (call-with-input-file path read-all-as-u8vector))))
(def default-cases '("release-necessary" "medication-necessary" "release-budget" "medication-unknown"))
(def (save path receipt)
  (call-with-output-file path (lambda (port) (write receipt port) (newline port))))
(def (main . args)
  (apply main-with-cases (cons default-cases args)))
(def (main-with-cases cases . args)
  (unless (and (list? cases) (pair? cases) (<= (length cases) 4) (andmap string? cases))
    (error "one to four explicit frozen model cases required"))
  (unless (= (length args) 6)
    (error "arguments: PYTHON BINARY LIBRARY ORACLE ENV-FILE NEW-OUTPUT-DIRECTORY"))
  (let* ((python (list-ref args 0)) (binary (list-ref args 1))
         (library (list-ref args 2)) (oracle (list-ref args 3))
         (env-file (list-ref args 4)) (output (list-ref args 5))
         (adapter "packages/python-runtime/tools/deepseek_adapter.py")
         (paths (append (list binary library oracle adapter
                      "t/qualification/temporal-model-native/scenario.ss"
                      "t/qualification/temporal-physical-native/model-scenario.ss"
                      "packages/python-testing/src/poo_flow_testing/model_study/semantic_provider.py"
                      "packages/python-testing/src/poo_flow_testing/model_study/semantic_plan.py"
                      "packages/python-runtime/src/poo_flow_runtime/scheme_wire.py")
                        (if (getenv "POO_FLOW_MODEL_PHYSICAL_RECEIPT" #f)
                          (list (getenv "POO_FLOW_MODEL_PHYSICAL_RECEIPT")) [])))
         (freeze (map (lambda (path) (cons path (file-digest path))) paths))
         (records []))
    ;; Existing output is a paid-batch claim: never overwrite or retry it.
    (create-directory output)
    (save (path-expand "plan.ss" output)
          `((schema . poo-flow.asp-temporal-model-plan.v1)
            (measurement-owner . asp-gerbil-scheme/benchmark-api)
            (cases . ,cases) (maximum-provider-calls . ,(* 2 (length cases))) (retries . 0)
            (content-idle-seconds . 5) (artifact-freeze . ,freeze)))
    (for-each
     (lambda (name)
       (let* ((receipt-path (path-expand (string-append name ".ss") output))
              (passed #t)
              (failure #f)
              (elapsed-ms
               (benchmark-elapsed-ms
                (lambda ()
                  (with-catch
                   (lambda (exception)
                     (set! passed #f)
                     (set! failure 'provider-adapter-failed)
                     (displayln "MODEL-CASE-FAILED " name))
                   (lambda ()
                     (run-process/batch
                      (list python adapter "--binary" binary "--library" library
                            "--oracle" oracle "--env-file" env-file
                            "--case" name "--output" receipt-path))))))))
         (when passed
           (let (result (scheme-wire-read
                        (utf8->string (call-with-input-file receipt-path read-all-as-u8vector))))
             (unless (eq? (hash-get result "passed") #t) (set! passed #f))))
         (set! records (cons `((case . ,name) (passed . ,passed)
                              (elapsed-ms . ,elapsed-ms) (failure . ,failure)) records))
         (save (path-expand "receipt.ss" output)
               `((schema . poo-flow.asp-temporal-model-progress.v1)
                 (measurement-owner . asp-gerbil-scheme/benchmark-api)
                 (cases . ,(reverse records))))
         (displayln "ASP-MODEL-CASE " name " passed=" passed)
         (force-output))) cases)
    (let* ((intact (equal? freeze (map (lambda (path) (cons path (file-digest path))) paths)))
           (passed (and intact (andmap (lambda (r) (cdr (assq 'passed r))) records))))
      (save (path-expand "receipt.ss" output)
            `((schema . poo-flow.asp-temporal-model-acceptance.v1)
              (measurement-owner . asp-gerbil-scheme/benchmark-api)
              (maximum-provider-calls . ,(* 2 (length cases))) (retries . 0)
              (freeze-intact . ,intact) (passed . ,passed)
              (cases . ,(reverse records))))
      (unless passed (exit 1)))))
