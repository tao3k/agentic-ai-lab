;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Funflow profile contract: GitHub Actions workflow schema projection.
;;; Invariant: this module owns a Funflow profile contract surface only. GitHub
;;; execution, API adapters, and CI runners remain outside the Scheme core.

(import (only-in :clan/poo/object
                 object<-alist)
        (only-in :core/modules/json-schema/json-schema-receipt
                 poo-flow-json-schema->contract-artifact
                 poo-flow-json-schema-contract-artifact-object-contract
                 poo-flow-json-schema-contract-artifact->alist)
        (only-in :core/modules/json-schema/json-schema-validate
                 poo-flow-json-schema-contract-artifact-validate
                 poo-flow-json-schema-object-contract-validation->alist))

(export +poo-flow-funflow-github-ci-schema-source+
        +poo-flow-funflow-github-ci-workflow-schema+
        +poo-flow-funflow-github-ci-schema-audit+
        poo-flow-funflow-github-ci-contract-artifact
        poo-flow-funflow-github-ci-workflow-contract
        poo-flow-funflow-github-ci-contract-receipt
        poo-flow-funflow-github-ci-profile
        poo-flow-funflow-github-ci-validate-workflow
        poo-flow-funflow-github-ci-validate-workflow->alist)

;; : GithubWorkflowSchemaSourceURL
(def +poo-flow-funflow-github-ci-schema-source+
  "https://json.schemastore.org/github-workflow.json")

;; : PinnedGithubWorkflowSchemaAudit
(def +poo-flow-funflow-github-ci-schema-audit+
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
(def +poo-flow-funflow-github-ci-workflow-schema+
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

;; : PooFlowJsonSchemaContractArtifact
(def poo-flow-funflow-github-ci-contract-artifact
  (poo-flow-json-schema->contract-artifact
   +poo-flow-funflow-github-ci-workflow-schema+
   `((source-ref . ,+poo-flow-funflow-github-ci-schema-source+)
     (owner . funflow)
     (object-kind . PooFlowFunflowGithubCiWorkflow)
     (object-key . funflow/github-ci/workflow))))

;; : (-> PooFlowObjectTypeContract)
(def (poo-flow-funflow-github-ci-workflow-contract)
  (poo-flow-json-schema-contract-artifact-object-contract
   poo-flow-funflow-github-ci-contract-artifact))

;; : (-> Alist)
(def (poo-flow-funflow-github-ci-contract-receipt)
  (poo-flow-json-schema-contract-artifact->alist
   poo-flow-funflow-github-ci-contract-artifact))

;;; The profile object exposes the contract artifact as data for module-system
;;; composition. It does not load the raw JSON file at runtime and does not
;;; execute GitHub Actions; those are adapter/runtime responsibilities.
;; : PooFlowFunflowGithubCiProfileObject
(def poo-flow-funflow-github-ci-profile
  (object<-alist
   (list
    (cons 'kind 'poo-flow.funflow.github-ci.profile)
    (cons 'module 'funflow)
    (cons 'profile 'github-ci)
    (cons 'feature '+cicd)
    (cons 'schema-source +poo-flow-funflow-github-ci-schema-source+)
    (cons 'contract-artifact poo-flow-funflow-github-ci-contract-artifact)
    (cons 'schema-audit +poo-flow-funflow-github-ci-schema-audit+)
    (cons 'runtime-executed #f))))

;; : (-> PooFlowObjectOrAlist PooFlowJsonSchemaObjectContractValidation)
(def (poo-flow-funflow-github-ci-validate-workflow workflow)
  (poo-flow-json-schema-contract-artifact-validate
   poo-flow-funflow-github-ci-contract-artifact
   workflow))

;; : (-> PooFlowObjectOrAlist Alist)
(def (poo-flow-funflow-github-ci-validate-workflow->alist workflow)
  (poo-flow-json-schema-object-contract-validation->alist
   (poo-flow-funflow-github-ci-validate-workflow workflow)))
