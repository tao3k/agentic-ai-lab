;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Pure per-stage temporal attempt and predecessor admission. No physical execution.
(import (only-in :clan/poo/object .ref object?)
        (only-in :std/list/list every ormap)
        :core/object-family/role-syntax
        (only-in :poo-flow/modules/search-engine/funs poo-flow-search-stage?))
(export poo-flow-search-attempt-state poo-flow-search-attempt-issue
        poo-flow-search-attempt-settle poo-flow-search-attempt-revise
        poo-flow-search-attempt-retire poo-flow-search-attempt-complete
        poo-flow-search-attempt-ready? poo-flow-search-attempt-issue-ready
        poo-flow-search-attempt-request poo-flow-search-attempt-current?)

(def (kind? value expected)
  (and (object? value)
       (with-catch (lambda (_) #f)
         (lambda () (eq? (.ref value 'kind) expected)))))
(def (text? value) (and (string? value) (> (string-length value) 0)))

(def (poo-flow-search-attempt-state stage generation configuration source-cut)
  (unless (and (poo-flow-search-stage? stage) (text? generation)
               (text? configuration) (text? source-cut))
    (error "invalid Search attempt scope"))
  (poo-core-role-object
   (slots ((kind 'search-attempt-state) (stage stage)
           (generation (string-copy generation))
           (configuration (string-copy configuration))
           (source-cut (string-copy source-cut))
           (revision 0) (next-attempt 0) (active #f) (retired? #f)))
   (supers)))

(def (require-state state)
  (unless (kind? state 'search-attempt-state) (error "expected Search attempt state")))

;;; Reconstruct an inert returned identity as a POO request in the original scope.
(def (poo-flow-search-attempt-request state source-cut revision attempt)
  (require-state state)
  (unless (and (text? source-cut) (integer? revision) (>= revision 0)
               (integer? attempt) (>= attempt 0))
    (error "invalid Search attempt identity"))
  (poo-core-role-object
   (slots ((kind 'search-attempt-request) (stage (.ref state 'stage))
           (generation (string-copy (.ref state 'generation)))
           (configuration (string-copy (.ref state 'configuration)))
           (source-cut (string-copy source-cut)) (revision revision) (attempt attempt)))
   (supers)))

;;; Caller must separately establish DAG readiness and input-evidence validity.
;;; The returned state and request are POO objects, not a public record protocol.
(def (poo-flow-search-attempt-issue state)
  (require-state state)
  (when (or (.ref state 'retired?) (.ref state 'active))
    (error "Search stage is retired or already has an active attempt"))
  (let* ((id (.ref state 'next-attempt))
         (request (poo-core-role-object
           (slots ((kind 'search-attempt-request) (stage (.ref state 'stage))
                   (generation (string-copy (.ref state 'generation)))
                   (configuration (string-copy (.ref state 'configuration)))
                   (source-cut (string-copy (.ref state 'source-cut)))
                   (revision (.ref state 'revision)) (attempt id)))
           (supers)))
         (next (poo-core-role-object
           (slots ((active request) (next-attempt (+ id 1)))) (supers state))))
    (poo-core-role-object
     (slots ((kind 'search-attempt-issue) (state next) (request request)))
     (supers))))

(def (same-request? left right)
  (and (kind? left 'search-attempt-request)
       (kind? right 'search-attempt-request)
       (every (lambda (slot) (equal? (.ref left slot) (.ref right slot)))
              '(stage generation configuration source-cut revision attempt))))

;;; Settlement carries identity admission only, not a candidate or truth guarantee.
(def (poo-flow-search-attempt-current? state request)
  (require-state state)
  (and (not (.ref state 'retired?))
       (same-request? (.ref state 'active) request)
       (every (lambda (slot) (equal? (.ref state slot) (.ref request slot)))
              '(stage generation configuration source-cut revision))))

(def (poo-flow-search-attempt-settle state request)
  (unless (poo-flow-search-attempt-current? state request)
    (error "stale, foreign, duplicate or retired Search attempt"))
  (poo-core-role-object (slots ((active #f))) (supers state)))

;;; Conservative whole-stage invalidation. Old physical obligations stay execution-owned.
(def (poo-flow-search-attempt-revise state source-cut)
  (require-state state)
  (unless (and (not (.ref state 'retired?)) (text? source-cut))
    (error "cannot revise retired Search attempt scope"))
  (poo-core-role-object
   (slots ((source-cut (string-copy source-cut))
           (revision (+ (.ref state 'revision) 1)) (active #f)))
   (supers state)))

(def (poo-flow-search-attempt-retire state)
  (require-state state)
  (poo-core-role-object (slots ((retired? #t))) (supers state)))

;;; Completion is an owner-admitted identity receipt, not proof of result truth.
(def (poo-flow-search-attempt-complete state request)
  (let (done (poo-flow-search-attempt-settle state request))
    (poo-core-role-object
     (slots ((kind 'search-attempt-completion) (state done)
             (request (poo-core-role-object
               (slots ((generation (string-copy (.ref request 'generation)))
                       (configuration (string-copy (.ref request 'configuration)))
                       (source-cut (string-copy (.ref request 'source-cut)))))
               (supers request)))))
     (supers))))

;;; The DAG owner supplies the exact current predecessor requests. Empty means root.
;;; Receipts from a prior generation/configuration cannot satisfy prerequisites.
(def (poo-flow-search-attempt-ready? state prerequisites completions)
  (require-state state)
  (and (list? prerequisites) (list? completions)
       (every
        (lambda (request)
          (and (kind? request 'search-attempt-request)
               (equal? (.ref request 'generation) (.ref state 'generation))
               (equal? (.ref request 'configuration) (.ref state 'configuration))
               (ormap (lambda (completion)
                        (and (kind? completion 'search-attempt-completion)
                             (same-request? request (.ref completion 'request))))
                      completions)))
        prerequisites)))

(def (poo-flow-search-attempt-issue-ready state prerequisites completions)
  (unless (poo-flow-search-attempt-ready? state prerequisites completions)
    (error "Search prerequisites are missing, stale or outside the execution scope"))
  (poo-flow-search-attempt-issue state))
