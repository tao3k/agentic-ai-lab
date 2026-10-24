;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :std/list/list delete-duplicates/hash)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        :yuanxu/profile-composition/selection-syntax
        (only-in :agentic-ai-lab/modules/services/opentofu/objects OpenTofuScope. agentic-ai-lab-opentofu-configuration-from-types)
        (only-in :yuanxu/modules/json-schema/json-schema-diagnostics yuanxu-json-schema-validation-diagnostic-metadata)
        :yuanxu/object-types/contracts :clan/poo/object)
(export opentofu-configuration-families-test)

(def (assert label value)
  (unless value (error "assertion failed" label))
  (displayln "ASSERT-OK " label) (force-output))
(def (accepted? result) (yuanxu-validation-evidence-accepted? result))
(def (path? result expected)
  (find (lambda (diagnostic)
          (equal? (cdr (assoc 'path
                         (yuanxu-json-schema-validation-diagnostic-metadata diagnostic)))
                  expected))
        (.get result diagnostics)))

(def opentofu-configuration-families-test
  (test-suite "opentofu-configuration-families-test"
    (yuanxu-test-case "one configuration, three actual Provider packages"
      ;; Only package/test integration supplies these paths.
      (def AWS (.get OpenTofuScope. modules aws))
      (def AWSCC (.get OpenTofuScope. modules awscc))
      (def Null (.get OpenTofuScope. modules null))
      (def SelectedTypes
        (use-module AWS as aws-scope
          (use-module AWSCC as awscc-scope
            (use-module Null as null-scope
              (.o
                provider: (.o aws: (.get aws-scope types provider)
                              awscc: (.get awscc-scope types provider)
                              null: (.get null-scope types provider))
                resource:
                (.o aws_security_group: (.get aws-scope types resources aws_security_group)
                    awscc_ec2_security_group: (.get awscc-scope types resources awscc_ec2_security_group)
                    null_resource: (.get null-scope types resources null_resource))
                data:
                (.o aws_region: (.get aws-scope types data aws_region)
                    awscc_ec2_security_group: (.get awscc-scope types data awscc_ec2_security_group)
                    null_data_source: (.get null-scope types data null_data_source)))))))
      (assert 'selection-declaration-inert
        (and (not (.ref/cached AWS 'provider)) (not (.ref/cached AWSCC 'provider))
             (not (.ref/cached Null 'provider))))
      (def ConfigurationContract
        (agentic-ai-lab-opentofu-configuration-from-types SelectedTypes))
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
      (def result (.call ConfigurationContract .admit Configuration #f))
      (assert 'whole-configuration-admitted (accepted? result))
      (assert 'selected-native-types-retained
        (eq? SelectedTypes (.get ConfigurationContract selected-types)))
      (def provider-types (.get SelectedTypes provider))
      (def AwsProvider (.get provider-types aws))
      (def AwsccProvider (.get provider-types awscc))
      (def NullProvider (.get provider-types null))
      (assert 'three-provider-names-identical
        (every (lambda (contract) (eq? (.get contract name) 'provider))
               (list AwsProvider AwsccProvider NullProvider)))
      (assert 'provider-identities-isolated
        (= 3 (length (delete-duplicates/hash
                        (map (lambda (contract) (.get contract identity))
                             (list AwsProvider AwsccProvider NullProvider))))))
      (assert 'awscc-resource-data-same-name
        (eq? (.get SelectedTypes resource awscc_ec2_security_group name)
             (.get SelectedTypes data awscc_ec2_security_group name)))
      (assert 'awscc-resource-data-distinct-identity
        (not (eq? (.get SelectedTypes resource awscc_ec2_security_group identity)
                  (.get SelectedTypes data awscc_ec2_security_group identity))))
      (for-each
        (lambda (module provider-contract version)
          (assert 'actual-version (equal? (.get provider-contract version) version))
          (assert 'source-provider
            (equal? (.get module source metadata provider) (.get provider-contract provider)))
          (assert 'source-digest
            (equal? (.get module source metadata schema-digest) (.get provider-contract schema-digest)))
          (assert 'contract-retains-native-source
            (eq? (.get module source) (.get provider-contract source))))
        (list AWS AWSCC Null) (list AwsProvider AwsccProvider NullProvider)
        '("5.100.0" "1.77.0" "3.2.4"))
      (def (reject-at candidate expected)
        (let (failure (.call ConfigurationContract .admit candidate #f))
          (assert 'full-error-path (and (not (accepted? failure)) (path? failure expected)))))
      (.def (WrongAWS @ Configuration)
        resource: =>.+ (.o aws_security_group: =>.+
          (.o web: =>.+ (.o ingress: (list (.o from_port: "wrong"))))))
      (reject-at WrongAWS '(resource aws_security_group web ingress 0 from_port))
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
        resource: =>.+ (.o awscc_ec2_security_group: =>.+
          (.o web: (.o id: "sg-1234"))))
      (reject-at WrongResource '(resource awscc_ec2_security_group web group_description))
      (.def (UnknownResource @ Configuration)
        resource: =>.+ (.o aws_s3_bucket: (.o unseen: (.o bucket: "unselected"))))
      (reject-at UnknownResource '(resource aws_s3_bucket))
      (assert 'unselected-aws-resource-stays-lazy
        (not (.ref/cached (.get AWS types resources) 'aws_s3_bucket)))
      (assert 'unselected-aws-data-stays-lazy
        (not (.ref/cached (.get AWS types data) 'aws_security_group)))
      (assert 'unselected-awscc-resource-stays-lazy
        (not (.ref/cached (.get AWSCC types resources) 'awscc_s3_bucket)))
      (assert 'unselected-awscc-data-stays-lazy
        (not (.ref/cached (.get AWSCC types data) 'awscc_s3_bucket)))
      ;; Null has only one resource and one data type; both are selected here.
      (assert 'wrong-kind-selection-rejected
        (with-catch (lambda (_) #t)
          (lambda ()
            (agentic-ai-lab-opentofu-configuration-from-types
              (.cc SelectedTypes 'resource (.o awscc_ec2_security_group:
                                              (.get SelectedTypes data awscc_ec2_security_group))))
            #f)))
      (assert 'different-package-schema-rejected
        (with-catch (lambda (_) #t)
          (lambda ()
            (agentic-ai-lab-opentofu-configuration-from-types
              (.cc SelectedTypes 'provider (.o aws: (.cc AwsProvider 'version "stale")
                                               awscc: AwsccProvider null: NullProvider)))
            #f)))
      (assert 'different-schema-digest-rejected
        (with-catch (lambda (_) #t)
          (lambda ()
            (agentic-ai-lab-opentofu-configuration-from-types
              (.cc SelectedTypes 'provider (.o aws: (.cc AwsProvider 'schema-digest "stale")
                                               awscc: AwsccProvider null: NullProvider)))
            #f)))
      (assert 'different-provider-address-rejected
        (with-catch (lambda (_) #t)
          (lambda ()
            (agentic-ai-lab-opentofu-configuration-from-types
              (.cc SelectedTypes 'provider (.o aws: (.cc AwsProvider 'provider "wrong/address")
                                               awscc: AwsccProvider null: NullProvider)))
            #f)))
      (assert 'wrong-resource-name-rejected
        (with-catch (lambda (_) #t)
          (lambda ()
            (agentic-ai-lab-opentofu-configuration-from-types
              (.cc SelectedTypes 'resource
                (.o wrong_name: (.get SelectedTypes resource null_resource))))
            #f)))
      (assert 'malformed-selection-rejected
        (with-catch (lambda (_) #t)
          (lambda ()
            (agentic-ai-lab-opentofu-configuration-from-types (.cc SelectedTypes 'data "wrong"))
            #f)))
      (displayln "OPENTOFU-CONFIGURATION-FAMILIES-OK"))))
