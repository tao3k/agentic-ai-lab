;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object
        (only-in :yuanxu/modules/json-schema/contracts ProjectionContract.)
        (only-in :agentic-ai-lab/scenarios/aws/types AWSInterfaceContract aws-scenario-contract))
(export AWSInterfaceContract validation-admission)
;; Operational slots are not AWS fields. Reuse the maintained Scenario relation
;; on its data projection, preserving the original execution object on success.
(def (validation-admission input-type)
  (let (base (aws-scenario-contract input-type))
    (.cc base 'value-contract
      (.cc ProjectionContract.
        'constraint (.get base value-contract)
        'project (lambda (scenario)
                   (.o profile: (.get scenario profile)
                       resource: (.get scenario resource)))))))
