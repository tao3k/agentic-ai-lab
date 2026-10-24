;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Opt-in measurement of the maintained path, not a runner or another publisher.
(import :std/test :clan/poo/object
        (only-in :yuanxu/observability/testing-fixture yuanxu-test-fixture)
        (only-in :agentic-ai-lab/modules/nix/func current-nix-process-completion-observer)
        (only-in :yuanxu/module-system/source/admission current-module-source-observer current-module-source-phase)
        (only-in :yuanxu/observability/debug YuanxuDebugMemoryAnomaly? YuanxuDebugMemoryAnomaly-receipt
                 yuanxu-debug-memory-snapshot)
        (only-in :yuanxu/admission/publication AdmissionPublication.)
        (only-in "./scenarios/aws/fixtures.ss"
                 Workspace prepare-aws-selection! realize-aws-selection))
(export aws-publication-cost-test)
(def aws-publication-cost-test
  (test-suite "Selected AWS publication cost"
    (yuanxu-test-fixture "same Graph and cached provider; Nix versus Scheme cost"
      (root Workspace)
      (def calls (make-hash-table))
      (def nix-seconds 0.)
      (def registrations 0)
      (def queries 0)
      (def realizations 0)
      (def started (real-time))
      (def (phase name)
        (displayln "AWS phase " name ": elapsed=" (- (real-time) started)
                   " nix=" nix-seconds)
        (force-output))
      (parameterize
        ((current-nix-process-completion-observer
           (lambda (argv seconds completed?)
             (hash-update! calls argv 1+ 0)
             (when (or (equal? (path-strip-directory (car argv)) "nix-instantiate")
                       (and (equal? (path-strip-directory (car argv)) "nix")
                            (or (member "--derivation" argv)
                                (and (member "eval" argv) (member "--apply" argv)
                                     (member "--raw" argv)))))
               (if (member "--read-write-mode" argv)
                 (set! registrations (1+ registrations))
                 (set! queries (1+ queries))))
             (when (member "--realise" argv)
               (set! realizations (1+ realizations)))
             (set! nix-seconds (+ nix-seconds seconds))
             (displayln "Nix " (path-strip-directory (car argv)) " repeat=" (hash-ref calls argv)
                        " seconds=" seconds " completed=" completed?
                        " phase=" (current-module-source-phase))
             (force-output))))
        (def fixture (prepare-aws-selection! root))
        (phase 'source)
        (def reads 0)
        (def stages (make-hash-table))
        (def files (make-hash-table))
        (def (source-report)
          (displayln "AWS SOURCE reads=" reads " stages=" (hash->list stages))
          (let loop ((rows (list-sort (lambda (a b) (> (cdr a) (cdr b))) (hash->list files))) (left 5))
            (unless (or (null? rows) (zero? left))
              (displayln "AWS SOURCE FILE " (car rows))
              (loop (cdr rows) (- left 1))))
          (force-output))
        (def selected
          (with-catch
            (lambda (failure)
              (source-report)
              (when (YuanxuDebugMemoryAnomaly? failure)
                (let (receipt (YuanxuDebugMemoryAnomaly-receipt failure))
                  (displayln "AWS MEMORY reason=" (.get receipt reason)
                             " live-growth=" (.get receipt live-growth-bytes))))
              (raise failure))
            (lambda ()
              (parameterize ((current-module-source-observer
                              (lambda (key amount)
                                (when (and (pair? key) (memq (car key) '(publication-start publication-end)))
                                  (let (sample (yuanxu-debug-memory-snapshot (car key)))
                                    (displayln "AWS DECLARATION " key " reads=" reads
                                               " heap=" (.get sample heap-size-bytes)
                                               " live=" (.get sample live-bytes)))
                                  (force-output))
                                (when (and (pair? key) (eq? (car key) 'file-read))
                                  (set! reads (+ reads amount))
                                  (hash-update! stages (cadr key) (cut + <> amount) 0)
                                  (hash-update! files (caddr key) (cut + <> amount) 0)
                                  (when (zero? (modulo reads 2000)) (source-report))))))
                (realize-aws-selection fixture (path-expand "packages" root))))))
        (source-report)
        (phase 'selected)
        (def selected-queries queries)
        (def publication (.call AdmissionPublication. .for-export selected 'aws 'Scenario))
        (phase 'bound)
        (def bound-queries queries)
        (def Parent (.get publication value))
        (def cached (.get Parent resource))
        (.def (Production @ (.get Parent profile)) instance_type: "t3.medium")
        (.def (Release @ Parent) profile: Production)
        (defvalues (evidence next failure) (.call publication .publish Parent Release))
        (phase 'published)
        (check-equal? failure #f)
        (displayln "AWS-PROCESS-COUNTS selected=" selected-queries
                   " bound=" bound-queries " published=" queries
                   " registrations=" registrations " realizations=" realizations)
        ;; Preserve the original total request budget: expression Source used
        ;; one explicit registration plus two/four readonly queries. Flake
        ;; path-info folds registration into its first derivation request.
        (check-equal? selected-queries (+ 1 2))
        (check-equal? bound-queries (+ 1 2))
        ;; The real fixture is a FlakeSource: path-info owns native drv
        ;; registration, with no separate --read-write-mode process.
        (check-equal? registrations 0)
        (check-equal? realizations 1)
        (check-equal? queries (+ 1 4))
        (check-equal? (.get next resource instance_type) "t3.medium")
        (check-equal? (.get cached instance_type) "t3.small")))))
