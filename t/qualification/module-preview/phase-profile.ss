;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Explicit diagnostic-build qualification, not a production test dependency.
;;; Uses the SAME complete cold/hot/fresh suite; never manufactures read records.
(import :std/test :clan/poo/object
        (only-in :std/test/base test-suite! TestResult-result)
        (only-in :std/list/list every)
        (only-in :clan/poo/slot-observation without-observation slot-read-dependencies)
        (only-in :yuanxu/observability/memory yuanxu-debug-memory-snapshot)
        (only-in :yuanxu/module-system/source/admission current-module-source-phase)
        (only-in :agentic-ai-lab/t/qualification/module-preview/process-accounting
                 process-accounting-sample)
        (only-in :agentic-ai-lab/t/module-preview-cost-test module-preview-cost-test))
(extern namespace: clan/poo/object
  current-issued-replay-probe require-object-read-route! object-issued-read-current?)
(extern namespace: yuanxu/module-system/source/admission current-module-source-operation-times)
(export replay-phase-profile-test test-cleanup!)

(def root-ids (make-table test: eq? weak-keys: #t))
(def owners (make-table test: eq? weak-keys: #t))
(def records (make-table test: eq? weak-keys: #t))
(def sampled (make-hash-table-eqv))
(def metrics (make-hash-table))
(def active-root (make-parameter #f))
(def active-stage (make-parameter 'none))
(def active-counter (make-parameter #f))
(def next-id 0)
(def (add kind amount)
  (hash-update! metrics (list (active-root) (active-stage) kind) (cut + <> amount) 0))
(def (measured stage action)
  (def failed? #f)
  (def failure #f)
  ;; One fixed counter per BATCH. Per-record hash keys would allocate in the
  ;; observer and induce GC/projection eviction, contaminating the workload.
  (def counter (vector 0))
  (def usage-before (process-accounting-sample))
  (def processor-before (##current-processor-id))
  (def stats
    (parameterize ((active-stage stage) (active-counter counter))
      (##exec-stats
        (lambda ()
          (with-catch
            (lambda (cause) (set! failed? #t) (set! failure cause) '())
            (lambda () (call-with-values action list)))))))
  (def usage-after (process-accounting-sample))
  (def processor-after (##current-processor-id))
  ;; Never retain result/closures in a metric: acquisition returns private
  ;; owners/projections, which must remain collectible after this frame ends.
  (hash-update! metrics (list (active-root) stage 'samples) (cut + <> 1) 0)
  (hash-update! metrics (list (active-root) stage 'issuance-calls)
    (cut + <> (vector-ref counter 0)) 0)
  ;; Endpoint changes detect SOME migrations, not a no-migration certificate.
  (unless (= processor-before processor-after)
    (hash-update! metrics (list (active-root) stage 'processor-endpoint-changes)
      (cut + <> 1) 0))
  (when (< (cdr (assq 'bytes-allocated stats)) 0)
    (hash-update! metrics (list (active-root) stage 'invalid-vm-account-samples) (cut + <> 1) 0))
  (for-each
    (lambda (name)
      (hash-update! metrics (list (active-root) stage name)
        (cut + <> (cdr (assq name stats))) 0))
    '(real-time user-time sys-time gc-user-time gc-sys-time gc-real-time
      nb-gcs bytes-allocated minflt majflt))
  (for-each
    (lambda (index name)
      (hash-update! metrics (list (active-root) stage name)
        (cut + <> (- (f64vector-ref usage-after index)
                     (f64vector-ref usage-before index))) 0))
    '(0 1 2 3 4 5)
    '(voluntary-switches involuntary-switches minor-faults major-faults
      block-inputs block-outputs))
  (if failed? (raise failure) (apply values (cdr (assq 'result stats)))))

(def (inspect payload)
  (def id (active-root))
  (def owner (vector-ref payload 1))
  (def reads (vector-ref payload 2))
  (def edges 0)
  (when owner (table-set! owners owner id))
  (unless (hash-key? sampled id)
    (hash-put! sampled id #t)
    (for-each
      (lambda (read)
        (table-set! records read #t)
        (set! edges (+ edges (length (slot-read-dependencies read))))) reads)
    (displayln (object->string (list 'REPLAY-GRAPH id
      (cons 'roots (length (vector-ref payload 0)))
      (cons 'records (length reads)) (cons 'edges edges)
      (cons 'receivers (hash-length (vector-ref payload 3))))))
    ;; These additional batches inspect original records AFTER the original
    ;; final check, still under its actual protected frame. They are NOT new
    ;; production phases, nor additive timing slices of normal replay.
    (without-observation
      (lambda ()
        (measured 'component-issuance
          (lambda () (unless (every object-read-issued? reads) (error "issuance failed"))))
        (measured 'component-route
          (lambda () (for-each require-object-read-route! reads)))
        (measured 'component-live-state
          (lambda () (unless (every object-issued-read-current? reads) (error "state failed"))))
        ;; Same original records and authentication, diagnostic hook disabled.
        ;; This separates measurement-observer allocation from the payload.
        ;; Repetition is a microprobe, NEVER a reused certification verdict.
        (parameterize ((current-issued-replay-probe #f))
          (for-each
            (lambda (_)
              (measured 'component-issuance/quiet
                (lambda () (unless (every object-read-issued? reads)
                             (error "quiet issuance failed")))))
            '(1 2 3 4)))))))

(def (probe event payload)
  (cond
   ((and (pair? event) (eq? (car event) 'reader-replay))
    (if (and (current-module-source-operation-times)
             (eq? (current-module-source-phase) 'graph-current/build-admit-before))
      (let* ((roots (cdr event))
             (id (or (table-ref root-ids roots #f)
                     (begin (set! next-id (+ next-id 1))
                       (table-set! root-ids roots next-id) next-id))))
        (parameterize ((active-root id)) (measured 'reader-total payload)))
      (payload)))
   ((eq? event 'issuance-attempt)
    (let (counter (active-counter))
      (when counter (vector-set! counter 0 (+ (vector-ref counter 0) 1)))))
   ((eq? event 'inspect) (when (active-root) (inspect payload)))
   ((active-root) (measured event payload))
   (else (payload))))

(def replay-phase-profile-test
  (test-suite "Original-record replay phases on a diagnostic runtime build"
    (test-case "same full product workload under runtime phase observation"
      (def result
        (parameterize ((current-issued-replay-probe probe))
          (test-suite! module-preview-cost-test)))
      (check-equal? (TestResult-result result) 'OK)
      (check-equal? (> next-id 0) #t))))

(def (test-cleanup!)
  (hash-for-each
    (lambda (key value) (displayln (object->string (list 'REPLAY-PHASE key value)))) metrics)
  (def memory (yuanxu-debug-memory-snapshot 'replay-probe-released collect?: #t))
  (displayln (object->string (list 'REPLAY-PROBE-RESIDENCY
    (cons 'root-spines (table-length root-ids))
    (cons 'private-owners (table-length owners))
    (cons 'original-records (table-length records))
    (cons 'process-live (.get memory live-bytes))))))
