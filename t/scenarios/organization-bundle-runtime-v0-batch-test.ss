;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :clan/poo/object :std/test
        :agentic-ai-lab/modules/workflow/contracts/organization-bundle-runtime-v0-batch)


(def (id high low) (agentic-ai-lab-runtime-v0-compact-id high low))

(def organization-bundle-runtime-v0-batch-test
  (test-suite
   "runtime v0 hot/bulk typed projection"
   (yuanxu-test-case "event projects fixed 96-byte native fields"
     (let* ((event (agentic-ai-lab-runtime-v0-event
                    1 0 7 (id 1 2) (id 3 4) (id 5 6)
                    64 128 9000 3))
            (fields (agentic-ai-lab-runtime-v0-event->native-fields event)))
       (check-equal? (cdr (assq 'layout-version fields)) 1)
       (check-equal? (cdr (assq 'header-bytes fields)) 96)
       (check-equal? (cdr (assq 'sequence fields)) 7)
       (check-equal? (cdr (assq 'payload-offset fields)) 64)
       (check-equal? (cdr (assq 'payload-length fields)) 128)
       (check-equal? (cdr (assq 'authorization-identity fields)) '(5 6))))
   (yuanxu-test-case "identity table accepts unique compact identities"
     (let (table
           (agentic-ai-lab-runtime-v0-identity-table
            (list (agentic-ai-lab-runtime-v0-identity-entry 'full-a (id 1 2))
                  (agentic-ai-lab-runtime-v0-identity-entry 'full-b (id 1 3)))))
       (check-equal? (.ref table 'collision-checked?) #t)))
   (yuanxu-test-case "identity table rejects compact collision"
     (check-equal?
      (with-catch
       (lambda (_failure) #t)
       (lambda ()
         (agentic-ai-lab-runtime-v0-identity-table
          (list (agentic-ai-lab-runtime-v0-identity-entry 'full-a (id 9 9))
                (agentic-ai-lab-runtime-v0-identity-entry 'full-b (id 9 9))))
         #f))
      #t))))
