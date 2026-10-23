;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object)
(export WebProfile Scenario)
;; Structural sample, not a deployment-ready AMI or AWS authorization.
(.def WebProfile ami: "ami-fixture" instance_type: "t3.small")
(.def (Scenario @ [] profile)
  profile: WebProfile
  resource: profile)
