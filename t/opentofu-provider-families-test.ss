;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        :yuanxu/profile-composition/selection-syntax
        (only-in :agentic-ai-lab/modules/services/opentofu/objects OpenTofuScope.)
        (only-in :yuanxu/modules/json-schema/json-schema-diagnostics yuanxu-json-schema-validation-diagnostic-metadata)
        :yuanxu/object-types/contracts :clan/poo/object)
(export opentofu-provider-families-test)

(def (assert label value)
  (unless value (error "assertion failed" label))
  (displayln "ASSERT-OK " label) (force-output))
(def (accepted? evidence) (yuanxu-validation-evidence-accepted? evidence))
(def (different? a b c) (and (not (eq? a b)) (not (eq? a c)) (not (eq? b c))))
(def (path? result expected)
  (find (lambda (d)
          (equal? (cdr (assoc 'path (yuanxu-json-schema-validation-diagnostic-metadata d))) expected))
        (.get result diagnostics)))
(def (verify-publication module contract address version directory)
  (assert 'contract-provider (equal? (.get contract provider) address))
  (assert 'contract-version (equal? (.get contract version) version))
  (assert 'generated-origin (eq? (.get module source kind) 'generated))
  (assert 'package-origin (equal? (.get module source value) directory))
  (assert 'origin-provider (equal? (.get module source metadata provider) address))
  (assert 'origin-version (equal? (.get module source metadata version) version))
  (assert 'origin-schema
    (equal? (.get module source metadata schema-digest) (.get contract schema-digest))))

(def opentofu-provider-families-test
  (test-suite "opentofu-provider-families-test"
    (yuanxu-test-case "three real Provider packages, native publication and admission"
      ;; One package collection supplies all leaf scopes, without per-provider ENV.
      (def AWS (.get OpenTofuScope. modules aws))
      (def AWSCC (.get OpenTofuScope. modules awscc))
      (def Null (.get OpenTofuScope. modules null))
      (def aws-path (.get AWS config provider-artifact))
      (def awscc-path (.get AWSCC config provider-artifact))
      (def null-path (.get Null config provider-artifact))
      (assert 'module-construction-inert
        (and (not (.ref/cached AWS 'provider)) (not (.ref/cached AWSCC 'provider))
             (not (.ref/cached Null 'provider))))
      (assert 'bounded-aliases-are-original-modules
        (and (use-module AWS as cloud (eq? cloud AWS))
             (use-module AWSCC as cloud (eq? cloud AWSCC))
             (use-module Null as cloud (eq? cloud Null))))
      (assert 'binding-does-not-load-packages
        (and (not (.ref/cached AWS 'provider)) (not (.ref/cached AWSCC 'provider))
             (not (.ref/cached Null 'provider))))
      (def AwsWeb
        (.o name: "web" ingress:
          (list (.o from_port: 443 to_port: 443 protocol: "tcp"
                    cidr_blocks: '("10.0.0.0/16")))))
      (def aws-result
        (use-module AWS as cloud
          (.call (.get cloud types resources aws_security_group) .admit AwsWeb #f)))
      (assert 'aws-resource-admitted (accepted? aws-result))
      (assert 'aws-demand-leaves-other-modules-unforced
        (and (not (.ref/cached AWSCC 'provider)) (not (.ref/cached Null 'provider))))
      (assert 'resource-demand-does-not-force-provider-config
        (not (.ref/cached (.get AWS types) 'provider)))
      (assert 'aws-unselected-resource-lazy
        (not (.ref/cached (.get AWS types resources) 'aws_iam_group_membership)))
      (def AwsccWeb
        (.o group_description: "web" security_group_ingress:
          (list (.o ip_protocol: "tcp" from_port: 443 to_port: 443
                    cidr_ip: "10.0.0.0/16"))))
      (def awscc-result
        (use-module AWSCC as cloud
          (.call (.get cloud types resources awscc_ec2_security_group) .admit AwsccWeb #f)))
      (assert 'awscc-resource-admitted (accepted? awscc-result))
      (assert 'awscc-demand-leaves-null-unforced (not (.ref/cached Null 'provider)))
      (assert 'awscc-unselected-resource-lazy
        (not (.ref/cached (.get AWSCC types resources) 'awscc_s3_bucket)))
      ;; All three real exports have the same provider configuration node.
      ;; No resource or Schema field is renamed to manufacture a collision.
      (def AwsConfig (use-module AWS as cloud (.get cloud types provider)))
      (def AwsccConfig (use-module AWSCC as cloud (.get cloud types provider)))
      (def NullConfig (use-module Null as cloud (.get cloud types provider)))
      (assert 'same-name-provider-contract-objects-isolated (different? AwsConfig AwsccConfig NullConfig))
      (assert 'same-name-provider-contract-identities-isolated
        (different? (.get AwsConfig identity) (.get AwsccConfig identity) (.get NullConfig identity)))
      (assert 'null-config-demand-leaves-resource-catalog-unforced
        (not (.ref/cached (.get Null types) 'resources)))
      (assert 'aws-config-admitted
        (use-module AWS as cloud
          (accepted? (.call (.get cloud types provider) .admit (.o region: "us-east-1") #f))))
      (assert 'awscc-config-admitted
        (use-module AWSCC as cloud
          (accepted? (.call (.get cloud types provider) .admit (.o region: "us-east-1") #f))))
      (assert 'null-empty-config-admitted
        (use-module Null as cloud
          (accepted? (.call (.get cloud types provider) .admit (.o) #f))))
      (assert 'aws-specific-config-accepted-by-aws
        (use-module AWS as cloud
          (accepted? (.call (.get cloud types provider) .admit (.o skip_credentials_validation: #t) #f))))
      (assert 'aws-specific-config-rejected-by-awscc
        (use-module AWSCC as cloud
          (not (accepted? (.call (.get cloud types provider) .admit (.o skip_credentials_validation: #t) #f)))))
      (assert 'region-rejected-by-null
        (use-module Null as cloud
          (not (accepted? (.call (.get cloud types provider) .admit (.o region: "us-east-1") #f)))))
      (def NullCheck (.o triggers: (.o release: "smoke")))
      (def null-result
        (use-module Null as cloud
          (.call (.get cloud types resources null_resource) .admit NullCheck #f)))
      (assert 'null-resource-admitted (accepted? null-result))
      (assert 'null-config-rejects-resource-fields
        (use-module Null as cloud
          (not (accepted? (.call (.get cloud types provider) .admit NullCheck #f)))))
      (def AwsResource (.get AWS types resources aws_security_group))
      (def AwsccResource (.get AWSCC types resources awscc_ec2_security_group))
      (def NullResource (.get Null types resources null_resource))
      (verify-publication AWS AwsResource "registry.opentofu.org/hashicorp/aws" "5.100.0" aws-path)
      (verify-publication AWSCC AwsccResource "registry.opentofu.org/hashicorp/awscc" "1.77.0" awscc-path)
      (verify-publication Null NullResource "registry.opentofu.org/hashicorp/null" "3.2.4" null-path)
      (assert 'provider-config-source-identity
        (and (equal? (.get AwsConfig provider) (.get AwsResource provider))
             (equal? (.get AwsccConfig provider) (.get AwsccResource provider))
             (equal? (.get NullConfig provider) (.get NullResource provider))))
      (assert 'provider-config-version-identity
        (and (equal? (.get AwsConfig version) "5.100.0")
             (equal? (.get AwsccConfig version) "1.77.0")
             (equal? (.get NullConfig version) "3.2.4")))
      (assert 'same-name-config-schema-origin
        (and (equal? (.get AwsConfig schema-digest) (.get AWS source metadata schema-digest))
             (equal? (.get AwsccConfig schema-digest) (.get AWSCC source metadata schema-digest))
             (equal? (.get NullConfig schema-digest) (.get Null source metadata schema-digest))))
      (assert 'admissions-name-own-contracts
        (and (eq? (.get aws-result contract-identity) (.get AwsResource identity))
             (eq? (.get awscc-result contract-identity) (.get AwsccResource identity))
             (eq? (.get null-result contract-identity) (.get NullResource identity))))
      (assert 'memoized-config-contracts
        (and (eq? AwsConfig (.get AWS types provider))
             (eq? AwsccConfig (.get AWSCC types provider))
             (eq? NullConfig (.get Null types provider))))
      (def wrong-aws
        (use-module AWS as cloud
          (.call (.get cloud types resources aws_security_group) .admit
            (.cc AwsWeb 'ingress (list (.o from_port: "wrong"))) #f)))
      (assert 'aws-port-type-path (and (not (accepted? wrong-aws)) (path? wrong-aws '(ingress 0 from_port))))
      (def wrong-awscc
        (use-module AWSCC as cloud
          (.call (.get cloud types resources awscc_ec2_security_group) .admit
            (.cc AwsccWeb 'security_group_ingress (list (.o from_port: "wrong"))) #f)))
      (assert 'awscc-port-type-path
        (and (not (accepted? wrong-awscc)) (path? wrong-awscc '(security_group_ingress 0 from_port))))
      (def wrong-null
        (use-module Null as cloud
          (.call (.get cloud types resources null_resource) .admit (.o triggers: (.o release: 42)) #f)))
      (assert 'null-trigger-type-path
        (and (not (accepted? wrong-null)) (path? wrong-null '(triggers release))))
      (assert 'aws-config-not-null-config (not (equal? (.get AwsConfig schema) (.get NullConfig schema))))
      (assert 'null-data-branch-still-unforced (not (.ref/cached (.get Null types) 'data)))
      (assert 'aws-data-branch-still-unforced (not (.ref/cached (.get AWS types) 'data)))
      (assert 'awscc-data-branch-starts-unforced (not (.ref/cached (.get AWSCC types) 'data)))
      ;; A second genuine name collision: resource and data share the identical
      ;; awscc_ec2_security_group name in the unmodified real export.
      (def Lookup (.o id: "sg-1234"))
      (def lookup-result
        (use-module AWSCC as cloud
          (.call (.get cloud types data awscc_ec2_security_group) .admit Lookup #f)))
      (def AwsccData (.get AWSCC types data awscc_ec2_security_group))
      (assert 'awscc-same-name-data-admitted (accepted? lookup-result))
      (assert 'same-name-resource-data-contracts-isolated (not (eq? AwsccResource AwsccData)))
      (assert 'same-name-resource-data-identities-isolated
        (not (eq? (.get AwsccResource identity) (.get AwsccData identity))))
      (assert 'data-rejects-resource-input
        (use-module AWSCC as cloud
          (not (accepted? (.call (.get cloud types data awscc_ec2_security_group) .admit AwsccWeb #f)))))
      (assert 'resource-rejects-data-input
        (use-module AWSCC as cloud
          (not (accepted? (.call (.get cloud types resources awscc_ec2_security_group) .admit Lookup #f)))))
      (assert 'data-contract-version-preserved (equal? (.get AwsccData version) "1.77.0"))
      (assert 'same-name-data-source-metadata
        (and (equal? (.get AwsccData provider) (.get AWSCC source metadata provider))
             (equal? (.get AwsccData schema-digest) (.get AWSCC source metadata schema-digest))))
      (assert 'data-admission-names-own-contract
        (eq? (.get lookup-result contract-identity) (.get AwsccData identity)))
      (assert 'other-awscc-data-stays-unforced
        (not (.ref/cached (.get AWSCC types data) 'awscc_s3_bucket)))
      (assert 'resource-cache-unchanged-after-data-demand
        (eq? AwsccResource (.get AWSCC types resources awscc_ec2_security_group)))
      (displayln "OPENTOFU-PROVIDER-FAMILIES-OK"))))
