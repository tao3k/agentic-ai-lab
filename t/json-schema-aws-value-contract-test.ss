;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Opt-in: existing acquired AWS 5.100.0 provider export, no network or Loader.
(import :std/test :clan/poo/object
        (only-in :clan/poo/mop element? validate)
        :clan/poo/object-contract
        :yuanxu/modules/json-schema/contracts
        (only-in :yuanxu/modules/json-schema/json-schema-source yuanxu-json-schema-read-file)
        (only-in :yuanxu/modules/json-schema/functional yuanxu-contract-object-ref)
        (only-in :agentic-ai-lab/modules/services/opentofu/func agentic-ai-lab-opentofu-block->schema))
(export json-schema-aws-value-contract-test)

(def (ref value key) (yuanxu-contract-object-ref value key #f))
(def source-path (or (getenv "YUANXU_JSON_SCHEMA_AWS_EXPORT")
                     (error "Set YUANXU_JSON_SCHEMA_AWS_EXPORT to the acquired AWS provider export")))
(def provider-export (yuanxu-json-schema-read-file source-path))
(def providers (ref provider-export 'provider_schemas))
(def tofu-provider (ref providers 'registry.opentofu.org/hashicorp/aws))
(def terraform-provider (ref providers 'registry.terraform.io/hashicorp/aws))
(when (and tofu-provider terraform-provider)
  (error "Select one exact AWS provider export, not two registry identities"))
(def provider (or tofu-provider terraform-provider))
(unless provider (error "Expected the AWS provider export"))
(def resources (ref provider 'resource_schemas))
(def vpc-input (agentic-ai-lab-opentofu-block->schema (ref (ref resources 'aws_vpc) 'block)))
(def instance-input (agentic-ai-lab-opentofu-block->schema (ref (ref resources 'aws_instance) 'block)))
(def VpcContract (schema-value-contract 'aws/vpc vpc-input))
(def InstanceContract (schema-value-contract 'aws/instance instance-input))
(def ProfileContract
  (.cc ObjectContract. responsibilities: (.o network: VpcContract web: InstanceContract)))
(def ScenarioContract
  (.cc ProjectionContract. constraint: ProfileContract
       project: (lambda (scenario) (.get scenario config))))

(.def (Parent @ [] config)
  config:
  (.o network: (.o cidr_block: "10.1.0.0/16" tags: (.o Owner: "platform"))
      web: (.o ami: "ami-fixture" instance_type: "t3.small"
               tags: (.o Owner: "platform")))
  resource:
  (.o instance_type: (.get config web instance_type)
      tags: (.get config web tags)))

(def json-schema-aws-value-contract-test
  (test-suite "Actual AWS provider inputs through JsonSchema value contracts"
    (test-case "real resource schemas compile and admit independent POO data"
      (check-equal? (element? ProfileContract (.get Parent config)) #t)
      (check-equal? (diagnose ProfileContract (.get Parent config)) '())
      (check-equal? (eq? (validate ScenarioContract Parent) Parent) #t)
      (def checked (validate ProfileContract (.get Parent config)))
      (check-equal? (diagnose ProfileContract checked) '())
      (check-equal? (.get checked web instance_type) "t3.small"))
    (test-case "real provider schema rejects spelling and computed-only attributes"
      (.def (typo @ (.get Parent config)) web: =>.+ (.o instnace_type: "t3.medium"))
      (check-equal? (element? ProfileContract typo) #f)
      (check-equal? (.get (car (diagnose ProfileContract typo)) path) '(web instnace_type))
      (.def (computed @ (.get Parent config)) network: =>.+ (.o arn: "not-a-configurable-input"))
      (check-equal? (element? ProfileContract computed) #f))
    (test-case "real input types and nested field vocabulary are checked"
      (.def (wrong @ (.get Parent config)) web: =>.+ (.o instance_type: 42))
      (check-equal? (element? ProfileContract wrong) #f)
      (check-equal? (.get (car (diagnose ProfileContract wrong)) path) '(web instance_type))
      ;; root_block_device is a real nested block; its field vocabulary stays closed.
      (.def (nested @ (.get Parent config))
        web: =>.+ (.o root_block_device: (list (.o volume_szie: 16))))
      (check-equal? (element? ProfileContract nested) #f))
    (test-case "parent-cached projection reads final child AWS fields and inherited tags"
      (def old-type (.get Parent resource instance_type))
      (def old-tags (.get Parent resource tags))
      (check-equal? (diagnose ProfileContract (.get Parent config)) '())
      (.def (Release @ Parent)
        config: =>.+
        (.o web: =>.+
            (.o instance_type: "t3.medium" tags: =>.+ (.o Environment: "production"))))
      (check-equal? (.get Release resource instance_type) "t3.medium")
      (check-equal? (.get Release resource tags Owner) "platform")
      (check-equal? (.get Release resource tags Environment) "production")
      (check-equal? (.slot? old-tags 'Environment) #f)
      (check-equal? old-type "t3.small")
      (check-equal? (diagnose ProfileContract (.get Release config)) '())
      (check-equal? (eq? (validate ScenarioContract Release) Release) #t)
      (check-equal? (eq? (.get Release config) (.get Parent config)) #f))))
