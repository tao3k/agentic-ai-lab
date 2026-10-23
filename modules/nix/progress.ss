;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (rename-in (only-in :yuanxu/ops/progress make-test-progress-reader) (make-test-progress-reader make-core-test-progress-reader)) (only-in :yuanxu/ops/progress execution-progress! progress-record))
(export make-nix-progress-reader make-nix-test-progress-reader)
(def (field record name) (and (hash-table? record) (hash-get record name)))
(def (make-nix-progress-reader observe: (observe #f))
  (unless (or (not observe) (procedure? observe))
    (error "Nix observation must be a procedure or false"))
  (def activities (make-hash-table))
  (lambda (line)
    (let* (;; Native diagnostic messages cannot advance liveness. A parent
           ;; test already receives the child's progress relay; do not decode
           ;; thousands of diagnostic JSON records there a second time. Keep
           ;; the general decoder for other serializations and activity events.
           (record (and (or observe
                            (not (string-prefix? "@nix {\"action\":\"msg\"," line)))
                        (progress-record line "@nix ")))
           (action (field record 'action)) (id (field record 'id))
           (kind (field record 'type)) (fields (field record 'fields)))
      ;; Reuse THIS decode for observation; observers cannot grant progress.
      (when (and observe (hash-table? record)) (observe record))
      (when (and (exact-integer? id) (>= id 0))
        (cond
         ((and (equal? action "start") (memv kind '(100 101 102 103 104 105 108 109 110 112))
               (< (hash-length activities) 4096))
          ;; Starting an activity is not evidence of completed work.
          (unless (hash-key? activities id) (hash-put! activities id #t)))
         ((and (eq? (hash-get activities id) #t) (equal? action "result")
               (eqv? kind 105) (vector? fields) (> (vector-length fields) 0)
               (exact-integer? (vector-ref fields 0)) (>= (vector-ref fields 0) 0))
          ;; Nix resProgress: done, expected, running, failed. Only done advances.
          (execution-progress! (list 'nix id 'done) (vector-ref fields 0)))
         ((and (eq? (hash-get activities id) #t) (equal? action "result")
               (eqv? kind 104) (vector? fields) (> (vector-length fields) 0)
               (string? (vector-ref fields 0)) (<= (string-length (vector-ref fields 0)) 128))
          (execution-progress! (list 'nix id 'phase (vector-ref fields 0)) 1))
         ((and (eq? (hash-get activities id) #t) (equal? action "stop"))
          (execution-progress! (list 'nix id 'completed) 1)
          ;; Keep the tombstone bounded: replayed starts/stops cannot renew.
          (hash-put! activities id 'completed)))))))

(def (make-nix-test-progress-reader)
  (make-core-test-progress-reader (make-nix-progress-reader)))
