;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :clan/poo/object :std/test
        :agentic-ai-lab/modules/query/semantic/organization-bundle
        :agentic-ai-lab/modules/query/semantic/organization-bundle-kernel
        :agentic-ai-lab/modules/workflow/contracts/organization-bundle-runtime-v0)


(def (runtime-v0-bundle)
  (agentic-ai-lab-organization-bundle
   12
   (agentic-ai-lab-organization-organization-facet
    (list (agentic-ai-lab-organization-principal 'pp)
          (agentic-ai-lab-organization-principal 'pc)
          (agentic-ai-lab-organization-role 'rp)
          (agentic-ai-lab-organization-role 'rc)
          (agentic-ai-lab-organization-agent 'parent 'pp 'rp #f
                                       '(write search) '(public private))
          (agentic-ai-lab-organization-agent 'child 'pc 'rc 'parent
                                       '(search) '(public))))
   (agentic-ai-lab-organization-authority-facet
    (list (agentic-ai-lab-organization-capability 'write #t)
          (agentic-ai-lab-organization-capability 'search #t))
    (list (agentic-ai-lab-organization-delegation 'parent 'child 'search)))
   (agentic-ai-lab-organization-context-facet
    (list (agentic-ai-lab-organization-context-projection 'child '(public))))
   (agentic-ai-lab-organization-protocol-facet
    (list (agentic-ai-lab-organization-tool-effect 'tool 'search 'external-tool)) '())
   (agentic-ai-lab-organization-empty-evidence-facet)))

(def (validated-state)
  (let-values (((candidate _) (agentic-ai-lab-organization-bundle-kernel-open
                                (runtime-v0-bundle))))
    (let-values (((state _) (agentic-ai-lab-organization-bundle-kernel-validate candidate)))
      state)))

(def organization-bundle-runtime-v0-test
  (test-suite
   "organization Bundle runtime v0 control packet"
   (yuanxu-test-case "validated Kernel projects deterministic pre-v1 packet"
     (let* ((state (validated-state))
            (packet (agentic-ai-lab-runtime-v0-control-packet state)))
       (check-equal? (.ref packet 'abi-major) 0)
       (check-equal? (.ref packet 'abi-minor) 1)
       (check-equal? (.ref packet 'bundle-schema)
                     'agentic-ai-lab.organization-bundle.draft.3)
       (check-equal? (.ref packet 'bundle-epoch) 12)
       (check-equal? (.ref packet 'abi-v1-frozen?) #f)))
   (yuanxu-test-case "candidate Kernel cannot cross runtime boundary"
     (let-values (((candidate _) (agentic-ai-lab-organization-bundle-kernel-open
                                   (runtime-v0-bundle))))
       (check-equal?
        (with-catch (lambda (_failure) #t)
                    (lambda ()
                      (agentic-ai-lab-runtime-v0-control-packet candidate)
                      #f))
        #t)))))
