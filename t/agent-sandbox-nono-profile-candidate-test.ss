;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: nono profile candidate tests cover backend-specific projection.
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
        :agentic-ai-lab/modules/agent-sandbox/profile-candidate
        :agentic-ai-lab/modules/agent-sandbox/nono-profile-candidate)

;; : (-> ProfileCandidateChoice Symbol)
(def (choice-action choice)
  (agent-sandbox-alist-ref choice 'action #f))

;; : (-> ProfileCandidateChoice Symbol)
(def (choice-section choice)
  (agent-sandbox-alist-ref choice 'section #f))

;; : (-> ProfileCandidateChoice Alist)
(def (choice-value choice)
  (agent-sandbox-alist-ref choice 'value '()))

(export agent-sandbox-nono-profile-candidate-test)

(def agent-sandbox-nono-profile-candidate-test
 (test-suite "nono profile candidate projection"
   (yuanxu-test-case "builds nono backend candidates through backend constructor"
     (let* ((choice
             (make-agent-sandbox-profile-candidate-choice
              'grant
              '((section . filesystem)
                (value . ((path . ".") (op . readwrite))))))
            (candidate
             (make-nono-agent-sandbox-profile-candidate
              'nono-why-json
              (list choice)
              '((profile-ref . "developer")
                (metadata . ((backend . nono)))))))
       (check-equal? (agent-sandbox-profile-candidate? candidate) #t)
       (check-equal? (agent-sandbox-profile-candidate-backend-kind candidate)
                     'nono)
       (check-equal? (agent-sandbox-profile-candidate-source candidate)
                     'nono-why-json)
       (check-equal? (agent-sandbox-profile-candidate-profile-ref candidate)
                     "developer")
       (check-equal? (length (agent-sandbox-profile-candidate-choices candidate))
                     1)))
   (yuanxu-test-case "projects denied nono why JSON into grant candidate"
     (let* ((why '((status . "denied")
                   (reason . "path_not_granted")
                   (details . "Path is not covered by any capability: /repo")
                   (suggested_flag . "--allow /repo")))
            (candidate
             (nono-why-json->agent-sandbox-profile-candidate
              why
              '((path . "/repo")
                (op . readwrite)
                (profile-ref . "developer")
                (command . ("nono" "why" "--json")))))
            (choice (car (agent-sandbox-profile-candidate-choices candidate)))
            (patch (agent-sandbox-profile-candidate->patch candidate))
            (grant (car (agent-sandbox-alist-ref patch 'grants '()))))
       (check-equal? (agent-sandbox-profile-candidate? candidate) #t)
       (check-equal? (choice-action choice) 'grant)
       (check-equal? (choice-section choice) 'filesystem)
       (check-equal? (agent-sandbox-alist-ref
                      (choice-value choice)
                      'suggested-flag
                      #f)
                     "--allow /repo")
       (check-equal? (agent-sandbox-alist-ref
                      (choice-value choice)
                      'path
                      #f)
                     "/repo")
       (check-equal? (agent-sandbox-alist-ref
                      (choice-value grant)
                      'op
                      #f)
                     'readwrite)
       (check-equal? (length (agent-sandbox-alist-ref patch 'grants '()))
                     1)
       (check-equal? (length (agent-sandbox-alist-ref patch 'skipped '()))
                     0)))
   (yuanxu-test-case "projects allowed nono why JSON into skip candidate"
     (let* ((why '((status . "allowed")
                   (reason . "granted_path")
                   (granted_path . "/repo")
                   (access . "read+write")
                   (source . "user")))
            (candidate
             (nono-why-json->agent-sandbox-profile-candidate
              why
              '((profile-ref . "developer"))))
            (choice (car (agent-sandbox-profile-candidate-choices candidate)))
            (patch (agent-sandbox-profile-candidate->patch candidate)))
       (check-equal? (choice-action choice) 'skip)
       (check-equal? (choice-section choice) 'filesystem)
       (check-equal? (agent-sandbox-alist-ref
                      (choice-value choice)
                      'granted-path
                      #f)
                     "/repo")
       (check-equal? (length (agent-sandbox-alist-ref patch 'grants '()))
                     0)
       (check-equal? (length (agent-sandbox-alist-ref patch 'skipped '()))
                     1)))
   (yuanxu-test-case "creates promotion request from denied nono why candidate"
     (let* ((why '((status . "denied")
                   (reason . "path_not_granted")
                   (suggested_flag . "--allow /repo")))
            (candidate
             (nono-why-json->agent-sandbox-profile-candidate
              why
              '((path . "/repo")
                (profile-ref . "developer"))))
            (request
             (agent-sandbox-profile-candidate->nono-promote-request
              candidate
              '((mode . diff)
                (draft-ref . "developer-draft")))))
       (check-equal? (agent-sandbox-profile-promotion-request? request) #t)
       (check-equal? (agent-sandbox-alist-ref request 'runtime-executed #t)
                     #f)
       (check-equal? (agent-sandbox-alist-ref request 'argv '())
                     '("nono" "profile" "promote" "--diff"
                       "developer-draft"))))))
