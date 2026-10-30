;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object
        (only-in :agentic-ai-lab/scenarios/aws/objects WebProfile)
        (only-in :agentic-ai-lab/modules/services/opentofu/execution OpenTofuExecution.))
(export Profile Scenario)
;; Syntactically valid example AMI, not a claim that it exists in any account.
(.def (Profile @ WebProfile) ami: "ami-0123456789abcdef0")
(.def (Scenario @ OpenTofuExecution. profile instance_type)
  instance_type: (.get Profile instance_type)
  profile: (let (selected-instance-type instance_type)
             (.o (:: @ Profile) instance_type: selected-instance-type))
  resource: profile
  provider-name: 'aws provider-config: (.o region: "us-east-1")
  environment:
  (.o AWS_ACCESS_KEY_ID: "" AWS_SECRET_ACCESS_KEY: "" AWS_SESSION_TOKEN: ""
      AWS_PROFILE: "" AWS_EC2_METADATA_DISABLED: "true"
      AWS_CONFIG_FILE: "/dev/null" AWS_SHARED_CREDENTIALS_FILE: "/dev/null")
  resource-kind: 'aws_instance)
