;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Native Org Elements -> YuanxuGraph projection, Org Elements -> ISO GQL
;;; expression compiler, ready-task slice resolver, and parser-verified Org
;;; structural updaters (`org-babel`, checklists, fission).
(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :std/list/list every find filter-map append-map)
        (only-in :std/string/misc string-trim string-prefix? string-contains)
        (only-in :tao3k/yuanxu/graph/types
                 yuanxu-graph yuanxu-graph-node yuanxu-graph-edge
                 yuanxu-graph-edges yuanxu-graph-edge-from yuanxu-graph-edge-to
                 yuanxu-graph-edge-kind yuanxu-graph-nodes yuanxu-graph-node-id
                 yuanxu-graph-node-payload)
        (only-in :orgize/languages/org/modules/org-elements/value-types
                 org-element-query?)
        (only-in :orgize/languages/org/modules/org-elements/values
                 org-element-graph-records
                 org-element-query-node-kind org-element-query-groups
                 org-element-query-relation org-element-query-target
                 org-element-clause-name org-element-clause-value
                 org-element-clause-match)
        (only-in :orgize/languages/org/modules/org-elements/query
                 make-org-element-query-context org-element-property)
        (only-in :orgize/languages/org/modules/org-elements/link-properties
                 org-image-link? org-link-kind org-link-protocol
                 org-link-attachment-path org-link-target-key)
        (only-in :tao3k/agentic-ai-lab/modules/query/semantic/orgize-source-interface
                 org-source-element-graph org-source-element-field)
        (only-in :tao3k/agentic-ai-lab/modules/query/objects
                 AgenticAILabQuery. AgenticAILabQueryElementSpace.
                 AgenticAILabSchemeGqlQueryLanguage. AgenticAILabGqlQueryProgram.
                 GraphSyntaxNode. GraphSyntaxStep. GraphSyntaxPath.
                 GraphSyntaxEquals. GraphSyntaxLiteral. GraphSyntaxProperty.
                 GraphSyntaxProjection. agentic-ai-lab-query-result-contract)
        (only-in :tao3k/agentic-ai-lab/modules/query/gql agentic-ai-lab-query->gql)
        (only-in :tao3k/agentic-ai-lab/modules/query/scheme-graph
                 agentic-ai-lab-query-select-scheme-graph)
        "types.ss" "objects.ss" "funs-scope.ss" "funs-org-properties.ss")
(export agentic-ai-lab-ai-agentic-context-org-element-graph
        agentic-ai-lab-ai-agentic-context-org-element->gql-query
        agentic-ai-lab-ai-agentic-context-org-elements-select
        agentic-ai-lab-ai-agentic-context-ready-task-slices
        agentic-ai-lab-ai-agentic-context-babel-upsert-results
        agentic-ai-lab-ai-agentic-context-checklist-set
        agentic-ai-lab-ai-agentic-context-headline-set-todo
        agentic-ai-lab-ai-agentic-context-fission-subtree)

(def digest agentic-ai-lab-ai-agentic-context-digest)

(def (org-source-cut? v)
  (and (object? v) (.slot? v 'kind)
       (eq? (.ref v 'kind) 'context.org-source.v1)
       (eq? (.ref v 'active?) #t)))

(def (utf8-slice bytes start end)
  (utf8->string (subu8vector bytes start end)))

(def (count-lines text)
  (let ((len (string-length text)))
    (if (zero? len) 0
      (let loop ((i 0) (n 1))
        (cond
         ((= i len) (if (char=? (string-ref text (- len 1)) #\newline) (- n 1) n))
         ((char=? (string-ref text i) #\newline) (loop (+ i 1) (+ n 1)))
         (else (loop (+ i 1) n)))))))

(def (split-csv text)
  (if (not (string? text)) '()
    (let loop ((chars (string->list text)) (cur '()) (acc '()))
      (cond
       ((null? chars)
        (let (s (string-trim (list->string (reverse cur))))
          (reverse (if (string-empty? s) acc (cons s acc)))))
       ((char=? (car chars) #\,)
        (let (s (string-trim (list->string (reverse cur))))
          (loop (cdr chars) '() (if (string-empty? s) acc (cons s acc)))))
       (else (loop (cdr chars) (cons (car chars) cur) acc))))))

(def (timestamp-part record key)
  (let (values (org-source-element-field record key))
    (and (pair? values) (null? (cdr values)) (string->number (car values)))))

(def (timestamp-epoch timestamp offset-minutes)
  (let ((year (timestamp-part timestamp "year"))
        (month (timestamp-part timestamp "month"))
        (day (timestamp-part timestamp "day"))
        (hour (or (timestamp-part timestamp "hour") 0))
        (minute (or (timestamp-part timestamp "minute") 0)))
    (def (leaps y) (- (+ (quotient y 4) (quotient y 400)) (quotient y 100)))
    (and (not (org-source-element-field timestamp "range-separator"))
         (not (org-source-element-field timestamp "time-range-separator"))
         (andmap exact-integer? (list year month day hour minute))
         (<= 1970 year 9999) (<= 1 month 12) (<= 0 hour 23) (<= 0 minute 59)
         (let* ((lengths (list 31 (+ 28 (- (leaps year) (leaps (- year 1))))
                               31 30 31 30 31 31 30 31 30 31))
                (before-month (let loop ((left (- month 1)) (days lengths) (sum 0))
                                (if (zero? left) sum
                                  (loop (- left 1) (cdr days) (+ sum (car days)))))))
           (and (<= 1 day (list-ref lengths (- month 1)))
                (- (+ (* 86400 (+ (* (- year 1970) 365)
                                  (- (leaps (- year 1)) (leaps 1969))
                                  before-month (- day 1)))
                      (* 3600 hour) (* 60 minute))
                   (* 60 offset-minutes)))))))

(def (normalize-checkbox raw)
  (cond
   ((or (not raw) (equal? raw "")) (values "" "" "none"))
   ((or (equal? raw " ") (equal? raw "[ ]") (equal? raw "unchecked"))
    (values "[ ]" " " "unchecked"))
   ((or (equal? raw "-") (equal? raw "[-]") (equal? raw "partial"))
    (values "[-]" "-" "partial"))
   ((or (equal? raw "X") (equal? raw "x") (equal? raw "[X]") (equal? raw "checked"))
    (values "[X]" "X" "checked"))
   (else (values (string-copy raw) (string-copy raw) "other"))))

(def (parse-header-arguments record)
  (let ((keys (or (org-source-element-field record "argument-key") '()))
        (raws (or (org-source-element-field record "argument-raw") '()))
        (table (make-hash-table)))
    (let loop ((ks keys) (rs raws))
      (when (and (pair? ks) (pair? rs))
        (let* ((k (string-downcase (string-trim (car ks))))
               (r (string-trim (car rs)))
               (prefix (string-append ":" k))
               (val (if (and (>= (string-length r) (string-length prefix))
                             (string-ci=? (substring r 0 (string-length prefix)) prefix))
                      (string-trim (substring r (string-length prefix) (string-length r)))
                      r)))
          (hash-put! table k val)
          (loop (cdr ks) (cdr rs)))))
    table))

(def (count-stars markers)
  (if (not (string? markers)) 1
    (let ((len (string-length markers)))
      (let loop ((i 0))
        (if (and (< i len) (char=? (string-ref markers i) #\*))
          (loop (+ i 1))
          (max 1 i))))))

(def (enclosing-headline-record record by-id)
  (let loop ((pid (.ref record 'parent)))
    (and pid
         (let (p (hash-get by-id pid))
           (and p
                (if (member (.ref p 'kind) '("headline" "inlinetask"))
                  p
                  (loop (.ref p 'parent))))))))

(def (gql-node binding label)
  (.o (:: @ GraphSyntaxNode.) binding label))

(def (gql-path start-binding start-label steps)
  (let ((start (gql-node start-binding start-label))
        (next (foldr (lambda (step next)
                       (with ([relation binding label] step)
                         (let (target (gql-node binding label))
                           (.o (:: @ GraphSyntaxStep.) relation target next))))
                     #f steps)))
    (.o (:: @ GraphSyntaxPath.) start next)))

(def (gql-literal val)
  (let ((literal-kind (cond ((string? val) 'string)
                            ((exact-integer? val) 'integer)
                            ((boolean? val) 'boolean)
                            ((symbol? val) 'symbol)
                            (else (error "Unsupported GQL literal value" val))))
        (value (if (string? val) (string-copy val) val)))
    (.o (:: @ GraphSyntaxLiteral.) literal-kind value)))

(def (gql-equals binding property val)
  (let ((left (.o (:: @ GraphSyntaxProperty.) binding property))
        (right (gql-literal val)))
    (.o (:: @ GraphSyntaxEquals.) left right)))

(def (gql-projections pairs)
  (foldr (lambda (pair next)
           (let* ((binding (car pair))
                  (property (cdr pair))
                  (expression (.o (:: @ GraphSyntaxProperty.) binding property)))
             (.o (:: @ GraphSyntaxProjection.) expression next)))
         #f pairs))

(def (make-element-gql-query elem-graph identity fields bound match where project)
  (let ((version "1")
        (semantic-revision (.ref elem-graph 'semantic-revision))
        (element-space-identity (.ref elem-graph 'identity))
        (selected-element-identities (.ref elem-graph 'element-identities))
        (language AgenticAILabSchemeGqlQueryLanguage.)
        (result-bound bound)
        (completeness-requirement (if (.ref elem-graph 'complete?) 'complete 'partial-allowed))
        (result-contract (agentic-ai-lab-query-result-contract identity 'relation-row fields bound))
        (program (.o (:: @ AgenticAILabGqlQueryProgram.) identity match where project)))
    (.o (:: @ AgenticAILabQuery.)
        identity version semantic-revision element-space-identity
        selected-element-identities language result-bound
        completeness-requirement result-contract program)))

;;; ---------------------------------------------------------------------------
;;; Pillar 1: Rich Native Org Elements -> YuanxuGraph Projection
;;; ---------------------------------------------------------------------------

(def (agentic-ai-lab-ai-agentic-context-org-element-graph
      identity sources (complete? #t) (tz-offset 0))
  (unless (and (symbol? identity)
               (pair? sources) (list? sources) (<= (length sources) 64)
               (every org-source-cut? sources)
               (boolean? complete?) (exact-integer? tz-offset))
    (error "Org element graph requires bounded active Org source cuts"))
  (let ((node-table (make-hash-table))
        (edge-table (make-hash-table))
        (headline-by-anchor (make-hash-table))
        (node-order '())
        (edge-order '())
        (deferred-links '())
        (collected-texts '()))
    (def (add-node! id payload)
      (unless (hash-get node-table id)
        (hash-put! node-table id (yuanxu-graph-node id payload))
        (set! node-order (cons id node-order))))
    (def (add-edge! from to kind)
      (let (k (list from to kind))
        (unless (hash-get edge-table k)
          (hash-put! edge-table k (yuanxu-graph-edge from to kind))
          (set! edge-order (cons k edge-order)))))
    (for-each
     (lambda (src)
       (let* ((sid (string-copy (.ref src 'identity)))
              (srev (.ref src 'generation))
              (sdigest (string-copy (.ref src 'source-digest)))
              (cid (string-copy (.ref src 'contract-identity)))
              (text (.ref src 'source))
              (bytes (string->utf8 text))
              (byteSize (u8vector-length bytes))
              (lineCount (count-lines text))
              (view (org-source-element-graph text))
              (ctx (make-org-element-query-context view))
              (records (list-sort (lambda (a b) (< (.ref a 'start) (.ref b 'start)))
                                  (org-element-graph-records view)))
              (by-id (make-hash-table))
              (headline-qid (make-hash-table))
              (headline-prop-id (make-hash-table))
              (headline-attach-dir (make-hash-table))
              (planning-by-parent (make-hash-table))
              (timestamps-by-parent (make-hash-table))
              (cookies-by-parent (make-hash-table))
              (keywords-ordered '())
              (drawers-ordered '())
              (special-blocks-by-parent (make-hash-table))
              (src-node-id (string-append "source:" sid)))
         (set! collected-texts (cons (cons sid (string-copy text)) collected-texts))
         (for-each
          (lambda (r)
            (hash-put! by-id (.ref r 'id) r)
            (let (k (.ref r 'kind))
              (cond
               ((equal? k "planning")
                (hash-put! planning-by-parent (.ref r 'parent) r))
               ((equal? k "timestamp")
                (hash-put! timestamps-by-parent (.ref r 'parent)
                           (append (or (hash-get timestamps-by-parent (.ref r 'parent)) '())
                                   (list r))))
               ((equal? k "statistics-cookie")
                (hash-put! cookies-by-parent (.ref r 'parent) r))
               ((equal? k "keyword")
                (set! keywords-ordered (cons r keywords-ordered)))
               ((equal? k "drawer")
                (set! drawers-ordered (cons r drawers-ordered)))
               ((equal? k "special-block")
                (hash-put! special-blocks-by-parent (.ref r 'parent)
                           (append (or (hash-get special-blocks-by-parent (.ref r 'parent)) '())
                                   (list r)))))))
          records)
         (set! keywords-ordered (reverse keywords-ordered))
         (set! drawers-ordered (reverse drawers-ordered))
         (let* ((root-rec (find (lambda (r) (equal? (.ref r 'kind) "org-data")) records))
                (rootAnchorId (string-copy (or (and root-rec (org-element-property ctx root-rec "property:ID")) "")))
                (projectId (string-copy (or (and root-rec (or (org-element-property ctx root-rec "property:GITOPS_PROJECT")
                                                              (org-element-property ctx root-rec "property:PROJECT_ID")))
                                            "")))
                (worktreeId (string-copy (or (and root-rec (or (org-element-property ctx root-rec "property:GITOPS_WORKTREE")
                                                               (org-element-property ctx root-rec "property:WORKTREE_ID")))
                                             ""))))
           (let ((identity src-node-id)
                 (label 'OrgSource)
                 (sourceId sid)
                 (sourceRevision srev)
                 (sourceDigest sdigest)
                 (contractIdentity cid))
             (add-node! src-node-id
               (.o identity label sourceId sourceRevision sourceDigest
                   contractIdentity projectId worktreeId rootAnchorId
                   lineCount byteSize)))
           ;; 1. Project Headline / Inlinetask elements
           (for-each
            (lambda (r)
              (when (member (.ref r 'kind) '("headline" "inlinetask"))
                (let* ((rid (.ref r 'id))
                       (prop-id (or (org-element-property ctx r "property:ID") ""))
                       (qid (if (string-empty? prop-id)
                              (digest (list 'org-headline.v1 sid (.ref r 'start) (.ref r 'end)))
                              (digest (list 'org-element.v1 sid prop-id))))
                       (title (string-copy (or (org-element-property ctx r "title") "")))
                       (sourceTitle (string-trim (or (org-element-property ctx r "source-title") "")))
                       (level (count-stars (org-element-property ctx r "markers")))
                       (todoKeyword (string-copy (or (org-element-property ctx r "todo-keyword") "")))
                       (todoType (string-copy (or (org-element-property ctx r "todo-type") "")))
                       (priority (string-copy (or (org-element-property ctx r "priority") "")))
                       (tags-list (or (org-element-property ctx r "tags") '()))
                       (tagsCsv (if (null? tags-list) ""
                                  (string-append ":" (string-join tags-list ":") ":")))
                       (hasAttachTag (and (member "ATTACH" tags-list) #t))
                       (dir-prop (org-element-property ctx r "property:DIR"))
                       (attachDir (cond
                                   ((and dir-prop (not (string-empty? dir-prop)))
                                    (string-copy dir-prop))
                                   ((and hasAttachTag (not (string-empty? prop-id)))
                                    (string-append "data/" prop-id))
                                   (else "")))
                       (plan (hash-get planning-by-parent rid))
                       (plan-keys (or (and plan (org-source-element-field plan "key")) '()))
                       (plan-vals (or (and plan (org-source-element-field plan "value")) '()))
                       (plan-ts (or (and plan (hash-get timestamps-by-parent (.ref plan 'id))) '()))
                       (find-plan
                        (lambda (target-key)
                          (let loop ((ks plan-keys) (vs plan-vals) (ts plan-ts))
                            (if (null? ks)
                              (values "" -1)
                              (if (string-ci=? (car ks) target-key)
                                (values (string-trim (if (pair? vs) (car vs) ""))
                                        (or (and (pair? ts) (timestamp-epoch (car ts) tz-offset)) -1))
                                (loop (cdr ks) (if (pair? vs) (cdr vs) '())
                                      (if (pair? ts) (cdr ts) '())))))))
                       (cookie (hash-get cookies-by-parent rid))
                       (cookieValue (string-copy (or (and cookie (org-source-element-field cookie "value")) "")))
                       (ownerAgentId (string-copy (or (org-element-property ctx r "property:AGENT_ID") "")))
                       (reviewerAgentId (string-copy (or (org-element-property ctx r "property:REVIEWER_AGENT_ID") "")))
                       (agentTier (string-copy (or (org-element-property ctx r "property:AGENT_TIER")
                                                   (org-element-property ctx r "property:MODEL_TIER") "")))
                       (taskId (string-copy (or (org-element-property ctx r "property:TASK_ID") "")))
                       (componentId (string-copy (or (org-element-property ctx r "property:ARCH_COMPONENT") "")))
                       (activeDefeaters (string-copy (or (org-element-property ctx r "property:ACTIVE_DEFEATERS") "")))
                       (originModule (string-copy (or (org-element-property ctx r "property:CONTEXT_ORIGIN_MODULE") "")))
                       (originSource (string-copy (or (org-element-property ctx r "property:CONTEXT_ORIGIN_SOURCE") "")))
                       (originId (string-copy (or (org-element-property ctx r "property:CONTEXT_ORIGIN_ID") "")))
                       (byteStart (.ref r 'start))
                       (byteEnd (.ref r 'end)))
                  (let-values (((scheduledRaw scheduledEpoch) (find-plan "SCHEDULED"))
                               ((deadlineRaw deadlineEpoch) (find-plan "DEADLINE"))
                               ((closedRaw _closedEpoch) (find-plan "CLOSED")))
                    (hash-put! headline-qid rid qid)
                    (hash-put! headline-prop-id rid (string-copy prop-id))
                    (hash-put! headline-attach-dir rid attachDir)
                    (unless (string-empty? prop-id)
                      (unless (hash-get headline-by-anchor prop-id)
                        (hash-put! headline-by-anchor prop-id qid))
                      (hash-put! headline-by-anchor (string-append sid "#" prop-id) qid))
                    (let ((identity qid)
                          (label 'OrgHeadline)
                          (sourceId sid)
                          (propertyId (string-copy prop-id)))
                      (add-node! qid
                        (.o identity label sourceId propertyId title sourceTitle
                            level todoKeyword todoType priority tagsCsv
                            hasAttachTag attachDir scheduledRaw scheduledEpoch
                            deadlineRaw deadlineEpoch closedRaw cookieValue
                            ownerAgentId reviewerAgentId agentTier taskId componentId
                            activeDefeaters originModule originSource originId
                            byteStart byteEnd)))
                    (add-edge! src-node-id qid 'HAS_HEADLINE)
                    (let (parent-h (enclosing-headline-record r by-id))
                      (when parent-h
                        (let (pqid (hash-get headline-qid (.ref parent-h 'id)))
                          (when pqid (add-edge! pqid qid 'PARENT_OF)))))
                    (for-each
                     (lambda (dep)
                       (set! deferred-links (cons (list 'depends-on sid qid dep) deferred-links)))
                     (split-csv (org-element-property ctx r "property:DEPENDS_ON")))
                    (when (not (string-empty? originId))
                      (set! deferred-links
                        (cons (list 'evolved-from originSource qid originId) deferred-links)))))))
            records)
           ;; 2. Project Drawers & Special Blocks (e.g. RESULTS, THINKING)
           (let ((drawer-qid-by-rid (make-hash-table)))
             (for-each
              (lambda (r)
                (when (member (.ref r 'kind) '("drawer" "special-block"))
                  (let* ((rid (.ref r 'id))
                         (dqid (digest (list 'org-drawer.v1 sid (.ref r 'start) (.ref r 'end))))
                         (owner-h (enclosing-headline-record r by-id))
                         (headlineId (or (and owner-h (hash-get headline-qid (.ref owner-h 'id))) ""))
                         (headlinePropertyId (or (and owner-h (hash-get headline-prop-id (.ref owner-h 'id))) ""))
                         (drawerName (string-upcase (string-trim (or (org-source-element-field r "name") ""))))
                         (drawerKind (string-copy (.ref r 'kind)))
                         (raw-slice (utf8-slice bytes (.ref r 'start) (.ref r 'end)))
                         (bodyText (let* ((nl (string-index raw-slice #\newline))
                                          (after-first (if nl (substring raw-slice (+ nl 1) (string-length raw-slice)) ""))
                                          (trimmed (string-trim after-first))
                                          (lines (reverse (string-split after-first #\newline)))
                                          (drop-end
                                           (let loop ((ls lines))
                                             (cond
                                              ((null? ls) '())
                                              ((string-empty? (string-trim (car ls))) (loop (cdr ls)))
                                              (else (reverse (cdr ls)))))))
                                     (if (null? drop-end) trimmed
                                       (string-trim (string-join drop-end "\n")))))
                         (byteStart (.ref r 'start))
                         (byteEnd (.ref r 'end)))
                    (hash-put! drawer-qid-by-rid rid dqid)
                    (let ((identity dqid)
                          (label 'OrgDrawer)
                          (sourceId sid))
                      (add-node! dqid
                        (.o identity label sourceId headlineId headlinePropertyId
                            drawerName drawerKind bodyText byteStart byteEnd)))
                    (if (not (string-empty? headlineId))
                      (add-edge! headlineId dqid 'HAS_DRAWER)
                      (add-edge! src-node-id dqid 'HAS_DRAWER))
                    (let (parent-rec (and (.ref r 'parent) (hash-get by-id (.ref r 'parent))))
                      (when (and parent-rec (equal? (.ref parent-rec 'kind) "drawer"))
                        (let (pdqid (hash-get drawer-qid-by-rid (.ref parent-rec 'id)))
                          (when pdqid (add-edge! pdqid dqid 'CONTAINS_DRAWER))))))))
              records)
             ;; 3. Project Plain-List / Checklist Items (`item`)
             (for-each
              (lambda (r)
                (when (equal? (.ref r 'kind) "item")
                  (let* ((iqid (digest (list 'org-item.v1 sid (.ref r 'start) (.ref r 'end))))
                         (owner-h (enclosing-headline-record r by-id))
                         (headlineId (or (and owner-h (hash-get headline-qid (.ref owner-h 'id))) ""))
                         (headlinePropertyId (or (and owner-h (hash-get headline-prop-id (.ref owner-h 'id))) ""))
                         (bullet (string-trim (or (org-source-element-field r "bullet") "-")))
                         (tag (string-trim (or (org-source-element-field r "tag") "")))
                         (raw-slice (string-trim (utf8-slice bytes (.ref r 'start) (.ref r 'end))))
                         (first-line (car (string-split raw-slice #\newline)))
                         (byteStart (.ref r 'start))
                         (byteEnd (.ref r 'end)))
                    (let-values (((checkbox checkboxRaw checkboxState)
                                  (normalize-checkbox (org-source-element-field r "checkbox"))))
                      (let* ((after-bullet
                              (if (string-prefix? bullet first-line)
                                (string-trim (substring first-line (string-length bullet) (string-length first-line)))
                                first-line))
                             (itemText
                              (if (and (not (string-empty? checkbox))
                                       (>= (string-length after-bullet) 3)
                                       (char=? (string-ref after-bullet 0) #\[)
                                       (char=? (string-ref after-bullet 2) #\]))
                                (string-trim (substring after-bullet 3 (string-length after-bullet)))
                                after-bullet))
                             (identity iqid)
                             (label 'OrgListItem)
                             (sourceId sid))
                        (add-node! iqid
                          (.o identity label sourceId headlineId headlinePropertyId
                              bullet checkbox checkboxRaw checkboxState tag
                              itemText byteStart byteEnd))
                        (if (not (string-empty? headlineId))
                          (add-edge! headlineId iqid 'HAS_ITEM)
                          (add-edge! src-node-id iqid 'HAS_ITEM)))))))
              records)
             ;; 4. Project Source Blocks / Org-Babel Units (`src-block`)
             (for-each
              (lambda (r)
                (when (equal? (.ref r 'kind) "src-block")
                  (let* ((bqid (digest (list 'org-src-block.v1 sid (.ref r 'start) (.ref r 'end))))
                         (owner-h (enclosing-headline-record r by-id))
                         (headlineId (or (and owner-h (hash-get headline-qid (.ref owner-h 'id))) ""))
                         (headlinePropertyId (or (and owner-h (hash-get headline-prop-id (.ref owner-h 'id))) ""))
                         (name-kw
                          (find (lambda (kw)
                                  (and (equal? (.ref kw 'parent) (.ref r 'parent))
                                       (string-ci=? (or (org-source-element-field kw "key") "") "NAME")
                                       (<= (.ref kw 'end) (.ref r 'start))
                                       (string-empty? (string-trim (utf8-slice bytes (.ref kw 'end) (.ref r 'start))))))
                                (reverse keywords-ordered)))
                         (blockName (string-trim (or (and name-kw (org-source-element-field name-kw "value")) "")))
                         (language (string-trim (or (org-source-element-field r "language") "")))
                         (hdr (parse-header-arguments r))
                         (model (string-copy (or (hash-get hdr "model") "")))
                         (thinking (string-copy (or (hash-get hdr "thinking") "")))
                         (resultsMode (string-copy (or (hash-get hdr "results") "")))
                         (tier (string-copy (or (hash-get hdr "tier") "")))
                         (rawBody (string-copy (or (org-source-element-field r "raw-body") "")))
                         (res-kw
                          (and (not (string-empty? blockName))
                               (find (lambda (kw)
                                       (and (equal? (.ref kw 'parent) (.ref r 'parent))
                                            (string-ci=? (or (org-source-element-field kw "key") "") "RESULTS")
                                            (equal? (string-trim (or (org-source-element-field kw "value") "")) blockName)
                                            (>= (.ref kw 'start) (.ref r 'end))))
                                     keywords-ordered)))
                         (res-drawer
                          (and res-kw
                               (find (lambda (dr)
                                       (and (equal? (.ref dr 'parent) (.ref r 'parent))
                                            (string-ci=? (or (org-source-element-field dr "name") "") "RESULTS")
                                            (>= (.ref dr 'start) (.ref res-kw 'end))
                                            (string-empty? (string-trim (utf8-slice bytes (.ref res-kw 'end) (.ref dr 'start))))))
                                     drawers-ordered)))
                         (hasResults (and res-drawer #t))
                         (res-dqid (and res-drawer (hash-get drawer-qid-by-rid (.ref res-drawer 'id))))
                         (res-node (and res-dqid (yuanxu-graph-node-payload (hash-get node-table res-dqid))))
                         (thinking-block
                          (and res-drawer
                               (find (lambda (sb)
                                       (string-ci=? (or (org-source-element-field sb "name") "") "THINKING"))
                                     (or (hash-get special-blocks-by-parent (.ref res-drawer 'id)) '()))))
                         (tb-dqid (and thinking-block (hash-get drawer-qid-by-rid (.ref thinking-block 'id))))
                         (tb-node (and tb-dqid (yuanxu-graph-node-payload (hash-get node-table tb-dqid))))
                         (thinkingText (string-copy (or (and tb-node (.ref tb-node 'bodyText)) "")))
                         (resultsText (string-copy (or (and res-node
                                                            (if thinking-block
                                                              (string-trim
                                                               (string-append
                                                                (utf8-slice bytes
                                                                            (+ (.ref res-drawer 'start) 10)
                                                                            (.ref thinking-block 'start))
                                                                "\n"
                                                                (utf8-slice bytes
                                                                            (.ref thinking-block 'end)
                                                                            (max (.ref thinking-block 'end)
                                                                                 (- (.ref res-drawer 'end) 6)))))
                                                              (.ref res-node 'bodyText)))
                                                       "")))
                         (byteStart (if name-kw (.ref name-kw 'start) (.ref r 'start)))
                         (byteEnd (.ref r 'end))
                         (resultsSpanStart (if res-kw (.ref res-kw 'start) -1))
                         (resultsSpanEnd (if res-drawer (.ref res-drawer 'end) -1))
                         (identity bqid)
                         (label 'OrgSrcBlock)
                         (sourceId sid))
                    (add-node! bqid
                      (.o identity label sourceId headlineId headlinePropertyId
                          blockName language model thinking resultsMode tier
                          rawBody hasResults resultsText thinkingText
                          byteStart byteEnd resultsSpanStart resultsSpanEnd))
                    (add-edge! src-node-id bqid 'HAS_SRC_BLOCK)
                    (when (not (string-empty? headlineId))
                      (add-edge! headlineId bqid 'HAS_SRC_BLOCK))
                    (when res-dqid
                      (add-edge! bqid res-dqid 'PRODUCES_RESULTS)))))
              records)
             ;; 5. Project Links (`link`, including `attachment:` and `id:`)
             (for-each
              (lambda (r)
                (when (equal? (.ref r 'kind) "link")
                  (let* ((lqid (digest (list 'org-link.v1 sid (.ref r 'start) (.ref r 'end))))
                         (owner-h (enclosing-headline-record r by-id))
                         (headlineId (or (and owner-h (hash-get headline-qid (.ref owner-h 'id))) ""))
                         (headlinePropertyId (or (and owner-h (hash-get headline-prop-id (.ref owner-h 'id))) ""))
                         (attachDir (or (and owner-h (hash-get headline-attach-dir (.ref owner-h 'id))) ""))
                         (rawPath (string-trim (or (org-source-element-field r "path") "")))
                         (description (string-trim (or (org-source-element-field r "description") "")))
                         (linkKind (org-link-kind rawPath))
                         (protocol (if (equal? linkKind "uri") (org-link-protocol rawPath)
                                     (if (equal? linkKind "id") "id" linkKind)))
                         (targetPath (cond
                                      ((equal? protocol "attachment") (org-link-attachment-path rawPath))
                                      ((equal? protocol "id")
                                       (let (tk (org-link-target-key rawPath))
                                         (if (string-prefix? "id:" tk)
                                           (substring tk 3 (string-length tk))
                                           tk)))
                                      (else rawPath)))
                         (imageLink (and (org-image-link? targetPath) #t))
                         (byteStart (.ref r 'start))
                         (byteEnd (.ref r 'end))
                         (identity lqid)
                         (label 'OrgLink)
                         (sourceId sid))
                    (add-node! lqid
                      (.o identity label sourceId headlineId headlinePropertyId
                          rawPath linkKind protocol targetPath description
                          imageLink attachDir byteStart byteEnd))
                    (if (not (string-empty? headlineId))
                      (add-edge! headlineId lqid 'HAS_LINK)
                      (add-edge! src-node-id lqid 'HAS_LINK))
                    (when (equal? protocol "id")
                      (set! deferred-links (cons (list 'link-id sid lqid targetPath) deferred-links))))))
              records)))))
     sources)
    (for-each
     (lambda (entry)
       (match entry
         (['depends-on sid from-qid ref]
          (let (to-qid (or (hash-get headline-by-anchor (string-append sid "#" ref))
                           (hash-get headline-by-anchor ref)))
            (when (and to-qid (hash-get node-table to-qid))
              (add-edge! from-qid to-qid 'DEPENDS_ON))))
         (['evolved-from origin-src from-qid origin-id]
          (let (to-qid (or (and (not (string-empty? origin-src))
                                (hash-get headline-by-anchor (string-append origin-src "#" origin-id)))
                           (hash-get headline-by-anchor origin-id)))
            (when (and to-qid (hash-get node-table to-qid))
              (add-edge! from-qid to-qid 'EVOLVED_FROM))))
         (['link-id sid from-lqid target-id]
          (let (to-qid (or (hash-get headline-by-anchor (string-append sid "#" target-id))
                           (hash-get headline-by-anchor target-id)))
            (when (and to-qid (hash-get node-table to-qid))
              (add-edge! from-lqid to-qid 'LINKS_TO_HEADLINE))))))
     (reverse deferred-links))
    (let* ((element-identities (reverse node-order))
           (ordered-edges (reverse edge-order))
           (source-digests (map (lambda (s) (string-copy (.ref s 'semantic-digest))) sources))
           (source-texts (reverse collected-texts))
           (semantic-revision
            (digest (list 'context-org-element-graph.v1 identity source-digests
                          element-identities ordered-edges)))
           (element-space
            (.o (:: @ AgenticAILabQueryElementSpace.)
                identity semantic-revision element-identities complete?))
           (graph (yuanxu-graph identity
                                (map (cut hash-get node-table <>) element-identities)
                                (map (cut hash-get edge-table <>) ordered-edges))))
      (.o (:: @ AiAgenticContextOrgElementGraph.)
          identity semantic-revision element-space graph
          source-digests source-texts element-identities complete?))))

;;; ---------------------------------------------------------------------------
;;; Pillar 2: Native Org Elements -> GQL Expression Compiler & Executor
;;; ---------------------------------------------------------------------------

(def (org-element-kind->gql-spec kind-str)
  (let (k (string-downcase (if (symbol? kind-str) (symbol->string kind-str) kind-str)))
    (cond
     ((or (equal? k "headline") (equal? k "inlinetask") (equal? k "section"))
      (values 'h 'OrgHeadline
              '((h . identity) (h . sourceId) (h . propertyId) (h . title)
                (h . todoKeyword) (h . todoType) (h . priority)
                (h . scheduledEpoch) (h . byteStart) (h . byteEnd))))
     ((or (equal? k "item") (equal? k "checklist-item") (equal? k "list-item"))
      (values 'i 'OrgListItem
              '((i . identity) (i . sourceId) (i . headlinePropertyId)
                (i . checkbox) (i . checkboxState) (i . itemText)
                (i . byteStart) (i . byteEnd))))
     ((or (equal? k "src-block") (equal? k "babel-block"))
      (values 'b 'OrgSrcBlock
              '((b . identity) (b . sourceId) (b . headlinePropertyId)
                (b . blockName) (b . language) (b . model) (b . thinking)
                (b . hasResults) (b . byteStart) (b . byteEnd))))
     ((or (equal? k "drawer") (equal? k "special-block"))
      (values 'd 'OrgDrawer
              '((d . identity) (d . sourceId) (d . headlinePropertyId)
                (d . drawerName) (d . drawerKind) (d . bodyText)
                (d . byteStart) (d . byteEnd))))
     ((or (equal? k "link") (equal? k "attachment-link"))
      (values 'l 'OrgLink
              '((l . identity) (l . sourceId) (l . headlinePropertyId)
                (l . protocol) (l . targetPath) (l . imageLink)
                (l . attachDir) (l . byteStart) (l . byteEnd))))
     ((or (equal? k "org-data") (equal? k "org-source") (equal? k "document"))
      (values 's 'OrgSource
              '((s . identity) (s . sourceId) (s . projectId) (s . worktreeId)
                (s . rootAnchorId) (s . lineCount) (s . byteSize))))
     (else (error "Unsupported Org Element kind for GQL compilation" kind-str)))))

(def (org-element-field->gql-property label field-raw)
  (let (f (if (symbol? field-raw) (symbol->string field-raw) field-raw))
    (cond
     ((or (equal? f "todo-type") (equal? f "todoType")) 'todoType)
     ((or (equal? f "todo-keyword") (equal? f "todoKeyword") (equal? f "todo")) 'todoKeyword)
     ((or (equal? f "source-title") (equal? f "sourceTitle")) 'sourceTitle)
     ((equal? f "title") 'title)
     ((equal? f "priority") 'priority)
     ((equal? f "level") 'level)
     ((or (equal? f "property:ID") (equal? f "id") (equal? f "property-id") (equal? f "propertyId")) 'propertyId)
     ((or (equal? f "source-id") (equal? f "sourceId")) 'sourceId)
     ((or (equal? f "tags") (equal? f "tags-csv") (equal? f "tagsCsv")) 'tagsCsv)
     ((or (equal? f "has-attach-tag") (equal? f "hasAttachTag")) 'hasAttachTag)
     ((or (equal? f "property:DIR") (equal? f "attach-dir") (equal? f "attachDir")) 'attachDir)
     ((or (equal? f "scheduled") (equal? f "scheduled-raw") (equal? f "scheduledRaw")) 'scheduledRaw)
     ((or (equal? f "deadline") (equal? f "deadline-raw") (equal? f "deadlineRaw")) 'deadlineRaw)
     ((or (equal? f "cookie") (equal? f "cookie-value") (equal? f "cookieValue")) 'cookieValue)
     ((or (equal? f "property:AGENT_ID") (equal? f "agent-id") (equal? f "ownerAgentId")) 'ownerAgentId)
     ((or (equal? f "property:REVIEWER_AGENT_ID") (equal? f "reviewer-agent-id") (equal? f "reviewerAgentId")) 'reviewerAgentId)
     ((or (equal? f "property:AGENT_TIER") (equal? f "property:MODEL_TIER")
          (equal? f "agent-tier") (equal? f "agentTier")) 'agentTier)
     ((or (equal? f "property:TASK_ID") (equal? f "task-id") (equal? f "taskId")) 'taskId)
     ((or (equal? f "property:ARCH_COMPONENT") (equal? f "arch-component") (equal? f "componentId")) 'componentId)
     ((or (equal? f "property:ACTIVE_DEFEATERS") (equal? f "active-defeaters") (equal? f "activeDefeaters")) 'activeDefeaters)
     ((or (equal? f "property:CONTEXT_ORIGIN_MODULE") (equal? f "origin-module") (equal? f "originModule")) 'originModule)
     ((or (equal? f "property:CONTEXT_ORIGIN_SOURCE") (equal? f "origin-source") (equal? f "originSource")) 'originSource)
     ((or (equal? f "property:CONTEXT_ORIGIN_ID") (equal? f "origin-id") (equal? f "originId")) 'originId)
     ((equal? f "checkbox") 'checkbox)
     ((or (equal? f "checkbox-state") (equal? f "checkboxState")) 'checkboxState)
     ((equal? f "bullet") 'bullet)
     ((or (equal? f "item-text") (equal? f "itemText")) 'itemText)
     ((or (equal? f "block-name") (equal? f "blockName")) 'blockName)
     ((equal? f "language") 'language)
     ((equal? f "model") 'model)
     ((equal? f "thinking") 'thinking)
     ((or (equal? f "results-mode") (equal? f "resultsMode") (equal? f "results")) 'resultsMode)
     ((equal? f "tier") 'tier)
     ((or (equal? f "raw-body") (equal? f "rawBody") (equal? f "body")) 'rawBody)
     ((or (equal? f "has-results") (equal? f "hasResults")) 'hasResults)
     ((equal? f "name")
      (if (eq? label 'OrgSrcBlock) 'blockName 'drawerName))
     ((or (equal? f "drawer-name") (equal? f "drawerName")) 'drawerName)
     ((or (equal? f "drawer-kind") (equal? f "drawerKind")) 'drawerKind)
     ((equal? f "protocol") 'protocol)
     ((or (equal? f "link-kind") (equal? f "linkKind")) 'linkKind)
     ((or (equal? f "path") (equal? f "raw-path") (equal? f "rawPath")) 'rawPath)
     ((or (equal? f "target-path") (equal? f "targetPath")) 'targetPath)
     ((or (equal? f "image-link") (equal? f "imageLink")) 'imageLink)
     (else (error "Unsupported Org Element field for GQL mapping" label field-raw)))))

(def (normalize-clause-value prop val)
  (if (eq? prop 'checkbox)
    (let-values (((cb _raw _state) (normalize-checkbox val))) cb)
    val))

(def (parse-sexp-predicate-groups expr label)
  (match expr
    (['property field val]
     (let (prop (org-element-field->gql-property label field))
       (list (list (list prop 'exact (normalize-clause-value prop val))))))
    (['property-contains field val]
     (let (prop (org-element-field->gql-property label field))
       (list (list (list prop 'contains val)))))
    (['all-of . subs]
     (unless (pair? subs) (error "all-of requires at least one clause"))
     (foldl (lambda (sub groups)
              (let (rhs (parse-sexp-predicate-groups sub label))
                (append-map (lambda (g) (map (lambda (r) (append g r)) rhs)) groups)))
            (list '()) subs))
    (['any-of . subs]
     (unless (pair? subs) (error "any-of requires at least one clause"))
     (append-map (cut parse-sexp-predicate-groups <> label) subs))
    (_ (error "Invalid Org Element S-expression clause" expr))))

(def (normalize-selector selector)
  (cond
   ((org-element-query? selector)
    (let-values (((binding label default-proj)
                  (org-element-kind->gql-spec (org-element-query-node-kind selector))))
      (let* ((rel (org-element-query-relation selector))
             (target (org-element-query-target selector))
             (groups
              (map (lambda (grp)
                     (map (lambda (cl)
                            (let ((prop (org-element-field->gql-property label (org-element-clause-name cl)))
                                  (m (org-element-clause-match cl))
                                  (v (org-element-clause-value cl)))
                              (list prop m (normalize-clause-value prop v))))
                          grp))
                   (org-element-query-groups selector))))
        (if (and (memq rel '(child-of descendant-of)) (equal? target "headline"))
          (let (edge (case label
                       ((OrgListItem) 'HAS_ITEM)
                       ((OrgSrcBlock) 'HAS_SRC_BLOCK)
                       ((OrgDrawer) 'HAS_DRAWER)
                       ((OrgLink) 'HAS_LINK)
                       ((OrgHeadline) 'PARENT_OF)
                       (else (error "Unsupported child-of relation for Org Element" label))))
            (values 'p 'OrgHeadline (list (list edge binding label))
                    binding label
                    (append '((p . propertyId) (p . title))
                            (filter (lambda (pr) (not (eq? (cdr pr) 'headlinePropertyId)))
                                    default-proj))
                    groups))
          (values binding label '() binding label default-proj groups)))))
   ((and (pair? selector) (eq? (car selector) 'org-elements) (pair? (cdr selector)))
    (let-values (((binding label default-proj)
                  (org-element-kind->gql-spec (cadr selector))))
      (let loop ((clauses (cddr selector))
                 (rel #f)
                 (groups (list '())))
        (if (null? clauses)
          (match rel
            (#f (values binding label '() binding label default-proj groups))
            (['child-of parent-sym]
             (if (memq parent-sym '(org-data document source))
               (let (edge (case label
                            ((OrgHeadline) 'HAS_HEADLINE)
                            ((OrgSrcBlock) 'HAS_SRC_BLOCK)
                            ((OrgLink) 'HAS_LINK)
                            (else (error "Unsupported source child-of relation" label))))
                 (values 's 'OrgSource (list (list edge binding label))
                         binding label (cons '(s . sourceId) default-proj) groups))
               (let ((pbind (if (eq? binding 'h) 'ph 'h))
                     (edge (case label
                             ((OrgListItem) 'HAS_ITEM)
                             ((OrgSrcBlock) 'HAS_SRC_BLOCK)
                             ((OrgDrawer) 'HAS_DRAWER)
                             ((OrgLink) 'HAS_LINK)
                             ((OrgHeadline) 'PARENT_OF)
                             (else (error "Unsupported headline child-of relation" label)))))
                 (values pbind 'OrgHeadline (list (list edge binding label))
                         binding label
                         (append (list (cons pbind 'propertyId) (cons pbind 'title))
                                 (filter (lambda (pr) (not (eq? (cdr pr) 'headlinePropertyId)))
                                         default-proj))
                         groups))))
            (['depends-on _target-sym]
             (unless (eq? label 'OrgHeadline)
               (error "depends-on relation requires headline Org Element"))
             (values 'h 'OrgHeadline '((DEPENDS_ON dep OrgHeadline))
                     'h 'OrgHeadline
                     '((h . identity) (h . sourceId) (h . propertyId) (h . title)
                       (h . todoKeyword) (h . todoType)
                       (dep . propertyId) (dep . title) (dep . todoType)
                       (h . byteStart) (h . byteEnd))
                     groups))
            (['evolved-from _origin-sym]
             (unless (eq? label 'OrgHeadline)
               (error "evolved-from relation requires headline Org Element"))
             (values 'h 'OrgHeadline '((EVOLVED_FROM orig OrgHeadline))
                     'h 'OrgHeadline
                     '((h . identity) (h . sourceId) (h . propertyId) (h . title)
                       (h . originModule) (orig . sourceId) (orig . propertyId) (orig . title)
                       (h . byteStart) (h . byteEnd))
                     groups))
            (['produces-results _drawer-sym]
             (unless (eq? label 'OrgSrcBlock)
               (error "produces-results relation requires src-block Org Element"))
             (values 'b 'OrgSrcBlock '((PRODUCES_RESULTS dr OrgDrawer))
                     'b 'OrgSrcBlock
                     '((b . identity) (b . sourceId) (b . blockName) (b . language)
                       (b . model) (dr . drawerName) (dr . bodyText)
                       (b . byteStart) (dr . byteEnd))
                     groups)))
          (let (cl (car clauses))
            (if (and (pair? cl) (memq (car cl) '(child-of depends-on evolved-from produces-results)))
              (begin
                (when rel (error "Duplicate relation clause in Org Element selector" cl))
                (loop (cdr clauses) cl groups))
              (let (rhs (parse-sexp-predicate-groups cl label))
                (loop (cdr clauses) rel
                      (append-map (lambda (g) (map (lambda (r) (append g r)) rhs))
                                  groups)))))))))
   (else (error "Expected Orgize OrgElementQuery or `(org-elements ...)` S-expression" selector))))

(def (agentic-ai-lab-ai-agentic-context-org-element->gql-query
      elem-graph selector (query-id 'org-elements-gql) (bound 128))
  (unless (and (agentic-ai-lab-ai-agentic-context-org-element-graph-shape? elem-graph)
               (symbol? query-id) (exact-integer? bound) (<= 1 bound 512))
    (error "Invalid Org Element -> GQL compilation inputs"))
  (let-values (((start-bind start-label steps target-bind _target-label proj-pairs groups)
                (normalize-selector selector)))
    (let* ((single-group? (= (length groups) 1))
           (primary-exact
            (and single-group?
                 (find (lambda (cl) (eq? (cadr cl) 'exact)) (car groups))))
           (where-ast
            (and primary-exact
                 (gql-equals target-bind (car primary-exact) (caddr primary-exact))))
           (residual-groups
            (if primary-exact
              (let (rest (filter (lambda (cl) (not (equal? cl primary-exact))) (car groups)))
                (if (null? rest) '() (list rest)))
              (if (equal? groups (list '())) '() groups)))
           (field-names
            (let loop ((ps proj-pairs) (seen '()) (out '()))
              (if (null? ps) (reverse out)
                (let* ((p (car ps))
                       (base (cdr p))
                       (fname (if (memq base seen)
                                (string->symbol (string-append (symbol->string (car p)) "_"
                                                               (symbol->string base)))
                                base)))
                  (loop (cdr ps) (cons fname seen) (cons fname out))))))
           (query
            (make-element-gql-query
             elem-graph query-id field-names bound
             (gql-path start-bind start-label steps)
             where-ast
             (gql-projections proj-pairs)))
           (gql (agentic-ai-lab-query->gql query))
           (kind 'agentic-ai-lab.ai-agentic-context.org-element-gql-plan.v1)
           (target-binding target-bind)
           (target-index
            (let loop ((ps proj-pairs) (idx 0))
              (cond
               ((null? ps) #f)
               ((and (eq? (caar ps) target-bind) (eq? (cdar ps) 'identity)) idx)
               (else (loop (cdr ps) (+ idx 1)))))))
      (.o kind query gql target-binding target-index residual-groups))))

(def (node-matches-residual-groups? node residual-groups)
  (or (null? residual-groups)
      (and (object? node)
           (ormap
            (lambda (grp)
              (every
               (lambda (cl)
                 (with ([prop matcher expected] cl)
                   (and (.slot? node prop)
                        (let (actual (.ref node prop))
                          (case matcher
                            ((exact) (equal? actual expected))
                            ((contains) (and (string? actual) (string? expected)
                                             (and (string-contains actual expected) #t)))
                            (else #f))))))
               grp))
            residual-groups))))

(def (agentic-ai-lab-ai-agentic-context-org-elements-select
      elem-graph selector (query-id 'org-elements-gql) (bound 128))
  (let* ((plan (agentic-ai-lab-ai-agentic-context-org-element->gql-query
                elem-graph selector query-id bound))
         (query (.ref plan 'query))
         (gql (.ref plan 'gql))
         (selection (agentic-ai-lab-query-select-scheme-graph
                     query (.ref elem-graph 'element-space) (.ref elem-graph 'graph)))
         (residuals (.ref plan 'residual-groups))
         (t-idx (.ref plan 'target-index))
         (payload-by-id (make-hash-table)))
    (for-each (lambda (n) (hash-put! payload-by-id (yuanxu-graph-node-id n) (yuanxu-graph-node-payload n)))
              (yuanxu-graph-nodes (.ref elem-graph 'graph)))
    (let* ((raw-rows (.ref selection 'rows))
           (rows
            (if (null? residuals)
              raw-rows
              (filter (lambda (row)
                        (and t-idx (< t-idx (length row))
                             (node-matches-residual-groups?
                              (hash-get payload-by-id (list-ref row t-idx))
                              residuals)))
                      raw-rows)))
           (nodes
            (if t-idx
              (filter-map (lambda (row)
                            (and (< t-idx (length row))
                                 (hash-get payload-by-id (list-ref row t-idx))))
                          rows)
              '()))
           (kind 'agentic-ai-lab.ai-agentic-context.org-elements-selection.v1)
           (action-authorized? #f))
      (.o kind plan query gql selection rows nodes action-authorized?))))

;;; ---------------------------------------------------------------------------
;;; Pillar 3: Ready-Task Context Slice Resolver
;;; ---------------------------------------------------------------------------

(def (priority-rank prio)
  (cond
   ((equal? prio "A") 0)
   ((equal? prio "B") 1)
   ((equal? prio "C") 2)
   ((string-empty? prio) 9)
   (else 5)))

(def (slice-node-text source-map node)
  (let (txt (cdr (or (assoc (.ref node 'sourceId) source-map) '(#f . #f))))
    (if txt
      (utf8-slice (string->utf8 txt) (.ref node 'byteStart) (.ref node 'byteEnd))
      "")))

(def (agentic-ai-lab-ai-agentic-context-ready-task-slices
      elem-graph (tier-filter #f))
  (unless (and (agentic-ai-lab-ai-agentic-context-org-element-graph-shape? elem-graph)
               (or (not tier-filter) (string? tier-filter)))
    (error "Invalid ready-task slice inputs"))
  (let* ((todo-sel
          (agentic-ai-lab-ai-agentic-context-org-elements-select
           elem-graph
           (if tier-filter
             `(org-elements headline (all-of (property todo-type "todo")
                                             (property agent-tier ,tier-filter)))
             '(org-elements headline (property todo-type "todo")))
           'context-ready-todo-headlines 256))
         (graph (.ref elem-graph 'graph))
         (source-map (.ref elem-graph 'source-texts))
         (payloads (make-hash-table))
         (deps-out (make-hash-table))
         (items-out (make-hash-table))
         (links-out (make-hash-table)))
    (for-each (lambda (n) (hash-put! payloads (yuanxu-graph-node-id n) (yuanxu-graph-node-payload n)))
              (yuanxu-graph-nodes graph))
    (for-each
     (lambda (e)
       (let ((from (yuanxu-graph-edge-from e))
             (to (yuanxu-graph-edge-to e))
             (k (yuanxu-graph-edge-kind e)))
         (case k
           ((DEPENDS_ON)
            (hash-put! deps-out from (append (or (hash-get deps-out from) '()) (list to))))
           ((HAS_ITEM)
            (hash-put! items-out from (append (or (hash-get items-out from) '()) (list to))))
           ((HAS_LINK)
            (hash-put! links-out from (append (or (hash-get links-out from) '()) (list to)))))))
     (yuanxu-graph-edges graph))
    (let* ((candidates (.ref todo-sel 'nodes))
           (ready-slices
            (filter-map
             (lambda (h)
               (let* ((hid (.ref h 'identity))
                      (dep-ids (or (hash-get deps-out hid) '()))
                      (dep-nodes (filter-map (cut hash-get payloads <>) dep-ids))
                      (blocked?
                       (ormap (lambda (dn) (equal? (.ref dn 'todoType) "todo")) dep-nodes)))
                 (and (not blocked?)
                      (let* ((item-nodes (filter-map (cut hash-get payloads <>)
                                                     (or (hash-get items-out hid) '())))
                             (uncheckedItems
                              (map (lambda (it) (.ref it 'itemText))
                                   (filter (lambda (it) (equal? (.ref it 'checkboxState) "unchecked"))
                                           item-nodes)))
                             (all-scoped-nodes (cons h dep-nodes))
                             (attachments
                              (append-map
                               (lambda (sn)
                                 (filter-map
                                  (lambda (lid)
                                    (let (ln (hash-get payloads lid))
                                      (and ln (equal? (.ref ln 'protocol) "attachment")
                                           (let ((sourceId (.ref ln 'sourceId))
                                                 (headlinePropertyId (.ref ln 'headlinePropertyId))
                                                 (attachDir (.ref ln 'attachDir))
                                                 (targetPath (.ref ln 'targetPath))
                                                 (imageLink (.ref ln 'imageLink)))
                                             (.o sourceId headlinePropertyId attachDir targetPath imageLink)))))
                                  (or (hash-get links-out (.ref sn 'identity)) '())))
                               all-scoped-nodes))
                             (dependencySlices
                              (map (lambda (dn)
                                     (let ((sourceId (.ref dn 'sourceId))
                                           (propertyId (.ref dn 'propertyId))
                                           (title (.ref dn 'title))
                                           (todoType (.ref dn 'todoType))
                                           (orgSlice (slice-node-text source-map dn)))
                                       (.o sourceId propertyId title todoType orgSlice)))
                                   dep-nodes))
                             (headlineIdentity hid)
                             (sourceId (.ref h 'sourceId))
                             (propertyId (.ref h 'propertyId))
                             (title (.ref h 'title))
                             (todoKeyword (.ref h 'todoKeyword))
                             (priority (.ref h 'priority))
                             (scheduledEpoch (.ref h 'scheduledEpoch))
                             (ownerAgentId (.ref h 'ownerAgentId))
                             (agentTier (.ref h 'agentTier))
                             (taskId (.ref h 'taskId))
                             (taskOrgSlice (slice-node-text source-map h)))
                        (.o headlineIdentity sourceId propertyId title todoKeyword
                            priority scheduledEpoch ownerAgentId agentTier taskId
                            taskOrgSlice uncheckedItems dependencySlices attachments)))))
             candidates))
           (slices
            (list-sort
             (lambda (a b)
               (let ((pa (priority-rank (.ref a 'priority)))
                     (pb (priority-rank (.ref b 'priority))))
                 (if (not (= pa pb)) (< pa pb)
                   (let ((sa (if (< (.ref a 'scheduledEpoch) 0) 999999999999 (.ref a 'scheduledEpoch)))
                         (sb (if (< (.ref b 'scheduledEpoch) 0) 999999999999 (.ref b 'scheduledEpoch))))
                     (if (not (= sa sb)) (< sa sb)
                       (string<? (.ref a 'headlineIdentity) (.ref b 'headlineIdentity)))))))
             ready-slices))
           (kind 'agentic-ai-lab.ai-agentic-context.ready-task-slices.v1)
           (gql (.ref todo-sel 'gql))
           (action-authorized? #f))
      (.o kind gql slices action-authorized?))))

;;; ---------------------------------------------------------------------------
;;; Pillar 4: Pure Parser-Verified Org Structural Updaters
;;; ---------------------------------------------------------------------------

(def (format-babel-results block-name body-text thinking-text)
  (let ((clean-body (string-trim body-text))
        (clean-thinking (and thinking-text (string-trim thinking-text))))
    (string-append
     "#+RESULTS: " block-name "\n"
     ":RESULTS:\n"
     (if (and clean-thinking (not (string-empty? clean-thinking)))
       (string-append "#+BEGIN_THINKING\n" clean-thinking "\n#+END_THINKING\n")
       "")
     clean-body
     (if (string-empty? clean-body) "" "\n")
     ":END:\n")))

(def (agentic-ai-lab-ai-agentic-context-babel-upsert-results
      source-text block-name body-text (thinking-text #f))
  (unless (and (string? source-text) (string? block-name)
               (not (string-empty? (string-trim block-name)))
               (string? body-text)
               (or (not thinking-text) (string? thinking-text)))
    (error "Invalid Org-Babel results upsert inputs"))
  (let* ((target-name (string-trim block-name))
         (bytes (string->utf8 source-text))
         (total (u8vector-length bytes))
         (view (org-source-element-graph source-text))
         (records (list-sort (lambda (a b) (< (.ref a 'start) (.ref b 'start)))
                             (org-element-graph-records view)))
         (keywords (filter (lambda (r) (equal? (.ref r 'kind) "keyword")) records))
         (drawers (filter (lambda (r) (equal? (.ref r 'kind) "drawer")) records))
         (src-blocks (filter (lambda (r) (equal? (.ref r 'kind) "src-block")) records))
         (matched-block
          (find (lambda (sb)
                  (find (lambda (kw)
                          (and (equal? (.ref kw 'parent) (.ref sb 'parent))
                               (string-ci=? (or (org-source-element-field kw "key") "") "NAME")
                               (equal? (string-trim (or (org-source-element-field kw "value") ""))
                                       target-name)
                               (<= (.ref kw 'end) (.ref sb 'start))
                               (string-empty? (string-trim (utf8-slice bytes (.ref kw 'end) (.ref sb 'start))))))
                        keywords))
                src-blocks)))
    (unless matched-block
      (error "Named Org-Babel source block not found" target-name))
    (let* ((res-kw
            (find (lambda (kw)
                    (and (equal? (.ref kw 'parent) (.ref matched-block 'parent))
                         (string-ci=? (or (org-source-element-field kw "key") "") "RESULTS")
                         (equal? (string-trim (or (org-source-element-field kw "value") ""))
                                 target-name)
                         (>= (.ref kw 'start) (.ref matched-block 'end))))
                  keywords))
           (res-drawer
            (and res-kw
                 (find (lambda (dr)
                         (and (equal? (.ref dr 'parent) (.ref matched-block 'parent))
                              (string-ci=? (or (org-source-element-field dr "name") "") "RESULTS")
                              (>= (.ref dr 'start) (.ref res-kw 'end))
                              (string-empty? (string-trim (utf8-slice bytes (.ref res-kw 'end) (.ref dr 'start))))))
                       drawers)))
           (formatted (format-babel-results target-name body-text thinking-text))
           (updated
            (if (and res-kw res-drawer)
              (string-append (utf8-slice bytes 0 (.ref res-kw 'start))
                             formatted
                             (utf8-slice bytes (.ref res-drawer 'end) total))
              (let* ((insert-pos (.ref matched-block 'end))
                     (prefix (utf8-slice bytes 0 insert-pos))
                     (suffix (utf8-slice bytes insert-pos total))
                     (sep (if (and (> (string-length prefix) 0)
                                   (char=? (string-ref prefix (- (string-length prefix) 1)) #\newline))
                            "\n" "\n\n")))
                (string-append prefix sep formatted suffix)))))
      (org-source-element-graph updated)
      updated)))

(def (agentic-ai-lab-ai-agentic-context-checklist-set
      source-text headline-property-id item-index checked?)
  (unless (and (string? source-text) (string? headline-property-id)
               (not (string-empty? headline-property-id))
               (exact-integer? item-index) (>= item-index 0)
               (boolean? checked?))
    (error "Invalid Org checklist update inputs"))
  (let* ((bytes (string->utf8 source-text))
         (total (u8vector-length bytes))
         (view (org-source-element-graph source-text))
         (ctx (make-org-element-query-context view))
         (records (list-sort (lambda (a b) (< (.ref a 'start) (.ref b 'start)))
                             (org-element-graph-records view)))
         (by-id (make-hash-table)))
    (for-each (lambda (r) (hash-put! by-id (.ref r 'id) r)) records)
    (let (target-h
          (find (lambda (r)
                  (and (member (.ref r 'kind) '("headline" "inlinetask"))
                       (equal? (org-element-property ctx r "property:ID")
                               headline-property-id)))
                records))
      (unless target-h
        (error "Headline ID not found for checklist update" headline-property-id))
      (let* ((checkbox-items
              (filter (lambda (r)
                        (and (equal? (.ref r 'kind) "item")
                             (org-source-element-field r "checkbox")
                             (let (eh (enclosing-headline-record r by-id))
                               (and eh (= (.ref eh 'id) (.ref target-h 'id))))))
                      records)))
        (unless (< item-index (length checkbox-items))
          (error "Checklist item index out of range" item-index (length checkbox-items)))
        (let* ((item-rec (list-ref checkbox-items item-index))
               (item-slice (utf8-slice bytes (.ref item-rec 'start) (.ref item-rec 'end)))
               (new-mark (if checked? "[X]" "[ ]"))
               (patched-item
                (let ((len (string-length item-slice)))
                  (let loop ((i 0))
                    (if (> (+ i 3) len)
                      (error "Malformed checkbox token in item" item-slice)
                      (if (and (char=? (string-ref item-slice i) #\[)
                               (char=? (string-ref item-slice (+ i 2)) #\]))
                        (string-append (substring item-slice 0 i)
                                       new-mark
                                       (substring item-slice (+ i 3) len))
                        (loop (+ i 1)))))))
               (done-count
                (let loop ((its checkbox-items) (idx 0) (acc 0))
                  (if (null? its) acc
                    (let-values (((_cb _raw st)
                                  (normalize-checkbox (org-source-element-field (car its) "checkbox"))))
                      (let (done? (if (= idx item-index) checked? (equal? st "checked")))
                        (loop (cdr its) (+ idx 1) (if done? (+ acc 1) acc)))))))
               (total-count (length checkbox-items))
               (cookie
                (find (lambda (r)
                        (and (equal? (.ref r 'kind) "statistics-cookie")
                             (equal? (.ref r 'parent) (.ref target-h 'id))))
                      records))
               (step1
                (string-append (utf8-slice bytes 0 (.ref item-rec 'start))
                               patched-item
                               (utf8-slice bytes (.ref item-rec 'end) total)))
               (updated
                (if (not cookie)
                  step1
                  (let* ((cval (or (org-source-element-field cookie "value") ""))
                         (pct? (string-contains cval "%"))
                         (new-cookie
                          (if pct?
                            (string-append "[" (number->string (quotient (* done-count 100) total-count)) "%]")
                            (string-append "[" (number->string done-count) "/" (number->string total-count) "]")))
                         (step1-bytes (string->utf8 step1)))
                    (string-append (utf8-slice step1-bytes 0 (.ref cookie 'start))
                                   new-cookie
                                   (utf8-slice step1-bytes (.ref cookie 'end)
                                               (u8vector-length step1-bytes)))))))
          (org-source-element-graph updated)
          updated)))))

(def (agentic-ai-lab-ai-agentic-context-headline-set-todo
      source-text headline-property-id new-keyword)
  (unless (and (string? source-text) (string? headline-property-id)
               (not (string-empty? headline-property-id))
               (string? new-keyword) (not (string-empty? (string-trim new-keyword))))
    (error "Invalid headline TODO state update inputs"))
  (let* ((kw (string-trim new-keyword))
         (bytes (string->utf8 source-text))
         (total (u8vector-length bytes))
         (view (org-source-element-graph source-text))
         (ctx (make-org-element-query-context view))
         (records (org-element-graph-records view))
         (target-h
          (find (lambda (r)
                  (and (member (.ref r 'kind) '("headline" "inlinetask"))
                       (equal? (org-element-property ctx r "property:ID")
                               headline-property-id)))
                records)))
    (unless target-h
      (error "Headline ID not found for TODO transition" headline-property-id))
    (let* ((h-slice (utf8-slice bytes (.ref target-h 'start) (.ref target-h 'end)))
           (nl (or (string-index h-slice #\newline) (string-length h-slice)))
           (first-line (substring h-slice 0 nl))
           (rest-slice (substring h-slice nl (string-length h-slice)))
           (markers (or (org-element-property ctx target-h "markers") "*"))
           (stars (make-string (count-stars markers) #\*))
           (old-kw (or (org-element-property ctx target-h "todo-keyword") ""))
           (after-stars (string-trim (substring first-line (string-length stars) (string-length first-line))))
           (after-old-kw
            (if (and (not (string-empty? old-kw)) (string-prefix? old-kw after-stars))
              (string-trim (substring after-stars (string-length old-kw) (string-length after-stars)))
              after-stars))
           (new-first-line (string-append stars " " kw " " after-old-kw))
           (updated
            (string-append (utf8-slice bytes 0 (.ref target-h 'start))
                           new-first-line rest-slice
                           (utf8-slice bytes (.ref target-h 'end) total))))
      (org-source-element-graph updated)
      updated)))

(def (inject-origin-properties subtree-text origin-module origin-source origin-id origin-gen)
  (let* ((props (agentic-ai-lab-ai-agentic-context-org-properties subtree-text))
         (sec-props (filter (lambda (p)
                              (and (eq? (.ref p 'container-kind) 'OrgSection)
                                   (= (.ref p 'container-start) 0)))
                            props)))
    (unless (pair? sec-props)
      (error "Promoted subtree requires a leading OrgSection property drawer"))
    (let* ((drawer-end (.ref (car sec-props) 'drawer-end))
           (bytes (string->utf8 subtree-text))
           (total (u8vector-length bytes))
           (drawer-slice (utf8-slice bytes 0 drawer-end))
           (end-pos (let loop ((i (- (string-length drawer-slice) 1)))
                      (cond
                       ((< i 0) (error "Malformed property drawer in promoted subtree"))
                       ((and (<= (+ i 5) (string-length drawer-slice))
                             (string-ci=? (substring drawer-slice i (+ i 5)) ":END:"))
                        i)
                       (else (loop (- i 1))))))
           (has-key? (lambda (k)
                       (find (cut agentic-ai-lab-ai-agentic-context-org-property-key? <> k) sec-props)))
           (extra
            (string-append
             (if (has-key? "CONTEXT_ORIGIN_MODULE") ""
               (string-append ":CONTEXT_ORIGIN_MODULE: " origin-module "\n"))
             (if (has-key? "CONTEXT_ORIGIN_SOURCE") ""
               (string-append ":CONTEXT_ORIGIN_SOURCE: " origin-source "\n"))
             (if (has-key? "CONTEXT_ORIGIN_ID") ""
               (string-append ":CONTEXT_ORIGIN_ID: " origin-id "\n"))
             (if (has-key? "CONTEXT_ORIGIN_GENERATION") ""
               (string-append ":CONTEXT_ORIGIN_GENERATION: " (number->string origin-gen) "\n")))))
      (string-append (substring drawer-slice 0 end-pos)
                     extra
                     (substring drawer-slice end-pos (string-length drawer-slice))
                     (utf8-slice bytes drawer-end total)))))

(def (agentic-ai-lab-ai-agentic-context-fission-subtree
      scratch-cut target-org-text target-property-id
      (origin-module "context.org-babel-fission"))
  (unless (and (org-source-cut? scratch-cut)
               (string? target-org-text)
               (string? target-property-id) (not (string-empty? target-property-id))
               (string? origin-module) (not (string-empty? origin-module)))
    (error "Invalid Org subtree fission inputs"))
  (let* ((eg (agentic-ai-lab-ai-agentic-context-org-element-graph
              'fission-inspect (list scratch-cut) #t))
         (nodes (map yuanxu-graph-node-payload (yuanxu-graph-nodes (.ref eg 'graph))))
         (target-h
          (find (lambda (n)
                  (and (eq? (.ref n 'label) 'OrgHeadline)
                       (equal? (.ref n 'propertyId) target-property-id)))
                nodes)))
    (unless target-h
      (error "Subtree ID not found in scratch Org source" target-property-id))
    (let (streaming-block
          (find (lambda (n)
                  (and (eq? (.ref n 'label) 'OrgSrcBlock)
                       (equal? (.ref n 'headlineId) (.ref target-h 'identity))
                       (string-ci=? (.ref n 'language) "llm")
                       (not (.ref n 'hasResults))))
                nodes))
      (when streaming-block
        (error "Refusing mid-stream Org subtree fission: unevaluated llm block"
               (.ref streaming-block 'blockName))))
    (let* ((scratch-text (.ref scratch-cut 'source))
           (sbytes (string->utf8 scratch-text))
           (stotal (u8vector-length sbytes))
           (raw-subtree (utf8-slice sbytes (.ref target-h 'byteStart) (.ref target-h 'byteEnd)))
           (promotedSubtree
            (inject-origin-properties
             raw-subtree origin-module
             (.ref scratch-cut 'identity)
             target-property-id
             (.ref scratch-cut 'generation)))
           (scratchOrg
            (string-append (utf8-slice sbytes 0 (.ref target-h 'byteStart))
                           (utf8-slice sbytes (.ref target-h 'byteEnd) stotal)))
           (sep (if (or (string-empty? target-org-text)
                        (char=? (string-ref target-org-text (- (string-length target-org-text) 1)) #\newline))
                  "\n" "\n\n"))
           (targetOrg (string-append target-org-text sep promotedSubtree))
           (kind 'agentic-ai-lab.ai-agentic-context.org-fission-result.v1)
           (promotedPropertyId (string-copy target-property-id))
           (originSource (string-copy (.ref scratch-cut 'identity)))
           (originGeneration (.ref scratch-cut 'generation))
           (action-authorized? #f))
      (org-source-element-graph scratchOrg)
      (org-source-element-graph targetOrg)
      (.o kind promotedPropertyId originSource originGeneration
          scratchOrg targetOrg promotedSubtree action-authorized?))))
