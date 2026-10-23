;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :clan/poo/object :std/test
        :agentic-ai-lab/modules/query/semantic/organization-bundle
        :agentic-ai-lab/modules/query/semantic/organization-bundle-kernel)


(def (bundle epoch child-authority)
  (agentic-ai-lab-organization-bundle
   epoch
   (agentic-ai-lab-organization-organization-facet
    (list (agentic-ai-lab-organization-principal 'pp)
          (agentic-ai-lab-organization-principal 'pc)
          (agentic-ai-lab-organization-role 'rp)
          (agentic-ai-lab-organization-role 'rc)
          (agentic-ai-lab-organization-agent 'parent 'pp 'rp #f
                                       '(write search) '(public private))
          (agentic-ai-lab-organization-agent 'child 'pc 'rc 'parent
                                       child-authority '(public))))
   (agentic-ai-lab-organization-authority-facet
    (list (agentic-ai-lab-organization-capability 'write #t)
          (agentic-ai-lab-organization-capability 'search #t))
    (list (agentic-ai-lab-organization-delegation 'parent 'child 'search)))
   (agentic-ai-lab-organization-context-facet
    (list (agentic-ai-lab-organization-context-projection 'child '(public))))
   (agentic-ai-lab-organization-protocol-facet
    (list (agentic-ai-lab-organization-tool-effect 'tool 'search 'external-tool)) '())
   (agentic-ai-lab-organization-empty-evidence-facet)))

(def (open+validate value)
  (let-values (((candidate _open)
                (agentic-ai-lab-organization-bundle-kernel-open value)))
    (agentic-ai-lab-organization-bundle-kernel-validate candidate)))

(def organization-bundle-kernel-test
  (test-suite
   "immutable organization Bundle kernel"
   (yuanxu-test-case "open and validate"
     (let-values (((state receipt) (open+validate (bundle 7 '(search)))))
       (check-equal? (.ref state 'phase) 'validated)
       (check-equal? (.ref state 'epoch) 0)
       (check-equal? (.ref receipt 'code) 'kernel-validated)))
   (yuanxu-test-case "advance increments and preserves previous state"
     (let-values (((state initial-receipt) (open+validate (bundle 7 '(search)))))
       (let-values (((next receipt)
                     (agentic-ai-lab-organization-bundle-kernel-advance
                      state (.ref state 'identity) 0 (bundle 8 '(search)))))
         (check-equal? (.ref receipt 'code) 'kernel-advanced)
         (check-equal? (.ref next 'epoch) 1)
         (check-equal? (.ref state 'epoch) 0)
         (check-equal? (.ref next 'previous-identity) (.ref state 'identity)))))
   (yuanxu-test-case "noop preserves state and epoch"
     (let-values (((state initial-receipt) (open+validate (bundle 7 '(search)))))
       (let-values (((next receipt)
                     (agentic-ai-lab-organization-bundle-kernel-advance
                      state (.ref state 'identity) 0 (bundle 7 '(search)))))
         (check-eq? next state)
         (check-equal? (.ref receipt 'code) 'kernel-noop)
         (check-equal? (.ref receipt 'after-epoch) 0))))
   (yuanxu-test-case "identity and epoch conflicts fail closed"
     (let-values (((state initial-receipt) (open+validate (bundle 7 '(search))))
                  ((other other-receipt) (open+validate (bundle 8 '(search)))))
       (let-values (((next identity-receipt)
                     (agentic-ai-lab-organization-bundle-kernel-advance
                      state (.ref other 'identity) 0 '#(unstable))))
         (check-equal? next #f)
         (check-equal? (.ref identity-receipt 'code) 'kernel-identity-conflict))
       (let-values (((next epoch-receipt)
                     (agentic-ai-lab-organization-bundle-kernel-advance
                      state (.ref state 'identity) 9 '#(unstable))))
         (check-equal? next #f)
         (check-equal? (.ref epoch-receipt 'code) 'kernel-stale-epoch))))
   (yuanxu-test-case "invalid next Bundle carries validation rejection"
     (let-values (((state initial-receipt) (open+validate (bundle 7 '(search)))))
       (let-values (((next receipt)
                     (agentic-ai-lab-organization-bundle-kernel-advance
                      state (.ref state 'identity) 0
                      (bundle 8 '(write search)))))
         (check-equal? next #f)
         (check-equal? (.ref receipt 'code) 'kernel-next-bundle-rejected)
         (check-equal? (agentic-ai-lab-organization-validation-accepted?
                        (.ref receipt 'validation-receipt)) #f))))
   (yuanxu-test-case "invalid phase fails closed"
     (let-values (((candidate open-receipt) (agentic-ai-lab-organization-bundle-kernel-open
                                  (bundle 7 '(search)))))
       (let-values (((next receipt)
                     (agentic-ai-lab-organization-bundle-kernel-advance
                      candidate (.ref candidate 'identity) 0
                      (bundle 8 '(search)))))
         (check-equal? next #f)
         (check-equal? (.ref receipt 'code) 'kernel-invalid-phase))))))
