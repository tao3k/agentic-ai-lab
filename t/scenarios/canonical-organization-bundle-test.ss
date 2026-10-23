;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :clan/poo/object
        :std/test
        :agentic-ai-lab/modules/workflow/contracts/organization-bundle
        :agentic-ai-lab/modules/query/semantic/organization-bundle)


(def (canonical-bundle . reverse-order?)
  (let* ((parent-principal (agentic-ai-lab-organization-principal 'principal-parent))
         (child-principal (agentic-ai-lab-organization-principal 'principal-child))
         (parent-role (agentic-ai-lab-organization-role 'role-parent))
         (child-role (agentic-ai-lab-organization-role 'role-child))
         (parent (agentic-ai-lab-organization-agent
                  'agent-parent 'principal-parent 'role-parent #f
                  '(write search) '(public private)))
         (child (agentic-ai-lab-organization-agent
                 'agent-child 'principal-child 'role-child 'agent-parent
                 '(search) '(public)))
         (search-capability
          (agentic-ai-lab-organization-capability 'search #t))
         (write-capability
          (agentic-ai-lab-organization-capability 'write #t))
         (delegation
          (agentic-ai-lab-organization-delegation
           'agent-parent 'agent-child 'search))
         (context
          (agentic-ai-lab-organization-context-projection 'agent-child '(public)))
         (effect
          (agentic-ai-lab-organization-tool-effect
           'search-tool 'search 'external-tool)))
    (let ((principals (if (pair? reverse-order?)
                        (list child-principal parent-principal)
                        (list parent-principal child-principal)))
          (roles (if (pair? reverse-order?)
                   (list child-role parent-role)
                   (list parent-role child-role)))
          (agents (if (pair? reverse-order?)
                    (list child parent) (list parent child)))
          (capabilities (if (pair? reverse-order?)
                          (list write-capability search-capability)
                          (list search-capability write-capability))))
      (agentic-ai-lab-organization-bundle
       7
       (agentic-ai-lab-organization-organization-facet
        (append principals roles agents))
       (agentic-ai-lab-organization-authority-facet capabilities (list delegation))
       (agentic-ai-lab-organization-context-facet (list context))
       (agentic-ai-lab-organization-protocol-facet (list effect) '())
       (agentic-ai-lab-organization-empty-evidence-facet)))))

(def (diagnostic-codes receipt)
  (map (lambda (entry) (cdr (assq 'code entry)))
       (agentic-ai-lab-organization-validation-diagnostics receipt)))

(def (bundle-principals bundle)
  (facet-entities (.ref bundle 'organization) 'principal))
(def (bundle-roles bundle)
  (facet-entities (.ref bundle 'organization) 'role))
(def (bundle-agents bundle)
  (facet-entities (.ref bundle 'organization) 'agent))
(def (bundle-capabilities bundle)
  (facet-entities (.ref bundle 'authority) 'capability))
(def (bundle-delegations bundle)
  (facet-relations (.ref bundle 'authority) 'delegation))
(def (bundle-contexts bundle)
  (facet-entities (.ref bundle 'context) 'context-projection))
(def (bundle-effects bundle)
  (facet-entities (.ref bundle 'protocol) 'tool-effect))
(def (flat-test-bundle epoch principals roles agents capabilities delegations
                       contexts effects)
  (agentic-ai-lab-organization-bundle
   epoch
   (agentic-ai-lab-organization-organization-facet
    (append principals roles agents))
   (agentic-ai-lab-organization-authority-facet capabilities delegations)
   (agentic-ai-lab-organization-context-facet contexts)
   (agentic-ai-lab-organization-protocol-facet effects '())
   (agentic-ai-lab-organization-empty-evidence-facet)))

(def canonical-organization-bundle-test
  (test-suite
   "canonical organization Bundle vertical slice"

   (yuanxu-test-case "normalization and digest are construction-order invariant"
     (let* ((left (canonical-bundle))
            (right (canonical-bundle #t))
            (left-canonical (agentic-ai-lab-organization-bundle-normalize left))
            (right-canonical (agentic-ai-lab-organization-bundle-normalize right))
            (left-id (agentic-ai-lab-organization-bundle-identity left))
            (right-id (agentic-ai-lab-organization-bundle-identity right)))
       (check-equal? left-canonical right-canonical)
       (check-equal? (agentic-ai-lab-organization-bundle-normalize left-canonical)
                     left-canonical)
       (check-equal? (.ref left-id 'algorithm) 'sha256)
       (check-equal? (.ref left-id 'digest) (.ref right-id 'digest))
       (check-equal? (string-length (.ref left-id 'digest)) 64)))

   (yuanxu-test-case "frozen parent child tool slice validates"
     (let* ((bundle (canonical-bundle))
            (receipt (agentic-ai-lab-organization-bundle-validate bundle))
            (contract (agentic-ai-lab-organization-bundle->contract bundle)))
       (check-equal? (agentic-ai-lab-organization-validation-accepted? receipt) #t)
       (check-equal? (agentic-ai-lab-organization-validation-diagnostics receipt) '())
       (check-equal? (agentic-ai-lab-organization-bundle-contract-ref contract 'canonical)
                     (agentic-ai-lab-organization-bundle-normalize bundle))
       (check-equal? (.ref (agentic-ai-lab-organization-bundle-contract-ref
                            contract 'identity)
                           'digest)
                     (.ref (agentic-ai-lab-organization-bundle-identity bundle) 'digest))))

   (yuanxu-test-case "semantic mutation changes digest"
     (let* ((bundle (canonical-bundle))
            (mutated
             (flat-test-bundle
              8
              (bundle-principals bundle)
              (bundle-roles bundle)
              (bundle-agents bundle)
              (bundle-capabilities bundle)
              (bundle-delegations bundle)
              (bundle-contexts bundle)
              (bundle-effects bundle))))
       (check (equal? (.ref (agentic-ai-lab-organization-bundle-identity bundle) 'digest)
                      (.ref (agentic-ai-lab-organization-bundle-identity mutated) 'digest))
              => #f)))

   (yuanxu-test-case "authority equality is rejected"
     (let* ((base (canonical-bundle))
            (parent (car (bundle-agents base)))
            (child (cadr (bundle-agents base)))
            (invalid-child
             (agentic-ai-lab-organization-agent
              (.ref child 'id) (.ref child 'principal-id) (.ref child 'role-id)
              (.ref child 'parent-id) '(write search) '(public)))
            (invalid
             (flat-test-bundle
              (.ref base 'epoch) (bundle-principals base) (bundle-roles base)
              (list parent invalid-child) (bundle-capabilities base)
              (bundle-delegations base) (bundle-contexts base)
              (bundle-effects base)))
            (receipt (agentic-ai-lab-organization-bundle-validate invalid)))
       (check (not (not (member 'authority-not-strict-subset
                                (diagnostic-codes receipt))))
              => #t)))

   (yuanxu-test-case "context leakage and identity mismatch are rejected"
     (let* ((base (canonical-bundle))
            (leaked-context
             (agentic-ai-lab-organization-context-projection
              'agent-child '(public secret)))
            (invalid
             (flat-test-bundle
              (.ref base 'epoch) (bundle-principals base) (bundle-roles base)
              (bundle-agents base) (bundle-capabilities base)
              (bundle-delegations base) (list leaked-context)
              (bundle-effects base)))
            (wrong-identity
             (.o (kind 'agentic-ai-lab.organization-bundle.identity.v1)
                 (algorithm 'sha256) (digest "00") (epoch 7)))
            (receipt
             (agentic-ai-lab-organization-bundle-validate invalid wrong-identity))
            (codes (diagnostic-codes receipt)))
       (check (not (not (member 'context-visibility-leak codes))) => #t)
       (check (not (not (member 'bundle-identity-mismatch codes))) => #t)))

   (yuanxu-test-case "undeclared effect and invalid epoch are rejected"
     (let* ((base (canonical-bundle))
            (effect
             (agentic-ai-lab-organization-tool-effect
              'unknown-tool 'unknown 'external-tool))
            (invalid
             (flat-test-bundle
              -1 (bundle-principals base) (bundle-roles base)
              (bundle-agents base) (bundle-capabilities base)
              (bundle-delegations base) (bundle-contexts base)
              (list effect)))
            (codes
             (diagnostic-codes
              (agentic-ai-lab-organization-bundle-validate invalid))))
       (check (not (not (member 'invalid-epoch codes))) => #t)
       (check (not (not (member 'undeclared-tool-effect codes))) => #t)))

   (yuanxu-test-case "duplicate and missing semantic identities are rejected"
     (let* ((base (canonical-bundle))
            (principal (car (bundle-principals base)))
            (invalid
             (flat-test-bundle
              (.ref base 'epoch)
              (list principal principal)
              '()
              (bundle-agents base)
              (bundle-capabilities base)
              (bundle-delegations base)
              (bundle-contexts base)
              (bundle-effects base)))
            (codes
             (diagnostic-codes
              (agentic-ai-lab-organization-bundle-validate invalid))))
       (check (not (not (member 'duplicate-identity codes))) => #t)
       (check (not (not (member 'missing-members codes))) => #t)
       (check (not (not (member 'missing-role codes))) => #t)))

   (yuanxu-test-case "unstable semantic values fail closed"
     (let* ((base (canonical-bundle))
            (parent (car (bundle-agents base)))
            (child (cadr (bundle-agents base)))
            (unstable-child
             (agentic-ai-lab-organization-agent
              (.ref child 'id) (.ref child 'principal-id) (.ref child 'role-id)
              (.ref child 'parent-id) (vector 'search) '(public)))
            (invalid
             (flat-test-bundle
              (.ref base 'epoch) (bundle-principals base) (bundle-roles base)
              (list parent unstable-child) (bundle-capabilities base)
              (bundle-delegations base) (bundle-contexts base)
              (bundle-effects base)))
            (receipt (agentic-ai-lab-organization-bundle-validate invalid)))
       (check-equal? (agentic-ai-lab-organization-validation-accepted? receipt) #f)
       (check-equal? (diagnostic-codes receipt) '(unstable-semantic-value))))))
