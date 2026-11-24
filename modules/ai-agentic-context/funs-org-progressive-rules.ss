;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; ASCENT-driven Progressive Disclosure (`L0..L3` + Agent Drill-Down),
;;; Case-Driven Dynamic Org Facet Synthesis (replacing static templates),
;;; Declarative Project Rule Overrides, and Two-Stage Org Repair (~90% AST
;;; Auto-Repair at 0 tokens + ~10% Diagnostic-Guided Flash Repair Request).
(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :std/error exception->string)
        (only-in :std/list/list every find filter-map append-map delete-duplicates/hash)
        (only-in :std/string/misc string-trim string-prefix? string-contains)
        (only-in :tao3k/yuanxu/graph/types
                 yuanxu-graph-edges yuanxu-graph-edge-from yuanxu-graph-edge-to
                 yuanxu-graph-edge-kind yuanxu-graph-nodes yuanxu-graph-node-id
                 yuanxu-graph-node-payload)
        (only-in :gerbil-ascent/program/api
                 relational-program relational-admit relational-solve
                 relational-query-name)
        (only-in :orgize/languages/org/modules/org-elements/values
                 org-element-graph-records)
        (only-in :orgize/languages/org/modules/org-elements/query
                 make-org-element-query-context org-element-property)
        (only-in :orgize/languages/org/modules/org-contract/source
                 org-source-contract-definitions)
        (only-in :orgize/languages/org/modules/org-contract/evaluation
                 org-contract-evaluate-definition)
        (only-in :orgize/languages/org/modules/org-contract/values
                 org-contract-definition-assertions
                 org-contract-assertion-id
                 org-contract-assertion-message
                 org-contract-assertion-fix
                 org-contract-result-assertion-id
                 org-contract-result-passed?)
        (only-in :tao3k/agentic-ai-lab/modules/query/semantic/orgize-source-interface
                 org-source-element-graph org-source-element-field)
        "types.ss" "objects.ss" "funs-org-properties.ss"
        "funs-org-elements-gql.ss" "org-contract/elements.ss")
(export agentic-ai-lab-ai-agentic-context-parse-rule-overrides
        agentic-ai-lab-ai-agentic-context-ascent-progressive-plan
        agentic-ai-lab-ai-agentic-context-render-progressive-org
        agentic-ai-lab-ai-agentic-context-ast-auto-repair
        agentic-ai-lab-ai-agentic-context-repair-org)

(def (utf8-slice bytes start end)
  (utf8->string (subu8vector bytes start end)))

;;; ---------------------------------------------------------------------------
;;; 1. Declarative Project Rule Overrides (`:org-progressive-rules`)
;;; ---------------------------------------------------------------------------

;; Reads inert `(split-line-watermark N)`, `(default-focus-depth 0..3)`,
;; `(require-sod-reviewer #t|#f)`, `(fold-thinking-by-default #t|#f)`, and
;; `(allow-agent-drill-down #t|#f)` forms from `#+begin_src scheme :org-progressive-rules`
;; blocks without `eval`.
(def (agentic-ai-lab-ai-agentic-context-parse-rule-overrides
      org-text (base-config AiAgenticContextProgressiveRuleConfig.))
  (unless (and (string? org-text)
               (agentic-ai-lab-ai-agentic-context-progressive-rule-config-shape? base-config))
    (error "Invalid progressive rule override inputs"))
  (let* ((view (org-source-element-graph org-text))
         (blocks (filter (lambda (r)
                           (and (equal? (.ref r 'kind) "src-block")
                                (equal? (org-source-element-field r "language") "scheme")
                                (let (hk (org-source-element-field r "header-key"))
                                  (and (list? hk) (member "org-progressive-rules" hk)))))
                         (org-element-graph-records view)))
         (split-line-watermark (.ref base-config 'split-line-watermark))
         (default-focus-depth (.ref base-config 'default-focus-depth))
         (require-sod-reviewer? (.ref base-config 'require-sod-reviewer?))
         (fold-thinking-by-default? (.ref base-config 'fold-thinking-by-default?))
         (allow-agent-drill-down? (.ref base-config 'allow-agent-drill-down?)))
    (for-each
     (lambda (blk)
       (let (body (or (org-source-element-field blk "body") ""))
         (call-with-input-string body
           (lambda (port)
             (let loop ()
               (let (form (read port))
                 (unless (eof-object? form)
                   (match form
                     (['split-line-watermark n]
                      (unless (and (exact-integer? n) (<= 50 n 100000))
                        (error "Invalid split-line-watermark in :org-progressive-rules" n))
                      (set! split-line-watermark n))
                     (['default-focus-depth d]
                      (unless (and (exact-integer? d) (<= 0 d 3))
                        (error "Invalid default-focus-depth in :org-progressive-rules" d))
                      (set! default-focus-depth d))
                     (['require-sod-reviewer b]
                      (unless (boolean? b)
                        (error "Invalid require-sod-reviewer in :org-progressive-rules" b))
                      (set! require-sod-reviewer? b))
                     (['fold-thinking-by-default b]
                      (unless (boolean? b)
                        (error "Invalid fold-thinking-by-default in :org-progressive-rules" b))
                      (set! fold-thinking-by-default? b))
                     (['allow-agent-drill-down b]
                      (unless (boolean? b)
                        (error "Invalid allow-agent-drill-down in :org-progressive-rules" b))
                      (set! allow-agent-drill-down? b))
                     (_ (error "Unsupported declaration in :org-progressive-rules" form)))
                   (loop))))))))
     blocks)
    (let (cfg (.o (:: @ base-config)
                  split-line-watermark default-focus-depth
                  require-sod-reviewer? fold-thinking-by-default?
                  allow-agent-drill-down?))
      (unless (agentic-ai-lab-ai-agentic-context-progressive-rule-config-shape? cfg)
        (error "Invalid resulting progressive rule configuration"))
      cfg)))

;;; ---------------------------------------------------------------------------
;;; 2. ASCENT Fixed-Point Progressive Disclosure (`L0..L3`) & Facet Engine
;;; ---------------------------------------------------------------------------

(def +facet-specs+
  '((1 inline-checklist
       "Synthesize a compact `* TODO` heading with `[0/N]` statistics cookie and `- [ ]` checklist items inside the active Org file.")
    (2 scheduled-todo-dag
       "Synthesize prioritized `* TODO [#A/#B]` subtrees with `SCHEDULED:` / `DEADLINE:` timestamps and `:DEPENDS_ON:` links.")
    (3 invariant-section
       "Synthesize an architecture/invariant section with `:ID:` and `:CUSTOM_ID:` referenced via `:DEPENDS_ON:` by implementation tasks.")
    (4 competing-hypotheses
       "Synthesize competing hypothesis subtrees with `:ACTIVE_DEFEATERS:` and non-destructive discriminator checks.")
    (5 attach-media
       "Tag media-bearing headings with `:ATTACH:` + `:ID:` and reference artifacts via standard `[[attachment:<filename>]]` links.")
    (6 sod-reviewer
       "Populate distinct `:AGENT_ID:`, `:REVIEWER_AGENT_ID:`, and `:TASK_ID:` properties enforcing separation of duties.")
    (7 gitops-split
       "Split matured `DONE` subtrees or oversized scratch sections intact into GitOps collection files with `:CONTEXT_ORIGIN_*:` provenance.")))

(def (signal->code sig)
  (case sig
    ((actionable-steps inline-checklist) 1)
    ((multi-step multi-agent scheduled-todo-dag) 2)
    ((cross-module protocol-change abi-change invariant-section) 3)
    ((competing-hypotheses security-inquiry debugging-ambiguous) 4)
    ((has-attachments multimodal attach-media) 5)
    ((governed-mutation sod-reviewer) 6)
    ((gitops-split over-watermark) 7)
    (else (error "Unknown ASCENT case signal" sig))))

(def (opt-ref opts key default)
  (if (and (object? opts) (.slot? opts key))
    (.ref opts key)
    default))

(def (agentic-ai-lab-ai-agentic-context-ascent-progressive-plan
      elem-graph (options #f))
  (unless (agentic-ai-lab-ai-agentic-context-org-element-graph-shape? elem-graph)
    (error "ASCENT progressive planner requires an OrgElementGraph"))
  (let* ((cfg (or (opt-ref options 'rule-config #f) AiAgenticContextProgressiveRuleConfig.))
         (focus-props (opt-ref options 'focus-property-ids '()))
         (extra-defeater-props (opt-ref options 'defeater-property-ids '()))
         (drill-downs (if (.ref cfg 'allow-agent-drill-down?)
                        (opt-ref options 'drill-downs '())
                        '()))
         (case-signals (opt-ref options 'case-signals '()))
         (graph (.ref elem-graph 'graph))
         (all-nodes (map yuanxu-graph-node-payload (yuanxu-graph-nodes graph)))
         (headlines (filter (lambda (n) (eq? (.ref n 'label) 'OrgHeadline)) all-nodes))
         (sources (filter (lambda (n) (eq? (.ref n 'label) 'OrgSource)) all-nodes))
         (links (filter (lambda (n) (eq? (.ref n 'label) 'OrgLink)) all-nodes))
         (idx-by-qid (make-hash-table))
         (idx-by-prop (make-hash-table))
         (node-by-idx (make-hash-table)))
    (let loop ((hs headlines) (i 0))
      (unless (null? hs)
        (let* ((h (car hs))
               (qid (.ref h 'identity))
               (pid (.ref h 'propertyId)))
          (hash-put! idx-by-qid qid i)
          (unless (string-empty? pid)
            (unless (hash-get idx-by-prop pid)
              (hash-put! idx-by-prop pid i)))
          (hash-put! node-by-idx i h)
          (loop (cdr hs) (+ i 1)))))
    (let* ((resolve-idx (lambda (id-or-prop)
                          (or (hash-get idx-by-prop id-or-prop)
                              (hash-get idx-by-qid id-or-prop))))
           ;; EDB 1: `(headline_node idx state_code)` where 0 = settled/ADR, 1 = todo, 2 = done
           (headline-rows
            (let loop ((hs headlines) (i 0) (acc '()))
              (if (null? hs) (reverse acc)
                (let* ((tt (.ref (car hs) 'todoType))
                       (sc (cond ((equal? tt "todo") 1)
                                 ((equal? tt "done") 2)
                                 (else 0))))
                  (loop (cdr hs) (+ i 1) (cons (list i sc) acc))))))
           ;; EDB 2: `(depends_edge from_idx to_idx)` & `(parent_edge parent_idx child_idx)`
           (depends-rows
            (filter-map
             (lambda (e)
               (and (eq? (yuanxu-graph-edge-kind e) 'DEPENDS_ON)
                    (let ((fi (hash-get idx-by-qid (yuanxu-graph-edge-from e)))
                          (ti (hash-get idx-by-qid (yuanxu-graph-edge-to e))))
                      (and fi ti (list fi ti)))))
             (yuanxu-graph-edges graph)))
           (parent-rows
            (filter-map
             (lambda (e)
               (and (eq? (yuanxu-graph-edge-kind e) 'PARENT_OF)
                    (let ((pi (hash-get idx-by-qid (yuanxu-graph-edge-from e)))
                          (ci (hash-get idx-by-qid (yuanxu-graph-edge-to e))))
                      (and pi ci (list pi ci)))))
             (yuanxu-graph-edges graph)))
           ;; Ready TODO indices via GQL ready-task resolver
           (ready-res (agentic-ai-lab-ai-agentic-context-ready-task-slices elem-graph))
           (ready-rows
            (filter-map
             (lambda (sl)
               (let (idx (hash-get idx-by-qid (.ref sl 'headlineIdentity)))
                 (and idx (list idx))))
             (.ref ready-res 'slices)))
           (focus-depth (if (.ref cfg 'fold-thinking-by-default?)
                          (.ref cfg 'default-focus-depth)
                          3))
           (focus-rows
            (filter-map
             (lambda (fid)
               (let (idx (resolve-idx fid))
                 (and idx (list idx focus-depth))))
             focus-props))
           (defeater-rows
            (delete-duplicates/hash
             (append
              (filter-map
               (lambda (h)
                 (and (not (string-empty? (.ref h 'activeDefeaters)))
                      (list (hash-get idx-by-qid (.ref h 'identity)))))
               headlines)
              (filter-map
               (lambda (did)
                 (let (idx (resolve-idx did))
                   (and idx (list idx))))
               extra-defeater-props))))
           (drill-rows
            (filter-map
             (lambda (pr)
               (let ((idx (resolve-idx (car pr)))
                     (lvl (cdr pr)))
                 (and idx (exact-integer? lvl) (<= 0 lvl 3)
                      (list idx lvl))))
             drill-downs))
           ;; EDB Case & AST signals for dynamic facet deduction
           (over-watermark?
            (ormap (lambda (s) (>= (.ref s 'lineCount) (.ref cfg 'split-line-watermark)))
                   sources))
           (has-attach-links?
            (ormap (lambda (l) (equal? (.ref l 'protocol) "attachment")) links))
           (multi-todo? (>= (length (filter (lambda (r) (= (cadr r) 1)) headline-rows)) 2))
           (signal-rows
            (delete-duplicates/hash
             (append
              (map (lambda (s) (list (signal->code s))) case-signals)
              (if over-watermark? '((7)) '())
              (if has-attach-links? '((5)) '())
              (if multi-todo? '((2)) '())
              (if (.ref cfg 'require-sod-reviewer?) '((6)) '())
              (if (pair? defeater-rows) '((4)) '()))))
           ;; Execute genuine `gerbil-ascent` fixed-point Datalog + Max-Lattice program!
           (program
            (relational-program
              (relation headline_node (idx state) headline-rows)
              (relation depends_edge (from to) depends-rows)
              (relation parent_edge (parent child) parent-rows)
              (relation ready_todo (idx) ready-rows)
              (relation focus_node (idx depth) focus-rows)
              (relation defeated_node (idx) defeater-rows)
              (relation drill_request (idx depth) drill-rows)
              (relation case_signal (code) signal-rows)
              (lattice disclose_depth (idx depth) '() max)
              (relation required_facet (code))
              ;; L0 baseline for all headlines (outline skeleton)
              (rule (disclose_depth ?x 0) (headline_node ?x ?_))
              ;; L1 for ready TODOs (properties + schedule + open checklist)
              (rule (disclose_depth ?x 1) (ready_todo ?x))
              ;; Focused target gets configured focus depth (default L2: results body, thinking folded)
              (rule (disclose_depth ?x ?d) (focus_node ?x ?d))
              ;; 1-hop DEPENDS_ON from focus: settled ADR/invariant gets L2; task neighbor gets L1
              (rule (disclose_depth ?dep 2)
                    (focus_node ?x ?_) (depends_edge ?x ?dep) (headline_node ?dep 0))
              (rule (disclose_depth ?dep 1)
                    (focus_node ?x ?_) (depends_edge ?x ?dep))
              ;; Active defeater escalates node and its parent container to L3 (full thinking & evidence)
              (rule (disclose_depth ?x 3) (defeated_node ?x))
              (rule (disclose_depth ?p 3) (parent_edge ?p ?c) (defeated_node ?c))
              ;; Explicit Agent Drill-Down joins into max lattice
              (rule (disclose_depth ?x ?d) (drill_request ?x ?d))
              ;; Dynamic Org Facet deduction rules (zero static boilerplate!)
              (rule (required_facet ?c) (case_signal ?c))
              ;; Cross-module / invariant change (3) implies scheduled TODO DAG (2) + SoD reviewer (6)
              (rule (required_facet 2) (required_facet 3))
              (rule (required_facet 6) (required_facet 3))
              ;; Scheduled TODO DAG (2) implies inline checklist structure (1)
              (rule (required_facet 1) (required_facet 2))
              (limits 1024 2048 2048)))
           (solution (relational-solve (relational-admit program)))
           (depth-rows (relational-query-name solution 'disclose_depth))
           (facet-rows (relational-query-name solution 'required_facet))
           (depth-by-idx (make-hash-table)))
      (for-each (lambda (r) (hash-put! depth-by-idx (car r) (cadr r))) depth-rows)
      (let* ((headlineDisclosures
              (let loop ((i 0) (acc '()))
                (if (= i (length headlines))
                  (reverse acc)
                  (let* ((h (hash-get node-by-idx i))
                         (depth (or (hash-get depth-by-idx i) 0))
                         (levelSymbol (vector-ref '#(L0 L1 L2 L3) depth))
                         (identity (.ref h 'identity))
                         (sourceId (.ref h 'sourceId))
                         (propertyId (.ref h 'propertyId))
                         (title (.ref h 'title)))
                    (loop (+ i 1)
                          (cons (.o identity sourceId propertyId title depth levelSymbol)
                                acc))))))
             (facet-codes
              (list-sort < (delete-duplicates/hash (map car facet-rows))))
             (triggeredFacets
              (filter-map
               (lambda (code)
                 (let (entry (assoc code +facet-specs+))
                   (and entry
                        (let ((facetCode code)
                              (facetId (cadr entry))
                              (flashInstruction (caddr entry)))
                          (.o facetCode facetId flashInstruction)))))
               facet-codes))
             (flashGuidancePrompt
              (if (null? triggeredFacets)
                "Keep minimal Org turn structure; no extra structural facets triggered."
                (string-join
                 (map (lambda (f)
                        (string-append "- [" (symbol->string (.ref f 'facetId)) "]: "
                                       (.ref f 'flashInstruction)))
                      triggeredFacets)
                 "\n")))
             (kind 'agentic-ai-lab.ai-agentic-context.ascent-progressive-plan.v1)
             (action-authorized? #f))
        (.o kind headlineDisclosures triggeredFacets flashGuidancePrompt
            action-authorized?)))))

;;; ---------------------------------------------------------------------------
;;; 3. Progressive Org View Renderer (`L0 -> L3` Token-Saving Slices)
;;; ---------------------------------------------------------------------------

(def (format-l0-headline h depth-sym)
  (let ((stars (make-string (.ref h 'level) #\*))
        (kw (if (string-empty? (.ref h 'todoKeyword)) ""
              (string-append " " (.ref h 'todoKeyword))))
        (prio (if (string-empty? (.ref h 'priority)) ""
                (string-append " [#" (.ref h 'priority) "]")))
        (tags (if (string-empty? (.ref h 'tagsCsv)) ""
                (string-append " " (.ref h 'tagsCsv))))
        (pid (if (string-empty? (.ref h 'propertyId)) "unanchored" (.ref h 'propertyId))))
    (string-append stars kw prio " " (.ref h 'title) tags
                   "  ;; [ID: " pid " | " (symbol->string depth-sym) "]\n")))

(def (fold-thinking-blocks slice-text)
  ;; Replaces `#+BEGIN_THINKING ... #+END_THINKING` interiors with a 1-line stub
  ;; at L2 so downstream models read conclusions without paying thinking tokens.
  (let loop ((lines (string-split slice-text #\newline))
             (in-thinking? #f)
             (out '()))
    (cond
     ((null? lines) (string-join (reverse out) "\n"))
     ((string-ci=? (string-trim (car lines)) "#+BEGIN_THINKING")
      (loop (cdr lines) #t
            (cons "#+BEGIN_THINKING [folded at L2; request drill-down L3 to inspect]" out)))
     ((string-ci=? (string-trim (car lines)) "#+END_THINKING")
      (loop (cdr lines) #f (cons "#+END_THINKING" out)))
     (in-thinking? (loop (cdr lines) #t out))
     (else (loop (cdr lines) #f (cons (car lines) out))))))

(def (agentic-ai-lab-ai-agentic-context-render-progressive-org
      elem-graph progressive-plan (source-filter #f))
  (unless (and (agentic-ai-lab-ai-agentic-context-org-element-graph-shape? elem-graph)
               (object? progressive-plan)
               (.slot? progressive-plan 'headlineDisclosures))
    (error "Invalid progressive Org render inputs"))
  (let* ((graph (.ref elem-graph 'graph))
         (source-map (.ref elem-graph 'source-texts))
         (all-nodes (map yuanxu-graph-node-payload (yuanxu-graph-nodes graph)))
         (items-by-h (make-hash-table))
         (depth-by-qid (make-hash-table)))
    (for-each
     (lambda (d) (hash-put! depth-by-qid (.ref d 'identity) (.ref d 'depth)))
     (.ref progressive-plan 'headlineDisclosures))
    (for-each
     (lambda (n)
       (when (eq? (.ref n 'label) 'OrgListItem)
         (let (hid (.ref n 'headlineId))
           (unless (string-empty? hid)
             (hash-put! items-by-h hid
                        (append (or (hash-get items-by-h hid) '()) (list n)))))))
     all-nodes)
    (let* ((selected-sources
            (filter (lambda (pr) (or (not source-filter) (equal? (car pr) source-filter)))
                    source-map))
           (rendered
            (map
             (lambda (pr)
               (let* ((sid (car pr))
                      (txt (cdr pr))
                      (bytes (string->utf8 txt))
                      (src-headlines
                       (list-sort (lambda (a b) (< (.ref a 'byteStart) (.ref b 'byteStart)))
                                  (filter (lambda (n)
                                            (and (eq? (.ref n 'label) 'OrgHeadline)
                                                 (equal? (.ref n 'sourceId) sid)))
                                          all-nodes)))
                      ;; Compute own span before first child headline so nested sections don't duplicate
                      (chunks
                       (let loop ((hs src-headlines) (acc '()))
                         (if (null? hs) (reverse acc)
                           (let* ((h (car hs))
                                  (hstart (.ref h 'byteStart))
                                  (hend (.ref h 'byteEnd))
                                  (first-child
                                   (find (lambda (c) (< hstart (.ref c 'byteStart) hend))
                                         (cdr hs)))
                                  (own-end (if first-child (.ref first-child 'byteStart) hend))
                                  (depth (or (hash-get depth-by-qid (.ref h 'identity)) 0))
                                  (chunk
                                   (case depth
                                     ((0) (format-l0-headline h 'L0))
                                     ((1)
                                      (let* ((its (filter (lambda (it)
                                                            (and (< (.ref it 'byteStart) own-end)
                                                                 (equal? (.ref it 'checkboxState) "unchecked")))
                                                          (or (hash-get items-by-h (.ref h 'identity)) '())))
                                             (sched (if (string-empty? (.ref h 'scheduledRaw)) ""
                                                      (string-append "SCHEDULED: " (.ref h 'scheduledRaw) "\n")))
                                             (deadl (if (string-empty? (.ref h 'deadlineRaw)) ""
                                                      (string-append "DEADLINE: " (.ref h 'deadlineRaw) "\n")))
                                             (checklist (if (null? its) ""
                                                          (string-append
                                                           (string-join
                                                            (map (lambda (it)
                                                                   (string-append "- [ ] " (.ref it 'itemText)))
                                                                 its)
                                                            "\n")
                                                           "\n"))))
                                        (string-append (format-l0-headline h 'L1) sched deadl checklist)))
                                     ((2) (fold-thinking-blocks (utf8-slice bytes hstart own-end)))
                                     (else (utf8-slice bytes hstart own-end)))))
                             (loop (cdr hs) (cons chunk acc)))))))
                 (string-append ";; Source: " sid "\n" (string-join chunks ""))))
             selected-sources)))
      (string-join rendered "\n"))))

;;; ---------------------------------------------------------------------------
;;; 4. Two-Stage Org Repair Pipeline (~90% AST Auto-Repair + ~10% Flash Request)
;;; ---------------------------------------------------------------------------

(def (headline-line? trimmed)
  (and (> (string-length trimmed) 0)
       (char=? (string-ref trimmed 0) #\*)))

(def (normalize-headline-line line fixes-box)
  ;; 1) Ensure space after leading `*+` (`*TODO Title` -> `* TODO Title`)
  ;; 2) Ensure trailing `:` on malformed end tag (`* Title :ATTACH` -> `* Title :ATTACH:`)
  (let* ((len (string-length line))
         (stars-end (let loop ((i 0))
                      (if (and (< i len) (char=? (string-ref line i) #\*))
                        (loop (+ i 1)) i)))
         (step1
          (if (and (> stars-end 0) (< stars-end len)
                   (not (char-whitespace? (string-ref line stars-end))))
            (begin
              (set-box! fixes-box (cons 'normalized-headline-star-space (unbox fixes-box)))
              (string-append (substring line 0 stars-end) " "
                             (substring line stars-end len)))
            line))
         (trimmed-end (string-trim step1))
         (last-space (let loop ((i (- (string-length trimmed-end) 1)))
                       (cond ((< i 0) #f)
                             ((char-whitespace? (string-ref trimmed-end i)) i)
                             (else (loop (- i 1))))))
         (tail-tok (and last-space
                        (substring trimmed-end (+ last-space 1) (string-length trimmed-end)))))
    (if (and tail-tok
             (> (string-length tail-tok) 1)
             (char=? (string-ref tail-tok 0) #\:)
             (not (char=? (string-ref tail-tok (- (string-length tail-tok) 1)) #\:))
             (let loop ((i 1))
               (or (= i (string-length tail-tok))
                   (let (ch (string-ref tail-tok i))
                     (and (or (char-alphabetic? ch) (char-numeric? ch)
                              (memv ch '(#\_ #\@ #\# #\% #\:)))
                          (loop (+ i 1)))))))
      (begin
        (set-box! fixes-box (cons 'normalized-headline-tag-colon (unbox fixes-box)))
        (string-append trimmed-end ":"))
      step1)))

(def (normalize-checkbox-line line fixes-box)
  ;; Normalizes `-[x] foo`, `- [x] foo`, `- [] foo` -> `- [X] foo`, `- [ ] foo`
  (let* ((len (string-length line))
         (indent-end (let loop ((i 0))
                       (if (and (< i len) (char=? (string-ref line i) #\space))
                         (loop (+ i 1)) i)))
         (indent (substring line 0 indent-end))
         (rest (substring line indent-end len)))
    (cond
     ((or (string-prefix? "- [x] " rest) (string-prefix? "-[x] " rest)
          (string-prefix? "- [X]" rest) (string-prefix? "-[X] " rest))
      (let* ((rb (string-index rest #\]))
             (tail (string-trim (substring rest (+ rb 1) (string-length rest))))
             (fixed (string-append indent "- [X] " tail)))
        (unless (equal? fixed line)
          (set-box! fixes-box (cons 'normalized-checkbox-token (unbox fixes-box))))
        fixed))
     ((or (string-prefix? "- [] " rest) (string-prefix? "-[] " rest)
          (string-prefix? "-[ ] " rest))
      (let* ((rb (string-index rest #\]))
             (tail (string-trim (substring rest (+ rb 1) (string-length rest)))))
        (set-box! fixes-box (cons 'normalized-checkbox-token (unbox fixes-box)))
        (string-append indent "- [ ] " tail)))
     (else line))))

(def (recompute-all-cookies org-text fixes-box)
  (let* ((bytes (string->utf8 org-text))
         (view (org-source-element-graph org-text))
         (records (list-sort (lambda (a b) (< (.ref a 'start) (.ref b 'start)))
                             (org-element-graph-records view)))
         (by-id (make-hash-table))
         (cookies (filter (lambda (r) (equal? (.ref r 'kind) "statistics-cookie")) records))
         (items (filter (lambda (r)
                          (and (equal? (.ref r 'kind) "item")
                               (org-source-element-field r "checkbox")))
                        records)))
    (for-each (lambda (r) (hash-put! by-id (.ref r 'id) r)) records)
    (if (null? cookies)
      org-text
      ;; Patch from right to left so earlier byte offsets remain exact!
      (foldl
       (lambda (cookie current-text)
         (let* ((hid (.ref cookie 'parent))
                (owned-items
                 (filter (lambda (it)
                           (let loop ((pid (.ref it 'parent)))
                             (and pid
                                  (let (p (hash-get by-id pid))
                                    (and p (if (member (.ref p 'kind) '("headline" "inlinetask"))
                                             (= (.ref p 'id) hid)
                                             (loop (.ref p 'parent))))))))
                         items)))
           (if (null? owned-items)
             current-text
             (let* ((total-cnt (length owned-items))
                    (done-cnt
                     (length (filter (lambda (it)
                                       (let (cb (org-source-element-field it "checkbox"))
                                         (or (equal? cb "X") (equal? cb "x"))))
                                     owned-items)))
                    (old-val (or (org-source-element-field cookie "value") ""))
                    (new-val
                     (if (string-contains old-val "%")
                       (string-append "[" (number->string (quotient (* done-cnt 100) total-cnt)) "%]")
                       (string-append "[" (number->string done-cnt) "/" (number->string total-cnt) "]"))))
               (if (equal? old-val new-val)
                 current-text
                 (let (cbytes (string->utf8 current-text))
                   (set-box! fixes-box (cons 'recomputed-statistics-cookie (unbox fixes-box)))
                   (string-append (utf8-slice cbytes 0 (.ref cookie 'start))
                                  new-val
                                  (utf8-slice cbytes (.ref cookie 'end)
                                              (u8vector-length cbytes)))))))))
       org-text
       (reverse cookies)))))

(def (agentic-ai-lab-ai-agentic-context-ast-auto-repair
      raw-org-text (defaults #f))
  (unless (string? raw-org-text)
    (error "AST auto-repair requires raw Org text"))
  (let ((fixes-box (box '()))
        (lines (string-split raw-org-text #\newline)))
    ;; Structural line-state pass:
    ;; - Converts nested `:THINKING: ... :END:` inside `:RESULTS:` into `#+BEGIN_THINKING ... #+END_THINKING`
    ;; - Closes unclosed `:PROPERTIES:`, `:RESULTS:`, `#+BEGIN_THINKING`, `#+BEGIN_SRC` before next headline / EOF
    ;; - Normalizes headline stars/tags and checkbox markers inside prose (never inside `src-block`!)
    (let loop ((rest lines)
               (in-src? #f)
               (open-drawer #f)       ;; 'properties | 'results | 'other | #f
               (in-nested-thinking? #f)
               (in-special-thinking? #f)
               (out '()))
      (if (null? rest)
        (let* ((closed-out
                (let* ((o1 (if in-src?
                             (begin
                               (set-box! fixes-box (cons 'closed-unterminated-src-block (unbox fixes-box)))
                               (cons "#+END_SRC" out))
                             out))
                       (o2 (if (or in-nested-thinking? in-special-thinking?)
                             (begin
                               (set-box! fixes-box (cons 'closed-unterminated-thinking-block (unbox fixes-box)))
                               (cons "#+END_THINKING" o1))
                             o1))
                       (o3 (if open-drawer
                             (begin
                               (set-box! fixes-box (cons 'closed-unterminated-drawer (unbox fixes-box)))
                               (cons ":END:" o2))
                             o2)))
                  (reverse o3)))
               (joined (let (s (string-join closed-out "\n"))
                         (if (or (string-empty? s)
                                 (char=? (string-ref s (- (string-length s) 1)) #\newline))
                           s (string-append s "\n"))))
               ;; Inject missing root `:PROPERTIES:` when caller supplies `defaults`
               (with-root
                (if (not (object? defaults))
                  joined
                  (let* ((props (agentic-ai-lab-ai-agentic-context-org-properties joined))
                         (root-props (filter (lambda (p) (eq? (.ref p 'container-kind) 'OrgFile)) props))
                         (has-root-key?
                          (lambda (k)
                            (find (cut agentic-ai-lab-ai-agentic-context-org-property-key? <> k) root-props))))
                    (if (pair? root-props)
                      joined
                      (let ((rid (opt-ref defaults 'root-id #f))
                            (cid (opt-ref defaults 'contract-id #f))
                            (crev (opt-ref defaults 'contract-revision "1"))
                            (proj (opt-ref defaults 'project-id #f)))
                        (if (and rid cid proj (not (has-root-key? "ID")))
                          (begin
                            (set-box! fixes-box (cons 'synthesized-root-property-drawer (unbox fixes-box)))
                            (string-append ":PROPERTIES:\n"
                                           ":ID: " rid "\n"
                                           ":CONTRACT_ID: " cid "\n"
                                           ":CONTRACT_REVISION: " crev "\n"
                                           ":GITOPS_PROJECT: " proj "\n"
                                           ":END:\n"
                                           joined))
                          joined))))))
               (cookie-fixed (recompute-all-cookies with-root fixes-box))
               (repairedOrg cookie-fixed)
               (appliedFixes (delete-duplicates/hash (reverse (unbox fixes-box))))
               (repaired? (pair? appliedFixes))
               (kind 'agentic-ai-lab.ai-agentic-context.ast-auto-repair.v1))
          (org-source-element-graph repairedOrg)
          (.o kind repaired? appliedFixes repairedOrg))
        (let* ((line (car rest))
               (trimmed (string-trim line)))
          (cond
           ;; Inside `#+BEGIN_SRC ... #+END_SRC`: preserve verbatim until `#+END_SRC` or headline escape
           (in-src?
            (cond
             ((string-prefix? "#+end_src" (string-downcase trimmed))
              (loop (cdr rest) #f open-drawer in-nested-thinking? in-special-thinking?
                    (cons line out)))
             ((headline-line? trimmed)
              (set-box! fixes-box (cons 'closed-unterminated-src-block (unbox fixes-box)))
              (loop rest #f open-drawer in-nested-thinking? in-special-thinking?
                    (cons "#+END_SRC" out)))
             (else
              (loop (cdr rest) #t open-drawer in-nested-thinking? in-special-thinking?
                    (cons line out)))))
           ;; Start of source block
           ((string-prefix? "#+begin_src" (string-downcase trimmed))
            (loop (cdr rest) #t open-drawer in-nested-thinking? in-special-thinking?
                  (cons line out)))
           ;; Headline encountered while a drawer or thinking block was left open -> close before headline!
           ((and (headline-line? trimmed)
                 (or open-drawer in-nested-thinking? in-special-thinking?))
            (let* ((o1 (if (or in-nested-thinking? in-special-thinking?)
                         (begin
                           (set-box! fixes-box (cons 'closed-unterminated-thinking-block (unbox fixes-box)))
                           (cons "#+END_THINKING" out))
                         out))
                   (o2 (if open-drawer
                         (begin
                           (set-box! fixes-box (cons 'closed-unterminated-drawer (unbox fixes-box)))
                           (cons ":END:" o1))
                         o1)))
              (loop rest #f #f #f #f o2)))
           ;; Nested `:THINKING:` drawer accidentally written inside `:RESULTS:` -> convert to `#+BEGIN_THINKING`!
           ((and (eq? open-drawer 'results) (string-ci=? trimmed ":THINKING:"))
            (set-box! fixes-box (cons 'rewrote-nested-thinking-drawer-to-special-block (unbox fixes-box)))
            (loop (cdr rest) #f 'results #t #f (cons "#+BEGIN_THINKING" out)))
           ;; Matching `:END:` for converted nested `:THINKING:` -> emit `#+END_THINKING` keeping `:RESULTS:` open!
           ((and in-nested-thinking? (string-ci=? trimmed ":END:"))
            (loop (cdr rest) #f open-drawer #f #f (cons "#+END_THINKING" out)))
           ((string-ci=? trimmed "#+BEGIN_THINKING")
            (loop (cdr rest) #f open-drawer in-nested-thinking? #t (cons line out)))
           ((string-ci=? trimmed "#+END_THINKING")
            (loop (cdr rest) #f open-drawer #f #f (cons line out)))
           ((string-ci=? trimmed ":PROPERTIES:")
            (loop (cdr rest) #f 'properties #f in-special-thinking? (cons line out)))
           ((string-ci=? trimmed ":RESULTS:")
            (loop (cdr rest) #f 'results #f in-special-thinking? (cons line out)))
           ((string-ci=? trimmed ":END:")
            (loop (cdr rest) #f #f #f in-special-thinking? (cons line out)))
           ((headline-line? trimmed)
            (loop (cdr rest) #f #f #f #f
                  (cons (normalize-headline-line line fixes-box) out)))
           (else
            (loop (cdr rest) #f open-drawer in-nested-thinking? in-special-thinking?
                  (cons (if open-drawer line (normalize-checkbox-line line fixes-box))
                        out)))))))))

(def (evaluate-inline-org-contracts org-text)
  (let* ((view (org-source-element-graph org-text))
         (defs (org-source-contract-definitions view))
         (failures '()))
    (for-each
     (lambda (d)
       (let* ((scope-id (if (eq? (.ref d 'scope) 'document) 0 (.ref d 'source-scope-id)))
              (results (org-contract-evaluate-definition d view scope-id))
              (assertions (org-contract-definition-assertions d)))
         (for-each
          (lambda (res)
            (unless (org-contract-result-passed? res)
              (let* ((aid (org-contract-result-assertion-id res))
                     (adecl (find (lambda (a) (equal? (org-contract-assertion-id a) aid))
                                  assertions))
                     (assertionId aid)
                     (message (or (and adecl (org-contract-assertion-message adecl))
                                  (string-append "Failed inline Org Contract assertion: " aid)))
                     (fixHint (or (and adecl (org-contract-assertion-fix adecl))
                                  "Update the Org section to satisfy the declared org-elements expectation.")))
                (set! failures (cons (.o assertionId message fixHint) failures)))))
          results)))
     defs)
    (reverse failures)))

(def (agentic-ai-lab-ai-agentic-context-repair-org
      source-id generation raw-org-text
      (defaults #f) (catalog DefaultOrgContractCatalog))
  (unless (and (string? source-id) (< 0 (string-length source-id) 257)
               (exact-integer? generation) (<= 1 generation 65534)
               (string? raw-org-text))
    (error "Invalid two-stage Org repair inputs"))
  (let* ((stage1 (agentic-ai-lab-ai-agentic-context-ast-auto-repair raw-org-text defaults))
         (repairedOrg (.ref stage1 'repairedOrg))
         (appliedFixes (.ref stage1 'appliedFixes)))
    (with-catch
     (lambda (exn)
       (let* ((diagnostic (exception->string exn))
              (offendingSlice (if (> (string-length repairedOrg) 2048)
                                (substring repairedOrg 0 2048)
                                repairedOrg))
              (sourceId (string-copy source-id))
              (fixHint "Resolve the Org Contract schema/property gap in this bounded slice using Flash.")
              (flashRepairRequest
               (.o kind: 'agentic-ai-lab.ai-agentic-context.flash-repair-request.v1
                   sourceId offendingSlice diagnostic fixHint))
              (kind 'agentic-ai-lab.ai-agentic-context.org-repair-receipt.v1)
              (accepted? #f)
              (stage 'needs-flash-semantic-repair)
              (sourceCut #f)
              (action-authorized? #f))
         (.o kind accepted? stage repairedOrg appliedFixes
             sourceCut flashRepairRequest action-authorized?)))
     (lambda ()
       (let ((cut (context-org-source source-id generation repairedOrg #t catalog))
             (inline-failures (evaluate-inline-org-contracts repairedOrg)))
         (if (pair? inline-failures)
           (let* ((first-f (car inline-failures))
                  (diagnostic (.ref first-f 'message))
                  (fixHint (.ref first-f 'fixHint))
                  (offendingSlice (if (> (string-length repairedOrg) 2048)
                                    (substring repairedOrg 0 2048)
                                    repairedOrg))
                  (sourceId (string-copy source-id))
                  (flashRepairRequest
                   (.o kind: 'agentic-ai-lab.ai-agentic-context.flash-repair-request.v1
                       sourceId offendingSlice diagnostic fixHint inlineFailures: inline-failures))
                  (kind 'agentic-ai-lab.ai-agentic-context.org-repair-receipt.v1)
                  (accepted? #f)
                  (stage 'needs-flash-semantic-repair)
                  (sourceCut #f)
                  (action-authorized? #f))
             (.o kind accepted? stage repairedOrg appliedFixes
                 sourceCut flashRepairRequest action-authorized?))
           (let ((kind 'agentic-ai-lab.ai-agentic-context.org-repair-receipt.v1)
                 (accepted? #t)
                 (stage (if (.ref stage1 'repaired?) 'ast-auto-repaired 'clean-as-is))
                 (sourceCut cut)
                 (flashRepairRequest #f)
                 (action-authorized? #f))
             (.o kind accepted? stage repairedOrg appliedFixes
                 sourceCut flashRepairRequest action-authorized?))))))))
