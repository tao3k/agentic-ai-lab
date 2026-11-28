;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; One projection of Org property drawers from parser-owned structural events.
;;; Context anchors and Org Contract source cuts consume these values; neither
;;; keeps a private event fold. Text inside a source block is never a property.
(import (only-in :clan/poo/object .o .ref)
        (only-in :tao3k/agentic-ai-lab/modules/query/semantic/orgize-source-interface
                 parse-org-events)
        "objects.ss")
(export agentic-ai-lab-ai-agentic-context-org-properties
        agentic-ai-lab-ai-agentic-context-org-property-key?
        agentic-ai-lab-ai-agentic-context-org-property-disjoint?
        agentic-ai-lab-ai-agentic-context-org-property-contains?)

;; Private positional traversal state. `key` and `value` are half-open UTF-8
;; byte spans `(start . end)`; `owned` stages drawer entries until their
;; enclosing `OrgFile` / `OrgSection` finishes at `container-end`.
(defstruct frame (kind start key value owned) final: #t)

(def (frame-with-span f token span)
  (case token
    ((PropertyKey) (make-frame (frame-kind f) (frame-start f) span (frame-value f) (frame-owned f)))
    ((PropertyValue) (make-frame (frame-kind f) (frame-start f) (frame-key f) span (frame-owned f)))
    (else f)))

(def (frame-prepend-owned f items)
  (make-frame (frame-kind f) (frame-start f) (frame-key f) (frame-value f)
              (append items (frame-owned f))))

(def (stack-with-property-span stack token span)
  (let loop ((rest stack) (above '()))
    (cond
     ((null? rest) stack)
     ((eq? (frame-kind (car rest)) 'OrgNodeProperty)
      (foldl cons (cons (frame-with-span (car rest) token span) (cdr rest)) above))
     (else (loop (cdr rest) (cons (car rest) above))))))

(def (drawer-property? f enclosing)
  (and (eq? (frame-kind f) 'OrgNodeProperty)
       (frame-key f)
       (pair? enclosing) (pair? (cdr enclosing))
       (eq? (frame-kind (car enclosing)) 'OrgPropertyDrawer)
       (memq (frame-kind (cadr enclosing)) '(OrgFile OrgSection))))

(def (drawer-property-frames events size)
  (let loop ((events events) (stack '()) (offset 0) (roots 0) (ordinal 0) (completed '()))
    (if (null? events)
      (begin
        (unless (and (= roots 1) (null? stack) (= offset size))
          (error "Incomplete Org property tree"))
        (list-sort (lambda (a b) (< (car a) (car b))) completed))
      (let (event (car events))
        (unless (pair? event) (error "Invalid Orgize structural event"))
        (case (car event)
          ((start)
           (unless (and (= (length event) 2) (symbol? (cadr event)))
             (error "Invalid Orgize node start"))
           (when (and (null? stack) (not (eq? (cadr event) 'OrgFile)))
             (error "Org property projection requires an OrgFile root"))
           (loop (cdr events) (cons (make-frame (cadr event) offset #f #f '()) stack)
                 offset (if (null? stack) (+ roots 1) roots) ordinal completed))
          ((token)
           (unless (and (= (length event) 4) (symbol? (cadr event)) (pair? stack)
                        (exact-integer? (caddr event)) (exact-integer? (cadddr event))
                        (= (caddr event) offset) (<= offset (cadddr event) size))
             (error "Org tokens do not partition source"))
           (let ((token (cadr event)) (end (cadddr event)))
             (loop (cdr events)
                   (if (memq token '(PropertyKey PropertyValue))
                     (stack-with-property-span stack token (cons offset end))
                     stack)
                   end roots ordinal completed)))
          ((finish)
           (unless (and (= (length event) 1) (pair? stack)) (error "Unbalanced Orgize tree"))
           (let ((f (car stack)) (enclosing (cdr stack)))
             (cond
              ((drawer-property? f enclosing)
               (loop (cdr events)
                     (cons (frame-prepend-owned (car enclosing) (list (cons ordinal f)))
                           (cdr enclosing))
                     offset roots (+ ordinal 1) completed))
              ((and (eq? (frame-kind f) 'OrgPropertyDrawer)
                    (pair? (frame-owned f)) (pair? enclosing)
                    (memq (frame-kind (car enclosing)) '(OrgFile OrgSection)))
               (let (stamped (map (lambda (it) (cons (car it) (cons offset (cdr it))))
                                  (frame-owned f)))
                 (loop (cdr events)
                       (cons (frame-prepend-owned (car enclosing) stamped) (cdr enclosing))
                       offset roots ordinal completed)))
              ((and (memq (frame-kind f) '(OrgFile OrgSection)) (pair? (frame-owned f)))
               (let (released
                     (map (lambda (it)
                            (list (car it) (frame-kind f) (frame-start f) offset (cadr it) (cddr it)))
                          (frame-owned f)))
                 (loop (cdr events) enclosing offset roots ordinal (append released completed))))
              (else
               (loop (cdr events) enclosing offset roots ordinal completed)))))
          (else (error "Unknown Orgize structural event")))))))

(def (property-object bytes entry)
  (with ([_ container-kind container-start container-end drawer-end f] entry)
    (let* ((slice (lambda (span) (utf8->string (subu8vector bytes (car span) (cdr span)))))
           (key-span (frame-key f))
           (val-span (let (s (frame-value f)) (and s (< (car s) (cdr s)) s)))
           (key (slice key-span))
           (key-start (car key-span))
           (key-end (cdr key-span))
           (value (and val-span (slice val-span)))
           (value-start (and val-span (car val-span)))
           (value-end (and val-span (cdr val-span))))
      (.o (:: @ AiAgenticContextOrgProperty.)
          container-kind container-start container-end drawer-end
          key key-start key-end value value-start value-end))))

(def (agentic-ai-lab-ai-agentic-context-org-properties source)
  (unless (string? source) (error "Org property projection requires source text"))
  (let (bytes (string->utf8 source))
    (map (cut property-object bytes <>)
         (drawer-property-frames (parse-org-events source) (u8vector-length bytes)))))

(def (agentic-ai-lab-ai-agentic-context-org-property-key? property key)
  (string-ci=? (.ref property 'key) key))

(def (agentic-ai-lab-ai-agentic-context-org-property-disjoint? left right)
  (or (<= (.ref left 'container-end) (.ref right 'container-start))
      (<= (.ref right 'container-end) (.ref left 'container-start))))

(def (agentic-ai-lab-ai-agentic-context-org-property-contains? outer inner)
  (and (<= (.ref outer 'container-start) (.ref inner 'container-start))
       (<= (.ref inner 'container-end) (.ref outer 'container-end))))
