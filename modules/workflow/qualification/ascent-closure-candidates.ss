;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Scheme implementation of the selected Ascent binary closure's shortest
;;; source support. Fact labels here are caller-owned integers; MRR retains
;;; semantic FactId, rule-pack, generation, and admission authority.

(import (only-in :clan/poo/object .o .mix .ref .call)
        (only-in :clan/poo/trie UIntTrieSet)
        (only-in :agentic-ai-lab/modules/workflow/qualification/ascent-table-expression
                 agentic-ai-lab-ascent-table-expression-prototype))

(export agentic-ai-lab-ascent-closure-candidates)

(def (support<? left right)
  (let loop ((left left) (right right))
    (cond ((null? left) (pair? right))
          ((null? right) #f)
          ((< (car left) (car right)) #t)
          ((> (car left) (car right)) #f)
          (else (loop (cdr left) (cdr right))))))

(def (better-support? candidate current)
  (or (not current)
      (< (length candidate) (length current))
      (and (= (length candidate) (length current))
           (support<? candidate current))))

(def (source-index facts radix)
  (let ((index (make-vector radix []))
        (nodes (make-hash-table))
        (ids (make-hash-table)))
    (for-each
     (lambda (fact)
       (let ((pair (car fact)) (id (cdr fact)))
         (unless (and (exact-integer? pair) (<= 0 pair) (< pair (* radix radix))
                      (exact-integer? id) (<= 0 id))
           (error "invalid ASCENT source fact" fact))
         (when (hash-get ids id)
           (error "duplicate ASCENT source fact label" id))
         (hash-put! ids id #t)
         (let ((from (quotient pair radix)) (to (modulo pair radix)))
           (hash-put! nodes from #t)
           (hash-put! nodes to #t)
           (vector-set! index from
                        (cons (cons to id) (vector-ref index from))))))
     facts)
    (let ((node-count 0))
      (hash-for-each (lambda (_ __) (set! node-count (+ node-count 1))) nodes)
      (values index node-count))))

(def (shortest-supports index origin radix)
  (let ((best (make-vector radix #f)))
    (let loop ((frontier (list (cons origin []))))
      (unless (null? frontier)
        (let (next [])
          (for-each
           (lambda (state)
             (for-each
              (lambda (edge)
                (let* ((target (car edge))
                       (support (append (cdr state) (list (cdr edge))))
                       (current (vector-ref best target)))
                  (when (better-support? support current)
                    (vector-set! best target support)
                    ;; A cycle can prove (origin, origin), but following it
                    ;; cannot improve any shortest path from origin.
                    (unless (= target origin)
                      (set! next (cons (cons target support) next))))))
              (vector-ref index (car state))))
           frontier)
          (loop (reverse next)))))
    best))

(def (closure-candidates facts radix max-input-facts max-derived-pairs max-results)
  (unless (and (exact-integer? radix) (> radix 1)
               (exact-integer? max-input-facts) (> max-input-facts 0)
               (exact-integer? max-derived-pairs) (> max-derived-pairs 0)
               (exact-integer? max-results) (> max-results 0))
    (error "invalid ASCENT closure bounds"))
  (when (> (length facts) max-input-facts)
    (error "ASCENT input fact budget exceeded" (length facts) max-input-facts))
  (let-values (((index node-count) (source-index facts radix)))
    (when (> (* node-count node-count) max-derived-pairs)
      (error "ASCENT derived pair budget exceeded"
             (* node-count node-count) max-derived-pairs))
    (let* ((edges (.call UIntTrieSet .<-list (map car facts)))
           (width radix)
           (expression
            (.mix agentic-ai-lab-ascent-table-expression-prototype
                  (.o (source-pairs edges) (radix width))))
           (pairs (.ref expression 'shortest-distance-pairs))
           (distance-of (.ref expression 'shortest-distance-of))
           (all
            (let loop ((remaining pairs) (origin #f) (supports #f) (result []))
              (if (null? remaining)
                (reverse result)
                (let* ((encoded (car remaining))
                       (from (quotient encoded radix))
                       (to (modulo encoded radix))
                       (paths (if (equal? origin from) supports
                                  (shortest-supports index from radix)))
                       (path (vector-ref paths to)))
                  (unless path
                    (error "ASCENT closure pair has no source support" encoded))
                  (unless (= (length path) (distance-of encoded))
                    (error "ASCENT shortest support and lattice distance disagree"
                           encoded))
                  (loop (cdr remaining) from paths
                        (cons (.o (pair encoded)
                                  (distance (length path))
                                  (support path)
                                  (rule (if (= (length path) 1)
                                          'base 'transitive)))
                              result))))))
           (truncated? (> (length all) max-results)))
      (.o (status (if truncated? 'output-truncated 'complete))
          (input-count (length facts))
          (candidates (if truncated? (take all max-results) all))))))

(def (agentic-ai-lab-ascent-closure-candidates
      source-facts radix max-input-facts max-derived-pairs max-results)
  (closure-candidates source-facts radix
                      max-input-facts max-derived-pairs max-results))
