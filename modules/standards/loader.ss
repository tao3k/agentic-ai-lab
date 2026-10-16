;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: explicit effectful Standard artifact materialization context.
;;; Invariant: loading is single-flight, content-identity checked and never
;;; hidden behind an ordinary POO lazy slot reference.
(import (only-in :clan/poo/object .o .ref)
        (only-in :std/hash/misc hash-remove!)
        (only-in :core/utilities/functional poo-flow-find)
        "types.ss"
        "objects.ss")

(export poo-flow-standard-materialization-context
        poo-flow-standard-load-source
        poo-flow-standard-materialize
        poo-flow-standard-evict!
        poo-flow-standard-materialization-stats)

(def +poo-flow-standard-unknown-generation+
  "sha256:0000000000000000000000000000000000000000000000000000000000000000")

(def (poo-flow-standard-materialization-context identity-value artifact-refs)
  (unless (and (poo-flow-standard-text? identity-value)
               (list? artifact-refs))
    (error "invalid Standard materialization context" identity-value))
  (let ((artifact-index (make-hash-table))
        (source-states (make-hash-table))
        (sources (make-hash-table))
        (states (make-hash-table))
        (artifacts (make-hash-table))
        (load-receipts (make-hash-table))
        (failures (make-hash-table))
        (active-materializations (make-parameter '()))
        (lock (make-mutex identity-value))
        (changed (make-condition-variable identity-value))
        (load-count 0)
        (materialization-count 0)
        (source-cache-hit-count 0)
        (cache-hit-count 0)
        (wait-count 0)
        (eviction-count 0)
        (artifact-reference-count 0))
    (for-each
     (lambda (artifact-ref)
       (unless (poo-flow-standard-artifact-ref? artifact-ref)
         (error "invalid Standard artifact ref" artifact-ref))
       (let (identity (.ref artifact-ref 'identity))
         ;; Artifact refs are truthy POO objects; one native lookup is enough.
         (when (hash-get artifact-index identity)
           (error "duplicate materialization artifact identity" identity))
         (hash-put! artifact-index identity artifact-ref)
         (set! artifact-reference-count (+ artifact-reference-count 1))))
     artifact-refs)
    (def (current-load-count)
      (mutex-lock! lock)
      (let (count load-count)
        (mutex-unlock! lock)
        count))
    (def (receipt identity artifact outcome load-receipt failures-value executed?)
      (let* ((artifact-ref (hash-get artifact-index identity))
             (generation
              (if artifact-ref (.ref artifact-ref 'generation)
                  +poo-flow-standard-unknown-generation+)))
        (poo-flow-standard-materialization-receipt
         identity artifact outcome generation load-receipt failures-value
         (current-load-count) executed?)))
    (def (terminal-failure identity code detail path)
      (poo-flow-standard-failure code identity detail path))
    (def (publish-source! cache-key source load-receipt state)
      (mutex-lock! lock)
      (when source
        (hash-put! sources cache-key source))
      (hash-put! load-receipts cache-key load-receipt)
      (hash-put! source-states cache-key state)
      (condition-variable-broadcast! changed)
      (mutex-unlock! lock)
      load-receipt)
    (def (load-source-one identity)
      (let loop ()
        (mutex-lock! lock)
        (let* ((artifact-ref (hash-get artifact-index identity))
               (cache-key (and artifact-ref (.ref artifact-ref 'cache-key)))
               (state (and cache-key (hash-get source-states cache-key))))
          (cond
           ((or (eq? state 'loaded) (eq? state 'failed))
            (set! source-cache-hit-count (+ source-cache-hit-count 1))
            (let (load-receipt (hash-get load-receipts cache-key))
              (mutex-unlock! lock)
              load-receipt))
           ((eq? state 'loading)
            (set! wait-count (+ wait-count 1))
            (mutex-unlock! lock changed)
            (mutex-unlock! lock)
            (loop))
           ((not artifact-ref)
            (mutex-unlock! lock)
            (let (failure
                  (terminal-failure
                   identity 'standard-dependency-missing
                   "source artifact was absent from the context"
                   (list identity)))
              (poo-flow-standard-load-receipt
               identity identity +poo-flow-standard-unknown-generation+
               +poo-flow-standard-unknown-generation+ 0 'failed
               (list failure) #f)))
           (else
            (hash-put! source-states cache-key 'loading)
            (mutex-unlock! lock)
            (with-catch
             (lambda (load-error)
               (let* ((failure
                       (terminal-failure
                        identity 'standard-load-failed load-error
                        (list identity)))
                      (load-receipt
                       (poo-flow-standard-load-receipt
                        identity cache-key (.ref artifact-ref 'generation)
                        (.ref artifact-ref 'digest) 0 'failed
                        (list failure) #t)))
                 (publish-source! cache-key #f load-receipt 'failed)))
             (lambda ()
               (let* ((source ((.ref artifact-ref 'source-loader)))
                      (source-valid?
                       (and (poo-flow-standard-artifact-source? source)
                            (string=? (.ref source 'artifact-identity) identity)
                            (string=? (.ref source 'digest)
                                     (.ref artifact-ref 'digest))
                            (eq? (.ref source 'representation)
                                 (.ref artifact-ref 'representation))
                            (= (.ref source 'size-bytes)
                               (.ref artifact-ref 'size-bytes)))))
                 (mutex-lock! lock)
                 (set! load-count (+ load-count 1))
                 (mutex-unlock! lock)
                 (if source-valid?
                   (publish-source!
                    cache-key source
                    (poo-flow-standard-load-receipt
                     identity cache-key (.ref artifact-ref 'generation)
                     (.ref source 'digest) (.ref source 'size-bytes)
                     'loaded '() #t)
                    'loaded)
                   (let* ((failure
                           (terminal-failure
                            identity 'standard-source-digest-mismatch
                            "loaded source identity, digest, representation, or size mismatch"
                            (list identity)))
                          (load-receipt
                           (poo-flow-standard-load-receipt
                            identity cache-key (.ref artifact-ref 'generation)
                            (.ref artifact-ref 'digest) 0 'failed
                            (list failure) #t)))
                     (publish-source!
                      cache-key #f load-receipt 'failed)))))))))))
    (def (publish-failure! identity failure load-receipt)
      (let* ((artifact-ref (hash-get artifact-index identity))
             (cache-key (and artifact-ref (.ref artifact-ref 'cache-key))))
      (mutex-lock! lock)
      (when cache-key
        (hash-put! states cache-key 'failed)
        (hash-put! failures cache-key failure)
        (when load-receipt
          (hash-put! load-receipts cache-key load-receipt)))
      (condition-variable-broadcast! changed)
      (mutex-unlock! lock)
      (receipt identity #f 'failed load-receipt (list failure) #t)))
    (def (load-one/unchecked identity path)
      (if (member identity path)
        (receipt
         identity #f 'failed #f
         (list (terminal-failure
                identity 'standard-dependency-cycle
                "materialization dependency cycle"
                (reverse (cons identity path))))
         #f)
        (let loop ()
          (mutex-lock! lock)
          (let* ((artifact-ref (hash-get artifact-index identity))
                 (cache-key (and artifact-ref (.ref artifact-ref 'cache-key)))
                 (state (and cache-key (hash-get states cache-key))))
            (cond
             ((eq? state 'ready)
              (set! cache-hit-count (+ cache-hit-count 1))
             (let (artifact (hash-get artifacts cache-key))
                (let (load-receipt (hash-get load-receipts cache-key))
                (mutex-unlock! lock)
                (receipt identity artifact 'cache-hit load-receipt '() #f))))
             ((eq? state 'failed)
              (let ((failure (hash-get failures cache-key))
                    (load-receipt (hash-get load-receipts cache-key)))
                (mutex-unlock! lock)
                (receipt identity #f 'failure-cache-hit load-receipt
                         (list failure) #f)))
             ((eq? state 'loading)
              (set! wait-count (+ wait-count 1))
              ;; Gambit's condition wait atomically releases LOCK.  Re-check
              ;; the state after wakeup; it returns with LOCK reacquired, so
              ;; release it before the loop takes the ordinary entry lock.
              (mutex-unlock! lock changed)
              (mutex-unlock! lock)
              (loop))
             ((not artifact-ref)
              (mutex-unlock! lock)
              (receipt
               identity #f 'failed #f
               (list (terminal-failure
                      identity 'standard-dependency-missing
                      "materialization artifact was absent from the context"
                      (reverse (cons identity path))))
               #f))
             (else
              (hash-put! states cache-key 'loading)
              (mutex-unlock! lock)
              (let (dependency-receipts
                    (map (lambda (dependency)
                           (load-one dependency (cons identity path)))
                         (.ref artifact-ref 'dependencies)))
                (let (dependency-failure
                      (poo-flow-find
                       (lambda (candidate)
                         (not (.ref candidate 'valid?)))
                       dependency-receipts))
                  (if dependency-failure
                    (publish-failure!
                     identity
                     (terminal-failure
                      identity 'standard-load-failed
                      (.ref dependency-failure 'failures)
                      (reverse (cons identity path)))
                     #f)
                    (let (load-receipt (load-source-one identity))
                      (if (not (.ref load-receipt 'valid?))
                        (publish-failure!
                         identity (car (.ref load-receipt 'failures)) load-receipt)
                        (with-catch
                         (lambda (materialization-error)
                           (publish-failure!
                            identity
                            (terminal-failure
                             identity 'standard-artifact-invalid
                             materialization-error
                             (reverse (cons identity path)))
                            load-receipt))
                         (lambda ()
                           (mutex-lock! lock)
                           (let (source (hash-get sources cache-key))
                             (mutex-unlock! lock)
                             (let (artifact
                                   (parameterize
                                    ((active-materializations
                                      (cons identity
                                            (active-materializations))))
                                    ((.ref artifact-ref 'materializer) source)))
                               (if (and (poo-flow-standard-artifact? artifact)
                                        (string=? (.ref artifact 'identity) identity)
                                        (string=? (.ref artifact 'digest)
                                                 (.ref artifact-ref 'digest))
                                        (eq? (.ref artifact 'representation)
                                             (.ref artifact-ref 'representation)))
                                 (begin
                                   (mutex-lock! lock)
                                   (set! materialization-count
                                         (+ materialization-count 1))
                                   (hash-put! artifacts cache-key artifact)
                                   (hash-put! states cache-key 'ready)
                                   (condition-variable-broadcast! changed)
                                   (mutex-unlock! lock)
                                   (receipt identity artifact 'materialized
                                            load-receipt '() #t))
                                 (publish-failure!
                                  identity
                                  (terminal-failure
                                   identity 'standard-artifact-invalid
                                   "materializer result identity, digest, or representation mismatch"
                                   (reverse (cons identity path)))
                                  load-receipt)))))))))))))))))
    (def (load-one identity path)
      (if (member identity (active-materializations))
        (receipt
         identity #f 'failed #f
         (list
          (terminal-failure
           identity 'standard-lazy-reentry
           "materializer recursively requested its active artifact"
           (reverse (cons identity (active-materializations)))))
         #f)
        (load-one/unchecked identity path)))
    (def (evict-one! identity)
      (mutex-lock! lock)
      (let* ((artifact-ref (hash-get artifact-index identity))
             (cache-key (and artifact-ref (.ref artifact-ref 'cache-key)))
             (state (and cache-key (hash-get states cache-key)))
             (source-state
              (and cache-key (hash-get source-states cache-key))))
        (cond
         ((or (eq? state 'loading) (eq? source-state 'loading))
          (mutex-unlock! lock)
          #f)
         ((or (eq? state 'ready) (eq? state 'failed)
              (eq? source-state 'loaded) (eq? source-state 'failed))
          (hash-remove! source-states cache-key)
          (hash-remove! sources cache-key)
          (hash-remove! states cache-key)
          (hash-remove! artifacts cache-key)
          (hash-remove! load-receipts cache-key)
          (hash-remove! failures cache-key)
          (set! eviction-count (+ eviction-count 1))
          (mutex-unlock! lock)
          #t)
         (else
          (mutex-unlock! lock)
          #f))))
    (def (stats-value)
      (mutex-lock! lock)
      (let* ((load-count-value load-count)
             (materialization-count-value materialization-count)
             (source-cache-hit-count-value source-cache-hit-count)
             (cache-hit-count-value cache-hit-count)
             (wait-count-value wait-count)
             (eviction-count-value eviction-count)
             (value
             (.o identity: identity-value
                  artifact-ref-count: artifact-reference-count
                  generation-count: artifact-reference-count
                  load-count: load-count-value
                  source-load-count: load-count-value
                  materialization-count: materialization-count-value
                  source-cache-hit-count: source-cache-hit-count-value
                  cache-hit-count: cache-hit-count-value
                  wait-count: wait-count-value
                  eviction-count: eviction-count-value)))
        (mutex-unlock! lock)
        value))
    (.o kind: +poo-flow-standard-materialization-context-kind+
        identity: identity-value
        load-source: load-source-one
        materialize: load-one
        evict!: evict-one!
        stats: stats-value)))

(def (poo-flow-standard-load-source context artifact-identity)
  (unless (poo-flow-standard-materialization-context? context)
    (error "invalid Standard materialization context" context))
  ((.ref context 'load-source) artifact-identity))

(def (poo-flow-standard-materialize context artifact-identity)
  (unless (poo-flow-standard-materialization-context? context)
    (error "invalid Standard materialization context" context))
  ((.ref context 'materialize) artifact-identity '()))

(def (poo-flow-standard-evict! context artifact-identity)
  (unless (poo-flow-standard-materialization-context? context)
    (error "invalid Standard materialization context" context))
  ((.ref context 'evict!) artifact-identity))

(def (poo-flow-standard-materialization-stats context)
  (unless (poo-flow-standard-materialization-context? context)
    (error "invalid Standard materialization context" context))
  ((.ref context 'stats)))
