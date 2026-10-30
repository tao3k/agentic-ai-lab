;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: profile candidate tests cover Scheme-side dynamic profile data.
;;; Invariant: tests do not execute nono promote/apply or native sandbox code.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check
                 check-eq?
                 check-equal?
                 check-false
                 check-not-equal?
                 check-output
                 check-true
                 test-error
                 test-suite)
        :agentic-ai-lab/modules/agent-sandbox/api
        :agentic-ai-lab/modules/agent-sandbox/profile-candidate)

(export agent-sandbox-profile-candidate-test)

(def agent-sandbox-profile-candidate-test
 (test-suite "agent sandbox profile candidates"
   (yuanxu-test-case "builds nono candidates through POO descriptors and macros"
     (let* ((choice
             (agent-sandbox-profile-candidate-choice
              grant
              (section 'filesystem)
              (value '((path . ".") (access . readwrite)))
              (reason 'sandbox-denial)))
            (descriptor
             (make-agent-sandbox-profile-candidate-descriptor
              'nono-profile-candidate
              'nono
              'nono-denial
              (list (cons 'metadata
                          '((backend . nono) (owner . profile-candidate))))))
            (candidate
             (agent-sandbox-profile-candidate-descriptor->candidate
              descriptor
              (list choice)
              (list (cons 'profile-ref "developer")
                    (cons 'command '("sh" "-c" "printf candidate"))
                    (cons 'observations
                          '(((status . denied)
                             (path . ".")
                             (op . readwrite))))
                    (cons 'metadata '((test . descriptor)))))))
       (check-equal? (agent-sandbox-profile-candidate-descriptor? descriptor)
                     #t)
       (check-equal? (agent-sandbox-profile-candidate? candidate) #t)
       (check-equal? (agent-sandbox-profile-candidate-backend-kind candidate)
                     'nono)
       (check-equal? (agent-sandbox-profile-candidate-source candidate)
                     'nono-denial)
       (check-equal? (agent-sandbox-profile-candidate-profile-ref candidate)
                     "developer")
       (check-equal? (agent-sandbox-alist-ref
                      (agent-sandbox-profile-candidate-metadata candidate)
                      'owner
                      #f)
                     'profile-candidate)
       (check-equal? (length (agent-sandbox-profile-candidate-choices candidate))
                     1)))
   (yuanxu-test-case "projects candidate choices into patch sections"
     (let* ((grant-choice
             (agent-sandbox-profile-candidate-choice
              grant
              (section 'filesystem)
              (value '((path . ".") (access . readwrite)))))
            (suppress-choice
             (agent-sandbox-profile-candidate-choice
              suppress
              (section 'filesystem)
              (value '((path . ".git") (reason . generated)))))
            (skip-choice
             (agent-sandbox-profile-candidate-choice
              skip
              (section 'network)
              (value '((host . "example.invalid")))))
            (candidate
             (make-agent-sandbox-profile-candidate
              'nono
              'nono-denial
              (list grant-choice suppress-choice skip-choice)
              (list (cons 'profile-ref "developer"))))
            (patch (agent-sandbox-profile-candidate->patch candidate)))
       (check-equal? (agent-sandbox-profile-candidate-patch? patch) #t)
       (check-equal? (agent-sandbox-alist-ref patch 'profile-ref #f)
                     "developer")
       (check-equal? (length (agent-sandbox-alist-ref patch 'grants '()))
                     1)
       (check-equal? (length (agent-sandbox-alist-ref patch 'suppressions '()))
                     1)
       (check-equal? (length (agent-sandbox-alist-ref patch 'skipped '()))
                     1)
       (check-equal? (agent-sandbox-alist-ref patch 'validation-errors #f)
                     '())))
   (yuanxu-test-case "creates inert nono promotion requests and receipts"
     (let* ((choice
             (agent-sandbox-profile-candidate-choice
              grant
              (section 'filesystem)
              (value '((path . ".") (access . readwrite)))))
            (candidate
             (agent-sandbox-profile-candidate
              'nono
              'nono-denial
              (list choice)
              (profile-ref "developer")
              (command '("sh" "-c" "printf promotion"))))
            (request
             (agent-sandbox-profile-candidate->nono-promote-request
              candidate
              (list (cons 'mode 'diff)
                    (cons 'draft-ref "developer-draft"))))
            (receipt
             (agent-sandbox-profile-promotion-receipt
              #t
              'diff-ready
              request
              (list (cons 'output "profile diff")
                    (cons 'metadata '((source . test)))))))
       (check-equal? (agent-sandbox-profile-promotion-request? request) #t)
       (check-equal? (agent-sandbox-alist-ref request 'runtime-executed #t)
                     #f)
       (check-equal? (agent-sandbox-alist-ref request 'argv '())
                     '("nono" "profile" "promote" "--diff"
                       "developer-draft"))
       (check-equal? (agent-sandbox-alist-ref receipt 'schema #f)
                     +agent-sandbox-profile-promotion-receipt-schema+)
       (check-equal? (agent-sandbox-alist-ref receipt 'ok? #f) #t)
       (check-equal? (agent-sandbox-alist-ref receipt 'runtime-executed #t)
                     #f)
       (check-equal? (agent-sandbox-alist-ref receipt 'applied? #t)
                     #f)))
   (yuanxu-test-case "reports structured contract validation errors"
     (let* ((errors
             (agent-sandbox-profile-candidate-validation-errors
              (list (cons 'schema 'wrong-schema)
                    (cons 'backend-kind 'nono)
                    (cons 'source 'nono-denial)
                    (cons 'choices
                          (list '((action . grant)
                                  (section . filesystem))))))))
       (check-equal? (agent-sandbox-alist-ref (car errors) 'field #f)
                     'schema)
       (check-equal? (agent-sandbox-alist-ref (cadr errors) 'field #f)
                     'choices)
       (check-equal? (agent-sandbox-alist-ref (cadr errors) 'code #f)
                     'missing-or-invalid)))))
