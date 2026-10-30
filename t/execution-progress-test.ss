;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :agentic-ai-lab/modules/nix/progress make-nix-progress-reader) (rename-in (only-in :agentic-ai-lab/modules/nix/progress make-nix-test-progress-reader) (make-nix-test-progress-reader make-test-progress-reader)) :std/test :clan/poo/object
        (except-in :yuanxu/ops/progress make-test-progress-reader)
        (only-in :yuanxu/ops/process-script ProcessScript.)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case
                 yuanxu-default-testing-case-profile)
        (only-in :yuanxu/observability/memory
                 YuanxuDebugDurationAnomaly? YuanxuDebugDurationAnomaly-receipt)
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :std/os/signal kill)
        (only-in :std/error Error? Error-message Error-irritants)
        (only-in :gerbil/runtime/system gerbil-home)
        (only-in :std/os/error os-error? OSError-errno ESRCH))
(export execution-progress-test)
(def scheme-runtime (path-expand "bin/gsc" (gerbil-home)))
(def start "@nix {\"action\":\"start\",\"id\":7,\"type\":101}")
(def (done n)
  (string-append "@nix {\"action\":\"result\",\"id\":7,\"type\":105,\"fields\":["
                 (number->string n) ",100,1,0]}"))
(def (program lines)
  `(begin
     ,@(map (lambda (line) `(begin (display ,line) (newline) (force-output) (thread-sleep! 0.1))) lines)))
(def (idle-failure? failure)
  (and (Error? failure) (string=? (Error-message failure) "Ops execution budget exceeded")
       (equal? (Error-irritants failure) '(idle))))
(def execution-progress-test
  (test-suite "Shared execution progress, idle deadline and finite total"
    (yuanxu-test-case "declared budgets reject infinity before execution"
      (check-exception (call-with-execution-progress +inf.0 1000 void) error?)
      (check-exception (call-with-execution-progress 1000 +inf.0 void) error?)
      (.def (Invalid @ ProcessScript.) command: '("true") timeout: +inf.0)
      (check-exception (.call Invalid .run) error?))
    (yuanxu-test-case "native counters advance; duplicate logs, expectations and replays do not"
      (def now 0)
      (call-with-execution-progress 100 1000
        (lambda (state)
          (def read-progress (make-nix-progress-reader))
          (read-progress start)
          (set! now 50)
          (read-progress (done 1))
          (set! now 110)
          (read-progress (done 1))
          (read-progress "@nix {\"action\":\"msg\",\"msg\":\"still building\"}")
          (read-progress "@nix {\"action\":\"result\",\"id\":7,\"type\":106,\"fields\":[101,999]}")
          (check-equal? (execution-progress-status state) #f)
          (set! now 151)
          (check-equal? (execution-progress-status state) 'idle)
          (read-progress (done 2))
          (check-equal? (execution-progress-status state) 'idle))
        clock: (lambda () now))
      (set! now 0)
      (call-with-execution-progress 100 1000
        (lambda (state)
          (def read-progress (make-nix-progress-reader))
          (read-progress start)
          (set! now 10)
          (read-progress "@nix {\"action\":\"stop\",\"id\":7}")
          (set! now 60)
          (read-progress start)
          (read-progress "@nix {\"action\":\"stop\",\"id\":7}")
          (set! now 111)
          (check-equal? (execution-progress-status state) 'idle))
        clock: (lambda () now)))
    (yuanxu-test-case "native observations share decoding but never renew liveness"
      (def now 0)
      (def observations 0)
      (call-with-execution-progress 100 1000
        (lambda (state)
          (def read-progress
            (make-nix-progress-reader observe:
              (lambda (_record) (set! observations (+ observations 1)))))
          (read-progress start)
          (set! now 90)
          (read-progress "@nix {\"action\":\"msg\",\"msg\":\"performing daemon worker op: 11\"}")
          (check-equal? observations 2)
          (set! now 101)
          (check-equal? (execution-progress-status state) 'idle))
        clock: (lambda () now))
      (check-exception (make-nix-progress-reader observe: 'invalid) error?))
    (yuanxu-test-case "relayed progress has a boundary after unterminated stdout"
      (def now 0)
      (def wire
        (call-with-output-string
          (lambda (port)
            (parameterize ((current-error-port port) (current-execution-progress '()))
              (display "unterminated" port)
              (call-with-execution-progress 2000 3000
                (lambda (_state) (set! now 1500) (execution-progress! 'completed 1))
                clock: (lambda () now))))))
      (check-equal? (string-prefix? "unterminated\n@yuanxu-progress " wire) #t))
    (yuanxu-test-case "progress never extends the total budget or replays worker evidence"
      (def now 0)
      (call-with-execution-progress 100 300
        (lambda (state)
          (def read-progress (make-test-progress-reader))
          (for-each (lambda (n)
                      (set! now (* n 80))
                      (read-progress (string-append "@yuanxu-progress [\"worker\","
                                                   (number->string n) "]")))
                    '(1 2 3))
          (set! now 301)
          (read-progress "@yuanxu-progress [\"worker\",4]")
          (check-equal? (execution-progress-status state) 'total))
        clock: (lambda () now)))
    (yuanxu-test-case "Ops keeps genuine progress alive past idle and rejects a noisy stall"
      (.def (Transfer @ ProcessScript.)
        timeout: 5 idle-timeout: 0.6 progress: make-nix-progress-reader
        command: (list scheme-runtime "-:max-heap=2G,debug=q" "-e"
                   (object->string (program (cons start (map done '(1 2 3 4 5 6 7 8 9 10)))))))
      (def parent (.cc yuanxu-default-testing-case-profile
                     'emit? #f 'max-idle-milliseconds 600 'max-duration-milliseconds 5000))
      (defvalues (receipt _memory)
        (.call parent .run parent "parent follows child progress"
          (lambda () (.call Transfer .run))))
      (check-equal? (.get receipt status) 0)
      (.def (Repeated @ Transfer)
        command: (list scheme-runtime "-:max-heap=2G,debug=q" "-e"
                   (object->string (program (cons start (make-list 30 (done 1)))))))
      (check-exception (.call Repeated .run) idle-failure?))
    (yuanxu-test-case "Case idle guard stays active when observation emission is disabled"
      (def policy (.cc yuanxu-default-testing-case-profile
                     'emit? #f 'max-idle-milliseconds 100 'max-duration-milliseconds 2000))
      (check-exception
        (.call policy .run policy "idle, no output" (lambda () (thread-sleep! 1)))
        YuanxuDebugDurationAnomaly?))
    (yuanxu-test-case "Case reports its triggering idle budget inside a nested progress extent"
      (def policy (.cc yuanxu-default-testing-case-profile
                     'emit? #f 'max-idle-milliseconds 100 'max-duration-milliseconds 2000))
      (check-exception
        (.call policy .run policy "outer idle, inner still current"
          (lambda ()
            (call-with-execution-progress 1000 2000
              (lambda (_inner) (thread-sleep! 1)))))
        (lambda (failure)
          (and (YuanxuDebugDurationAnomaly? failure)
               (let (receipt (YuanxuDebugDurationAnomaly-receipt failure))
                 (and (eq? (.get receipt reason) 'idle-exceeded)
                      (= (.get receipt limit-milliseconds) 100)))))))
    (yuanxu-test-case "Ops idle cancellation cleans up its owned descendants"
      (call-with-temporary-directory "progress-cleanup"
        (lambda (root)
          (def file (path-expand "child.pid" root))
          (.def (Stalled @ ProcessScript.)
            timeout: 5 idle-timeout: 0.5 progress: make-test-progress-reader
            ;; Only Gambit OS primitives are exercised. -e evaluates this
            ;; expression without compiling files or loading Gerbil's expander.
            command: (list scheme-runtime "-:max-heap=2G,debug=q" "-e"
              (object->string
                `(let ((child (open-process '(path: "sleep" arguments: ("10") stdin-redirection: #f))))
                   (call-with-output-file ,file (lambda (port) (write (process-pid child) port)))
                   (thread-sleep! 10)))))
          (check-exception (.call Stalled .run) idle-failure?)
          (check-equal? (file-exists? file) #t)
          (def pid (call-with-input-file file read))
          (def (gone?)
            (with-catch (lambda (e) (if (and (os-error? e) (= (OSError-errno e) ESRCH)) #t (raise e)))
              (lambda () (kill pid 0) #f)))
          (let wait ((left 100))
            (cond ((gone?) (check-equal? #t #t))
                  ((zero? left) (check-equal? (gone?) #t))
                  (else (thread-sleep! 0.01) (wait (- left 1))))))))))
