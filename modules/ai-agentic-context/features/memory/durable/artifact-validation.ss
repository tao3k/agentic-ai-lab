;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: durable artifact validation and policy receipt projection.
;;; Invariant: validation compares already-built POO objects and emits bounded
;;; policy receipts; it does not create runtime manifests or perform handoff.

(import (only-in :clan/poo/object .ref .slot? object?)
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/artifact-profile
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/artifact-object)

(export agentic-ai-lab-durable-artifact-validate
        agentic-ai-lab-durable-artifact-policy-receipt?
        agentic-ai-lab-durable-artifact-policy-receipt-valid?
        agentic-ai-lab-durable-artifact-policy-receipt->alist)

(def +agentic-ai-lab-durable-artifact-policy-receipt-kind+
  'agentic-ai-lab.durable.artifact.policy-receipt)

(def +agentic-ai-lab-durable-artifact-policy-receipt-schema+
  'agentic-ai-lab.durable.artifact.policy-receipt.v1)

(def +agentic-ai-lab-durable-artifact-policy-receipt-fields+
  '(artifact-policy-receipt-kind
    artifact-policy-receipt-schema
    artifact-id
    profile-name
    database-name
    valid?
    scope-contained?
    storage-supported?
    analysis-supported?
    publish-gated?
    retention-supported?
    lifecycle-state-valid?
    database-storage-supported?
    database-capability-satisfied?
    diagnostics
    runtime-executed
    source))

(defstruct agentic-ai-lab-durable-artifact-policy-receipt-record
  (artifact-policy-receipt-kind
   artifact-policy-receipt-schema
   artifact-id
   profile-name
   database-name
   valid?
   scope-contained?
   storage-supported?
   analysis-supported?
   publish-gated?
   retention-supported?
   lifecycle-state-valid?
   database-storage-supported?
   database-capability-satisfied?
   diagnostics
   runtime-executed
   source)
  transparent: #t)

;; : (-> PooDurableArtifactPolicyReceipt Symbol Datum)
(def (agentic-ai-lab-durable-artifact-policy-receipt-ref receipt field)
  (if (agentic-ai-lab-durable-artifact-policy-receipt-record? receipt)
    (case field
      ((artifact-policy-receipt-kind)
       (agentic-ai-lab-durable-artifact-policy-receipt-record-artifact-policy-receipt-kind receipt))
      ((artifact-policy-receipt-schema)
       (agentic-ai-lab-durable-artifact-policy-receipt-record-artifact-policy-receipt-schema receipt))
      ((artifact-id)
       (agentic-ai-lab-durable-artifact-policy-receipt-record-artifact-id receipt))
      ((profile-name)
       (agentic-ai-lab-durable-artifact-policy-receipt-record-profile-name receipt))
      ((database-name)
       (agentic-ai-lab-durable-artifact-policy-receipt-record-database-name receipt))
      ((valid?)
       (agentic-ai-lab-durable-artifact-policy-receipt-record-valid? receipt))
      ((scope-contained?)
       (agentic-ai-lab-durable-artifact-policy-receipt-record-scope-contained? receipt))
      ((storage-supported?)
       (agentic-ai-lab-durable-artifact-policy-receipt-record-storage-supported? receipt))
      ((analysis-supported?)
       (agentic-ai-lab-durable-artifact-policy-receipt-record-analysis-supported? receipt))
      ((publish-gated?)
       (agentic-ai-lab-durable-artifact-policy-receipt-record-publish-gated? receipt))
      ((retention-supported?)
       (agentic-ai-lab-durable-artifact-policy-receipt-record-retention-supported? receipt))
      ((lifecycle-state-valid?)
       (agentic-ai-lab-durable-artifact-policy-receipt-record-lifecycle-state-valid? receipt))
      ((database-storage-supported?)
       (agentic-ai-lab-durable-artifact-policy-receipt-record-database-storage-supported? receipt))
      ((database-capability-satisfied?)
       (agentic-ai-lab-durable-artifact-policy-receipt-record-database-capability-satisfied? receipt))
      ((diagnostics)
       (agentic-ai-lab-durable-artifact-policy-receipt-record-diagnostics receipt))
      ((runtime-executed)
       (agentic-ai-lab-durable-artifact-policy-receipt-record-runtime-executed receipt))
      ((source)
       (agentic-ai-lab-durable-artifact-policy-receipt-record-source receipt))
      (else #f))
    (.ref receipt field)))

(def +agentic-ai-lab-durable-artifact-lifecycle-states+
  '(created
    stored
    indexed
    analyzed
    callable
    publish-approved
    published
    retained
    expired
    archived
    revoked))

;; : (-> Datum [Datum])
(def (agentic-ai-lab-artifact-value->list value)
  (cond
   ((null? value) '())
   ((pair? value) value)
   (else (list value))))

;; : (-> Datum Datum Boolean)
(def (agentic-ai-lab-artifact-values-contained? required allowed)
  (agentic-ai-lab-artifact-scope-subset?
   (agentic-ai-lab-artifact-value->list required)
   (agentic-ai-lab-artifact-value->list allowed)))

;; : (-> [Symbol] Boolean Symbol [Symbol])
(def (agentic-ai-lab-artifact-diagnostic diagnostics ok? code)
  (if ok?
    diagnostics
    (cons code diagnostics)))

;; : (-> Symbol Boolean)
(def (agentic-ai-lab-durable-artifact-lifecycle-state-valid? state)
  (agentic-ai-lab-artifact-list-has?
   +agentic-ai-lab-durable-artifact-lifecycle-states+
   state))

;; : (-> Symbol Symbol Symbol Boolean Boolean Boolean Boolean Boolean Boolean Boolean Boolean Boolean [Symbol] PooDurableArtifactPolicyReceipt)
(def (agentic-ai-lab-durable-artifact-policy-receipt/direct
      artifact-id-value
      profile-name-value
      database-name-value
      valid-value
      scope-contained-value
      storage-supported-value
      analysis-supported-value
      publish-gated-value
      retention-supported-value
      lifecycle-state-valid-value
      database-storage-supported-value
      database-capability-satisfied-value
      diagnostics-value)
  (make-agentic-ai-lab-durable-artifact-policy-receipt-record
   +agentic-ai-lab-durable-artifact-policy-receipt-kind+
   +agentic-ai-lab-durable-artifact-policy-receipt-schema+
   artifact-id-value
   profile-name-value
   database-name-value
   valid-value
   scope-contained-value
   storage-supported-value
   analysis-supported-value
   publish-gated-value
   retention-supported-value
   lifecycle-state-valid-value
   database-storage-supported-value
   database-capability-satisfied-value
   diagnostics-value
   #f
   'agentic-ai-lab.durable.artifact.policy))

;;; Boundary: artifact validation is the durable policy gate between POO
;;; profile objects and downstream artifact/database runtime handoff.
;; : (-> PooDurableArtifact PooArtifactProfile PooArtifactDatabaseProfile PooDurableArtifactPolicyReceipt)
(def (agentic-ai-lab-durable-artifact-validate artifact profile database-profile)
  (let* ((artifact-id-value (.ref artifact 'artifact-id))
         (profile-name-value (.ref profile 'name))
         (database-name-value (.ref database-profile 'name))
         (scope-contained-value
          (agentic-ai-lab-artifact-values-contained?
           (.ref artifact 'artifact-scope)
           (.ref profile 'scope)))
         (storage-supported-value
          (agentic-ai-lab-artifact-values-contained?
           (.ref artifact 'storage-class)
           (.ref profile 'storage)))
         (analysis-supported-value
          (agentic-ai-lab-artifact-values-contained?
           (.ref artifact 'analysis-policy)
           (.ref profile 'analysis)))
         (publish-gated-value
          (and (agentic-ai-lab-artifact-values-contained?
                (.ref artifact 'publish-policy)
                (.ref profile 'publish))
               (agentic-ai-lab-artifact-publish-gated? profile)
               #t))
         (retention-supported-value
          (agentic-ai-lab-artifact-values-contained?
           (.ref artifact 'retention-policy)
           (.ref profile 'retention)))
         (lifecycle-state-valid-value
          (agentic-ai-lab-durable-artifact-lifecycle-state-valid?
           (.ref artifact 'lifecycle-state)))
         (database-storage-supported-value
          (agentic-ai-lab-artifact-values-contained?
           (.ref artifact 'storage-class)
           (.ref database-profile 'storage)))
         (database-capability-satisfied-value
          (agentic-ai-lab-artifact-values-contained?
           (.ref artifact 'index-policy)
           (.ref database-profile 'capabilities)))
         (diagnostics
          (reverse
           (agentic-ai-lab-artifact-diagnostic
            (agentic-ai-lab-artifact-diagnostic
             (agentic-ai-lab-artifact-diagnostic
              (agentic-ai-lab-artifact-diagnostic
               (agentic-ai-lab-artifact-diagnostic
                (agentic-ai-lab-artifact-diagnostic
                 (agentic-ai-lab-artifact-diagnostic
                  (agentic-ai-lab-artifact-diagnostic
                   '()
                   scope-contained-value
                   'artifact-scope-not-contained-by-profile)
                  storage-supported-value
                  'artifact-storage-not-supported-by-profile)
                 analysis-supported-value
                 'artifact-analysis-not-supported-by-profile)
                publish-gated-value
                'artifact-publish-policy-not-gated)
               retention-supported-value
               'artifact-retention-not-supported-by-profile)
              lifecycle-state-valid-value
              'artifact-lifecycle-state-invalid)
             database-storage-supported-value
             'artifact-storage-not-supported-by-database)
            database-capability-satisfied-value
            'artifact-database-capability-not-satisfied)))
         (valid-value (and scope-contained-value
                           storage-supported-value
                           analysis-supported-value
                           publish-gated-value
                           retention-supported-value
                           lifecycle-state-valid-value
                           database-storage-supported-value
                           database-capability-satisfied-value
                           #t)))
    (agentic-ai-lab-durable-artifact-policy-receipt/direct
     artifact-id-value
     profile-name-value
     database-name-value
     valid-value
     scope-contained-value
     storage-supported-value
     analysis-supported-value
     publish-gated-value
     retention-supported-value
     lifecycle-state-valid-value
     database-storage-supported-value
     database-capability-satisfied-value
     diagnostics)))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-durable-artifact-policy-receipt? receipt)
  (or (agentic-ai-lab-durable-artifact-policy-receipt-record? receipt)
      (and (object? receipt)
           (.slot? receipt 'artifact-policy-receipt-kind)
           (eq? (.ref receipt 'artifact-policy-receipt-kind)
                +agentic-ai-lab-durable-artifact-policy-receipt-kind+))))

;; : (-> PooDurableArtifactPolicyReceipt Boolean)
(def (agentic-ai-lab-durable-artifact-policy-receipt-valid? receipt)
  (agentic-ai-lab-durable-artifact-policy-receipt-ref receipt 'valid?))

;; : (forall (v) (-> v [(Pair Symbol Object)]))
;; : (-> PooDurableArtifactPolicyReceipt Alist)
(def (agentic-ai-lab-durable-artifact-policy-receipt->alist receipt)
  (map (lambda (field)
         (cons field
               (agentic-ai-lab-durable-artifact-policy-receipt-ref receipt field)))
       +agentic-ai-lab-durable-artifact-policy-receipt-fields+))
