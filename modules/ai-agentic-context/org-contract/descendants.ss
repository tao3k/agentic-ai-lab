;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .o .ref)
        (only-in :std/list/list find filter-map)
        (only-in :orgize/languages/org/modules/org-elements/source-interface
                 org-source-element-graph org-source-element-field)
        (only-in :orgize/languages/org/modules/org-contract/evaluation org-contract-select)
        (only-in :orgize/languages/org/modules/org-elements/values org-element-graph-records)
        "../funs-scope.ss")
(export context-org-descendants context-org-anchor-element)

(def digest agentic-ai-lab-ai-agentic-context-digest)

(def (context-org-anchor-element records anchor)
  (find (lambda (row) (equal? (org-source-element-field row "property:ID") anchor)) records))

;; The path lists ancestors in root-first order, including the scoped anchor
;; and excluding the selected Element. Byte coordinates are half-open UTF-8.
(def (context-org-descendants source anchor max-depth result-bound (element-query #f))
  (unless (and (string? anchor) (exact-integer? max-depth) (<= 1 max-depth 32)
               (exact-integer? result-bound) (<= 1 result-bound 32))
    (error "Invalid Org descendant window"))
  (let* ((raw (.ref source 'source))
         (bytes (string->utf8 raw))
         (length-bytes (u8vector-length bytes))
         (source-id (.ref source 'identity))
         (generation (.ref source 'generation))
         (source-digest (.ref source 'source-digest))
         (parser (.ref source 'parser-identity))
         (contract (.ref source 'contract-identity))
         (contract-revision (.ref source 'contract-revision))
         (cut (.ref source 'semantic-digest))
         (graph (org-source-element-graph raw))
         (records (org-element-graph-records graph))
         (root (and (find (lambda (row) (equal? (.ref row 'propertyId) anchor)) (.ref source 'nodes))
                    (context-org-anchor-element records anchor)))
         (index (make-hash-table-eqv)))
    (unless root (error "Unknown Org descendant root" anchor))
    (for-each (lambda (record) (hash-put! index (.ref record 'id) record)) records)
    (def (element-id row) (digest (list 'context-org-graph-element.v1 cut parser (.ref row 'id))))
    (def (range row)
      (let ((start (.ref row 'start)) (end (.ref row 'end)))
        (unless (<= 0 start end length-bytes) (error "Org Element span is outside its source"))
        (list (element-id row) (.ref row 'kind) start end)))
    (def (ancestors row)
      (let walk ((child row) (fuel max-depth) (path '()))
        (and (> fuel 0) (not (eq? child root))
             (let (parent (hash-get index (.ref child 'parent)))
               (and parent
                    (begin
                      (unless (<= (.ref parent 'start) (.ref child 'start)
                                  (.ref child 'end) (.ref parent 'end))
                        (error "Org descendant span escapes its parent"))
                      (let (next (cons (range parent) path))
                        (if (eq? parent root) next (walk parent (- fuel 1) next)))))))))
    (let* ((candidates (if element-query
                           (org-contract-select element-query graph (.ref root 'id))
                           records))
           (count 0)
           (nodes
           (filter-map
            (lambda (row)
              (let* ((kind (.ref row 'kind))
                     (path (and (member kind '("table" "paragraph" "link")) (ancestors row))))
                (and path
                     (match (range row)
                       ([element-id kind start end]
                        (set! count (+ count 1))
                        (when (> count result-bound)
                          (error "Org descendant result bound exceeded" result-bound))
                        (let ((path-digest (digest path))
                              (content (utf8->string (subu8vector bytes start end))))
                          (.o label: 'OrgElement identity: element-id rootAnchor: anchor
                              sourceId: source-id sourceRevision: generation sourceDigest: source-digest
                              contractIdentity: contract contractRevision: contract-revision
                              elementKind: kind byteStart: start byteEnd: end parserIdentity: parser
                              ancestryDigest: path-digest ancestry: path text: content
                              link-path: (and (equal? kind "link")
                                              (org-source-element-field row "path")))))))))
            candidates))
           (root-coordinates (range root)))
      (.o root-range: root-coordinates descendants: nodes))))
