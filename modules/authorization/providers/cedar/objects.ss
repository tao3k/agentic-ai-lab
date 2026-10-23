;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO-native Cedar Provider policy, authority, and handoff values.
;;; Invariant: construction and projection perform no authorization or runtime IO.
(import (only-in :clan/poo/object .o .ref .alist object?)
        (only-in :std/encoding/hex hex-encode)
        :yuanxu/object-family/syntax)

(export agentic-ai-lab-cedar-policy agentic-ai-lab-cedar-policy?
        agentic-ai-lab-cedar-schema agentic-ai-lab-cedar-entities
        agentic-ai-lab-cedar-proof-binding agentic-ai-lab-cedar-proof-binding?
        agentic-ai-lab-cedar-authority-context agentic-ai-lab-cedar-authority-context?
        agentic-ai-lab-cedar-runtime-capability agentic-ai-lab-cedar-runtime-capability?
        agentic-ai-lab-cedar-authority-snapshot agentic-ai-lab-cedar-authority-snapshot?
        agentic-ai-lab-cedar-runtime-handoff agentic-ai-lab-cedar-runtime-handoff?
        agentic-ai-lab-cedar-authorization-request agentic-ai-lab-cedar-authorization-request?
        agentic-ai-lab-cedar-authority-snapshot->runtime
        agentic-ai-lab-cedar-authorization-request->runtime)

;;; Boundary: this constructor centralizes immutable family metadata without
;;; introducing a Cedar-specific public macro or runtime registry.
;; : (-> Symbol POOObject)
(def (cedar-family-prototype kind-value)
  (.o (kind kind-value)
      (schema 'agentic-ai-lab.cedar-values.v1)
      (runtime-owner 'native.cedar-authority)
      (runtime-executed? #f)))

(def policy-kind 'cedar-policy)
(def Policy. (cedar-family-prototype policy-kind))
(defpoo-object-family policy-kind agentic-ai-lab-cedar-policy? (accessors) (projections))
(def schema-kind 'cedar-schema)
(def Schema. (cedar-family-prototype schema-kind))
(defpoo-object-family schema-kind cedar-schema? (accessors) (projections))
(def entities-kind 'cedar-entities)
(def Entities. (cedar-family-prototype entities-kind))
(defpoo-object-family entities-kind cedar-entities? (accessors) (projections))
(def proof-kind 'cedar-proof-binding)
(def ProofBinding. (cedar-family-prototype proof-kind))
(defpoo-object-family proof-kind agentic-ai-lab-cedar-proof-binding? (accessors) (projections))
(def context-kind 'cedar-authority-context)
(def AuthorityContext. (cedar-family-prototype context-kind))
(defpoo-object-family context-kind agentic-ai-lab-cedar-authority-context? (accessors) (projections))
(def capability-kind 'cedar-runtime-capability)
(def Capability. (cedar-family-prototype capability-kind))
(defpoo-object-family capability-kind agentic-ai-lab-cedar-runtime-capability? (accessors) (projections))
(def snapshot-kind 'cedar-authority-snapshot)
(def Snapshot. (cedar-family-prototype snapshot-kind))
(defpoo-object-family snapshot-kind agentic-ai-lab-cedar-authority-snapshot? (accessors) (projections))
(def handoff-kind 'cedar-runtime-handoff)
(def Handoff. (cedar-family-prototype handoff-kind))
(defpoo-object-family handoff-kind agentic-ai-lab-cedar-runtime-handoff? (accessors) (projections))
(def request-kind 'cedar-authorization-request)
(def Request. (cedar-family-prototype request-kind))
(defpoo-object-family request-kind agentic-ai-lab-cedar-authorization-request? (accessors) (projections))

;; : (-> String Boolean Object Unit)
(def (require-value message accepted? value)
  (unless accepted? (error message value)))

;; : (-> Object Boolean)
(def (text? value) (and (string? value) (> (string-length value) 0)))
;; : (-> Object Boolean)
(def (natural? value) (and (exact-integer? value) (<= 0 value 9223372036854775807)))
;; : (-> Object Boolean)
(def (positive? value) (and (natural? value) (> value 0)))
;; : (forall (a) (-> (-> a Boolean) (List a) Boolean))
;; : (-> Procedure List Boolean)
(def (every? predicate values)
  (and (list? values)
       (let loop ((rest values))
         (or (null? rest) (and (predicate (car rest)) (loop (cdr rest)))))))

;; : (-> Object Boolean)
(def (digest? value)
  (and (string? value) (= (string-length value) 71)
       (string=? (substring value 0 7) "sha256:")
       (let loop ((index 7))
         (or (= index 71)
             (let (character (string-ref value index))
               (and (or (char<=? #\0 character #\9) (char<=? #\a character #\f))
                    (loop (+ index 1))))))))

;; : (-> String String CedarPolicy)
(def (agentic-ai-lab-cedar-policy identity-value source-value)
  (require-value "Cedar policy identity/source must be nonempty text"
                 (and (text? identity-value) (text? source-value)) identity-value)
  (.o (:: @ Policy.) identity: identity-value source: source-value))

;; These are official Cedar JSON documents, not a POO alist/schema DSL. The
;; native boundary parses them once with duplicate-key and schema validation.
;; : (-> String CedarSchema)
(def (agentic-ai-lab-cedar-schema document-value)
  (require-value "Cedar schema must be a JSON document" (text? document-value) document-value)
  (.o (:: @ Schema.) document: document-value))

;; : (-> String CedarEntities)
(def (agentic-ai-lab-cedar-entities document-value)
  (require-value "Cedar entities must be a JSON document" (text? document-value) document-value)
  (.o (:: @ Entities.) document: document-value))

;; : (-> String Digest Digest Digest Digest (List String) CedarProofBinding)
(def (agentic-ai-lab-cedar-proof-binding composition-value profile-identities-value
                                    origin-value profile-value independent-value
                                    capability-value governance-value
                                    subject-value names-value)
  (require-value "composition identity must be text" (text? composition-value) composition-value)
  (require-value "proof binding requires concrete Profile identities"
                 (and (pair? profile-identities-value)
                      (every? text? profile-identities-value))
                 profile-identities-value)
  (require-value "proof binding requires canonical content identities"
                 (every? digest?
                         (list origin-value profile-value independent-value
                               capability-value governance-value subject-value))
                 composition-value)
  (require-value "proof binding requires named certifications"
                 (and (pair? names-value) (every? text? names-value)) names-value)
  (.o (:: @ ProofBinding.) composition: composition-value
      profile-identities: profile-identities-value
      profile-origin: origin-value
      profile-bundle: profile-value independent-bundle: independent-value
      capability-contract: capability-value
      governance-assessment: governance-value
      subject-snapshot: subject-value
      certification-names: names-value))

;; : (-> String String Natural Digest Natural Natural Natural CedarAuthorityContext)
(def (agentic-ai-lab-cedar-authority-context authority-value context-value generation-value
                                       bundle-value epoch-value policy-value revocation-value)
  (require-value "authority and runtime context must be text"
                 (and (text? authority-value) (text? context-value)) authority-value)
  (require-value "runtime generation and policy revision must be positive"
                 (and (positive? generation-value) (positive? policy-value)) generation-value)
  (require-value "bundle/revocation epochs must be natural integers"
                 (and (natural? epoch-value) (natural? revocation-value)) epoch-value)
  (require-value "runtime bundle must be a content identity" (digest? bundle-value) bundle-value)
  (.o (:: @ AuthorityContext.) authority: authority-value runtime-context: context-value
      generation: generation-value runtime-bundle: bundle-value bundle-epoch: epoch-value
      policy-revision: policy-value revocation-epoch: revocation-value))

;; : (-> String PositiveInteger [Boolean] CedarRuntimeCapability)
(def (agentic-ai-lab-cedar-runtime-capability action-value event-value
                                        source-admission-required?:
                                        (required-value #f))
  (require-value "Cedar action must be text" (text? action-value) action-value)
  (require-value "runtime event kind must be a positive uint32"
                 (and (positive? event-value) (<= event-value 4294967295)) event-value)
  (require-value "source admission requirement must be Boolean"
                 (boolean? required-value) required-value)
  (.o (:: @ Capability.) action: action-value event-kind: event-value
      source-admission-required?: required-value))

;; : (-> CedarAuthorityContext CedarProofBinding (List CedarPolicy) CedarSchema CedarEntities (List CedarRuntimeCapability) CedarAuthoritySnapshot)
(def (agentic-ai-lab-cedar-authority-snapshot context-value proof-value policy-values
                                        schema-value entities-value capability-values)
  (require-value "authority snapshot requires AuthorityContext"
                 (agentic-ai-lab-cedar-authority-context? context-value) context-value)
  (require-value "authority snapshot requires ProofBinding"
                 (agentic-ai-lab-cedar-proof-binding? proof-value) proof-value)
  (require-value "authority snapshot requires POO Cedar policies"
                 (every? agentic-ai-lab-cedar-policy? policy-values) policy-values)
  (require-value "authority snapshot requires Cedar schema/entities documents"
                 (and (cedar-schema? schema-value) (cedar-entities? entities-value)) schema-value)
  (require-value "authority snapshot requires POO runtime capabilities"
                 (and (pair? capability-values) (every? agentic-ai-lab-cedar-runtime-capability? capability-values)) capability-values)
  (.o (:: @ Snapshot.) context: context-value proof-binding: proof-value policies: policy-values
      cedar-schema: schema-value entities: entities-value capabilities: capability-values))

;; : (-> PositiveInteger U8Vector Digest Digest Digest Digest CedarRuntimeHandoff)
(def (agentic-ai-lab-cedar-runtime-handoff sequence-value payload-value semantic-value
                                     before-value after-value observation-value)
  (require-value "handoff sequence must be positive" (positive? sequence-value) sequence-value)
  (require-value "handoff payload must be at most 64 KiB of bytes"
                 (and (u8vector? payload-value) (<= (u8vector-length payload-value) 65536)) sequence-value)
  (require-value "handoff roots must be canonical content identities"
                 (every? digest? (list semantic-value before-value after-value observation-value)) sequence-value)
  ;; Freeze the caller's mutable byte vector as an immutable textual projection.
  (.o (:: @ Handoff.) sequence: sequence-value payload-hex: (hex-encode payload-value)
      semantic-root: semantic-value before-execution-root: before-value
      after-execution-root: after-value observation-digest: observation-value))

;; : (-> String String String POOObject Digest CedarRuntimeHandoff CedarAuthorizationRequest)
(def (agentic-ai-lab-cedar-authorization-request principal-value action-value resource-value
                                           context-value intent-value handoff-value)
  (require-value "Cedar subject identifiers must be text"
                 (every? text? (list principal-value action-value resource-value)) principal-value)
  (require-value "Cedar context must be a POO object" (object? context-value) context-value)
  (require-value "intent must be a canonical content identity" (digest? intent-value) intent-value)
  (require-value "authorization requires a runtime handoff value"
                 (agentic-ai-lab-cedar-runtime-handoff? handoff-value) handoff-value)
  (.o (:: @ Request.) principal: principal-value action: action-value resource: resource-value
      context: context-value intent: intent-value handoff: handoff-value))

;; All hash/alist materialization is confined to the explicit runtime boundary.
;; : (forall (a) (-> (Pair String a) ... HashTable))
;; : (-> Pair ... HashTable)
(def (runtime-record . fields)
  (let (result (make-hash-table))
    (for-each (lambda (field) (hash-put! result (car field) (cdr field))) fields)
    result))

;; : (-> Object JsonValue)
(def (context->runtime value)
  (cond
   ((object? value)
    (let (result (make-hash-table))
      (for-each
       (lambda (field)
         (require-value "Cedar context keys must be symbols" (symbol? (car field)) (car field))
         (hash-put! result (symbol->string (car field)) (context->runtime (cdr field))))
       (.alist value))
      result))
   ((or (string? value) (boolean? value) (exact-integer? value)) value)
   ((list? value) (list->vector (map context->runtime value)))
   ((vector? value) (list->vector (map context->runtime (vector->list value))))
   (else (error "Cedar context contains an unsupported value" value))))

;; : (-> CedarRuntimeHandoff HashTable)
(def (handoff->runtime value)
  (runtime-record
   (cons "sequence" (.ref value 'sequence)) (cons "payload_hex" (.ref value 'payload-hex))
   (cons "semantic_root" (.ref value 'semantic-root))
   (cons "before_execution_root" (.ref value 'before-execution-root))
   (cons "after_execution_root" (.ref value 'after-execution-root))
   (cons "observation_digest" (.ref value 'observation-digest))))

;; : (-> CedarAuthoritySnapshot HashTable)
(def (agentic-ai-lab-cedar-authority-snapshot->runtime value)
  (require-value "runtime projection requires an authority snapshot" (agentic-ai-lab-cedar-authority-snapshot? value) value)
  (let ((context (.ref value 'context)) (proof (.ref value 'proof-binding)))
    (runtime-record
     (cons "schema_id" "agentic-ai-lab.cedar-authority-snapshot.v1")
     (cons "producer" "agentic-ai-lab.scheme-control")
     (cons "source" "modules/authorization/providers/cedar/objects.ss")
     (cons "object_kind" "cedar-authority-snapshot")
     (cons "provenance" (runtime-record
                          (cons "composition_identity" (.ref proof 'composition))
                          (cons "profile_identities"
                                (list->vector (.ref proof 'profile-identities)))
                          (cons "profile_origin_digest" (.ref proof 'profile-origin))
                          (cons "governance_assessment_digest"
                                (.ref proof 'governance-assessment))
                          (cons "subject_snapshot_digest"
                                (.ref proof 'subject-snapshot))
                          (cons "governance_admitted" #t)
                          (cons "certification_names" (list->vector (.ref proof 'certification-names)))))
     (cons "authority_id" (.ref context 'authority)) (cons "runtime_context_id" (.ref context 'runtime-context))
     (cons "runtime_generation" (.ref context 'generation)) (cons "bundle_epoch" (.ref context 'bundle-epoch))
     (cons "runtime_bundle_digest" (.ref context 'runtime-bundle))
     (cons "profile_bundle_digest" (.ref proof 'profile-bundle))
     (cons "independent_bundle_digest" (.ref proof 'independent-bundle))
     (cons "capability_contract_digest" (.ref proof 'capability-contract))
     (cons "policy_revision" (.ref context 'policy-revision)) (cons "revocation_epoch" (.ref context 'revocation-epoch))
     (cons "schema_json" (.ref (.ref value 'cedar-schema) 'document))
     (cons "entities_json" (.ref (.ref value 'entities) 'document))
     (cons "policies" (list->vector
                       (map (lambda (policy) (runtime-record (cons "identity" (.ref policy 'identity)) (cons "source" (.ref policy 'source))))
                            (.ref value 'policies))))
     (cons "capabilities" (list->vector
                           (map (lambda (capability)
                                  (runtime-record
                                   (cons "action" (.ref capability 'action))
                                   (cons "event_kind" (.ref capability 'event-kind))
                                   (cons "source_admission_required"
                                         (.ref capability 'source-admission-required?))))
                                (.ref value 'capabilities)))))))

;; : (-> CedarAuthorizationRequest HashTable)
(def (agentic-ai-lab-cedar-authorization-request->runtime value)
  (require-value "runtime projection requires a Cedar request" (agentic-ai-lab-cedar-authorization-request? value) value)
  (let (context (.ref value 'context))
    (require-value "context.agentic_ai_lab is reserved to the authority"
                   (not (assq 'agentic_ai_lab (.alist context))) context)
    (runtime-record
     (cons "schema_id" "agentic-ai-lab.cedar-authorization-request.v1")
     (cons "principal" (.ref value 'principal)) (cons "action" (.ref value 'action))
     (cons "resource" (.ref value 'resource)) (cons "context" (context->runtime context))
     (cons "intent_digest" (.ref value 'intent)) (cons "handoff" (handoff->runtime (.ref value 'handoff))))))
