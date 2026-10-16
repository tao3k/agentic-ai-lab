;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         :clan/poo/object :std/test
        :poo-flow/modules/query/semantic/organization-bundle
        :poo-flow/modules/query/semantic/organization-bundle-kernel)


(def (bundle epoch child-authority)
  (poo-flow-organization-bundle
   epoch
   (poo-flow-organization-organization-facet
    (list (poo-flow-organization-principal 'pp)
          (poo-flow-organization-principal 'pc)
          (poo-flow-organization-role 'rp)
          (poo-flow-organization-role 'rc)
          (poo-flow-organization-agent 'parent 'pp 'rp #f
                                       '(write search) '(public private))
          (poo-flow-organization-agent 'child 'pc 'rc 'parent
                                       child-authority '(public))))
   (poo-flow-organization-authority-facet
    (list (poo-flow-organization-capability 'write #t)
          (poo-flow-organization-capability 'search #t))
    (list (poo-flow-organization-delegation 'parent 'child 'search)))
   (poo-flow-organization-context-facet
    (list (poo-flow-organization-context-projection 'child '(public))))
   (poo-flow-organization-protocol-facet
    (list (poo-flow-organization-tool-effect 'tool 'search 'external-tool)) '())
   (poo-flow-organization-empty-evidence-facet)))

(def (open+validate value)
  (let-values (((candidate _open)
                (poo-flow-organization-bundle-kernel-open value)))
    (poo-flow-organization-bundle-kernel-validate candidate)))

(def organization-bundle-kernel-test
  (test-suite
   "immutable organization Bundle kernel"
   (poo-flow-test-case "open and validate"
     (let-values (((state receipt) (open+validate (bundle 7 '(search)))))
       (check-equal? (.ref state 'phase) 'validated)
       (check-equal? (.ref state 'epoch) 0)
       (check-equal? (.ref receipt 'code) 'kernel-validated)))
   (poo-flow-test-case "advance increments and preserves previous state"
     (let-values (((state initial-receipt) (open+validate (bundle 7 '(search)))))
       (let-values (((next receipt)
                     (poo-flow-organization-bundle-kernel-advance
                      state (.ref state 'identity) 0 (bundle 8 '(search)))))
         (check-equal? (.ref receipt 'code) 'kernel-advanced)
         (check-equal? (.ref next 'epoch) 1)
         (check-equal? (.ref state 'epoch) 0)
         (check-equal? (.ref next 'previous-identity) (.ref state 'identity)))))
   (poo-flow-test-case "noop preserves state and epoch"
     (let-values (((state initial-receipt) (open+validate (bundle 7 '(search)))))
       (let-values (((next receipt)
                     (poo-flow-organization-bundle-kernel-advance
                      state (.ref state 'identity) 0 (bundle 7 '(search)))))
         (check-eq? next state)
         (check-equal? (.ref receipt 'code) 'kernel-noop)
         (check-equal? (.ref receipt 'after-epoch) 0))))
   (poo-flow-test-case "identity and epoch conflicts fail closed"
     (let-values (((state initial-receipt) (open+validate (bundle 7 '(search))))
                  ((other other-receipt) (open+validate (bundle 8 '(search)))))
       (let-values (((next identity-receipt)
                     (poo-flow-organization-bundle-kernel-advance
                      state (.ref other 'identity) 0 '#(unstable))))
         (check-equal? next #f)
         (check-equal? (.ref identity-receipt 'code) 'kernel-identity-conflict))
       (let-values (((next epoch-receipt)
                     (poo-flow-organization-bundle-kernel-advance
                      state (.ref state 'identity) 9 '#(unstable))))
         (check-equal? next #f)
         (check-equal? (.ref epoch-receipt 'code) 'kernel-stale-epoch))))
   (poo-flow-test-case "invalid next Bundle carries validation rejection"
     (let-values (((state initial-receipt) (open+validate (bundle 7 '(search)))))
       (let-values (((next receipt)
                     (poo-flow-organization-bundle-kernel-advance
                      state (.ref state 'identity) 0
                      (bundle 8 '(write search)))))
         (check-equal? next #f)
         (check-equal? (.ref receipt 'code) 'kernel-next-bundle-rejected)
         (check-equal? (poo-flow-organization-validation-accepted?
                        (.ref receipt 'validation-receipt)) #f))))
   (poo-flow-test-case "invalid phase fails closed"
     (let-values (((candidate open-receipt) (poo-flow-organization-bundle-kernel-open
                                  (bundle 7 '(search)))))
       (let-values (((next receipt)
                     (poo-flow-organization-bundle-kernel-advance
                      candidate (.ref candidate 'identity) 0
                      (bundle 8 '(search)))))
         (check-equal? next #f)
         (check-equal? (.ref receipt 'code) 'kernel-invalid-phase))))))
