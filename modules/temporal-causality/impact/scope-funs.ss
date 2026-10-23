;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; A declaration-bound audit of supplied candidate and observed trajectories.
;;; Direct targets are not automatically causal descendants; protected outcomes
;;; are explicit negative controls, not every non-target variable.
(import (only-in :clan/poo/object .ref)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :std/list/list any every delete-duplicates/hash)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/types
                 agentic-ai-lab-temporal-instant?)
        (only-in :agentic-ai-lab/modules/temporal-causality/trajectory/types
                 agentic-ai-lab-temporal-trajectory-series?)
        (only-in :agentic-ai-lab/modules/temporal-causality/impact/scope-types
                 agentic-ai-lab-temporal-impact-scope?)
        (only-in :agentic-ai-lab/modules/temporal-causality/impact/scope-objects
                 agentic-ai-lab-temporal-impact-scope-value
                 agentic-ai-lab-temporal-impact-scope-audit-value)
        (only-in :agentic-ai-lab/modules/temporal-causality/impact/funs
                 agentic-ai-lab-temporal-intervention-window-audit))
(export agentic-ai-lab-temporal-impact-scope
        agentic-ai-lab-temporal-impact-scope-audit)

(def (text? value) (and (string? value) (> (string-length value) 0)))
(def (unique? values)
  (= (length values) (length (delete-duplicates/hash values))))
(def (digest datum)
  (string-append "sha256:"
   (hex-encode (sha256 (string->utf8
    (call-with-output-string (lambda (port) (write datum port))))))))
(def (instant-row instant)
  (list (.ref instant 'identity) (.ref instant 'domain-identity)
        (.ref instant 'coordinate) (.ref instant 'provenance-identity)
        (.ref instant 'modality)))
(def (outcome series) (.ref series 'outcome-identity))

(def (agentic-ai-lab-temporal-impact-scope
      identity intervention subject cut projection onset end targets protected)
  (unless (and (every text? (list identity intervention subject cut projection))
               (agentic-ai-lab-temporal-instant? onset)
               (agentic-ai-lab-temporal-instant? end)
               (equal? (.ref onset 'domain-identity)
                       (.ref end 'domain-identity))
               (< (.ref onset 'coordinate) (.ref end 'coordinate))
               (list? targets) (pair? targets) (every text? targets)
               (list? protected) (every text? protected)
               (unique? targets) (unique? protected)
               (every (lambda (id) (not (member id protected))) targets))
    (error "invalid temporal impact scope"))
  (let* ((targets (list-sort string<? targets))
         (protected (list-sort string<? protected))
         (domain (.ref onset 'domain-identity)))
    (agentic-ai-lab-temporal-impact-scope-value
     identity
     (digest (list 'agentic-ai-lab.temporal-causality.impact-scope.v1
                   identity intervention subject cut projection domain
                   (instant-row onset) (instant-row end) targets protected))
     intervention subject cut projection domain onset end targets protected)))

(def (agentic-ai-lab-temporal-impact-scope-audit
      identity scope candidates baselines)
  (unless (and (text? identity) (agentic-ai-lab-temporal-impact-scope? scope)
               (list? candidates) (pair? candidates)
               (list? baselines) (pair? baselines)
               (every agentic-ai-lab-temporal-trajectory-series? candidates)
               (every agentic-ai-lab-temporal-trajectory-series? baselines))
    (error "invalid temporal impact scope audit input"))
  (let* ((canonical
          (agentic-ai-lab-temporal-impact-scope
           (.ref scope 'identity) (.ref scope 'intervention-identity)
           (.ref scope 'subject-identity) (.ref scope 'source-cut-digest)
           (.ref scope 'source-projection-digest)
           (.ref scope 'onset) (.ref scope 'end)
           (.ref scope 'direct-target-outcomes)
           (.ref scope 'protected-outcomes)))
         (candidate-outcomes (map outcome candidates))
         (baseline-outcomes (map outcome baselines))
         (required (append (.ref scope 'direct-target-outcomes)
                           (.ref scope 'protected-outcomes)))
         (candidate-scenario (.ref (car candidates) 'scenario-identity))
         (baseline-scenario (.ref (car baselines) 'scenario-identity)))
    (unless (and (equal? (.ref scope 'semantic-digest)
                         (.ref canonical 'semantic-digest))
                 (unique? candidate-outcomes) (unique? baseline-outcomes)
                 (unique? (map (lambda (series) (.ref series 'identity))
                               candidates))
                 (unique? (map (lambda (series) (.ref series 'identity))
                               baselines))
                 (not (equal? candidate-scenario baseline-scenario))
                 (equal? (list-sort string<? candidate-outcomes)
                         (list-sort string<? baseline-outcomes))
                 (every (lambda (id) (member id candidate-outcomes)) required)
                 (every (lambda (series)
                          (and (equal? (.ref series 'subject-identity)
                                       (.ref scope 'subject-identity))
                               (equal? (.ref series 'source-cut-digest)
                                       (.ref scope 'source-cut-digest))
                               (equal? (.ref series 'source-projection-digest)
                                       (.ref scope 'source-projection-digest))
                               (equal? (.ref series 'time-domain-identity)
                                       (.ref scope 'time-domain-identity))))
                        (append candidates baselines))
                 (every (lambda (series)
                          (and (equal? (.ref series 'scenario-identity)
                                       candidate-scenario)
                               (memq (.ref series 'modality)
                                     '(predicted counterfactual)))) candidates)
                 (every (lambda (series)
                          (and (equal? (.ref series 'scenario-identity)
                                       baseline-scenario)
                               (eq? (.ref series 'modality) 'observed)))
                        baselines))
      (error "temporal impact scope or supplied inventory differs"))
    (let* ((baseline-index
            (let (index (make-hash-table))
              (for-each (lambda (series)
                          (hash-put! index (outcome series) series)) baselines)
              index))
           (ordered (list-sort
                     (lambda (a b) (string<? (outcome a) (outcome b)))
                     candidates))
           (audits
            (map (lambda (candidate)
                   (let* ((id (outcome candidate))
                          (baseline (hash-get baseline-index id)))
                     (agentic-ai-lab-temporal-intervention-window-audit
                      (string-append identity "/" id)
                      (.ref scope 'intervention-identity)
                      candidate baseline (.ref scope 'onset) (.ref scope 'end))))
                 ordered))
           (prefix-status
            (cond ((any (lambda (audit)
                          (eq? (.ref audit 'prefix-status) 'diverged)) audits)
                   'diverged)
                  ((any (lambda (audit)
                          (eq? (.ref audit 'prefix-status) 'unobserved)) audits)
                   'unobserved)
                  (else 'consistent)))
           (protected-audits
            (filter (lambda (audit)
                      (member (.ref audit 'outcome-identity)
                              (.ref scope 'protected-outcomes))) audits))
           (protected-status
            (cond ((null? protected-audits) 'unobserved)
                  ((every (lambda (audit)
                            (every (lambda (point)
                                     (zero? (.ref point 'level-delta)))
                                   (.ref audit 'window-points)))
                          protected-audits) 'consistent)
                  (else 'diverged)))
           (status
            (cond ((or (eq? prefix-status 'diverged)
                       (eq? protected-status 'diverged)) 'violated)
                  ((or (eq? prefix-status 'unobserved)
                       (eq? protected-status 'unobserved)) 'unknown)
                  (else 'consistent-with-declaration)))
           (semantic-digest
            (digest
             (list 'agentic-ai-lab.temporal-causality.impact-scope-audit.v1
                   identity (.ref scope 'semantic-digest)
                   candidate-scenario baseline-scenario
                   (map (lambda (audit)
                          (list (.ref audit 'outcome-identity)
                                (.ref audit 'semantic-digest))) audits)
                   prefix-status protected-status status))))
      (agentic-ai-lab-temporal-impact-scope-audit-value
       identity semantic-digest (.ref scope 'semantic-digest)
       candidate-scenario baseline-scenario
       (map outcome ordered) audits prefix-status protected-status status))))
