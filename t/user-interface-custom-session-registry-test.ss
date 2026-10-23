;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: custom user-interface session-registry scenario.
;;; Invariant: registry receipts index declared sessions; they are not live
;;; runtime stores.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-user-module-selection-key
                 yuanxu-user-module-selection-flag-entry)
        (only-in "../user-interface/custom/my-module/cases/session-registry"
                 agentic-ai-lab-custom-my-module-session-registry-case))

(export user-interface-custom-session-registry-test)

;; : (-> Alist Symbol MaybeValue)
(def (test-ref row key)
  (let (entry (assoc key row))
    (if entry (cdr entry) #f)))

;; : (-> [PooUserModuleSelection] [Value])
(def (module-config-rows module-selection-bundle)
  (let* ((selection (car module-selection-bundle))
         (entry
          (yuanxu-user-module-selection-flag-entry selection ':session-rows)))
    (if entry (cdr entry) '())))

;; : TestSuite
(def user-interface-custom-session-registry-test
  (test-suite "agentic-ai-lab custom user-interface session-registry case"
    (yuanxu-test-case "projects custom session registry receipt"
      (let* ((selection
              (car agentic-ai-lab-custom-my-module-session-registry-case))
             (rows
              (module-config-rows
               agentic-ai-lab-custom-my-module-session-registry-case))
             (registry (car rows))
             (entries (.ref registry 'entries))
             (build-entry (cadr entries)))
        (check-equal? (yuanxu-user-module-selection-key selection)
                      '(session . session))
        (check-equal? (.ref registry 'kind)
                      'agentic-ai-lab.session.registry-receipt)
        (check-equal? (.ref registry 'project-id) 'custom/project)
        (check-equal? (.ref registry 'root-session-ids)
                      '(custom/root-session))
        (check-equal? (.ref registry 'child-session-ids)
                      '(custom/build-session custom/audit-session))
        (check-equal? (.ref registry 'entry-count) 3)
        (check-equal? (.ref registry 'durable-policy-refs)
                      '(durable/custom-project
                        durable/custom-project
                        durable/custom-project))
        (check-equal? (test-ref build-entry 'parent-session-ids)
                      '(custom/root-session))
        (check-equal? (test-ref build-entry 'communication-channels)
                      '(channel/build-root channel/build-audit))
        (check-equal? (.ref registry 'runtime-executed) #f)))))
