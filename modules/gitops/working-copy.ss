;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; GitOps library semantics. Execution and custody belong to the selected consumer.
(import "types.ss" "objects.ss" "contracts.ss"
        (only-in :clan/poo/type element? raise-type-error)
        (only-in :clan/poo/object .o .cc .get object?)
        (only-in :orgize/languages/org/modules/org-elements/source-interface
                 org-source-element-graph)
        (only-in :orgize/languages/org/modules/org-elements/query
                 make-org-element-query-context org-element-map org-element-select org-element-property)
        (only-in :orgize/languages/org/modules/org-elements/syntax org-elements property)
        (only-in :orgize/languages/org/modules/org-elements/values
                 org-element-graph-id-of))
(export GitOpsWorkingCopyPolicy gitops-bind-working-copy-policy
        gitops-select-working-copy gitops-working-copy-evidence
        gitops-admit-working-copy-receipt gitops-refresh-working-copy-evidence)

;; These observations and receipts retain the caller's object identities.
(def (require-gitops-value type value)
  (unless (element? type value)
    (raise-type-error type value)))

;; A derived POO policy closes over the selected parsed Org source and parent
;; policy restrictions. Unknown, absent or ambiguous declarations fail closed.
(def (gitops-bind-working-copy-policy parent source-value anchor-value revision-value)
  (require-gitops-value GitOpsWorkingCopyPolicyType parent)
  (require-gitops-value GitOpsSourceCut source-value)
  (unless (and (string? anchor-value)
               (string? revision-value)
               (> (string-length revision-value) 0))
    (error "GitOps requires one source-qualified Org anchor and policy revision"))
  (def graph (org-source-element-graph (.get source-value text)))
  (def context (make-org-element-query-context graph))
  (def document (car (org-element-map context "org-data" true)))
  (def document-id ((org-element-graph-id-of graph) document))
  (def ids
    (org-element-select
      (org-elements node-property
        (property key "ID")
        (property value anchor-value))
      context document-id '()))
  (def headings
    (org-element-map context "headline"
      (lambda (heading)
        (equal? (org-element-property context heading "property:ID") anchor-value))))
  (unless (and (= (length ids) 1) (= (length headings) 1))
    (error "GitOps requires one source-qualified Org anchor and policy revision"))
  (def heading (car headings))
  (def allowed-text (org-element-property context heading "property:GITOPS_ALLOWED"))
  (def preferred-text (org-element-property context heading "property:GITOPS_PREFERRED"))
  (def allowed-words
    (and (string? allowed-text)
         (filter (lambda (word) (> (string-length word) 0))
                 (string-split allowed-text #\space))))
  (unless (pair? allowed-words)
    (error "Missing GitOps capability declaration"))
  (unless (and (string? preferred-text)
               (> (string-length preferred-text) 0)
               (equal? (string-split preferred-text #\space) (list preferred-text)))
    (error "Missing GitOps provider preference"))
  (def declared (map string->symbol allowed-words))
  (def preferred (string->symbol preferred-text))
  (unless (memq preferred declared)
    (error "GitOps preference must name a declared capability"))
  (def parent-capabilities (.get parent allowed))
  (.cc parent source: source-value
       anchor: anchor-value
       revision: revision-value
       allowed: (filter (cut memq <> parent-capabilities) declared)
       preferred: preferred))

(def (gitops-select-working-copy policy availability)
  (require-gitops-value GitOpsWorkingCopyPolicyType policy)
  (unless (object? availability) (error "GitOps availability must be a POO observation"))
  (let (selected ((.get policy select-provider) policy availability))
    (cond ((not selected) #f)
          ((and (memq selected (.get policy allowed))
                (gitops-provider-available? availability selected)) selected)
          (else (error "GitOps selector violated capability restrictions")))))

(def (gitops-working-copy-evidence)
  (.o receipts: '()
      accepted-requests: '()
      binding: #f
      active-policy: #f
      active-request: #f
      active-provider: #f
      accepted?: #f
      admitted?: #f))

(def (same-source? a b)
  (gitops-create-source-current?
    (equal? (.get a project) (.get b project))
    (equal? (.get a worktree) (.get b worktree))
    (equal? (.get a path) (.get b path))
    (equal? (.get a text) (.get b text))
    (equal? (.get a git-head) (.get b git-head))))

(def (retain-current? policy state current)
  (gitops-create-retain-current?
    (.get state accepted?)
    (eq? (.get state active-policy) policy)
    (equal? (.get state active-request) (.get current request))
    (eq? (.get state active-provider) (.get current provider))
    (.get current authorized?)
    (.get current fence-current?)
    (same-source? (.get policy source) (.get current source))
    (equal? (.get policy revision) (.get current policy-revision))))

;; Pure evidence transition. Runtime custody/fence facts are supplied by the
;; consumer's execution owner, never inferred from success status or Org prose.
(def (gitops-admit-working-copy-receipt policy state receipt current)
  (require-gitops-value GitOpsWorkingCopyPolicyType policy)
  (require-gitops-value GitOpsSourceCut (.get policy source))
  (require-gitops-value GitOpsEvidenceState state)
  (require-gitops-value GitOpsReceipt receipt)
  (require-gitops-value GitOpsCurrentFacts current)
  (def source (.get policy source))
  (def revision (.get policy revision))
  (def request (.get receipt request))
  (def provider (.get receipt provider))
  (def binding (.get receipt working-copy))
  (def accepted-requests (.get state accepted-requests))
  (def admitted?
    (gitops-create-semantic-admit?
      (.get current authorized?)
      (.get current fence-current?)
      (same-source? source (.get current source))
      (equal? revision (.get current policy-revision))
      (same-source? source (.get receipt source))
      (equal? revision (.get receipt policy-revision))
      (equal? (.get policy anchor) (.get receipt anchor))
      (not (member request accepted-requests))
      (equal? request (.get current request))
      (.get receipt custody-valid?)
      (.get receipt executed?)
      (and (eq? provider (.get current provider))
           (memq provider (.get policy allowed)))
      (eq? (.get receipt outcome) 'applied)
      (element? GitOpsAppliedWorkingCopy binding)))
  (def retained? (and (not admitted?) (retain-current? policy state current)))
  (.cc state receipts: (cons receipt (.get state receipts))
       active-policy: (if admitted? policy (.get state active-policy))
       active-request: (if admitted? request (.get state active-request))
       active-provider: (if admitted? provider (.get state active-provider))
       admitted?: admitted?
       accepted?: (or admitted? retained?)
       accepted-requests: (if admitted? (cons request accepted-requests) accepted-requests)
       binding: (if admitted? binding (and retained? (.get state binding)))))

(def (gitops-refresh-working-copy-evidence policy state current)
  (require-gitops-value GitOpsWorkingCopyPolicyType policy)
  (require-gitops-value GitOpsSourceCut (.get policy source))
  (require-gitops-value GitOpsEvidenceState state)
  (require-gitops-value GitOpsCurrentFacts current)
  (def retained? (retain-current? policy state current))
  (.cc state admitted?: #f
       accepted?: retained?
       binding: (and retained? (.get state binding))))
