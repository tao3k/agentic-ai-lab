;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        "./fixtures/opentofu/aws-5.100.0/qualification.ss"
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :yuanxu/object-types/contracts :clan/poo/object)
(export opentofu-aws-binary-test)

(def opentofu-aws-binary-test
  (test-suite "opentofu-aws-binary-test"
    (yuanxu-test-case "actual AWS 5.100.0 darwin_arm64 binary source"
      (def path (getenv "YUANXU_AWS_BINARY" #f))
      (unless path (error "YUANXU_AWS_BINARY must name the acquired AWS 5.100.0 binary"))
      (def (assert label value)
        (unless value (error "assertion failed" label))
        (displayln "ASSERT-OK " label) (force-output))
      (def selection (.o provider: "registry.terraform.io/hashicorp/aws" version: "5.100.0"))
      (def request (.cc (.o) 'selection selection 'path path))
      (assert 'actual-binary
        (yuanxu-validation-evidence-accepted?
          (.call AwsProviderBinaryContract .admit request #f)))
      (def wrong-version
        (.call AwsProviderBinaryContract .admit
          (.cc request 'selection (.cc selection 'version "5.99.0")) #f))
      (assert 'wrong-version
        (eq? (.get (car (.get wrong-version diagnostics)) reason) 'provider-version-mismatch))
      (def wrong-bytes
        (.call AwsProviderBinaryContract .admit
          (.cc request 'path "t/fixtures/opentofu/aws-5.100.0/group_membership.go") #f))
      (assert 'wrong-binary
        (eq? (.get (car (.get wrong-bytes diagnostics)) reason) 'provider-binary-mismatch))
      (displayln "OPENTOFU-AWS-BINARY-OK"))))
