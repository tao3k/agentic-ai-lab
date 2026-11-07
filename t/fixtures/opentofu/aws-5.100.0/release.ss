;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Maintainer-reviewed, fixed historical release. Regenerate/review together
;;; with its executable acquisition control; this is not a provider registry.
(import :clan/poo/object
        (only-in :yuanxu/feature-system/source-lock-feature SourceLockEntry.))
(export Aws5100Release)

(.def Aws5100Release
  provider: "registry.terraform.io/hashicorp/aws"
  version: "5.100.0"
  platform: "darwin_arm64"
  sdk-version: "2.36.1"
  source-commit: "f7a3b98da589ab1d52756b0dcee0dbf2de83d635"
  sdk-commit: "7b9b1111b68d597dccb33fdc8ac4904d8a122f44"
  signer: "C874011F0AB405110D02105534365D9472D7468F"
  signature-policy: 'pinned-historical-signature
  archive-digest: "sha256:bb64e8aff37becab373a1a0cc1080990785304141af42ed6aa3dd4913b000421"
  binary-digest: "sha256:0d25f8f99c202cdf4d9566d3bc5165d518e7ea88de87a3ec4e77b2cf367daac4"
  export-digest: "sha256:cb0e8a42f6eaea3983698d70cba213a630c661420f974a7246685d026da32781"
  collections:
  (.o aws_iam_group_membership: '((users))
      aws_security_group: '((ingress security_groups) (egress security_groups)))
  sources:
  (list
    (.o (:: @ SourceLockEntry.)
        identity: "SHA256SUMS" path: "SHA256SUMS"
        canonical-uri: "https://releases.hashicorp.com/terraform-provider-aws/5.100.0/terraform-provider-aws_5.100.0_SHA256SUMS"
        exact-version: "5.100.0" representation: 'bytes
        digest: "sha256:43e80a4c7d3e7c0146429c0dd6cf7a3a372420f1aca6eecd6b81451501d27b71" size-bytes: 1697)
    (.o (:: @ SourceLockEntry.)
        identity: "SHA256SUMS.sig" path: "SHA256SUMS.sig"
        canonical-uri: "https://releases.hashicorp.com/terraform-provider-aws/5.100.0/terraform-provider-aws_5.100.0_SHA256SUMS.72D7468F.sig"
        exact-version: "5.100.0" representation: 'bytes
        digest: "sha256:0de1ac780ca1d2562e7ce40c5c62a55f37145f42a61311eb22ee2cb519254261" size-bytes: 566)
    (.o (:: @ SourceLockEntry.)
        identity: "create-hashcode.go" path: "create-hashcode.go"
        canonical-uri: "https://raw.githubusercontent.com/hashicorp/terraform-provider-aws/f7a3b98da589ab1d52756b0dcee0dbf2de83d635/internal/create/hashcode.go"
        exact-version: "5.100.0" representation: 'bytes
        digest: "sha256:d0737f257cd46e26b7fbc827f2f50dcbd9538a1c6ce6ef50171832f9092d5f7f" size-bytes: 483)
    (.o (:: @ SourceLockEntry.)
        identity: "download.json" path: "download.json"
        canonical-uri: "https://registry.terraform.io/v1/providers/hashicorp/aws/5.100.0/download/darwin/arm64"
        exact-version: "5.100.0" representation: 'bytes
        digest: "sha256:ba4170470cdd9cd2982eedc41ef42e9e0eed06257d31f2e220055b6b07833c2c" size-bytes: 8596)
    (.o (:: @ SourceLockEntry.)
        identity: "go.mod" path: "go.mod"
        canonical-uri: "https://raw.githubusercontent.com/hashicorp/terraform-provider-aws/f7a3b98da589ab1d52756b0dcee0dbf2de83d635/go.mod"
        exact-version: "5.100.0" representation: 'bytes
        digest: "sha256:37fa2534052d4442cbf3ce78a1b298d365d381610496a5ef5fdae8047c52bc42" size-bytes: 21059)
    (.o (:: @ SourceLockEntry.)
        identity: "group_membership.go" path: "group_membership.go"
        canonical-uri: "https://raw.githubusercontent.com/hashicorp/terraform-provider-aws/f7a3b98da589ab1d52756b0dcee0dbf2de83d635/internal/service/iam/group_membership.go"
        exact-version: "5.100.0" representation: 'bytes
        digest: "sha256:248b266cb6c1568b8733385fee35d732232f19e86fedeed27d938d6860a8ef1f" size-bytes: 5948)
    (.o (:: @ SourceLockEntry.)
        identity: "hashicorp.asc" path: "hashicorp.asc"
        canonical-uri: "https://registry.terraform.io/v1/providers/hashicorp/aws/5.100.0/download/darwin/arm64"
        exact-version: "5.100.0" representation: 'bytes
        digest: "sha256:7dfc64a99fe0c18d4886545e43809bafa78da1be8c25186c0f6744a3232cc892" size-bytes: 7716)
    (.o (:: @ SourceLockEntry.)
        identity: "provider.lock.hcl" path: "provider.lock.hcl"
        canonical-uri: "urn:agentic-ai-lab:opentofu:aws:5.100.0:provider-lock"
        exact-version: "5.100.0" representation: 'bytes
        digest: "sha256:96022e37c1424c8716af0ff53330edec5a7d6dbe482606d1a58e4944a01a3450" size-bytes: 1403)
    (.o (:: @ SourceLockEntry.)
        identity: "schema.json" path: "schema.json"
        canonical-uri: "urn:agentic-ai-lab:opentofu:aws:5.100.0:selected-schema"
        exact-version: "5.100.0" representation: 'bytes
        digest: "sha256:30cf1c04c71f30ce3ec366e5ce7e841b333d75d7ce06ae0764a5a22e2fc831b9" size-bytes: 5899)
    (.o (:: @ SourceLockEntry.)
        identity: "sdk-hashcode.go" path: "sdk-hashcode.go"
        canonical-uri: "https://raw.githubusercontent.com/hashicorp/terraform-plugin-sdk/7b9b1111b68d597dccb33fdc8ac4904d8a122f44/internal/helper/hashcode/hashcode.go"
        exact-version: "2.36.1" representation: 'bytes
        digest: "sha256:80ef69479e0335e64231a1dc9f4ad6dc39e4673a49bd3083dc71e171c6ad2a90" size-bytes: 731)
    (.o (:: @ SourceLockEntry.)
        identity: "sdk-set.go" path: "sdk-set.go"
        canonical-uri: "https://raw.githubusercontent.com/hashicorp/terraform-plugin-sdk/7b9b1111b68d597dccb33fdc8ac4904d8a122f44/helper/schema/set.go"
        exact-version: "2.36.1" representation: 'bytes
        digest: "sha256:77f7799f9a72e694def391ff70646734d73a966f6f6af66ffef4497d8028cfb8" size-bytes: 5323)
    (.o (:: @ SourceLockEntry.)
        identity: "vpc_security_group.go" path: "vpc_security_group.go"
        canonical-uri: "https://raw.githubusercontent.com/hashicorp/terraform-provider-aws/f7a3b98da589ab1d52756b0dcee0dbf2de83d635/internal/service/ec2/vpc_security_group.go"
        exact-version: "5.100.0" representation: 'bytes
        digest: "sha256:0c5d01828242e27e59e9cdd8667f156ef0d3ea47fd3c65b40578b08242d3170f" size-bytes: 46571)))
