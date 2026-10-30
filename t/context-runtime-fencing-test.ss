;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Real independent Actors/connections share one local durable authority.
(import (only-in :clan/poo/object .o .ref)
        :agentic-ai-lab/modules/temporal-causality/runtime/durable-journal)
(export runtime-fencing-probe)

(def (ensure value message) (unless value (error message)))

(def (runtime-fencing-probe path)
  (let (caller (current-thread))
    (def (start-owner original?)
      (let (actor
             (thread-start! (make-thread
               (lambda ()
                 (let (journal (journal-open path))
                   (when original? (journal-evidence! journal "original" "source-bytes"))
                   (thread-send caller (journal-epoch journal))
                   (let loop ()
                     (let* ((command (thread-receive))
                            (answer
                              (with-catch (lambda (failure) (list #f failure))
                                (lambda ()
                                  (list #t
                                    (case command
                                      ((old-write) (journal-evidence! journal "late-original" "obsolete"))
                                      ((new-write) (journal-evidence! journal "successor" "fresh"))
                                      ((inspect)
                                       (and (equal? (journal-get journal "original" #t) "source-bytes")
                                            (not (journal-get journal "late-original" #t))
                                            (equal? (journal-get journal "successor" #t) "fresh")))
                                      ((close) (journal-close! journal))
                                      (else (error "Unknown fencing probe command"))))))))
                       (thread-send caller answer)
                       (if (eq? command 'close) 'owner-closed (loop)))))))))
        (values actor (thread-receive 10 'start-timeout))))
    (def (ask actor command)
      (thread-send actor command)
      (let (answer (thread-receive 10 'reply-timeout))
        (ensure (pair? answer) "Fencing Actor did not answer")
        answer))
    (let-values (((old-owner old-epoch) (start-owner #t)))
      (let-values (((new-owner new-epoch) (start-owner #f)))
        (let* ((old-result (ask old-owner 'old-write))
               (new-result (ask new-owner 'new-write))
               (inspection (ask new-owner 'inspect)))
          ;; Always close/join both native Actors before admitting the outcome.
          ;; The pre-fix control therefore detects the retained lock itself.
          (ensure (car (ask old-owner 'close)) "Old journal did not close")
          (ensure (car (ask new-owner 'close)) "New journal did not close")
          (for-each (lambda (actor)
            (ensure (eq? (thread-join! actor 2 'join-timeout) 'owner-closed) "Fencing owner did not join"))
            (list old-owner new-owner))
          (displayln "OWNER-FENCE old-epoch=" old-epoch " new-epoch=" new-epoch
            " stale-refused=" (not (car old-result)) " successor-progress=" (car new-result))
          (ensure (> new-epoch old-epoch) "Authority takeover did not advance the real epoch")
          (ensure (not (car old-result)) "Superseded owner wrote new evidence")
          (ensure (car new-result) "Refused old owner retained the successor's write lock")
          (ensure (and (car inspection) (cadr inspection)) "Original evidence or successor write changed")
          (displayln "MODULE-OK t/context-runtime-fencing-test.ss")
          (displayln "HARNESS-OK context-runtime-fencing")
          (displayln "OK"))))))
