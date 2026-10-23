;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: owns canonical organization-bundle values, normalization, and validation.
;;; Invariant: normalized content identity is stable across equivalent input ordering.
(export #t)

(import (only-in :clan/poo/object .o .ref object?)
        (only-in :std/crypto/digest sha256)
        (only-in :std/list/list delete-duplicates/hash)
        (only-in :std/encoding/hex hex-encode)
        "funcs.ss")

(def +agentic-ai-lab-organization-bundle-schema+
  'agentic-ai-lab.organization-bundle.draft.3)
(def +agentic-ai-lab-organization-facet-schema+
  'agentic-ai-lab.organization-facet.draft.3)

(def +agentic-ai-lab-organization-bundle-digest-algorithm+ 'sha256)

(def (agentic-ai-lab-organization-principal principal-id-value)
  (.o (kind 'principal) (id principal-id-value)))

(def (agentic-ai-lab-organization-role role-id-value)
  (.o (kind 'role) (id role-id-value)))

(def (agentic-ai-lab-organization-agent agent-id-value principal-id-value role-id-value
                                  parent-id-value authorities-value
                                  context-visible-value)
  (.o (kind 'agent)
      (id agent-id-value)
      (principal-id principal-id-value)
      (role-id role-id-value)
      (parent-id parent-id-value)
      (authorities authorities-value)
      (context-visible context-visible-value)))

(def (agentic-ai-lab-organization-capability capability-id-value delegable-value?)
  (.o (kind 'capability)
      (id capability-id-value)
      (delegable? delegable-value?)))

(def (agentic-ai-lab-organization-delegation parent-id-value child-id-value
                                       capability-id-value)
  (.o (kind 'delegation)
      (id (list parent-id-value child-id-value capability-id-value))
      (parent-id parent-id-value)
      (child-id child-id-value)
      (capability-id capability-id-value)))

(def (agentic-ai-lab-organization-context-projection agent-id-value visible-value)
  (.o (kind 'context-projection)
      (id agent-id-value)
      (agent-id agent-id-value)
      (visible visible-value)))

(def (agentic-ai-lab-organization-tool-effect effect-id-value capability-id-value
                                        effect-kind-value)
  (.o (kind 'tool-effect)
      (id effect-id-value)
      (capability-id capability-id-value)
      (effect-kind effect-kind-value)))

(def (agentic-ai-lab-organization-protocol-transition transition-id-value
                                                participants-value
                                                capability-id-value)
  (.o (kind 'protocol-transition)
      (id transition-id-value)
      (participants participants-value)
      (capability-id capability-id-value)))

(def (agentic-ai-lab-organization-evidence-obligation obligation-id-value
                                                subject-id-value
                                                target-kind-value
                                                target-id-value)
  (.o (kind 'evidence-obligation)
      (id obligation-id-value)
      (subject-id subject-id-value)
      (target-kind target-kind-value)
      (target-id target-id-value)))

(def (agentic-ai-lab-organization-facet facet-name-value entities-value relations-value
                                  constraints-value)
  (.o (kind (case facet-name-value
              ((organization) 'agentic-ai-lab.organization-facet.organization)
              ((authority) 'agentic-ai-lab.organization-facet.authority)
              ((context) 'agentic-ai-lab.organization-facet.context)
              ((protocol) 'agentic-ai-lab.organization-facet.protocol)
              ((evidence) 'agentic-ai-lab.organization-facet.evidence)
              (else (error "unknown organization facet" facet-name-value))))
      (schema +agentic-ai-lab-organization-facet-schema+)
      (facet-name facet-name-value)
      (entities entities-value)
      (relations relations-value)
      (constraints constraints-value)))

(def (agentic-ai-lab-organization-organization-facet entities . rest)
  (agentic-ai-lab-organization-facet 'organization entities
                               (if (pair? rest) (car rest) '())
                               (if (and (pair? rest) (pair? (cdr rest)))
                                 (cadr rest) '())))
(def (agentic-ai-lab-organization-authority-facet entities relations . constraints)
  (agentic-ai-lab-organization-facet 'authority entities relations
                               (if (pair? constraints) (car constraints) '())))
(def (agentic-ai-lab-organization-context-facet entities . constraints)
  (agentic-ai-lab-organization-facet 'context entities '()
                               (if (pair? constraints) (car constraints) '())))
(def (agentic-ai-lab-organization-protocol-facet entities relations . constraints)
  (agentic-ai-lab-organization-facet 'protocol entities relations
                               (if (pair? constraints) (car constraints) '())))
(def (agentic-ai-lab-organization-evidence-facet entities relations . constraints)
  (agentic-ai-lab-organization-facet 'evidence entities relations
                               (if (pair? constraints) (car constraints) '())))
(def (agentic-ai-lab-organization-empty-organization-facet)
  (agentic-ai-lab-organization-organization-facet '()))
(def (agentic-ai-lab-organization-empty-authority-facet)
  (agentic-ai-lab-organization-authority-facet '() '()))
(def (agentic-ai-lab-organization-empty-context-facet)
  (agentic-ai-lab-organization-context-facet '()))
(def (agentic-ai-lab-organization-empty-protocol-facet)
  (agentic-ai-lab-organization-protocol-facet '() '()))
(def (agentic-ai-lab-organization-empty-evidence-facet)
  (agentic-ai-lab-organization-evidence-facet '() '()))

(def (agentic-ai-lab-organization-bundle epoch-value organization-value authority-value
                                   context-value protocol-value evidence-value)
  (.o (kind +agentic-ai-lab-organization-bundle-schema+)
      (epoch epoch-value)
      (organization organization-value)
      (authority authority-value)
      (context context-value)
      (protocol protocol-value)
      (evidence evidence-value)))

(def (agentic-ai-lab-organization-object? value expected-kind)
  (and (object? value)
       (with-catch
        (lambda (_failure) #f)
        (lambda () (eq? (.ref value 'kind) expected-kind)))))

(def (agentic-ai-lab-organization-bundle? value)
  (agentic-ai-lab-organization-object? value +agentic-ai-lab-organization-bundle-schema+))

(def (agentic-ai-lab-organization-object-id value)
  (.ref value 'id))

(def (semantic-id-string value)
  (cond
   ((symbol? value) (symbol->string value))
   ((string? value) value)
   (else
    (let (port (open-output-string))
      (write value port)
      (get-output-string port)))))

(def (semantic-object<? left right)
  (string<? (semantic-id-string (agentic-ai-lab-organization-object-id left))
            (semantic-id-string (agentic-ai-lab-organization-object-id right))))

(def (semantic-sort objects)
  (list-sort semantic-object<? (append objects '())))

(def (semantic-symbol-sort values)
  (list-sort (lambda (left right)
               (string<? (semantic-id-string left) (semantic-id-string right)))
             (append values '())))

(def (principal->canonical value)
  (list 'principal (agentic-ai-lab-organization-object-id value)))

(def (role->canonical value)
  (list 'role (agentic-ai-lab-organization-object-id value)))

(def (agent->canonical value)
  (list 'agent
        (agentic-ai-lab-organization-object-id value)
        (list 'principal (.ref value 'principal-id))
        (list 'role (.ref value 'role-id))
        (list 'parent (.ref value 'parent-id))
        (cons 'authorities (semantic-symbol-sort (.ref value 'authorities)))
        (cons 'context-visible
              (semantic-symbol-sort (.ref value 'context-visible)))))

(def (capability->canonical value)
  (list 'capability
        (agentic-ai-lab-organization-object-id value)
        (list 'delegable? (.ref value 'delegable?))))

(def (delegation->canonical value)
  (list 'delegation
        (list 'parent (.ref value 'parent-id))
        (list 'child (.ref value 'child-id))
        (list 'capability (.ref value 'capability-id))))

(def (context-projection->canonical value)
  (list 'context-projection
        (list 'agent (.ref value 'agent-id))
        (cons 'visible (semantic-symbol-sort (.ref value 'visible)))))

(def (tool-effect->canonical value)
  (list 'tool-effect
        (agentic-ai-lab-organization-object-id value)
        (list 'capability (.ref value 'capability-id))
        (list 'effect-kind (.ref value 'effect-kind))))
(def (protocol-transition->canonical value)
  (list 'protocol-transition (agentic-ai-lab-organization-object-id value)
        (cons 'participants (semantic-symbol-sort (.ref value 'participants)))
        (list 'capability (.ref value 'capability-id))))
(def (evidence-obligation->canonical value)
  (list 'evidence-obligation (agentic-ai-lab-organization-object-id value)
        (list 'subject (.ref value 'subject-id))
        (list 'target-kind (.ref value 'target-kind))
        (list 'target (.ref value 'target-id))))

(def (semantic-kind=? value kind)
  (and (object? value)
       (with-catch (lambda (_failure) #f)
                   (lambda () (eq? (.ref value 'kind) kind)))))
(def (facet-entities facet kind)
  (filter (lambda (value) (semantic-kind=? value kind))
          (.ref facet 'entities)))
(def (facet-relations facet kind)
  (filter (lambda (value) (semantic-kind=? value kind))
          (.ref facet 'relations)))
(def (facet->canonical facet)
  (list (.ref facet 'facet-name)
        (list 'schema (.ref facet 'schema))
        (cons 'entities
              (map (lambda (value)
                     (case (.ref value 'kind)
                       ((principal) (principal->canonical value))
                       ((role) (role->canonical value))
                       ((agent) (agent->canonical value))
                       ((capability) (capability->canonical value))
                       ((context-projection) (context-projection->canonical value))
                       ((tool-effect) (tool-effect->canonical value))
                       ((protocol-transition) (protocol-transition->canonical value))
                       ((evidence-obligation) (evidence-obligation->canonical value))
                       (else (error "unsupported facet entity" value))))
                   (semantic-sort (.ref facet 'entities))))
        (cons 'relations
              (map (lambda (value)
                     (case (.ref value 'kind)
                       ((delegation) (delegation->canonical value))
                       (else (error "unsupported facet relation" value))))
                   (semantic-sort (.ref facet 'relations))))
        (cons 'constraints (semantic-symbol-sort (.ref facet 'constraints)))))

(def (agentic-ai-lab-organization-bundle-normalize/object bundle)
  (unless (agentic-ai-lab-organization-bundle? bundle)
    (error "expected POO organization Bundle" bundle))
  (list +agentic-ai-lab-organization-bundle-schema+
        (list 'epoch (.ref bundle 'epoch))
        (facet->canonical (.ref bundle 'organization))
        (facet->canonical (.ref bundle 'authority))
        (facet->canonical (.ref bundle 'context))
        (facet->canonical (.ref bundle 'protocol))
        (facet->canonical (.ref bundle 'evidence))
        '(outcomes start allow deny timeout retry cancellation checkpoint
                   restore stale-epoch evidence)))

(def (agentic-ai-lab-organization-bundle-normalize bundle)
  (if (and (pair? bundle)
           (eq? (car bundle) +agentic-ai-lab-organization-bundle-schema+))
    (begin
      (unless (stable-semantic-value? bundle)
        (error "canonical Bundle contains unstable values" bundle))
      bundle)
    (agentic-ai-lab-organization-bundle-normalize/object bundle)))

(def (agentic-ai-lab-organization-canonical->string canonical)
  (let (port (open-output-string))
    (write canonical port)
    (get-output-string port)))

(def (agentic-ai-lab-organization-digest canonical . maybe-algorithm)
  (let (algorithm (if (pair? maybe-algorithm)
                     (car maybe-algorithm)
                     +agentic-ai-lab-organization-bundle-digest-algorithm+))
    (case algorithm
      ((sha256)
       (hex-encode
        (sha256
         (string->utf8
          (agentic-ai-lab-organization-canonical->string canonical)))))
      (else (error "unsupported Bundle digest algorithm" algorithm)))))

(def (agentic-ai-lab-organization-bundle-identity bundle)
  (let* ((canonical (agentic-ai-lab-organization-bundle-normalize bundle))
         (digest-value (agentic-ai-lab-organization-digest canonical)))
    (.o (kind 'agentic-ai-lab.organization-bundle.identity.v1)
        (algorithm +agentic-ai-lab-organization-bundle-digest-algorithm+)
        (digest digest-value)
        (epoch (.ref bundle 'epoch)))))

(def (agentic-ai-lab-organization-bundle-identity->alist identity)
  (list (cons 'algorithm (.ref identity 'algorithm))
        (cons 'digest (.ref identity 'digest))
        (cons 'epoch (.ref identity 'epoch))))

(def (stable-semantic-value? value)
  (cond
   ((or (null? value) (symbol? value) (string? value)
        (boolean? value) (number? value)) #t)
   ((pair? value)
    (and (stable-semantic-value? (car value))
         (stable-semantic-value? (cdr value))))
   (else #f)))

(def (semantic-index objects)
  (agentic-ai-lab-semantic-index-by agentic-ai-lab-organization-object-id objects))

(def (semantic-duplicate-ids objects)
  (agentic-ai-lab-semantic-adjacent-duplicate-identities
   agentic-ai-lab-organization-object-id (semantic-sort objects)))

(def semantic-subset? agentic-ai-lab-semantic-subset?)

(def semantic-unique-count agentic-ai-lab-semantic-unique-count)

(def (semantic-proper-subset? child parent)
  (and (semantic-subset? child parent)
       (< (semantic-unique-count child)
          (semantic-unique-count parent))))

(def (diagnostic code path expected observed)
  (list (cons 'code code)
        (cons 'path path)
        (cons 'expected expected)
        (cons 'observed observed)))

;;; Validation boundary: collect cross-facet diagnostics against one canonical bundle identity.
(def (agentic-ai-lab-organization-bundle-validate/unsafe bundle . maybe-identity)
  (let* ((organization (.ref bundle 'organization))
         (authority (.ref bundle 'authority))
         (context-facet (.ref bundle 'context))
         (protocol (.ref bundle 'protocol))
         (evidence (.ref bundle 'evidence))
         (principals (facet-entities organization 'principal))
         (roles (facet-entities organization 'role))
         (agents (facet-entities organization 'agent))
         (capabilities (facet-entities authority 'capability))
         (delegations (facet-relations authority 'delegation))
         (contexts (facet-entities context-facet 'context-projection))
         (effects (facet-entities protocol 'tool-effect))
         (transitions (facet-entities protocol 'protocol-transition))
         (obligations (facet-entities evidence 'evidence-obligation))
         (principal-index (semantic-index principals))
         (role-index (semantic-index roles))
         (agent-index (semantic-index agents))
         (capability-index (semantic-index capabilities))
         (context-index (semantic-index contexts))
         (effect-index (semantic-index effects))
         (transition-index (semantic-index transitions))
         (delegation-index
          (let (index (make-hash-table))
            (for-each
             (lambda (value)
               (hash-put! index
                          (list (.ref value 'parent-id) (.ref value 'child-id)
                                (.ref value 'capability-id))
                          value))
             delegations)
            index))
         (epoch (.ref bundle 'epoch))
         (identity-value (if (pair? maybe-identity)
                           (car maybe-identity)
                           (agentic-ai-lab-organization-bundle-identity bundle)))
         (diagnostic-values '()))
    (def (reject! code path expected observed)
      (set! diagnostic-values
            (cons (diagnostic code path expected observed) diagnostic-values)))
    (for-each
     (lambda (entry)
       (let ((name (car entry)) (facet (cdr entry)))
         (unless (and (object? facet)
                      (eq? (.ref facet 'schema)
                           +agentic-ai-lab-organization-facet-schema+)
                      (eq? (.ref facet 'facet-name) name))
           (reject! 'invalid-facet (list 'facets name)
                    'typed-facet 'invalid))))
     (list (cons 'organization organization) (cons 'authority authority)
           (cons 'context context-facet) (cons 'protocol protocol)
           (cons 'evidence evidence)))
    (unless (and (integer? epoch) (>= epoch 0))
      (reject! 'invalid-epoch '(epoch) 'nonnegative-integer 'invalid))
    (for-each
     (lambda (entry)
       (let ((label (car entry)) (values (cdr entry)))
         (when (null? values)
           (reject! 'missing-members (list label) 'nonempty 'empty))
         (for-each
          (lambda (id)
            (reject! 'duplicate-identity (list label id) 'unique 'duplicate))
          (semantic-duplicate-ids values))))
     (list (cons 'principals principals)
           (cons 'roles roles)
           (cons 'agents agents)
           (cons 'capabilities capabilities)
           (cons 'context-projections contexts)
           (cons 'tool-effects effects)))
    (let ((identity-entities
           (append principals roles agents capabilities effects
                   transitions obligations)))
      (let (identity-kind-index (make-hash-table))
        (for-each
         (lambda (value)
           (let* ((id (.ref value 'id))
                  (kinds (or (hash-get identity-kind-index id) '())))
             (hash-put! identity-kind-index id (cons (.ref value 'kind) kinds))))
         identity-entities)
        (for-each
       (lambda (id)
         (let (kinds (reverse (hash-get identity-kind-index id)))
           (when (> (semantic-unique-count kinds) 1)
             (reject! 'incompatible-shared-identity
                      (list 'identity-universe id) 'one-kind kinds))))
       (semantic-duplicate-ids identity-entities))))
    (for-each
     (lambda (agent)
       (let ((agent-id (.ref agent 'id))
             (principal-id (.ref agent 'principal-id))
             (role-id (.ref agent 'role-id)))
         (unless (hash-key? principal-index principal-id)
           (reject! 'missing-principal (list 'agents agent-id 'principal)
                    'declared principal-id))
         (unless (hash-key? role-index role-id)
           (reject! 'missing-role (list 'agents agent-id 'role)
                    'declared role-id))))
     agents)
    (let* ((roots (filter (lambda (agent) (not (.ref agent 'parent-id))) agents))
           (children (filter (lambda (agent) (.ref agent 'parent-id)) agents)))
      (unless (= (length roots) 1)
        (reject! 'invalid-root-count '(agents) 1 (length roots)))
      (unless (pair? children)
        (reject! 'invalid-child-count '(agents) 'at-least-one 0))
      (when (= (length roots) 1)
        (let* ((parent (car roots))
               (parent-id (.ref parent 'id))
               (parent-authority (.ref parent 'authorities)))
          (for-each
           (lambda (child)
             (let* ((child-id (.ref child 'id))
                    (child-authority (.ref child 'authorities))
                    (context (hash-get context-index child-id)))
               (unless (equal? (.ref child 'parent-id) parent-id)
                 (reject! 'invalid-parent-binding
                          (list 'agents child-id 'parent)
                          parent-id (.ref child 'parent-id)))
               (unless (semantic-proper-subset?
                        child-authority parent-authority)
                 (reject! 'authority-not-strict-subset
                          (list 'agents child-id 'authorities)
                          'strict-subset child-authority))
               (unless context
                 (reject! 'missing-context-projection
                          (list 'context-projections child-id)
                          'declared 'missing))
               (when (and context
                          (not (semantic-subset?
                                (.ref context 'visible)
                                (.ref parent 'context-visible))))
                 (reject! 'context-visibility-leak
                          (list 'context-projections child-id 'visible)
                          'parent-visible-subset (.ref context 'visible)))
               (for-each
                (lambda (authority)
                  (let (capability (hash-get capability-index authority))
                    (when (and capability
                               (not (.ref capability 'delegable?)))
                      (reject! 'nondelegable-capability
                               (list 'agents child-id 'authorities authority)
                               'delegable authority)))
                  (unless (hash-get delegation-index
                                    (list parent-id child-id authority))
                    (reject! 'undelegated-authority
                             (list 'agents child-id 'authorities authority)
                             'explicit-delegation 'missing)))
                child-authority)))
           children))))
    (for-each
     (lambda (effect)
       (let* ((effect-id (.ref effect 'id))
              (capability-id (.ref effect 'capability-id))
              (capability (hash-get capability-index capability-id)))
         (unless capability
           (reject! 'undeclared-tool-effect
                    (list 'tool-effects effect-id 'capability)
                    'declared capability-id))))
     effects)
    (for-each
     (lambda (transition)
       (let ((transition-id (.ref transition 'id))
             (capability-id (.ref transition 'capability-id)))
         (for-each
          (lambda (participant)
            (unless (hash-key? agent-index participant)
              (reject! 'missing-protocol-participant
                       (list 'protocol transition-id 'participants participant)
                       'declared-agent participant)))
          (.ref transition 'participants))
         (unless (hash-key? capability-index capability-id)
           (reject! 'unauthorized-protocol-capability
                    (list 'protocol transition-id 'capability)
                    'declared-capability capability-id))))
     transitions)
    (for-each
     (lambda (obligation)
       (let ((obligation-id (.ref obligation 'id))
             (subject-id (.ref obligation 'subject-id))
             (target-kind (.ref obligation 'target-kind))
             (target-id (.ref obligation 'target-id)))
         (unless (hash-key? agent-index subject-id)
           (reject! 'missing-evidence-subject
                    (list 'evidence obligation-id 'subject)
                    'declared-agent subject-id))
         (unless
          (case target-kind
            ((transition) (hash-get transition-index target-id))
            ((effect) (hash-get effect-index target-id))
            ((subject) (hash-get agent-index target-id))
            (else #f))
          (reject! 'missing-evidence-target
                   (list 'evidence obligation-id 'target)
                   target-kind target-id))))
     obligations)
    (unless (stable-semantic-value?
             (agentic-ai-lab-organization-bundle-normalize bundle))
      (reject! 'unstable-semantic-value '(bundle) 'canonical 'unstable))
    (let (computed (agentic-ai-lab-organization-bundle-identity bundle))
      (unless (and (eq? (.ref identity-value 'algorithm)
                        +agentic-ai-lab-organization-bundle-digest-algorithm+)
                   (equal? (.ref identity-value 'digest) (.ref computed 'digest))
                   (equal? (.ref identity-value 'epoch) epoch))
        (reject! 'bundle-identity-mismatch '(identity)
                 (agentic-ai-lab-organization-bundle-identity->alist computed)
                 (agentic-ai-lab-organization-bundle-identity->alist identity-value))))
    (set! diagnostic-values (reverse diagnostic-values))
    (.o (kind 'agentic-ai-lab.organization-bundle.validation-receipt.v1)
        (identity identity-value)
        (accepted? (null? diagnostic-values))
        (diagnostics diagnostic-values))))

(def (agentic-ai-lab-organization-bundle-validate bundle . maybe-identity)
  (with-catch
   (lambda (_failure)
     (.o (kind 'agentic-ai-lab.organization-bundle.validation-receipt.v1)
         (identity #f)
         (accepted? #f)
         (diagnostics
          (list (diagnostic 'unstable-semantic-value
                            '(bundle)
                            'canonical
                            'unstable)))))
   (lambda ()
     (apply agentic-ai-lab-organization-bundle-validate/unsafe
            bundle
            maybe-identity))))

(def (agentic-ai-lab-organization-validation-accepted? receipt)
  (.ref receipt 'accepted?))

(def (agentic-ai-lab-organization-validation-diagnostics receipt)
  (.ref receipt 'diagnostics))
