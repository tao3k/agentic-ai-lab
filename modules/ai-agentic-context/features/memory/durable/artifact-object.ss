;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: durable artifact object construction, visibility, and lifecycle.
;;; Invariant: this module owns artifact policy data only; validation receipts
;;; and runtime handoff manifests stay in durable-artifact-policy.

(import (only-in :clan/poo/object .ref .slot? object? object<-alist)
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/artifact-profile)

(export agentic-ai-lab-durable-artifact
        agentic-ai-lab-durable-artifact?
        agentic-ai-lab-durable-artifact->alist
        agentic-ai-lab-durable-artifact-visible?
        agentic-ai-lab-durable-artifact-lifecycle-transition-allowed?
        agentic-ai-lab-durable-artifact-transition
        agentic-ai-lab-artifact-list-has?
        agentic-ai-lab-artifact-scope-subset?)

(def +agentic-ai-lab-durable-artifact-kind+
  'agentic-ai-lab.durable.artifact)

(def +agentic-ai-lab-durable-artifact-schema+
  'agentic-ai-lab.durable.artifact.v1)

(def +agentic-ai-lab-durable-artifact-fields+
  '(durable-artifact-kind
    durable-artifact-schema
    artifact-id
    artifact-kind
    artifact-scope
    storage-class
    lifecycle-state
    producer-ref
    owner-ref
    sandbox-scope
    checksum-policy
    analysis-policy
    index-policy
    call-policy
    publish-policy
    retention-policy
    explicit-grants
    runtime-executed
    source))

(def +agentic-ai-lab-durable-artifact-lifecycle-edges+
  '((created . stored)
    (stored . indexed)
    (indexed . analyzed)
    (analyzed . callable)
    (callable . publish-approved)
    (publish-approved . published)
    (published . retained)
    (published . expired)
    (published . archived)
    (published . revoked)))

;; : (-> Symbol Symbol)
(def (agentic-ai-lab-durable-artifact-section-slot key)
  (case key
    ((:artifact-kind artifact-kind :kind kind) 'artifact-kind)
    ((:artifact-scope artifact-scope :scope scope) 'artifact-scope)
    ((:storage-class storage-class :storage storage) 'storage-class)
    ((:lifecycle-state lifecycle-state :state state) 'lifecycle-state)
    ((:producer-ref producer-ref :producer producer) 'producer-ref)
    ((:owner-ref owner-ref :owner owner) 'owner-ref)
    ((:sandbox-scope sandbox-scope :sandbox sandbox) 'sandbox-scope)
    ((:checksum-policy checksum-policy :checksum checksum) 'checksum-policy)
    ((:analysis-policy analysis-policy :analysis analysis) 'analysis-policy)
    ((:index-policy index-policy :index index) 'index-policy)
    ((:call-policy call-policy :call call) 'call-policy)
    ((:publish-policy publish-policy :publish publish) 'publish-policy)
    ((:retention-policy retention-policy :retention retention) 'retention-policy)
    ((:explicit-grants explicit-grants :grants grants) 'explicit-grants)
    (else key)))

;; : (-> [Datum] Alist)
(def (agentic-ai-lab-durable-artifact-sections->alist sections)
  (match sections
    ([] '())
    ([key]
     (error "durable artifact section requires a value" key))
    ([key value . rest]
     (cons (cons (agentic-ai-lab-durable-artifact-section-slot key) value)
           (agentic-ai-lab-durable-artifact-sections->alist rest)))))

;; : (-> Symbol Symbol [Symbol] Symbol Symbol Datum Datum [Symbol] [Symbol] [Symbol] [Symbol] [Symbol] [Symbol] [Symbol] [Symbol] PooDurableArtifact)
(def (agentic-ai-lab-durable-artifact/direct artifact-id-value
                                       artifact-kind-value
                                       artifact-scope-value
                                       storage-class-value
                                       lifecycle-state-value
                                       producer-ref-value
                                       owner-ref-value
                                       sandbox-scope-value
                                       checksum-policy-value
                                       analysis-policy-value
                                       index-policy-value
                                       call-policy-value
                                       publish-policy-value
                                       retention-policy-value
                                       explicit-grants-value)
  (object<-alist
   (list
    (cons 'durable-artifact-kind +agentic-ai-lab-durable-artifact-kind+)
    (cons 'durable-artifact-schema +agentic-ai-lab-durable-artifact-schema+)
    (cons 'artifact-id artifact-id-value)
    (cons 'artifact-kind artifact-kind-value)
    (cons 'artifact-scope artifact-scope-value)
    (cons 'storage-class storage-class-value)
    (cons 'lifecycle-state lifecycle-state-value)
    (cons 'producer-ref producer-ref-value)
    (cons 'owner-ref owner-ref-value)
    (cons 'sandbox-scope sandbox-scope-value)
    (cons 'checksum-policy checksum-policy-value)
    (cons 'analysis-policy analysis-policy-value)
    (cons 'index-policy index-policy-value)
    (cons 'call-policy call-policy-value)
    (cons 'publish-policy publish-policy-value)
    (cons 'retention-policy retention-policy-value)
    (cons 'explicit-grants explicit-grants-value)
    (cons 'runtime-executed #f)
    (cons 'source 'agentic-ai-lab.durable.artifact.policy))))

;; : (-> Symbol [Datum] PooDurableArtifact)
(def (agentic-ai-lab-durable-artifact artifact-id-value sections)
  (let (fields (agentic-ai-lab-durable-artifact-sections->alist sections))
    (agentic-ai-lab-durable-artifact/direct
     artifact-id-value
     (agentic-ai-lab-artifact-alist-ref fields 'artifact-kind artifact-id-value)
     (agentic-ai-lab-artifact-alist-ref fields 'artifact-scope '())
     (agentic-ai-lab-artifact-alist-ref fields 'storage-class '())
     (agentic-ai-lab-artifact-alist-ref fields 'lifecycle-state 'created)
     (agentic-ai-lab-artifact-alist-ref fields 'producer-ref #f)
     (agentic-ai-lab-artifact-alist-ref fields 'owner-ref #f)
     (agentic-ai-lab-artifact-alist-ref fields 'sandbox-scope '())
     (agentic-ai-lab-artifact-alist-ref fields 'checksum-policy '())
     (agentic-ai-lab-artifact-alist-ref fields 'analysis-policy '())
     (agentic-ai-lab-artifact-alist-ref fields 'index-policy '())
     (agentic-ai-lab-artifact-alist-ref fields 'call-policy '())
     (agentic-ai-lab-artifact-alist-ref fields 'publish-policy '())
     (agentic-ai-lab-artifact-alist-ref fields 'retention-policy '())
     (agentic-ai-lab-artifact-alist-ref fields 'explicit-grants '()))))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-durable-artifact? artifact)
  (and (object? artifact)
       (.slot? artifact 'durable-artifact-kind)
       (eq? (.ref artifact 'durable-artifact-kind)
            +agentic-ai-lab-durable-artifact-kind+)))

;; : (forall (v) (-> v [(Pair Symbol Object)]))
;; : (-> PooDurableArtifact Alist)
(def (agentic-ai-lab-durable-artifact->alist artifact)
  (map (lambda (field) (cons field (.ref artifact field)))
       +agentic-ai-lab-durable-artifact-fields+))

;; agentic-ai-lab-artifact-list-has?
;; : (-> [Datum] Datum Boolean)
;; | doc m%
;;   Return true when ITEMS contains VALUE using durable policy equality.
;;   # Examples
;;   ```scheme
;;   (agentic-ai-lab-artifact-list-has? '(session publish) 'session)
;;   ;; => #t
;;   ```
(def (agentic-ai-lab-artifact-list-has? items value)
  (and (member value items) #t))

;; agentic-ai-lab-artifact-scope-subset?
;; : (-> [Symbol] [Symbol] Boolean)
;; | doc m%
;;   Return true when every actor scope entry is allowed by artifact scope.
;;   # Examples
;;   ```scheme
;;   (agentic-ai-lab-artifact-scope-subset? '(session) '(session project))
;;   ;; => #t
;;   ```
(def (agentic-ai-lab-artifact-scope-subset? actor-scope artifact-scope)
  (andmap (lambda (scope-id)
            (agentic-ai-lab-artifact-list-has? artifact-scope scope-id))
          actor-scope))

;; : (-> PooDurableArtifact Datum Boolean)
(def (agentic-ai-lab-durable-artifact-explicit-grant? artifact actor)
  (let ((artifact-id (.ref artifact 'artifact-id))
        (actor-ref (and (object? actor)
                        (.slot? actor 'actor-ref)
                        (.ref actor 'actor-ref))))
    (or (and (object? actor)
             (.slot? actor 'artifact-grants)
             (agentic-ai-lab-artifact-list-has? (.ref actor 'artifact-grants)
                                          artifact-id))
        (and actor-ref
             (agentic-ai-lab-artifact-list-has? (.ref artifact 'explicit-grants)
                                          actor-ref)))))

;; : (-> PooDurableArtifact Datum Boolean)
(def (agentic-ai-lab-durable-artifact-visible? artifact actor)
  (let ((actor-scope (if (and (object? actor) (.slot? actor 'scope))
                       (.ref actor 'scope)
                       '()))
        (artifact-scope (.ref artifact 'artifact-scope)))
    (or (agentic-ai-lab-artifact-scope-subset? actor-scope artifact-scope)
        (agentic-ai-lab-durable-artifact-explicit-grant? artifact actor))))

;; : (-> Symbol Symbol Boolean)
(def (agentic-ai-lab-durable-artifact-lifecycle-transition-allowed? from-state
                                                              to-state)
  (agentic-ai-lab-artifact-list-has?
   +agentic-ai-lab-durable-artifact-lifecycle-edges+
   (cons from-state to-state)))

;; : (-> PooDurableArtifact Symbol PooDurableArtifact)
(def (agentic-ai-lab-durable-artifact-transition artifact to-state)
  (let (from-state (.ref artifact 'lifecycle-state))
    (if (agentic-ai-lab-durable-artifact-lifecycle-transition-allowed?
         from-state
         to-state)
      (agentic-ai-lab-durable-artifact/direct
       (.ref artifact 'artifact-id)
       (.ref artifact 'artifact-kind)
       (.ref artifact 'artifact-scope)
       (.ref artifact 'storage-class)
       to-state
       (.ref artifact 'producer-ref)
       (.ref artifact 'owner-ref)
       (.ref artifact 'sandbox-scope)
       (.ref artifact 'checksum-policy)
       (.ref artifact 'analysis-policy)
       (.ref artifact 'index-policy)
       (.ref artifact 'call-policy)
       (.ref artifact 'publish-policy)
       (.ref artifact 'retention-policy)
       (.ref artifact 'explicit-grants))
      (error "durable artifact lifecycle transition is not allowed"
             from-state
             to-state))))
