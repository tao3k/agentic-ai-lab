;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         :clan/poo/object :std/test
        :poo-flow/modules/query/semantic/organization-bundle
        :poo-flow/modules/query/semantic/organization-bundle-kernel
        :poo-flow/modules/workflow/contracts/organization-bundle-runtime-v0)


(def (runtime-v0-bundle)
  (poo-flow-organization-bundle
   12
   (poo-flow-organization-organization-facet
    (list (poo-flow-organization-principal 'pp)
          (poo-flow-organization-principal 'pc)
          (poo-flow-organization-role 'rp)
          (poo-flow-organization-role 'rc)
          (poo-flow-organization-agent 'parent 'pp 'rp #f
                                       '(write search) '(public private))
          (poo-flow-organization-agent 'child 'pc 'rc 'parent
                                       '(search) '(public))))
   (poo-flow-organization-authority-facet
    (list (poo-flow-organization-capability 'write #t)
          (poo-flow-organization-capability 'search #t))
    (list (poo-flow-organization-delegation 'parent 'child 'search)))
   (poo-flow-organization-context-facet
    (list (poo-flow-organization-context-projection 'child '(public))))
   (poo-flow-organization-protocol-facet
    (list (poo-flow-organization-tool-effect 'tool 'search 'external-tool)) '())
   (poo-flow-organization-empty-evidence-facet)))

(def (validated-state)
  (let-values (((candidate _) (poo-flow-organization-bundle-kernel-open
                                (runtime-v0-bundle))))
    (let-values (((state _) (poo-flow-organization-bundle-kernel-validate candidate)))
      state)))

(def organization-bundle-runtime-v0-test
  (test-suite
   "organization Bundle runtime v0 control packet"
   (poo-flow-test-case "validated Kernel projects deterministic pre-v1 packet"
     (let* ((state (validated-state))
            (packet (poo-flow-runtime-v0-control-packet state)))
       (check-equal? (.ref packet 'abi-major) 0)
       (check-equal? (.ref packet 'abi-minor) 1)
       (check-equal? (.ref packet 'bundle-schema)
                     'poo-flow.organization-bundle.draft.3)
       (check-equal? (.ref packet 'bundle-epoch) 12)
       (check-equal? (.ref packet 'abi-v1-frozen?) #f)))
   (poo-flow-test-case "candidate Kernel cannot cross runtime boundary"
     (let-values (((candidate _) (poo-flow-organization-bundle-kernel-open
                                   (runtime-v0-bundle))))
       (check-equal?
        (with-catch (lambda (_failure) #t)
                    (lambda ()
                      (poo-flow-runtime-v0-control-packet candidate)
                      #f))
        #t)))))
