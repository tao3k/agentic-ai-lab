;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Bounded, source-preserving reverse explanation. It infers candidate
;;; support and explicit conflicts; it never authenticates sources or admits
;;; actions. The caller owns domain claim names and step topology.
(import (only-in :clan/poo/object .o .ref object?)
        (only-in :std/list/list every find)
        (only-in :agentic-ai-lab/modules/query/scheme-select
                 agentic-ai-lab-query-select-scheme-nodes)
        (only-in :gerbil-ascent/program/interface
                 relational-program gerbil-ascent-evaluate-program))

(export agentic-ai-lab-evidence-assessment-evaluate
        agentic-ai-lab-evidence-hypothesis-result
        agentic-ai-lab-evidence-assessment-explore)

(def (agentic-ai-lab-evidence-hypothesis-result receipt hypothesis-id)
  (let (result
        (find (lambda (item)
                (eq? (.ref item 'identity) hypothesis-id))
              (.ref receipt 'hypothesis-results)))
    (or result (error "unknown evidence assessment hypothesis" hypothesis-id))))

(def (evidence-reference? reference source)
  (and (object? reference)
       (eq? (.ref reference 'kind)
            'agentic-ai-lab.evidence-assessment.evidence-reference)
       (eq? (.ref reference 'source) source)
       (string? (.ref reference 'uri))
       (> (string-length (.ref reference 'uri)) 0)
       (symbol? (.ref reference 'independence-group))
       (let (digest (.ref reference 'content-digest))
         (or (not digest)
             (and (string? digest) (> (string-length digest) 0))))))

(def (claim? value allowed)
  (and (object? value)
       (eq? (.ref value 'kind) 'agentic-ai-lab.evidence-assessment.claim)
       (symbol? (.ref value 'identity))
       (memq (.ref value 'identity) allowed)
       (symbol? (.ref value 'value))
       (not (eq? (.ref value 'value) 'absent))
       (symbol? (.ref value 'source))
       (let (reference (.ref value 'evidence-reference))
         (or (not reference)
             (evidence-reference? reference (.ref value 'source))))))

;;; Return one bounded path of actual supported step rows, not merely a
;;; transitive reachability assertion. The visited set cuts candidate cycles.
(def (shortest-witness-path origin destination supported-steps)
  (let loop ((frontier (list (list origin '()))) (visited (list origin)))
    (if (null? frontier) '()
      (let* ((entry (car frontier))
             (node (car entry))
             (path (cadr entry)))
        (if (eq? node destination) (reverse path)
          (let* ((next-steps
                  (filter (lambda (step)
                            (and (eq? (car step) node)
                                 (not (memq (cadr step) visited))))
                          supported-steps))
                 (next-entries
                  (map (lambda (step)
                         (list (cadr step) (cons step path)))
                       next-steps)))
            (loop (append (cdr frontier) next-entries)
                  (append visited (map car next-entries)))))))))

(def (step? value allowed)
  (and (object? value)
       (eq? (.ref value 'kind) 'agentic-ai-lab.evidence-assessment.step)
       (symbol? (.ref value 'from))
       (symbol? (.ref value 'to))
       (memq (.ref value 'first) allowed)
       (memq (.ref value 'second) allowed)
       (memq (.ref value 'join) '(presence equal-value))))

(def (hypothesis? value allowed)
  (and (object? value)
       (eq? (.ref value 'kind) 'agentic-ai-lab.evidence-assessment.hypothesis)
       (symbol? (.ref value 'identity))
       (symbol? (.ref value 'from))
       (symbol? (.ref value 'to))
       (not (eq? (.ref value 'from) (.ref value 'to)))
       (list? (.ref value 'required-claims))
       (every (lambda (claim) (memq claim allowed))
              (.ref value 'required-claims))))

(def (agentic-ai-lab-evidence-assessment-evaluate case-value)
  (unless (and (object? case-value)
               (eq? (.ref case-value 'kind)
                    'agentic-ai-lab.evidence-assessment.case))
    (error "reverse evidence requires a POO Case" case-value))
  (let* ((claims (.ref case-value 'claims))
         (steps (.ref case-value 'steps))
         (hypotheses (.ref case-value 'hypotheses))
         (query (.ref case-value 'query))
         (allowed (.ref query 'selected-element-identities)))
    (unless (and (list? claims) (<= (length claims) 64)
                 (every (lambda (claim) (claim? claim allowed)) claims)
                 (list? steps) (<= (length steps) 64)
                 (every (lambda (step) (step? step allowed)) steps)
                 (list? hypotheses) (pair? hypotheses)
                 (<= (length hypotheses) 32)
                 (every (lambda (hypothesis)
                          (hypothesis? hypothesis allowed)) hypotheses))
      (error "invalid bounded reverse evidence Case" case-value))
    (let* ((nodes
            (map (lambda (claim)
                   (.o label: 'EvidenceClaim
                       identity: (.ref claim 'identity)
                       value: (.ref claim 'value)
                       evidenceSource: (.ref claim 'source)))
                 claims))
           (query-result (agentic-ai-lab-query-select-scheme-nodes query nodes))
           (selected (.ref query-result 'rows))
           (presence-steps
            (map (lambda (step)
                   (list (.ref step 'from) (.ref step 'to)
                         (.ref step 'first) (.ref step 'second)))
                 (filter (lambda (step)
                           (eq? (.ref step 'join) 'presence)) steps)))
           (equal-steps
            (map (lambda (step)
                   (list (.ref step 'from) (.ref step 'to)
                         (.ref step 'first) (.ref step 'second)))
                 (filter (lambda (step)
                           (eq? (.ref step 'join) 'equal-value)) steps)))
           (equal-claim-kinds
            (map list
                 (append (map caddr equal-steps)
                         (map cadddr equal-steps))))
           ;; Equality is a finite source, so mismatch rules use checked
           ;; negation without passing a host predicate into Ascent.
           (equal-values
            (map (lambda (row) (list (cadr row) (cadr row))) selected))
           (result
            (gerbil-ascent-evaluate-program
             (relational-program
              (relation claim (name value source) selected)
              (relation step (from to first second) presence-steps)
              (relation equal-step (from to first second) equal-steps)
              (relation equal-claim (name) equal-claim-kinds)
              (relation equal-value (first second) equal-values)
              (relation required (name))
              (relation seen (name))
              (relation missing (name))
              (relation mismatch
                (first first-value first-source
                 second second-value second-source))
              (relation conflict
                (name first-value first-source second-value second-source))
              (relation supported-step
                (from to first first-source second second-source))
              (relation reverse-reach (from to))
              (rule (required ?first) (step ?from ?to ?first ?second))
              (rule (required ?second) (step ?from ?to ?first ?second))
              (rule (required ?first) (equal-step ?from ?to ?first ?second))
              (rule (required ?second) (equal-step ?from ?to ?first ?second))
              (rule (seen ?name) (claim ?name ?value ?source))
              (rule (missing ?name) (required ?name) (not (seen ?name)))
              (rule (mismatch ?first ?first-value ?first-source
                              ?second ?second-value ?second-source)
                    (equal-step ?from ?to ?first ?second)
                    (claim ?first ?first-value ?first-source)
                    (claim ?second ?second-value ?second-source)
                    (not (equal-value ?first-value ?second-value)))
              (rule (conflict ?name ?first-value ?first-source
                              ?second-value ?second-source)
                    (equal-claim ?name)
                    (claim ?name ?first-value ?first-source)
                    (claim ?name ?second-value ?second-source)
                    (not (equal-value ?first-value ?second-value)))
              (rule (supported-step ?from ?to ?first ?first-source
                                    ?second ?second-source)
                    (step ?from ?to ?first ?second)
                    (claim ?first ?first-value ?first-source)
                    (claim ?second ?second-value ?second-source))
              (rule (supported-step ?from ?to ?first ?first-source
                                    ?second ?second-source)
                    (equal-step ?from ?to ?first ?second)
                    (claim ?first ?value ?first-source)
                    (claim ?second ?value ?second-source))
              (rule (reverse-reach ?from ?to)
                    (supported-step ?from ?to ?first ?first-source
                                    ?second ?second-source))
              (rule (reverse-reach ?from ?end)
                    (reverse-reach ?from ?middle)
                    (supported-step ?middle ?end ?first ?first-source
                                    ?second ?second-source))
              (limits 384 256 512))))
           (rows-of (.ref result 'rows-of))
           (reach (rows-of 'reverse-reach))
           (supported-steps (rows-of 'supported-step))
           (mismatches (rows-of 'mismatch))
           (conflicts (rows-of 'conflict))
           (consistent? (and (null? mismatches) (null? conflicts)))
           (evaluated-hypotheses
            (map
             (lambda (hypothesis)
               (let* ((required (.ref hypothesis 'required-claims))
                      (absent
                       (filter (lambda (claim-id)
                                 (not (member (list claim-id)
                                              (rows-of 'seen))))
                               required))
                      (route-reachable?
                       (and (member (list (.ref hypothesis 'from)
                                          (.ref hypothesis 'to)) reach) #t))
                      (relevant-mismatches
                       (filter (lambda (row)
                                 (and (memq (car row) required)
                                      (memq (cadddr row) required)))
                               mismatches))
                      (relevant-conflicts
                       (filter (lambda (row)
                                 (memq (car row) required)) conflicts))
                      (result-status
                       (cond ((or (pair? relevant-mismatches)
                                  (pair? relevant-conflicts)) 'conflicted)
                             ((and route-reachable? (null? absent)) 'supported)
                             (else 'needs-evidence))))
                 (.o kind: 'agentic-ai-lab.evidence-assessment.hypothesis-result
                     identity: (.ref hypothesis 'identity)
                     status: result-status
                     reachable?: route-reachable?
                     witness-path:
                     (if route-reachable?
                       (shortest-witness-path
                        (.ref hypothesis 'from) (.ref hypothesis 'to)
                        supported-steps)
                       '())
                     missing-claims: absent
                     equality-mismatches: relevant-mismatches
                     value-conflicts: relevant-conflicts)))
             hypotheses)))
      (.o kind: 'agentic-ai-lab.evidence-assessment.receipt
          query-selected-claims: selected
          query-source-identity: (.ref query-result 'query-source-identity)
          query-executed-in-scheme?: #t
          evidence-references:
          (filter-map
           (lambda (claim)
             (let (reference (.ref claim 'evidence-reference))
               (and reference
                    (list (.ref claim 'identity) reference))))
           claims)
          evidence-without-content-digest:
          (map (lambda (claim) (.ref claim 'identity))
               (filter
                (lambda (claim)
                  (let (reference (.ref claim 'evidence-reference))
                    (not (and reference
                              (.ref reference 'content-digest)))))
                claims))
          supported-inference-steps: supported-steps
          reachable-candidates: reach
          missing-claims: (rows-of 'missing)
          equality-mismatches: mismatches
          value-conflicts: conflicts
          evidence-consistent?: consistent?
          hypothesis-results: evaluated-hypotheses
          unresolved-witnesses: (.ref case-value 'unresolved)
          historical-attribution-verified?: #f
          source-authenticity-verified?: #f
          action-authority?: #f))))

;;; Agents and investigators author competing branches. Each branch can add
;;; possible claims or withhold a contested source. The engine evaluates
;;; every branch and every hypothesis without choosing a winner or action.
(def (inference-branch? branch-value allowed)
  (and (object? branch-value)
       (eq? (.ref branch-value 'kind)
            'agentic-ai-lab.evidence-assessment.branch)
       (symbol? (.ref branch-value 'identity))
       (symbol? (.ref branch-value 'reason))
       (let ((proposed (.ref branch-value 'proposed-claims))
             (withheld (.ref branch-value 'withheld-claims)))
         (and (list? proposed) (<= (length proposed) 4)
              (every (lambda (claim) (claim? claim allowed)) proposed)
              (list? withheld) (<= (length withheld) 4)
              (every (lambda (id) (and (symbol? id) (memq id allowed)))
                     withheld)
              (or (pair? proposed) (pair? withheld))))))

(def (unique-branch-identities? branches)
  (let loop ((pending branches) (seen '()))
    (or (null? pending)
        (let (id (.ref (car pending) 'identity))
          (and (not (memq id seen))
               (loop (cdr pending) (cons id seen)))))))

(def (agentic-ai-lab-evidence-assessment-explore case-value branch-values)
  (let (allowed (.ref (.ref case-value 'query)
                      'selected-element-identities))
    (unless (and (list? branch-values) (pair? branch-values)
                 (<= (length branch-values) 8)
                 (every (lambda (branch-value)
                          (inference-branch? branch-value allowed))
                        branch-values)
                 (unique-branch-identities? branch-values))
      (error "invalid bounded evidence assessment branches" branch-values)))
  (let* ((baseline (agentic-ai-lab-evidence-assessment-evaluate case-value))
         (explored
          (map
           (lambda (branch-value)
             (let* ((withheld (.ref branch-value 'withheld-claims))
                    (remaining
                     (filter
                      (lambda (claim)
                        (not (memq (.ref claim 'identity) withheld)))
                      (.ref case-value 'claims)))
                    (branch-receipt
                     (agentic-ai-lab-evidence-assessment-evaluate
                      (.o (:: @ case-value)
                          claims:
                          (append remaining
                                  (.ref branch-value 'proposed-claims)))))
                    (transitions
                     (map
                      (lambda (old-result)
                        (let* ((id (.ref old-result 'identity))
                               (new-result
                                (agentic-ai-lab-evidence-hypothesis-result
                                 branch-receipt id))
                               (old-status (.ref old-result 'status))
                               (new-status (.ref new-result 'status)))
                          (.o kind:
                              'agentic-ai-lab.evidence-assessment.branch-transition
                              hypothesis: id
                              before-status: old-status
                              after-status: new-status
                              changed?: (not (eq? old-status new-status))
                              witness-path: (.ref new-result 'witness-path)
                              missing-claims: (.ref new-result
                                                    'missing-claims))))
                      (.ref baseline 'hypothesis-results))))
               (.o kind: 'agentic-ai-lab.evidence-assessment.branch-result
                   identity: (.ref branch-value 'identity)
                   reason: (.ref branch-value 'reason)
                   proposed-claims: (.ref branch-value 'proposed-claims)
                   withheld-claims: withheld
                   hypothesis-transitions: transitions
                   evidence-consistent?:
                   (.ref branch-receipt 'evidence-consistent?)
                   receipt: branch-receipt
                   hypothetical?: #t
                   action-authority?: #f)))
           branch-values)))
    (.o kind: 'agentic-ai-lab.evidence-assessment.exploration
        baseline-receipt: baseline
        branch-results: explored
        historical-attribution-verified?: #f
        source-authenticity-verified?: #f
        action-authority?: #f)))
