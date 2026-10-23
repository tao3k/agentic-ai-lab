;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :clan/poo/object :std/test
        :agentic-ai-lab/modules/query/semantic/organization-bundle)


(def (five-facet-bundle . overrides)
  (let* ((bad-protocol? (memq 'bad-protocol overrides))
         (bad-evidence? (memq 'bad-evidence overrides))
         (conflict? (memq 'conflict overrides))
         (organization
          (agentic-ai-lab-organization-organization-facet
           (list (agentic-ai-lab-organization-principal 'pp)
                 (agentic-ai-lab-organization-principal 'pc)
                 (agentic-ai-lab-organization-role 'rp)
                 (agentic-ai-lab-organization-role 'rc)
                 (agentic-ai-lab-organization-agent 'parent 'pp 'rp #f
                                              '(write search) '(public private))
                 (agentic-ai-lab-organization-agent 'child 'pc 'rc 'parent
                                              '(search) '(public)))))
         (authority
          (agentic-ai-lab-organization-authority-facet
           (list (agentic-ai-lab-organization-capability
                  (if conflict? 'child 'write) #t)
                 (agentic-ai-lab-organization-capability 'search #t))
           (list (agentic-ai-lab-organization-delegation
                  'parent 'child 'search))))
         (context
          (agentic-ai-lab-organization-context-facet
           (list (agentic-ai-lab-organization-context-projection
                  'child '(public)))))
         (protocol
          (agentic-ai-lab-organization-protocol-facet
           (list (agentic-ai-lab-organization-tool-effect
                  'tool 'search 'external-tool)
                 (agentic-ai-lab-organization-protocol-transition
                  'run (if bad-protocol? '(ghost) '(parent child)) 'search))
           '()))
         (evidence
          (agentic-ai-lab-organization-evidence-facet
           (list (agentic-ai-lab-organization-evidence-obligation
                  'audit 'child 'transition
                  (if bad-evidence? 'missing 'run)))
           '())))
    (agentic-ai-lab-organization-bundle 9 organization authority context protocol evidence)))

(def (codes receipt)
  (map (lambda (entry) (cdr (assq 'code entry)))
       (agentic-ai-lab-organization-validation-diagnostics receipt)))

(def organization-bundle-five-facets-test
  (test-suite
   "five typed organization facets"
   (yuanxu-test-case "five facets validate and normalize deterministically"
     (let* ((bundle (five-facet-bundle))
            (receipt (agentic-ai-lab-organization-bundle-validate bundle))
            (canonical (agentic-ai-lab-organization-bundle-normalize bundle)))
       (check-equal? (agentic-ai-lab-organization-validation-accepted? receipt) #t)
       (check-equal? (map car (cddr canonical))
                     '(organization authority context protocol evidence outcomes))))
   (yuanxu-test-case "protocol participants resolve through organization facet"
     (check-equal? (not (not (member 'missing-protocol-participant
                                     (codes (agentic-ai-lab-organization-bundle-validate
                                             (five-facet-bundle 'bad-protocol)))))) #t))
   (yuanxu-test-case "evidence target resolves through protocol facet"
     (check-equal? (not (not (member 'missing-evidence-target
                                     (codes (agentic-ai-lab-organization-bundle-validate
                                             (five-facet-bundle 'bad-evidence)))))) #t))
   (yuanxu-test-case "incompatible shared identity fails closed"
     (check-equal? (not (not (member 'incompatible-shared-identity
                                     (codes (agentic-ai-lab-organization-bundle-validate
                                             (five-facet-bundle 'conflict)))))) #t))
   (yuanxu-test-case "missing facet fails closed"
     (let* ((base (five-facet-bundle))
            (invalid (agentic-ai-lab-organization-bundle
                      9 (.ref base 'organization) (.ref base 'authority)
                      (.ref base 'context) (.ref base 'protocol) #f)))
       (check-equal? (agentic-ai-lab-organization-validation-accepted?
                      (agentic-ai-lab-organization-bundle-validate invalid)) #f)))))
