;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Parser-owned events only; no text/regex parser and no source-block execution.
(import
 (only-in :clan/poo/object .o .ref)
 (only-in :std/list/list find delete-duplicates/hash)
 (only-in
  :agentic-ai-lab/modules/query/semantic/orgize-source-interface
  parse-org-native-events
  org-source-headline-elements
  org-source-headline-parser-identity)
 (only-in
  :agentic-ai-lab/modules/ai-agentic-context/funs-scope
  agentic-ai-lab-ai-agentic-context-digest))

(export
 context-org-source)

(defstruct frame (kind start key-start key-end value-start value-end))

(def (text? v)
  (and (string? v) (< 0 (string-length v) 257)))

;;; Consume native parser events, including structural ownership of drawers.
;;; ID-looking text inside a source block is not a document/headline property.
;;; IDs are local anchors; the registered source identity qualifies them.
(def (context-org-source identity-value generation-value bytes-value (active-value #t))
  (unless (and
           (text? identity-value)
           (exact-integer? generation-value)
           (<= 1 generation-value 65534)
           (string? bytes-value)
           (<= (u8vector-length (string->utf8 bytes-value)) 1048576)
           (boolean? active-value))
    (error "Invalid Org source cut"))
  (let* ((raw (string-copy bytes-value))
         (bytes (string->utf8 raw))
         (size (u8vector-length bytes))
         (projection (org-source-headline-elements raw))
         (source-digest-value (.ref projection 'source-sha256))
         (stack '())
         (offset 0)
         (roots 0)
         (properties '()))
    (def (slice start end)
      (utf8->string (subu8vector bytes start end)))
    (for-each
     (lambda (event)
       (case (car event)
         ((start)
          (when (null? stack)
            (set! roots (+ roots 1))
            (unless (eq? (cadr event) 'OrgFile)
              (error "Expected OrgFile")))
          (set! stack (cons (make-frame (cadr event) offset #f #f #f #f) stack)))
         ((token)
          (unless (and
                   (pair? stack)
                   (= offset (caddr event))
                   (<= offset (cadddr event) size))
            (error "Incomplete Org event partition"))
          (let (p (find (lambda (v) (eq? (frame-kind v) 'OrgNodeProperty)) stack))
            (when p
              (case (cadr event)
                ((PropertyKey)
                 (set! (frame-key-start p) offset)
                 (set! (frame-key-end p) (cadddr event)))
                ((PropertyValue)
                 (set! (frame-value-start p) offset)
                 (set! (frame-value-end p) (cadddr event))))))
          (set! offset (cadddr event)))
         ((finish)
          (unless (pair? stack)
            (error "Unbalanced Org event"))
          (let (p (car stack))
            (set! stack (cdr stack))
            (when (and
                   (eq? (frame-kind p) 'OrgNodeProperty)
                   (frame-key-start p)
                   (pair? stack)
                   (pair? (cdr stack))
                   (eq? (frame-kind (car stack)) 'OrgPropertyDrawer)
                   (memq (frame-kind (cadr stack)) '(OrgFile OrgSection)))
              (unless (and
                       (frame-value-start p)
                       (< (frame-value-start p) (frame-value-end p)))
                (error "Empty Org Contract property"))
              (set!
               properties
               (cons
                (list
                 (frame-kind (cadr stack))
                 (frame-start (cadr stack))
                 (string-upcase (slice (frame-key-start p) (frame-key-end p)))
                 (slice (frame-value-start p) (frame-value-end p)))
                properties)))))
         (else (error "Unknown Org event"))))
     (parse-org-native-events raw))
    (unless (and (= roots 1) (null? stack) (= offset size) (.ref projection 'complete?))
      (error "Incomplete Org source"))
    (let* ((props (reverse properties))
           (at-root
            (lambda (key)
              (let (p
                    (find
                     (lambda (p)
                       (and (eq? (car p) 'OrgFile) (equal? (caddr p) key)))
                     props))
                (and p (cadddr p)))))
           (contract-id (at-root "CONTRACT_ID"))
           (contract-rev (at-root "CONTRACT_REVISION"))
           (session-id-value (at-root "SESSION_ID"))
           (id-props (filter (lambda (p) (equal? (caddr p) "ID")) props))
           (ids (map cadddr id-props)))
      (unless (and
               (text? (at-root "ID"))
               (text? contract-id)
               (text? contract-rev)
               (<= 1 (length ids) 32)
               (andmap text? ids)
               (= (length ids) (length (delete-duplicates/hash ids)))
               (=
                (length props)
                (length
                 (delete-duplicates/hash
                  (map (lambda (p) (list (car p) (cadr p) (caddr p))) props)))))
        (error "Org Contract requires unique local IDs and root contract revision"))
      (when (equal? contract-id "context.consumer.v1")
        (unless (and (text? session-id-value)
                     (= (string-length session-id-value) 71)
                     (string=? (substring session-id-value 0 7) "sha256:")
                     (andmap
                      (lambda (ch)
                        (or (char<=? #\0 ch #\9)
                            (char<=? #\a ch #\f)))
                      (string->list (substring session-id-value 7 71))))
          (error "Consumer Org Contract requires its owner-derived Session ID")))
      (let* ((sid (string-copy identity-value))
             (cut
              (agentic-ai-lab-ai-agentic-context-digest
               (list
                'org-contract-cut.v1
                sid
                generation-value
                source-digest-value
                contract-id
                contract-rev
                active-value)))
             (nodes-value
              (map
               (lambda (p)
                 (let ((qualified
                        (agentic-ai-lab-ai-agentic-context-digest
                         (list 'org-element.v1 sid (cadddr p))))
                       (local-id (string-copy (cadddr p)))
                       (kind-value (symbol->string (car p)))
                       (start-value (cadr p)))
                   (.o
                     label: 'OrgElement
                     identity: qualified
                     propertyId: local-id
                     sourceId: sid
                     sourceRevision: generation-value
                     sourceDigest: source-digest-value
                     contractIdentity: contract-id
                     contractRevision: contract-rev
                     elementKind: kind-value
                     byteStart: start-value
                     parserIdentity: org-source-headline-parser-identity)))
               id-props)))
        (.o
          kind: 'context.org-source.v1
          identity: sid
          generation: generation-value
          source: raw
          source-digest: source-digest-value
          contract-identity: contract-id
          contract-revision: contract-rev
          session-identity: session-id-value
          parser-identity: org-source-headline-parser-identity
          active?: active-value
          nodes: nodes-value
          semantic-digest: cut)))))
