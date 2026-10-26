;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; One GQL model; bounded native Org refinement, positive proof and source feed.
(import
 (only-in :clan/poo/object .o .ref .slot? .call object? object<-alist .alist/sort)
 (only-in :clan/poo/mop validate)
 (only-in :std/list/list find every delete-duplicates/hash)
 :yuanxu/poo-clos/interface
 :agentic-ai-lab/modules/query/objects
 (only-in :agentic-ai-lab/modules/query/types AgenticAILabQuery agentic-ai-lab-query?)
 :agentic-ai-lab/modules/query/contracts
 :agentic-ai-lab/modules/query/gql
 :agentic-ai-lab/modules/query/funs
 :agentic-ai-lab/modules/query/scheme-select
 :agentic-ai-lab/modules/query/results/funs
 :agentic-ai-lab/modules/temporal-causality/runtime/change-feed
 :agentic-ai-lab/modules/temporal-causality/evaluator/positive-proof
 :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/interface
 :agentic-ai-lab/modules/temporal-causality/revisions/interface
 :agentic-ai-lab/modules/temporal-causality/time/objects
 (only-in
  :gerbil-ascent/candidate/checked-program
  reasoning-source-snapshot
  reasoning-attempt
  reasoning-receipt-proof)
 (only-in
  :gerbil-ascent/candidate/provenance
  positive-proof-nodes
  positive-proof-roots
  proof-node-id
  proof-node-kind
  proof-node-relation
  proof-node-row
  proof-node-inputs)
 "org-contract/elements.ss"
 "funs-scope.ss")

(export
 context-org-source
 context-org-query
 ContextOrgQueryProvider
 context-query-host
 context-query-source!
 context-query-withdraw!
 context-query-current-source
 context-query-execute
 context-query-current?
 context-query-watch! context-query-unwatch!
 context-query-history
 context-query-export
 context-query-restore
 context-query-lineage
 context-query-journal)

(def digest
  agentic-ai-lab-ai-agentic-context-digest)

;;; Receipts and recovery data cross the owner boundary as detached values.
;;; This codec is data-only: no closures, private owners or evaluator hooks.
(def (copy-data value)
  (cond
   ((string? value) (string-copy value))
   ((pair? value) (map copy-data value))
   ((object? value)
    (object<-alist
     (map (lambda (entry) (cons (car entry) (copy-data (cdr entry))))
          (.alist/sort value))))
   (else value)))

(def (data-form value)
  (cond
   ((pair? value) (map data-form value))
   ((object? value)
    (map (lambda (entry) (list (car entry) (data-form (cdr entry))))
         (.alist/sort value)))
   (else value)))

(def columns
  '(identity propertyId sourceId sourceRevision sourceDigest contractIdentity contractRevision elementKind byteStart parserIdentity))

(def ContextOrgResultContract
  (agentic-ai-lab-query-result-contract
   'context/org-element-row-v1
   'relation-row
   columns
   32))


;;; Query core owns admission and the receipt protocol. This Provider contributes
;;; a concrete executor method; it does not create a second Query language.
(def ContextOrgExecutor
  (poo-clos-class
   'context/org-query-executor
   direct-superclasses:
   (list QueryReceiptBindingExecutor)))

(def ContextOrgQueryProvider
  (agentic-ai-lab-query-provider
   'context/org-elements
   '(gql)
   'agentic-ai-lab
   (poo-clos-make-instance ContextOrgExecutor)))

(def binding-method
  (poo-clos-method
   'context/org-query-binding
   (list
    (poo-clos-class-specializer ContextOrgExecutor)
    (poo-clos-eql-specializer ContextOrgQueryProvider)
    (poo-clos-prototype-specializer AgenticAILabQuery.)
    (poo-clos-any-specializer)
    (poo-clos-any-specializer))
   (lambda (_frame _executor provider query admission candidate)
     (agentic-ai-lab-query-bind-execution-receipt/default
      provider
      query
      admission
      candidate))))

(.defmethod-bundle ContextOrgQueryMethods QueryReceiptBindingProtocol binding-method)

(poo-clos-compose-method-bundle QueryReceiptBindingGeneric ContextOrgQueryMethods)

(def (canonical-source source)
  (let (fresh
        (context-org-source
         (.ref source 'identity)
         (.ref source 'generation)
         (.ref source 'source)
         (.ref source 'active?)))
    (unless (equal? (.ref fresh 'semantic-digest) (.ref source 'semantic-digest))
      (error "Forged Org source cut"))
    fresh))

(def (space source)
  (agentic-ai-lab-query-element-space
   (.ref source 'semantic-digest)
   (.ref source 'semantic-digest)
   (map (lambda (n) (.ref n 'identity)) (.ref source 'nodes))
   #t))

(def (projections fields)
  (and
   (pair? fields)
   (.o
     (:: @ GraphSyntaxProjection.)
     expression: (.o
                   (:: @ GraphSyntaxProperty.)
                   binding: 'e
                   property: (car fields))
     next: (projections (cdr fields)))))


;;; Ordinary authors receive a native Query value. The fixed result projection
;;; carries qualified Element identity, Property ID, source cut and Contract cut.
;;; Unsupported joins or projections are refused rather than partially executed.
(def (context-org-query
      source
      literal-value
      (key 'propertyId)
      (id 'context/org-elements)
      (version-value "1")
      (bound 32)
      (selected #f))
  (let* ((src (canonical-source source)) (sp (space src)))
    (unless (and
             (memq key columns)
             (or (string? literal-value) (exact-integer? literal-value))
             (exact-integer? bound)
             (<= 1 bound 32))
      (error "Unsupported Org GQL predicate/bound"))
    (validate
     AgenticAILabQuery
     (.o
       (:: @ AgenticAILabQuery.)
       identity: id
       version: version-value
       semantic-revision: (.ref sp 'semantic-revision)
       element-space-identity: (.ref sp 'identity)
       selected-element-identities: (or selected (.ref sp 'element-identities))
       language: AgenticAILabSchemeGqlQueryLanguage.
       program: (.o
                  (:: @ AgenticAILabGqlQueryProgram.)
                  identity: 'context/org-element-program
                  match: (.o
                           (:: @ GraphSyntaxPath.)
                           start: (.o
                                    (:: @ GraphSyntaxNode.)
                                    binding: 'e
                                    label: 'OrgElement))
                  where: (.o
                           (:: @ GraphSyntaxEquals.)
                           left: (.o
                                   (:: @ GraphSyntaxProperty.)
                                   binding: 'e
                                   property: key)
                           right: (.o
                                    (:: @ GraphSyntaxLiteral.)
                                    literal-kind: (cond
                                                   ((string? literal-value) 'string)
                                                   ((symbol? literal-value) 'symbol)
                                                   (else 'integer))
                                    value: literal-value))
                  project: (projections columns))
       result-bound: bound
       completeness-requirement: 'complete
       evidence-requirements: '(source-content-identity provenance-root result-digest)
       visibility-request: 'restricted
       result-contract: ContextOrgResultContract))))


;;; Reconstruct the supported Query from its typed fields and compare its GQL
;;; rendering and contracts. A changed program cannot borrow an old receipt.
(def (descriptor query source)
  (unless (and
           (eq? (.ref (.ref query 'language) '.program?)
                (.ref AgenticAILabSchemeGqlQueryLanguage. '.program?))
           (agentic-ai-lab-query? query))
    (error "Provider requires a native Query"))
  (let* ((p (.ref (.ref query 'program) 'where))
         (key-value (.ref (.ref p 'left) 'property))
         (literal-value (.ref (.ref p 'right) 'value))
         (fresh
          (context-org-query
           source
           literal-value
           key-value
           (.ref query 'identity)
           (.ref query 'version)
           (.ref query 'result-bound)
           (.ref query 'selected-element-identities))))
    (unless (and
             (equal? (agentic-ai-lab-query->gql query) (agentic-ai-lab-query->gql fresh))
             (every
              (lambda (k)
                (equal? (.ref query k) (.ref fresh k)))
              '(semantic-revision element-space-identity completeness-requirement evidence-requirements visibility-request mutation-authority? action-authority? runtime-executed?))
             (every
              (lambda (k)
                (equal? (.ref (.ref query 'language) k) (.ref (.ref fresh 'language) k)))
              '(identity representation execution-boundary runtime-owner parser-owner syntax-contract))
             (every
              (lambda (k)
                (equal? (.ref (.ref query 'result-contract) k) (.ref ContextOrgResultContract k)))
              '(identity result-kind required-fields max-results)))
      (error "Unsupported or rebound Context GQL Query"))
    (let ((id-value (.ref query 'identity))
          (version-value (.ref query 'version))
          (bound-value (.ref query 'result-bound))
          (selected-value (map string-copy (.ref query 'selected-element-identities))))
      (.o
        identity: id-value
        version: version-value
        key: key-value
        value: literal-value
        bound: bound-value
        selected: selected-value))))

(def (from-descriptor src d)
  (context-org-query
   src
   (.ref d 'value)
   (.ref d 'key)
   (.ref d 'identity)
   (.ref d 'version)
   (.ref d 'bound)
   (.ref d 'selected)))


;;; Runtime effects stay behind this owner capability. Source versions and the
;;; native evidence journal are append-only; subscribers prepare before mutation.
(defstruct owner (thread sources versions journal feed queries))

(def (context-query-host)
  (.o kind: 'context.query-provider-host.v1
      private-owner:
      (make-owner
       (current-thread) (make-hash-table) '() '() (make-change-feed) '())))

(def (state host)
  (let (s (.ref host 'private-owner))
    (unless (and (owner? s) (eq? (owner-thread s) (current-thread)))
      (error "Query Provider requires serialized owner"))
    s))

(def (instant n)
  (agentic-ai-lab-temporal-instant
   (number->string n)
   "context-org"
   n
   "source-owner"
   'observed))

(def (journal revisions)
  (agentic-ai-lab-temporal-evidence-journal "context-org-sources" "context-org" revisions))

(def (context-query-journal host)
  (copy-data (journal (owner-journal (state host)))))

(def (context-query-current-source host id (required? #t))
  (let (s (state host))
    (change-feed-open! (owner-feed s))
    (let (source (hash-get (owner-sources s) id))
      (cond
       (source (canonical-source source))
       (required? (error "Unknown Org source"))
       (else #f)))))

(def (context-query-unwatch! host observer)
  (change-feed-unwatch! (owner-feed (state host)) observer))
(def (context-query-watch! host observer)
  (change-feed-watch! (owner-feed (state host)) observer))


;;; Publish a new source cut only after every subscriber can prepare. Delivery
;;; fences cached Contexts and active Attempts without waiting for a use query.
;;; Same-generation replacement, including same-ID/different-bytes, is refused.
(def (context-query-source! host source)
  (let* ((s (state host))
         (src (canonical-source source))
         (id (.ref src 'identity))
         (old (hash-get (owner-sources s) id))
         (start (length (owner-journal s))))
    (change-feed-open! (owner-feed s))
    (when (>= (length (owner-versions s)) 127)
      (error "Org source version capacity"))
    (when old
      (unless (> (.ref src 'generation) (.ref old 'generation))
        (error "Org source version reuse or rollback")))
    (unless (or old (.ref src 'active?))
      (error "Cannot withdraw an unregistered Org source"))
    ;; Each immutable version has its own evidence subject. Replacement retires
    ;; the old subject and admits a new one. Re-admission after withdrawal never
    ;; rewrites a tombstone or gives the old version support again.
    (let* ((retired
            (if (and old (.ref old 'active?))
                (list
                 (agentic-ai-lab-temporal-evidence-revision
                  (digest (list 'retire (.ref old 'semantic-digest)
                                (.ref src 'semantic-digest)))
                  (.ref old 'semantic-digest) 'retract
                  (.ref old 'semantic-digest)
                  (instant (+ start 1)) #f #f))
                '()))
           (admitted
            (if (.ref src 'active?)
                (list
                 (agentic-ai-lab-temporal-evidence-revision
                  (.ref src 'semantic-digest) (.ref src 'semantic-digest)
                  'assert #f (instant (+ start (length retired) 1))
                  (agentic-ai-lab-temporal-interval
                   "org-validity" (instant 0) (instant 65535) #t #f)
                  (.ref src 'source-digest)))
                '()))
           (next-journal (append (owner-journal s) retired admitted)))
      (when (> (length next-journal) 128)
        (error "Org evidence journal capacity"))
      (journal next-journal)
      (when old
        (change-feed-stage! (owner-feed s)
                            (authority-change 'org-source id (.ref src 'generation)
                                              old src (.ref old 'semantic-digest) (.ref src 'semantic-digest))))
      (hash-put! (owner-sources s) id src)
      (set! (owner-versions s) (append (owner-versions s) (list src)))
      (set! (owner-journal s) next-journal)
      (when old
        (change-feed-drain! (owner-feed s)))
      (canonical-source src))))

(def (context-query-withdraw! host id generation)
  (let (old (context-query-current-source host id))
    (context-query-source! host (context-org-source id generation (.ref old 'source) #f))))

(def (result-row values)
  (agentic-ai-lab-query-result-row
   (car values)
   (map
    (lambda (field value)
      (agentic-ai-lab-query-result-cell field value))
    columns
    values)))

(def (node-row n)
  (result-row (map (lambda (k) (.ref n k)) columns)))


;;; Named Org-to-Fact refinement: each native fact binds the actual source digest,
;;; version, qualified Element and canonical result-row digest. Strings become
;;; symbol atoms because this ASCENT source profile accepts typed scalar atoms.
(def (fact src row)
  (list
   (string->symbol (.ref src 'source-digest))
   (.ref src 'generation)
   (string->symbol (.ref row 'identity))
   (string->symbol (.ref row 'semantic-digest))))


;;; Run real ASCENT for each selected row and replay its positive proof through
;;; the existing admission adapter. Membership is proved; external source truth
;;; and tool authorization are deliberately separate admission obligations.
(def (prove src rows)
  (let (snapshot
        (reasoning-source-snapshot
         (.ref src 'semantic-digest)
         (.ref src 'generation)
         (list
          (list 'orgRow 4 (map (lambda (n) (fact src (node-row n))) (.ref src 'nodes))))))
    (map
     (lambda (row)
       (let* ((datum
               (list
                'candidate
                '(relation selected 4)
                '(rule (selected ?s ?v ?id ?d) (orgRow ?s ?v ?id ?d))
                (cons 'query (cons 'selected (fact src row)))
                '(limits 8 128 128)))
              (receipt (reasoning-attempt snapshot datum 512))
              (admitted
               (agentic-ai-lab-temporal-positive-proof-from-ascent
                (.ref row 'identity)
                snapshot
                datum
                receipt
                512
                128))
              (p (reasoning-receipt-proof receipt))
              (dag-value
               (map
                (lambda (n)
                  (list
                   (proof-node-id n)
                   (proof-node-kind n)
                   (proof-node-relation n)
                   (proof-node-row n)
                   (proof-node-inputs n)))
                (positive-proof-nodes p)))
              (roots-value (positive-proof-roots p))
              (candidate-value datum)
              (admission-value admitted))
         (.o
           kind: 'context.org-row-proof.v1
           admission: admission-value
           candidate: candidate-value
           dag: dag-value
           roots: roots-value)))
     rows)))


;;; GQL selection -> native membership proof -> support -> Provider receipt.
;;; Source-content-identity in Query core hashes GQL text; the separate lineage
;;; below binds original Org bytes and its source/Contract revision as well.
(def (execute src query source-journal seq)
  (unless (.ref src 'active?)
    (error "Org source withdrawn"))
  (let* ((d (descriptor query src))
         (sp (space src))
         (admission (agentic-ai-lab-query-admit query sp))
         (_ (unless (.ref admission 'accepted?) (error "Context Query admission denied")))
         (nodes
          (filter
           (lambda (n)
             (member (.ref n 'identity) (.ref query 'selected-element-identities)))
           (.ref src 'nodes)))
         (selected (agentic-ai-lab-query-select-scheme-nodes query nodes))
         (rows (map result-row (.ref selected 'rows)))
         (rs
          (agentic-ai-lab-query-result-set
           (digest (list (.ref src 'semantic-digest) (agentic-ai-lab-query->gql query)))
           ContextOrgResultContract
           (.ref query 'identity)
           (.ref query 'version)
           (.ref query 'semantic-revision)
           rows
           #t))
         (candidate
          (agentic-ai-lab-query-execution-candidate
           (.ref ContextOrgQueryProvider 'identity)
           (.ref query 'identity)
           (.ref query 'version)
           (.ref query 'semantic-revision)
           (agentic-ai-lab-query-source-content-identity query)
           (.ref (.ref query 'language) 'parser-owner)
           (.ref src 'semantic-digest)
           (.ref rs 'result-digest)
           (length rows)
           #t))
         (receipt
          (agentic-ai-lab-query-bind-execution-receipt
           ContextOrgQueryProvider
           query
           admission
           candidate))
         (_r (unless (.ref receipt 'admitted?) (error "Context Provider receipt denied")))
         (proofs-value (prove src rows))
         (supports
          (map
           (lambda (row proof)
             (agentic-ai-lab-temporal-support
              (.ref row 'identity)
              (.ref row 'identity)
              (.ref (.ref proof 'admission) 'proof-digest)
              (list
               (agentic-ai-lab-temporal-support-premise
                (.ref src 'semantic-digest)
                (.ref src 'semantic-digest)))
              '()))
           rows
           proofs-value))
         (program-value
          (and
           (pair? supports)
           (agentic-ai-lab-temporal-support-program
            "org-query-membership"
            "org-source-current"
            #t
            supports)))
         (query-digest-value (agentic-ai-lab-query-source-content-identity query))
         (result-value (.ref rs 'semantic-digest))
         (source-id-value (.ref src 'identity))
         (generation-value (.ref src 'generation))
         (source-value (.ref src 'source-digest))
         (contract-value (.ref src 'contract-identity))
         (contract-revision-value (.ref src 'contract-revision))
         (ids-value
          (map
           (lambda (row)
             (.ref
              (find (lambda (c) (eq? (.ref c 'field) 'propertyId)) (.ref row 'cells))
              'value))
           (.ref rs 'rows)))
         (proof-digests-value
          (map (lambda (p) (.ref (.ref p 'admission) 'proof-digest)) proofs-value))
         (support-value (and program-value (.ref program-value 'semantic-digest)))
         (journal-value (.ref source-journal 'semantic-digest))
         (binding-value
          (digest
           (list
            'context-query-lineage.v1
            source-id-value
            generation-value
            source-value
            contract-value
            contract-revision-value
            query-digest-value
            (.ref query 'identity)
            (.ref query 'version)
            (.ref query 'selected-element-identities)
            (.ref query 'result-bound)
            result-value
            ids-value
            proof-digests-value
            support-value
            journal-value)))
         (lineage-value
          (.o
            kind: 'context.query-lineage.v1
            source: source-id-value
            generation: generation-value
            source-digest: source-value
            contract: contract-value
            contract-revision: contract-revision-value
            query-digest: query-digest-value
            result-digest: result-value
            org-ids: ids-value
            proof-digests: proof-digests-value
            support-digest: support-value
            journal-digest: journal-value
            semantic-digest: binding-value)))
    (.o
      kind: 'context.query-observation.v1
      source-cut: src
      query-descriptor: d
      query-source: (agentic-ai-lab-query->gql query)
      result-set: rs
      query-receipt: receipt
      proofs: proofs-value
      support-program: program-value
      journal: source-journal
      admission-sequence: seq
      lineage: lineage-value
      semantic-digest: binding-value)))

(def (context-query-execute host source-id query)
  (let* ((src (context-query-current-source host source-id))
         (s (state host))
         (observed
          (execute src query (journal (owner-journal s)) (length (owner-journal s)))))
    (when (>= (length (owner-queries s)) 128)
      (error "Query journal capacity"))
    (set! (owner-queries s) (cons (copy-data observed) (owner-queries s)))
    (copy-data observed)))

(def (context-query-lineage observed)
  (.ref observed 'lineage))


;;; Final-use defense is independent of subscription delivery. Even a deliberately
;;; disabled subscriber cannot make an obsolete source/support current again.
(def (context-query-current? host observed)
  (with-catch
   (lambda (e)
     #f)
   (lambda ()
     (let* ((source (.ref observed 'source-cut))
            (live (context-query-current-source host (.ref source 'identity)))
            (program (.ref observed 'support-program))
            (evaluation
             (and
              program
              (agentic-ai-lab-temporal-support-evaluate
               program
               (context-query-journal host)
               (instant (length (owner-journal (state host))))
               #f
               128))))
       (and
        (.ref live 'active?)
        (equal? (.ref live 'semantic-digest) (.ref source 'semantic-digest))
        (or
         (not program)
         (every
          (lambda (c)
            (eq? (.ref c 'status) 'supported))
          (.ref evaluation 'conclusions))))))))

(def (context-query-history host)
  (let (s (state host))
    (copy-data
     (list (owner-versions s)
           (reverse (owner-queries s))
           (context-query-journal host)))))

;;; Durable data contains original source history, a bounded Query descriptor and
;;; the admission cut. It never serializes owner pointers or executable closures.
(def (context-query-export host (observed #f))
  (let* ((s (state host))
         (history-value (map canonical-source (owner-versions s)))
         (queries-value (copy-data (reverse (owner-queries s))))
         (reference-value (and observed (.ref observed 'semantic-digest))))
    ;; One canonical Query journal owns originals. Context bindings reference an
    ;; existing receipt digest; they do not allocate a second observation ID.
    ;; A catalog with no observation is a valid durable root. It does not need
    ;; a dummy Query or Session. Consumer capsules still select an existing ref.
    (unless (or (not observed)
                (find (lambda (q) (equal? (.ref q 'semantic-digest) reference-value))
                      queries-value))
      (error "Cannot export an observation absent from its Query journal"))
    (.o kind: 'context.query-recovery.v2
        history: history-value
        queries: queries-value
        observation-ref: reference-value)))

;;; Rebuild a historical journal record from original Org bytes and typed Query
;;; input. The current source registry is not rolled back during this replay.
(def (replay-record s recorded)
  (let* ((cut (canonical-source (.ref recorded 'source-cut)))
         (known
           (find
             (lambda (v)
               (equal? (.ref v 'semantic-digest) (.ref cut 'semantic-digest)))
             (owner-versions s)))
         (seq (.ref recorded 'admission-sequence))
         (prefix
           (let loop ((xs (owner-journal s)) (n seq))
             (cond
               ((= n 0) '())
               ((or (< n 0) (null? xs)) (error "Missing Query journal cut"))
               (else (cons (car xs) (loop (cdr xs) (- n 1)))))))
         (fresh
           (execute
             (or known (error "Unknown retained Query source"))
             (from-descriptor cut (.ref recorded 'query-descriptor))
             (journal prefix) seq)))
    (unless (equal? (data-form fresh) (data-form recorded))
      (error "Recovered Query record differs from native replay"))
    fresh))

;;; Restore every original Query record, including inputs no longer current.
;;; Re-admission can create a fresh Context but never removes its old query,
;;; proof, support or journal. Sharing uses the same catalog, not parallel IDs.
(def (context-query-restore saved (restored-host #f))
  (unless (eq? (.ref saved 'kind) 'context.query-recovery.v2)
    (error "Unsupported Query recovery capsule"))
  (let ((host (or restored-host (context-query-host)))
        (history (.ref saved 'history))
        (queries (.ref saved 'queries)))
    (unless (and (list? history) (<= (length history) 127)
                 (list? queries) (<= (length queries) 128))
      (error "Query recovery journal capacity"))
    (unless restored-host
      (for-each (lambda (src) (context-query-source! host src)) history))
    (let (s (state host))
      (if restored-host
        ;; Equal Query records alone cannot establish equal catalog heads: a
        ;; source can change without another Query. Never roll back a shared
        ;; owner to match a stale capsule, including an empty Query journal.
        (unless (and
                 (equal? (data-form (owner-versions s)) (data-form history))
                 (equal? (data-form (reverse (owner-queries s))) (data-form queries)))
          (error "Conflicting source history or Query journal for shared catalog"))
        (set! (owner-queries s)
          (reverse (map (lambda (record) (replay-record s record)) queries))))
      (let* ((reference (.ref saved 'observation-ref))
             (observed
              (and reference
               (find
                (lambda (record)
                  (equal? (.ref record 'semantic-digest) reference))
                (owner-queries s)))))
        (unless (or (not reference) observed)
          (error "Query observation reference is not in the retained journal"))
        (values host (copy-data observed))))))
