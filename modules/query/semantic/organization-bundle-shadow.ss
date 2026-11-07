;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: compares canonical organization bundles through a shadow-evaluation lane.
;;; Invariant: shadow comparison observes divergence without changing accepted state.
(export #t)

(import (only-in :clan/poo/object .o .ref object?)
        :agentic-ai-lab/modules/query/semantic/organization-bundle
        :agentic-ai-lab/modules/query/semantic/funcs)

(def +agentic-ai-lab-organization-shadow-receipt-schema+
  'agentic-ai-lab.organization-bundle-shadow-receipt.draft.1)

(def +shadow-facet-order+
  '(organization authority context protocol evidence))

(def (agentic-ai-lab-organization-shadow-fact facet-value path-value key-value value)
  (.o (kind 'agentic-ai-lab.organization-shadow-fact.draft.1)
      (facet facet-value) (path path-value) (key key-value)
      (semantic-value value)))

(def (agentic-ai-lab-organization-shadow-profile entries-value)
  (.o (kind 'agentic-ai-lab.organization-shadow-profile.draft.1)
      (entries entries-value)))

(def (shadow-write value)
  (let (port (open-output-string))
    (write value port)
    (get-output-string port)))

(def (shadow-fact-identity fact)
  (list (.ref fact 'facet) (.ref fact 'path) (.ref fact 'key)))

(def (shadow-fact<? left right)
  (string<? (shadow-write (shadow-fact-identity left))
            (shadow-write (shadow-fact-identity right))))

(def (shadow-sort facts)
  (list-sort shadow-fact<? (append facts '())))

(def (shadow-valid-facet? facet)
  (memq facet +shadow-facet-order+))

(def (shadow-value-admissible? value)
  (or (null? value) (symbol? value) (string? value)
      (boolean? value) (number? value) (pair? value)))

(def (shadow-valid-fact? fact)
  (with-catch
   (lambda (_failure) #f)
   (lambda ()
     (and (shadow-valid-facet? (.ref fact 'facet))
          (pair? (.ref fact 'path))
          (shadow-value-admissible? (.ref fact 'semantic-value))))))

(def (shadow-facet-rank facet)
  (let (ranked-tail (memq facet +shadow-facet-order+))
    (if ranked-tail
      (- (length +shadow-facet-order+) (length ranked-tail))
      99)))

(def (shadow-section-facts facet section values)
  (map (lambda (value)
         (agentic-ai-lab-organization-shadow-fact
          facet (list section value) 'value value))
       values))

(def (shadow-facet-facts canonical)
  (let ((facet (car canonical))
        (schema (cadr canonical))
        (entities (caddr canonical))
        (relations (cadddr canonical))
        (constraints (car (cddddr canonical))))
    (append
     (list (agentic-ai-lab-organization-shadow-fact
            facet '(schema) 'schema (cadr schema)))
     (shadow-section-facts facet 'entities (cdr entities))
     (shadow-section-facts facet 'relations (cdr relations))
     (shadow-section-facts facet 'constraints (cdr constraints)))))

(def (agentic-ai-lab-organization-bundle-shadow-facts state)
  (unless (and (object? state) (memq (.ref state 'phase) '(validated advanced)))
    (error "shadow projection requires validated Bundle Kernel state" state))
  (let (canonical (.ref state 'canonical-payload))
    (shadow-sort
     (apply append (map shadow-facet-facts
                        (list (list-ref canonical 2)
                              (list-ref canonical 3)
                              (list-ref canonical 4)
                              (list-ref canonical 5)
                              (list-ref canonical 6)))))))

(def (agentic-ai-lab-organization-shadow-profile/all facts)
  (agentic-ai-lab-organization-shadow-profile
   (map (lambda (fact) (list (.ref fact 'facet) (.ref fact 'path))) facts)))

(def (shadow-profile-covers? profile fact)
  (member (list (.ref fact 'facet) (.ref fact 'path))
          (.ref profile 'entries)))

(def (shadow-duplicate-identities facts)
  (let (previous+duplicates
        (foldl
         (lambda (fact state)
           (let ((previous (car state))
                 (duplicates (cdr state))
                 (identity (shadow-fact-identity fact)))
             (cons identity
                   (if (and previous (equal? previous identity))
                     (cons identity duplicates)
                     duplicates))))
         (cons #f '())
         (shadow-sort facts)))
    (reverse (cdr previous+duplicates))))

(def (shadow-diagnostic code-value path-value expected-value observed-value)
  (.o (kind 'agentic-ai-lab.organization-shadow-diagnostic.draft.1)
      (code code-value) (path path-value)
      (expected expected-value) (observed observed-value)))

(def (shadow-receipt state-value accepted-value? equivalent-value?
                     compared-value matched-value missing-current-value
                     missing-bundle-value mismatches-value diagnostics-value)
  (.o (kind 'agentic-ai-lab.organization-bundle-shadow-receipt)
      (schema +agentic-ai-lab-organization-shadow-receipt-schema+)
      (bundle-identity (.ref state-value 'identity))
      (bundle-epoch (.ref state-value 'epoch))
      (compared-facets compared-value)
      (matched-paths matched-value)
      (missing-current missing-current-value)
      (missing-bundle missing-bundle-value)
      (mismatched-values mismatches-value)
      (accepted? accepted-value?) (equivalent? equivalent-value?)
      (v1-conformant? #f) (diagnostics diagnostics-value)))

;;; Comparison boundary: report duplicate, missing, and mismatched facts without mutating shadow state.
(def (agentic-ai-lab-organization-bundle-shadow-compare state current-facts profile)
  (let* ((bundle-facts (agentic-ai-lab-organization-bundle-shadow-facts state))
         (all-facts (append current-facts bundle-facts))
         (profile-entry-index
          (agentic-ai-lab-semantic-index-by (lambda (entry) entry)
                                      (.ref profile 'entries)))
         (invalid-facts
          (filter (lambda (fact) (not (shadow-valid-fact? fact)))
                  all-facts))
         (duplicates (shadow-duplicate-identities current-facts))
         (invalid-profile
          (filter (lambda (entry)
                    (not (and (pair? entry) (pair? (cdr entry))
                              (null? (cddr entry))
                              (shadow-valid-facet? (car entry))
                              (pair? (cadr entry)))))
                  (.ref profile 'entries)))
         (uncovered
          (filter (lambda (fact)
                    (not (hash-key?
                          profile-entry-index
                          (list (.ref fact 'facet) (.ref fact 'path)))))
                  all-facts))
         (profile-facets
          (filter (lambda (facet)
                    (find (lambda (entry) (eq? (car entry) facet))
                          (.ref profile 'entries)))
                  +shadow-facet-order+)))
    (if (or (pair? invalid-facts) (pair? duplicates)
            (pair? invalid-profile) (pair? uncovered))
      (shadow-receipt
       state #f #f profile-facets '() '() '() '()
       (append
        (map (lambda (fact)
               (shadow-diagnostic 'invalid-shadow-fact
                                  (and (object? fact) (shadow-fact-identity fact))
                                  'stable-typed-fact 'invalid)) invalid-facts)
        (map (lambda (identity)
               (shadow-diagnostic 'duplicate-shadow-fact identity 'unique 'duplicate))
             duplicates)
        (map (lambda (entry)
               (shadow-diagnostic 'invalid-shadow-profile entry
                                  '(known-facet canonical-path) 'invalid))
             invalid-profile)
        (map (lambda (fact)
               (shadow-diagnostic 'incomplete-shadow-profile
                                  (shadow-fact-identity fact) 'covered 'missing))
             uncovered)))
      (let ((missing-current '()) (missing-bundle '())
            (mismatches '()) (matched '()))
        (let ((current-index
               (agentic-ai-lab-semantic-index-by shadow-fact-identity current-facts))
              (bundle-index
               (agentic-ai-lab-semantic-index-by shadow-fact-identity bundle-facts)))
        (for-each
         (lambda (bundle-fact)
           (let (current (hash-get current-index
                                  (shadow-fact-identity bundle-fact)))
             (cond
              ((not current)
               (set! missing-current (cons (shadow-fact-identity bundle-fact)
                                           missing-current)))
              ((not (equal? (.ref current 'semantic-value)
                            (.ref bundle-fact 'semantic-value)))
               (set! mismatches
                     (cons (list (shadow-fact-identity bundle-fact)
                                 (.ref bundle-fact 'semantic-value)
                                 (.ref current 'semantic-value))
                           mismatches)))
              (else (set! matched (cons (shadow-fact-identity bundle-fact)
                                        matched)))))) bundle-facts)
        (for-each
         (lambda (current)
           (unless (hash-key? bundle-index (shadow-fact-identity current))
             (set! missing-bundle
                   (cons (shadow-fact-identity current) missing-bundle))))
         current-facts)
        (let (equivalent? (and (null? missing-current)
                               (null? missing-bundle) (null? mismatches)))
          (shadow-receipt state #t equivalent? profile-facets
                          (reverse matched) (reverse missing-current)
                          (reverse missing-bundle) (reverse mismatches) '())))))))
