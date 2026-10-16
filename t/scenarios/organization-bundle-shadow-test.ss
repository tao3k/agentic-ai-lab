;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         :clan/poo/object :std/test
        :poo-flow/modules/query/semantic/organization-bundle
        :poo-flow/modules/query/semantic/organization-bundle-kernel
        :poo-flow/modules/query/semantic/organization-bundle-shadow)


(def (shadow-bundle)
  (poo-flow-organization-bundle
   11
   (poo-flow-organization-organization-facet
    (list (poo-flow-organization-principal 'pp)
          (poo-flow-organization-principal 'pc)
          (poo-flow-organization-role 'rp)
          (poo-flow-organization-role 'rc)
          (poo-flow-organization-agent 'parent 'pp 'rp #f
                                       '(write search) '(public private))
          (poo-flow-organization-agent 'child 'pc 'rc 'parent '(search) '(public))))
   (poo-flow-organization-authority-facet
    (list (poo-flow-organization-capability 'write #t)
          (poo-flow-organization-capability 'search #t))
    (list (poo-flow-organization-delegation 'parent 'child 'search)))
   (poo-flow-organization-context-facet
    (list (poo-flow-organization-context-projection 'child '(public))))
   (poo-flow-organization-protocol-facet
    (list (poo-flow-organization-tool-effect 'tool 'search 'external-tool)
          (poo-flow-organization-protocol-transition
           'run '(parent child) 'search)) '())
   (poo-flow-organization-evidence-facet
    (list (poo-flow-organization-evidence-obligation
           'audit 'child 'transition 'run)) '())))

(def (validated-state)
  (let* ((bundle (shadow-bundle))
         (canonical (poo-flow-organization-bundle-normalize bundle))
         (identity (poo-flow-organization-bundle-identity bundle)))
    (kernel-state 'validated bundle canonical identity 0 #f 'validate #f)))

(def organization-bundle-shadow-test
  (test-suite
   "read-only organization Bundle shadow projection"
   (poo-flow-test-case "equivalent facts are deterministic draft evidence"
     (let* ((state (validated-state))
            (facts (poo-flow-organization-bundle-shadow-facts state))
            (profile (poo-flow-organization-shadow-profile/all facts))
            (receipt (poo-flow-organization-bundle-shadow-compare
                      state (reverse facts) profile)))
       (check-equal? (.ref receipt 'accepted?) #t)
       (check-equal? (.ref receipt 'equivalent?) #t)
       (check-equal? (.ref receipt 'v1-conformant?) #f)
       (check-equal? (.ref state 'phase) 'validated)
       (check-equal? (.ref state 'epoch) 0)))
   (poo-flow-test-case "three semantic difference classes stay distinct"
     (let* ((state (validated-state))
            (facts (poo-flow-organization-bundle-shadow-facts state))
            (first (car facts))
            (changed (poo-flow-organization-shadow-fact
                      (.ref first 'facet) (.ref first 'path) (.ref first 'key) 'changed))
            (extra (poo-flow-organization-shadow-fact
                    'organization '(extra) 'value 'extra))
            (current (cons changed (cons extra (cddr facts))))
            (profile (poo-flow-organization-shadow-profile
                      (cons '(organization (extra))
                            (.ref (poo-flow-organization-shadow-profile/all facts)
                                  'entries))))
            (receipt (poo-flow-organization-bundle-shadow-compare state current profile)))
       (check-equal? (.ref receipt 'accepted?) #t)
       (check-equal? (.ref receipt 'equivalent?) #f)
       (check-equal? (length (.ref receipt 'missing-current)) 1)
       (check-equal? (length (.ref receipt 'missing-bundle)) 1)
       (check-equal? (length (.ref receipt 'mismatched-values)) 1)))
   (poo-flow-test-case "duplicate current fact fails closed"
     (let* ((state (validated-state))
            (facts (poo-flow-organization-bundle-shadow-facts state))
            (profile (poo-flow-organization-shadow-profile/all facts))
            (receipt (poo-flow-organization-bundle-shadow-compare
                      state (cons (car facts) facts) profile)))
       (check-equal? (.ref receipt 'accepted?) #f)
       (check-equal? (.ref receipt 'equivalent?) #f)))
   (poo-flow-test-case "incomplete profile fails closed"
     (let* ((state (validated-state))
            (facts (poo-flow-organization-bundle-shadow-facts state))
            (profile (poo-flow-organization-shadow-profile '()))
            (receipt (poo-flow-organization-bundle-shadow-compare state facts profile)))
       (check-equal? (.ref receipt 'accepted?) #f)))
   (poo-flow-test-case "unknown facet and unstable value fail closed"
     (let* ((state (validated-state))
            (facts (poo-flow-organization-bundle-shadow-facts state))
            (profile (poo-flow-organization-shadow-profile
                      (cons '(unknown (bad))
                            (.ref (poo-flow-organization-shadow-profile/all facts)
                                  'entries))))
            (unstable (poo-flow-organization-shadow-fact
                       'organization '(unstable) 'value '#(unstable)))
            (receipt (poo-flow-organization-bundle-shadow-compare
                      state (cons unstable facts) profile)))
       (check-equal? (.ref receipt 'accepted?) #f)
       (check-equal? (.ref receipt 'equivalent?) #f)
       (check-equal? (.ref receipt 'v1-conformant?) #f)))
   (poo-flow-test-case "schema is explicitly draft.3"
     (check-equal? +poo-flow-organization-bundle-schema+
                   'poo-flow.organization-bundle.draft.3)
     (check-equal? +poo-flow-organization-facet-schema+
                   'poo-flow.organization-facet.draft.3))))
