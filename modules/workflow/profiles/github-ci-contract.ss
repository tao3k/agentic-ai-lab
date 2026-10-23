;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Product workflow profile: GitHub Actions schema projection over Core's
;;; JSON Schema contracts. The generic Core Funflow publication stays independent
;;; of this optional GitHub-specific profile and its product-owned schema.

(import (only-in :clan/poo/object
                 object<-alist)
        (only-in :yuanxu/modules/json-schema/json-schema-receipt
                 yuanxu-json-schema->contract-artifact
                 yuanxu-json-schema-contract-artifact-object-contract
                 yuanxu-json-schema-contract-artifact->alist)
        (only-in :yuanxu/modules/json-schema/json-schema-validate
                 yuanxu-json-schema-contract-artifact-validate
                 yuanxu-json-schema-object-contract-validation->alist))

(export +agentic-ai-lab-funflow-github-ci-schema-source+
        +agentic-ai-lab-funflow-github-ci-workflow-schema+
        +agentic-ai-lab-funflow-github-ci-schema-audit+
        agentic-ai-lab-funflow-github-ci-contract-artifact
        agentic-ai-lab-funflow-github-ci-workflow-contract
        agentic-ai-lab-funflow-github-ci-contract-receipt
        agentic-ai-lab-funflow-github-ci-profile
        agentic-ai-lab-funflow-github-ci-validate-workflow
        agentic-ai-lab-funflow-github-ci-validate-workflow->alist)

;; : GithubWorkflowSchemaSourceURL
(def +agentic-ai-lab-funflow-github-ci-schema-source+
  "https://json.schemastore.org/github-workflow.json")

;; : PinnedGithubWorkflowSchemaAudit
(def +agentic-ai-lab-funflow-github-ci-schema-audit+
  '((source . "https://json.schemastore.org/github-workflow.json")
    (repo-path . "schemas/json/github-workflow.json")
    (sha256 . "7a952fdb7c1b130732e40ccea9db9bced906c1198e97834f8a49ae3b411f3161")
    (draft . "http://json-schema.org/draft-07/schema#")
    (bytes . 113286)
    (required-root-slots . ("on" "jobs"))
    (root-properties . ("concurrency" "defaults" "env" "jobs" "name" "on"
                        "permissions" "run-name"))
    (definitions-observed . 30)
    (unsupported-semantics-observed
     . ((patternProperties . 7)
        (if . 8)
        (then . 5)
        (not . 9)))
    (contract-scope . top-level-profile-shape)))

;;; Boundary: this curated schema fragment is derived from the pinned raw
;;; SchemaStore file, but it intentionally projects the Funflow profile shape
;;; we can enforce today. Dynamic job identifiers stay visible through
;;; patternProperties metadata until the bridge owns map-value contracts.
;; : FunflowGithubCiWorkflowJsonLikeSchema
(def +agentic-ai-lab-funflow-github-ci-workflow-schema+
  '((type . "object")
    (required . ("on" "jobs"))
    (additionalProperties . #f)
    (properties
     . ((name . ((type . "string")
                 (minLength . 1)))
        (run-name . ((type . "string")
                     (minLength . 1)))
        (on . ((oneOf . (((type . "string")
                          (minLength . 1))
                         ((type . "array")
                          (minItems . 1)
                          (items . ((type . "string")
                                    (minLength . 1))))
                         ((type . "object")
                          (minProperties . 1)
                          (additionalProperties . #t))))))
        (env . (($ref . "#/definitions/env")))
        (defaults . (($ref . "#/definitions/defaults")))
        (concurrency . ((oneOf . ((($ref . "#/definitions/concurrency"))
                                  ((type . "string")
                                   (minLength . 1))))))
        (permissions . (($ref . "#/definitions/permissions")))
        (jobs . ((type . "object")
                 (minProperties . 1)
                 (patternProperties
                  . (("^[_a-zA-Z][a-zA-Z0-9_-]*$"
                     . (($ref . "#/definitions/job")))))
                 (additionalProperties . #f)))))
    (definitions
     . ((env . ((type . "object")
                (additionalProperties
                 . ((oneOf . (((type . "string"))
                              ((type . "number"))
                              ((type . "boolean"))))))))
        (defaults . ((type . "object")
                     (properties
                      . ((run . ((type . "object")
                                 (properties
                                  . ((shell . ((type . "string")))
                                     (working-directory
                                      . ((type . "string")))))))))))
        (permissions . ((oneOf . (((type . "string")
                                   (enum . ("read-all" "write-all")))
                                  ((type . "object")
                                   (additionalProperties . #t))))))
        (concurrency . ((type . "object")
                        (required . ("group"))
                        (properties
                         . ((group . ((type . "string")
                                      (minLength . 1)))
                            (cancel-in-progress
                             . ((oneOf . (((type . "boolean"))
                                          ((type . "string"))))))))))
        (job . ((type . "object")
                (required . ("runs-on" "steps"))
                (properties
                 . ((name . ((type . "string")))
                    (runs-on . ((oneOf . (((type . "string")
                                           (minLength . 1))
                                          ((type . "array")
                                           (minItems . 1)
                                           (items . ((type . "string")
                                                     (minLength . 1))))))))
                    (needs . ((oneOf . (((type . "string"))
                                        ((type . "array")
                                         (items . ((type . "string"))))))))
                    (env . (($ref . "#/definitions/env")))
                    (steps . ((type . "array")
                              (minItems . 1)
                              (items . (($ref . "#/definitions/step")))))))))
        (step . ((type . "object")
                 (properties
                  . ((name . ((type . "string")))
                     (id . ((type . "string")
                            (pattern . "^[_a-zA-Z][a-zA-Z0-9_-]*$")))
                     (uses . ((type . "string")
                              (minLength . 1)))
                     (run . ((type . "string")
                             (minLength . 1)))
                     (shell . ((type . "string")))
                     (with . ((type . "object")))
                     (env . (($ref . "#/definitions/env")))))))))))

;; : YuanxuJsonSchemaContractArtifact
(def agentic-ai-lab-funflow-github-ci-contract-artifact
  (yuanxu-json-schema->contract-artifact
   +agentic-ai-lab-funflow-github-ci-workflow-schema+
   `((source-ref . ,+agentic-ai-lab-funflow-github-ci-schema-source+)
     (owner . funflow)
     (object-kind . AgenticAILabFunflowGithubCiWorkflow)
     (object-key . funflow/github-ci/workflow))))

;; : (-> YuanxuObjectTypeContract)
(def (agentic-ai-lab-funflow-github-ci-workflow-contract)
  (yuanxu-json-schema-contract-artifact-object-contract
   agentic-ai-lab-funflow-github-ci-contract-artifact))

;; : (-> Alist)
(def (agentic-ai-lab-funflow-github-ci-contract-receipt)
  (yuanxu-json-schema-contract-artifact->alist
   agentic-ai-lab-funflow-github-ci-contract-artifact))

;;; The profile object exposes the contract artifact as data for module-system
;;; composition. It does not load the raw JSON file at runtime and does not
;;; execute GitHub Actions; those are adapter/runtime responsibilities.
;; : AgenticAILabFunflowGithubCiProfileObject
(def agentic-ai-lab-funflow-github-ci-profile
  (object<-alist
   (list
    (cons 'kind 'agentic-ai-lab.funflow.github-ci.profile)
    (cons 'module 'funflow)
    (cons 'profile 'github-ci)
    (cons 'feature '+cicd)
    (cons 'schema-source +agentic-ai-lab-funflow-github-ci-schema-source+)
    (cons 'contract-artifact agentic-ai-lab-funflow-github-ci-contract-artifact)
    (cons 'schema-audit +agentic-ai-lab-funflow-github-ci-schema-audit+)
    (cons 'runtime-executed #f))))

;; : (-> AgenticAILabObjectOrAlist YuanxuJsonSchemaObjectContractValidation)
(def (agentic-ai-lab-funflow-github-ci-validate-workflow workflow)
  (yuanxu-json-schema-contract-artifact-validate
   agentic-ai-lab-funflow-github-ci-contract-artifact
   workflow))

;; : (-> AgenticAILabObjectOrAlist Alist)
(def (agentic-ai-lab-funflow-github-ci-validate-workflow->alist workflow)
  (yuanxu-json-schema-object-contract-validation->alist
   (agentic-ai-lab-funflow-github-ci-validate-workflow workflow)))
