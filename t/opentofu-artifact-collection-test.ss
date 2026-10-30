;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        :yuanxu/profile-composition/selection-syntax
        (only-in :agentic-ai-lab/modules/services/opentofu/objects OpenTofuScope.) :yuanxu/object-types/contracts :clan/poo/object)
(export opentofu-artifact-collection-test)
(def (assert label value)
  (unless value (error "assertion failed" label))
  (displayln "ASSERT-OK " label) (force-output))
(def (accepted? result) (yuanxu-validation-evidence-accepted? result))

(def opentofu-artifact-collection-test
  (test-suite "opentofu-artifact-collection-test"
    (yuanxu-test-case "one actual Nix collection, bounded scope and final candidate"
      (assert 'default-root-inert (not (.ref/cached OpenTofuScope. 'modules)))
      (let (tf 'outside)
        (assert 'one-bounded-binding (use-module OpenTofuScope. as tf (eq? tf OpenTofuScope.)))
        (assert 'alias-does-not-leak (eq? tf 'outside)))
      (def Contract (.get OpenTofuScope. types configuration))
      (assert 'contract-does-not-demand-collection (not (.ref/cached OpenTofuScope. 'modules)))
      (def Modules (.get OpenTofuScope. modules))
      (assert 'three-real-package-names (= (length (.all-slots Modules)) 3))
      (assert 'name-discovery-keeps-leaves-unforced
        (every (lambda (name) (not (.ref/cached Modules name))) '(aws awscc null)))
      (def AwsOnly (.o resource: (.o aws_security_group: (.o web: (.o name: "web")))))
      (def first
        (use-module OpenTofuScope. as tf
          (.call (.get tf types configuration) .admit AwsOnly #f)))
      (assert 'aws-resource-admitted (accepted? first))
      (assert 'other-package-leaves-unforced
        (and (not (.ref/cached Modules 'awscc)) (not (.ref/cached Modules 'null))))
      (assert 'provider-config-input-still-unread
        (not (.call (.get Modules aws provider artifact) .index-loaded? 'provider)))
      (def Configuration
        (.o provider: (.o aws: (list (.o region: "us-east-1"))
                          awscc: (list (.o region: "us-east-1")) null: (list (.o)))
            resource:
            (.o aws_security_group: (.o web: (.o name: "web"))
                awscc_ec2_security_group: (.o web: (.o group_description: "web"))
                null_resource: (.o smoke: (.o triggers: (.o release: "smoke"))))
            data:
            (.o aws_region: (.o current: (.o name: "us-east-1"))
                awscc_ec2_security_group: (.o existing: (.o id: "sg-1234"))
                null_data_source: (.o release: (.o inputs: (.o name: "smoke"))))))
      (def result
        (use-module OpenTofuScope. as tf
          (.call (.get tf types configuration) .admit Configuration #f)))
      (assert 'all-three-provider-configuration-admitted (accepted? result))
      (assert 'nine-original-child-admissions (= (length (.get result classification children)) 9))
      (assert 'same-cached-root-contract (eq? Contract (.get OpenTofuScope. types configuration)))
      (.def (WithGroup @ Configuration)
        resource: =>.+ (.o aws_iam_group: (.o release: (.o name: "release"))))
      (def extended (.call Contract .admit WithGroup #f))
      (assert 'cached-contract-discovers-new-type (accepted? extended))
      (assert 'new-type-input-read-once
        (= (.call (.get Modules aws provider artifact) .entry-read-count 'aws_iam_group 'resource) 1))
      (assert 'unselected-real-input-remains-unread
        (= (.call (.get Modules awscc provider artifact) .entry-read-count 'awscc_s3_bucket 'resource) 0))
      ;; Demand fixture: 99 poisonous metadata leaves are not real Providers.
      ;; It tests object construction laziness, not 100-provider performance.
      (call-with-temporary-directory "opentofu-collection-demand"
        (lambda (tmp)
          (create-symbolic-link (.get Modules aws config provider-artifact) (string-append tmp "/aws"))
          (let loop ((n 1))
            (when (< n 100)
              (let (directory (string-append tmp "/probe" (number->string n)))
                (create-directory directory)
                (call-with-output-file (string-append directory "/manifest.json") (cut display "{}" <>)))
              (loop (1+ n))))
          (.def (Probe @ OpenTofuScope.) config: =>.+ (.o artifact: tmp))
          (def ProbeModules (.get Probe modules))
          (assert 'hundred-directory-keys (= (length (.all-slots ProbeModules)) 100))
          (assert 'new-root-does-not-reuse-parent-registry (not (eq? Modules ProbeModules)))
          (assert 'hundred-leaves-initially-unforced
            (every (lambda (name) (not (.ref/cached ProbeModules name))) (.all-slots ProbeModules)))
          (assert 'single-selected-leaf-among-hundred
            (accepted? (.call (.get Probe types configuration) .admit AwsOnly #f)))
          (assert 'ninety-nine-poison-leaves-still-unforced
            (every (lambda (name) (or (eq? name 'aws) (not (.ref/cached ProbeModules name))))
                   (.all-slots ProbeModules)))
          (assert 'retargeted-parent-contract-unchanged
            (eq? Contract (.get OpenTofuScope. types configuration)))))
      (displayln "OPENTOFU-ARTIFACT-COLLECTION-OK"))))
