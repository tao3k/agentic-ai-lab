;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        :yuanxu/profile-composition/selection-syntax
        (only-in :agentic-ai-lab/modules/services/opentofu/objects OpenTofuScope. OpenTofuConfiguration.)
        (only-in :yuanxu/modules/json-schema/json-schema-diagnostics yuanxu-json-schema-validation-diagnostic-metadata yuanxu-json-schema-validation-diagnostic-reason)
        :yuanxu/object-types/contracts :clan/poo/object)
(export opentofu-configuration-discovery-test)

(def (assert label value)
  (unless value (error "assertion failed" label))
  (displayln "ASSERT-OK " label) (force-output))
(def (accepted? result) (yuanxu-validation-evidence-accepted? result))
(def (diagnostic-at result path)
  (find (lambda (diagnostic)
          (equal? (cdr (assoc 'path
                         (yuanxu-json-schema-validation-diagnostic-metadata diagnostic))) path))
        (.get result diagnostics)))
(def (cached? module name kind)
  (.call (.get module provider) .contract-cached? name kind))

(def opentofu-configuration-discovery-test
  (test-suite "opentofu-configuration-discovery-test"
    (yuanxu-test-case "final candidate discovers native Contracts without SelectedTypes"
      (def AWS (.get OpenTofuScope. modules aws))
      (def AWSCC (.get OpenTofuScope. modules awscc))
      (def Null (.get OpenTofuScope. modules null))
      ;; Upstream publishes the binding once. Neither keys nor values of all
      ;; bound modules may be traversed to discover a resource's owner.
      (.def (Infrastructure @ OpenTofuConfiguration.)
        modules: (.o aws: AWS awscc: AWSCC null: Null
                     unused: (error "unselected module was demanded")))
      (def Contract (.get Infrastructure types configuration))
      (def Context (.o request: 'discovery-control))
      (def (admit candidate)
        (use-module Infrastructure as tf
          (.call (.get tf types configuration) .admit candidate Context)))
      (assert 'contract-construction-keeps-packages-unforced
        (and (not (.ref/cached AWS 'provider)) (not (.ref/cached AWSCC 'provider))
             (not (.ref/cached Null 'provider))))
      (assert 'empty-configuration-admitted (accepted? (admit (.o))))
      (assert 'empty-admission-keeps-packages-unforced
        (and (not (.ref/cached AWS 'provider)) (not (.ref/cached AWSCC 'provider))
             (not (.ref/cached Null 'provider))))
      (assert 'malformed-envelope-rejected
        (not (accepted? (admit (.o resource: "wrong")))))
      (assert 'malformed-envelope-keeps-packages-unforced
        (and (not (.ref/cached AWS 'provider)) (not (.ref/cached AWSCC 'provider))
             (not (.ref/cached Null 'provider))))
      (def AwsOnly (.o resource: (.o aws_security_group: (.o web: (.o name: "web")))))
      (assert 'implicit-provider-resource-admitted (accepted? (admit AwsOnly)))
      (assert 'single-provider-demand-leaves-other-packages-unforced
        (and (not (.ref/cached AWSCC 'provider)) (not (.ref/cached Null 'provider))))
      (assert 'implicit-provider-does-not-compile-provider-config
        (not (cached? AWS 'provider 'provider)))
      (assert 'discovery-does-not-construct-type-catalog
        (not (.ref/cached (.get AWS provider) 'types)))
      (def Configuration
        (.o
          provider: (.o aws: (list (.o region: "us-east-1"))
                        awscc: (list (.o region: "us-east-1"))
                        null: (list (.o)))
          resource:
          (.o aws_security_group:
              (.o web: (.o name: "web" ingress:
                        (list (.o from_port: 443 to_port: 443 protocol: "tcp"
                                  cidr_blocks: '("10.0.0.0/16")))))
              awscc_ec2_security_group:
              (.o web: (.o group_description: "web" security_group_ingress:
                        (list (.o ip_protocol: "tcp" from_port: 443 to_port: 443
                                  cidr_ip: "10.0.0.0/16"))))
              null_resource: (.o smoke: (.o triggers: (.o release: "smoke"))))
          data:
          (.o aws_region: (.o current: (.o name: "us-east-1"))
              awscc_ec2_security_group: (.o existing: (.o id: "sg-1234"))
              null_data_source: (.o release: (.o inputs: (.o name: "smoke"))))))
      (def result (admit Configuration))
      (assert 'whole-configuration-admitted (accepted? result))
      (def children (.get result classification children))
      (assert 'nine-real-child-admissions (= (length children) 9))
      (assert 'children-receive-original-context
        (every (lambda (child) (eq? (.get child admission context) Context)) children))
      (assert 'native-child-admissions-all-accepted
        (every (lambda (child) (accepted? (.get child admission))) children))
      (def (child-at path)
        (find (lambda (child) (equal? (.get child path) path)) children))
      (def AwsProvider (.get (child-at '(provider aws 0)) contract))
      (def AwsccProvider (.get (child-at '(provider awscc 0)) contract))
      (def NullProvider (.get (child-at '(provider null 0)) contract))
      (assert 'provider-same-name-isolated
        (and (not (eq? (.get AwsProvider identity) (.get AwsccProvider identity)))
             (not (eq? (.get AwsProvider identity) (.get NullProvider identity)))
             (not (eq? (.get AwsccProvider identity) (.get NullProvider identity)))))
      (def AwsccResource (.get (child-at '(resource awscc_ec2_security_group web)) contract))
      (def AwsccData (.get (child-at '(data awscc_ec2_security_group existing)) contract))
      (assert 'resource-data-same-name-isolated
        (and (eq? (.get AwsccResource name) (.get AwsccData name))
             (not (eq? (.get AwsccResource identity) (.get AwsccData identity)))))
      (for-each
        (lambda (module contract version)
          (assert 'source-is-original-object (eq? (.get module source) (.get contract source)))
          (assert 'version-preserved (equal? (.get contract version) version))
          (assert 'digest-preserved
            (equal? (.get module source metadata schema-digest) (.get contract schema-digest))))
        (list AWS AWSCC Null) (list AwsProvider AwsccProvider NullProvider)
        '("5.100.0" "1.77.0" "3.2.4"))
      (def (reject-at candidate path)
        (let (failure (admit candidate))
          (assert 'full-error-path (and (not (accepted? failure)) (diagnostic-at failure path)))
          failure))
      (.def (WrongAWS @ Configuration)
        resource: =>.+ (.o aws_security_group: =>.+
          (.o web: =>.+ (.o ingress: (list (.o from_port: "wrong"))))))
      (def failure (reject-at WrongAWS '(resource aws_security_group web ingress 0 from_port)))
      (assert 'field-error-retains-provider-source
        (eq? (cdr (assoc 'source (yuanxu-json-schema-validation-diagnostic-metadata
                       (diagnostic-at failure '(resource aws_security_group web ingress 0 from_port)))))
             (.get AWS source)))
      (.def (WrongAWSCC @ Configuration)
        resource: =>.+ (.o awscc_ec2_security_group: =>.+
          (.o web: =>.+ (.o security_group_ingress: (list (.o from_port: "wrong"))))))
      (reject-at WrongAWSCC '(resource awscc_ec2_security_group web security_group_ingress 0 from_port))
      (.def (WrongNull @ Configuration)
        resource: =>.+ (.o null_resource: =>.+
          (.o smoke: =>.+ (.o triggers: (.o release: 42)))))
      (reject-at WrongNull '(resource null_resource smoke triggers release))
      (.def (WrongProvider @ Configuration)
        provider: =>.+ (.o null: (list (.o region: "us-east-1"))))
      (reject-at WrongProvider '(provider null 0 region))
      (.def (WrongData @ Configuration)
        data: =>.+ (.o awscc_ec2_security_group: =>.+
          (.o existing: (.o group_description: "resource-input"))))
      (reject-at WrongData '(data awscc_ec2_security_group existing id))
      (.def (WrongResource @ Configuration)
        resource: =>.+ (.o awscc_ec2_security_group: =>.+ (.o web: (.o id: "sg-1234"))))
      (reject-at WrongResource '(resource awscc_ec2_security_group web group_description))
      (def missing
        (reject-at (.o resource: (.o aws_not_a_real_type: (.o x: (.o))))
                   '(resource aws_not_a_real_type)))
      (assert 'unknown-type-reason
        (eq? (yuanxu-json-schema-validation-diagnostic-reason
               (diagnostic-at missing '(resource aws_not_a_real_type))) 'provider-type-not-found))
      (reject-at (.o resource: (.o absent_resource: (.o x: (.o)))) '(resource absent_resource))
      (assert 'unselected-binding-never-demanded
        (not (.ref/cached (.get Infrastructure modules) 'unused)))
      (assert 'unselected-aws-type-never-compiled (not (cached? AWS 'aws_iam_group 'resource)))
      (assert 'unselected-aws-data-never-compiled (not (cached? AWS 'aws_security_group 'data)))
      (assert 'unselected-awscc-type-never-compiled (not (cached? AWSCC 'awscc_s3_bucket 'resource)))
      (assert 'unselected-awscc-data-never-compiled (not (cached? AWSCC 'awscc_s3_bucket 'data)))
      (assert 'no-catalog-enumeration
        (every (lambda (module) (not (.ref/cached (.get module provider) 'types)))
               (list AWS AWSCC Null)))
      ;; The parent Contract is already cached. A new effective candidate must
      ;; discover its new type rather than inherit a stale SelectedTypes list.
      (.def (WithGroup @ Configuration)
        resource: =>.+ (.o aws_iam_group: (.o release: (.o name: "release"))))
      (def extended (admit WithGroup))
      (assert 'new-final-type-discovered (accepted? extended))
      (assert 'new-type-compiled-only-when-used (cached? AWS 'aws_iam_group 'resource))
      (assert 'ten-current-child-admissions (= (length (.get extended classification children)) 10))
      (assert 'old-admission-not-mutated (= (length (.get result classification children)) 9))
      (.def (Restricted @ Infrastructure) modules: (.o aws: AWS))
      (assert 'child-registry-does-not-reuse-parent-bindings
        (use-module Restricted as tf
          (not (accepted? (.call (.get tf types configuration) .admit Configuration Context)))))
      (assert 'parent-registry-still-admits (accepted? (admit Configuration)))
      (assert 'discovery-reuses-public-provider-contract
        (eq? AwsProvider (.get AWS types provider)))
      (assert 'discovery-reuses-public-resource-contract
        (eq? AwsccResource (.get AWSCC types resources awscc_ec2_security_group)))
      (assert 'discovery-reuses-public-data-contract
        (eq? AwsccData (.get AWSCC types data awscc_ec2_security_group)))
      (displayln "OPENTOFU-CONFIGURATION-DISCOVERY-OK"))))
