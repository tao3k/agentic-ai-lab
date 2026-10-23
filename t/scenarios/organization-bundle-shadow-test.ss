;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :clan/poo/object :std/test
        :agentic-ai-lab/modules/query/semantic/organization-bundle
        :agentic-ai-lab/modules/query/semantic/organization-bundle-kernel
        :agentic-ai-lab/modules/query/semantic/organization-bundle-shadow)


(def (shadow-bundle)
  (agentic-ai-lab-organization-bundle
   11
   (agentic-ai-lab-organization-organization-facet
    (list (agentic-ai-lab-organization-principal 'pp)
          (agentic-ai-lab-organization-principal 'pc)
          (agentic-ai-lab-organization-role 'rp)
          (agentic-ai-lab-organization-role 'rc)
          (agentic-ai-lab-organization-agent 'parent 'pp 'rp #f
                                       '(write search) '(public private))
          (agentic-ai-lab-organization-agent 'child 'pc 'rc 'parent '(search) '(public))))
   (agentic-ai-lab-organization-authority-facet
    (list (agentic-ai-lab-organization-capability 'write #t)
          (agentic-ai-lab-organization-capability 'search #t))
    (list (agentic-ai-lab-organization-delegation 'parent 'child 'search)))
   (agentic-ai-lab-organization-context-facet
    (list (agentic-ai-lab-organization-context-projection 'child '(public))))
   (agentic-ai-lab-organization-protocol-facet
    (list (agentic-ai-lab-organization-tool-effect 'tool 'search 'external-tool)
          (agentic-ai-lab-organization-protocol-transition
           'run '(parent child) 'search)) '())
   (agentic-ai-lab-organization-evidence-facet
    (list (agentic-ai-lab-organization-evidence-obligation
           'audit 'child 'transition 'run)) '())))

(def (validated-state)
  (let* ((bundle (shadow-bundle))
         (canonical (agentic-ai-lab-organization-bundle-normalize bundle))
         (identity (agentic-ai-lab-organization-bundle-identity bundle)))
    (kernel-state 'validated bundle canonical identity 0 #f 'validate #f)))

(def organization-bundle-shadow-test
  (test-suite
   "read-only organization Bundle shadow projection"
   (yuanxu-test-case "equivalent facts are deterministic draft evidence"
     (let* ((state (validated-state))
            (facts (agentic-ai-lab-organization-bundle-shadow-facts state))
            (profile (agentic-ai-lab-organization-shadow-profile/all facts))
            (receipt (agentic-ai-lab-organization-bundle-shadow-compare
                      state (reverse facts) profile)))
       (check-equal? (.ref receipt 'accepted?) #t)
       (check-equal? (.ref receipt 'equivalent?) #t)
       (check-equal? (.ref receipt 'v1-conformant?) #f)
       (check-equal? (.ref state 'phase) 'validated)
       (check-equal? (.ref state 'epoch) 0)))
   (yuanxu-test-case "three semantic difference classes stay distinct"
     (let* ((state (validated-state))
            (facts (agentic-ai-lab-organization-bundle-shadow-facts state))
            (first (car facts))
            (changed (agentic-ai-lab-organization-shadow-fact
                      (.ref first 'facet) (.ref first 'path) (.ref first 'key) 'changed))
            (extra (agentic-ai-lab-organization-shadow-fact
                    'organization '(extra) 'value 'extra))
            (current (cons changed (cons extra (cddr facts))))
            (profile (agentic-ai-lab-organization-shadow-profile
                      (cons '(organization (extra))
                            (.ref (agentic-ai-lab-organization-shadow-profile/all facts)
                                  'entries))))
            (receipt (agentic-ai-lab-organization-bundle-shadow-compare state current profile)))
       (check-equal? (.ref receipt 'accepted?) #t)
       (check-equal? (.ref receipt 'equivalent?) #f)
       (check-equal? (length (.ref receipt 'missing-current)) 1)
       (check-equal? (length (.ref receipt 'missing-bundle)) 1)
       (check-equal? (length (.ref receipt 'mismatched-values)) 1)))
   (yuanxu-test-case "duplicate current fact fails closed"
     (let* ((state (validated-state))
            (facts (agentic-ai-lab-organization-bundle-shadow-facts state))
            (profile (agentic-ai-lab-organization-shadow-profile/all facts))
            (receipt (agentic-ai-lab-organization-bundle-shadow-compare
                      state (cons (car facts) facts) profile)))
       (check-equal? (.ref receipt 'accepted?) #f)
       (check-equal? (.ref receipt 'equivalent?) #f)))
   (yuanxu-test-case "incomplete profile fails closed"
     (let* ((state (validated-state))
            (facts (agentic-ai-lab-organization-bundle-shadow-facts state))
            (profile (agentic-ai-lab-organization-shadow-profile '()))
            (receipt (agentic-ai-lab-organization-bundle-shadow-compare state facts profile)))
       (check-equal? (.ref receipt 'accepted?) #f)))
   (yuanxu-test-case "unknown facet and unstable value fail closed"
     (let* ((state (validated-state))
            (facts (agentic-ai-lab-organization-bundle-shadow-facts state))
            (profile (agentic-ai-lab-organization-shadow-profile
                      (cons '(unknown (bad))
                            (.ref (agentic-ai-lab-organization-shadow-profile/all facts)
                                  'entries))))
            (unstable (agentic-ai-lab-organization-shadow-fact
                       'organization '(unstable) 'value '#(unstable)))
            (receipt (agentic-ai-lab-organization-bundle-shadow-compare
                      state (cons unstable facts) profile)))
       (check-equal? (.ref receipt 'accepted?) #f)
       (check-equal? (.ref receipt 'equivalent?) #f)
       (check-equal? (.ref receipt 'v1-conformant?) #f)))
   (yuanxu-test-case "schema is explicitly draft.3"
     (check-equal? +agentic-ai-lab-organization-bundle-schema+
                   'agentic-ai-lab.organization-bundle.draft.3)
     (check-equal? +agentic-ai-lab-organization-facet-schema+
                   'agentic-ai-lab.organization-facet.draft.3))))
