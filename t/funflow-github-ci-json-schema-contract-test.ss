;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Funflow: GitHub CI profile contract backed by JSON Schema projection.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object
                 object<-alist)
        (only-in :std/encoding/json
                 JSONReadOptions
                 string->json)
        (only-in :yuanxu/module-system/schema/slot-contracts
                 yuanxu-contract-slot-name
                 yuanxu-object-contract-slots)
        (only-in :yuanxu/modules/json-schema/json-schema-source
                 yuanxu-json-schema-read-file)
        (only-in :yuanxu/modules/json-schema/json-schema-receipt
                 yuanxu-json-schema->contract-artifact
                 yuanxu-json-schema-contract-artifact-object-contract
                 yuanxu-json-schema-contract-artifact->alist)
        (only-in :agentic-ai-lab/modules/workflow/profiles/github-ci-contract
                 +agentic-ai-lab-funflow-github-ci-schema-audit+
                 agentic-ai-lab-funflow-github-ci-contract-receipt
                 agentic-ai-lab-funflow-github-ci-validate-workflow->alist))

(export funflow-github-ci-json-schema-contract-test)

;; : (-> Alist Symbol Object)
(def (funflow-github-ci-test-ref rows key)
  (let (entry (assoc key rows))
    (if entry (cdr entry) #f)))

;; : (-> Alist Symbol Object)
(def (funflow-github-ci-audit-ref key)
  (funflow-github-ci-test-ref
   +agentic-ai-lab-funflow-github-ci-schema-audit+
   key))

;; : (-> Object [Object] Boolean)
(def (funflow-github-ci-member? value values)
  (if (member value values) #t #f))

;; : Alist
(def funflow-github-ci-valid-workflow
  '((name . "Agentic AI Lab CI")
    (on . ("push" "pull_request"))
    (jobs . ((build . ((runs-on . "macos-latest")
                       (steps . (((run . "gxpkg build -g"))))))))))

;; : AgenticAILabObject
(def funflow-github-ci-valid-poo-workflow
  (object<-alist
   '((name . "Agentic AI Lab CI")
     (on . ((push . #t)))
     (jobs . ((build . ((runs-on . "ubuntu-latest")
                        (steps . (((uses . "actions/checkout@v4")))))))))))

;; : Alist
(def funflow-github-ci-missing-jobs-workflow
  '((name . "Agentic AI Lab CI")
    (on . "push")))

;; : Alist
(def funflow-github-ci-empty-jobs-workflow
  '((name . "Agentic AI Lab CI")
    (on . "push")
    (jobs . ())))

;; : Alist
(def funflow-github-ci-missing-runs-on-workflow
  '((name . "Agentic AI Lab CI")
    (on . "push")
    (jobs . ((build . ((steps . (((run . "gxpkg build -g"))))))))))

;; : Alist
(def funflow-github-ci-invalid-job-key-workflow
  '((name . "Agentic AI Lab CI")
    (on . "push")
    (jobs . ((1bad . ((runs-on . "ubuntu-latest")
                      (steps . (((run . "gxpkg build -g"))))))))))

;; : Alist
(def funflow-github-ci-invalid-step-id-workflow
  '((name . "Agentic AI Lab CI")
    (on . "push")
    (jobs . ((build . ((runs-on . "ubuntu-latest")
                       (steps . (((id . "bad id")
                                  (run . "gxpkg build -g"))))))))))

;; : String
(def funflow-github-ci-native-json
  "{\"name\":\"Agentic AI Lab CI\",\"on\":\"push\",\"jobs\":{\"build\":{\"runs-on\":\"ubuntu-latest\",\"steps\":[{\"run\":\"gxpkg build -g\"}]}}}")

;; : TestSuite
(def funflow-github-ci-json-schema-contract-test
  (test-suite "funflow github-ci json schema contract"
    (yuanxu-test-case "keeps the upstream workflow schema pinned in the repo"
      (let ((receipt (agentic-ai-lab-funflow-github-ci-contract-receipt)))
        (check-equal?
         (funflow-github-ci-audit-ref 'repo-path)
         "schemas/json/github-workflow.json")
        (check-equal?
         (funflow-github-ci-audit-ref 'sha256)
         "7a952fdb7c1b130732e40ccea9db9bced906c1198e97834f8a49ae3b411f3161")
        (check-equal? (funflow-github-ci-test-ref receipt 'valid?) #t)
        (check-equal? (funflow-github-ci-test-ref receipt 'diagnostic-count) 0)))
    (yuanxu-test-case "feeds the pinned raw github workflow schema into the bridge"
      (let* ((schema
              (yuanxu-json-schema-read-file
               "schemas/json/github-workflow.json"))
             (artifact
              (yuanxu-json-schema->contract-artifact
               schema
               '((source-ref . schemas/json/github-workflow.json)
                 (owner . funflow)
                 (object-kind . AgenticAILabFunflowPinnedGithubWorkflow)
                 (object-key . funflow/github-ci/pinned-workflow))))
             (receipt
              (yuanxu-json-schema-contract-artifact->alist artifact))
             (slots
              (map
               yuanxu-contract-slot-name
               (yuanxu-object-contract-slots
                (yuanxu-json-schema-contract-artifact-object-contract
                 artifact)))))
        (check-equal? (funflow-github-ci-test-ref receipt 'valid?) #t)
        (check-equal? (funflow-github-ci-member? 'on slots) #t)
        (check-equal? (funflow-github-ci-member? 'jobs slots) #t)
        (check-equal?
         (>= (funflow-github-ci-test-ref receipt 'diagnostic-count) 1)
         #t)))
    (yuanxu-test-case "validates top-level github workflow profile shape"
      (let ((alist-receipt
             (agentic-ai-lab-funflow-github-ci-validate-workflow->alist
              funflow-github-ci-valid-workflow))
            (poo-receipt
             (agentic-ai-lab-funflow-github-ci-validate-workflow->alist
              funflow-github-ci-valid-poo-workflow)))
        (check-equal? (funflow-github-ci-test-ref alist-receipt 'valid?) #t)
        (check-equal? (funflow-github-ci-test-ref alist-receipt 'checked-slots)
                      '(name run-name on env defaults concurrency permissions jobs))
        (check-equal? (funflow-github-ci-test-ref poo-receipt 'valid?) #t)))
    (yuanxu-test-case "validates native JSON hash objects directly"
      (let* ((string-key-workflow
              (string->json funflow-github-ci-native-json
                            (JSONReadOptions object-as-hash: #t)))
             (symbol-key-workflow
              (string->json funflow-github-ci-native-json
                            (JSONReadOptions object-as-hash: #t
                                             key-as-symbol: #t)))
             (string-key-receipt
              (agentic-ai-lab-funflow-github-ci-validate-workflow->alist
               string-key-workflow))
             (symbol-key-receipt
              (agentic-ai-lab-funflow-github-ci-validate-workflow->alist
               symbol-key-workflow)))
        (check-equal? (hash-table? string-key-workflow) #t)
        (check-equal? (hash-table? symbol-key-workflow) #t)
        (check-equal?
         (funflow-github-ci-test-ref string-key-receipt 'valid?)
         #t)
        (check-equal?
         (funflow-github-ci-test-ref symbol-key-receipt 'valid?)
         #t)))
    (yuanxu-test-case "rejects missing and empty required workflow slots"
      (let ((missing-receipt
             (agentic-ai-lab-funflow-github-ci-validate-workflow->alist
              funflow-github-ci-missing-jobs-workflow))
            (empty-receipt
             (agentic-ai-lab-funflow-github-ci-validate-workflow->alist
              funflow-github-ci-empty-jobs-workflow)))
        (check-equal? (funflow-github-ci-test-ref missing-receipt 'valid?) #f)
        (check-equal? (funflow-github-ci-test-ref missing-receipt
                                                  'missing-required)
                      '(jobs))
        (check-equal? (funflow-github-ci-test-ref empty-receipt 'valid?) #f)
        (check-equal? (funflow-github-ci-test-ref empty-receipt 'invalid-slots)
                      '(jobs))))
    (yuanxu-test-case "recursively validates dynamic job ids and job bodies"
      (let ((missing-runs-on
             (agentic-ai-lab-funflow-github-ci-validate-workflow->alist
              funflow-github-ci-missing-runs-on-workflow))
            (invalid-job-key
             (agentic-ai-lab-funflow-github-ci-validate-workflow->alist
              funflow-github-ci-invalid-job-key-workflow))
            (invalid-step-id
             (agentic-ai-lab-funflow-github-ci-validate-workflow->alist
              funflow-github-ci-invalid-step-id-workflow)))
        (check-equal? (funflow-github-ci-test-ref missing-runs-on 'valid?) #f)
        (check-equal? (funflow-github-ci-test-ref missing-runs-on
                                                  'missing-required)
                      '(jobs/build/runs-on))
        (check-equal? (funflow-github-ci-test-ref invalid-job-key 'valid?) #f)
        (check-equal? (funflow-github-ci-test-ref invalid-job-key
                                                  'invalid-slots)
                      '(jobs/1bad))
        (check-equal? (funflow-github-ci-test-ref invalid-step-id 'valid?) #f)
        (check-equal? (funflow-github-ci-test-ref invalid-step-id
                                                  'invalid-slots)
                      '(jobs/build/steps/0/id))))))
