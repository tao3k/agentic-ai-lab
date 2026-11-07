#!/usr/bin/env gxi
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Example owner: this composition keeps human authority and evidence return
;;; explicit across every stage before bundle publication.

(import (only-in :yuanxu/modules/funflow/scenario Scenario)
        (only-in :clan/poo/mop .new)
        :agentic-ai-lab/modules/workflow/control-plane/plan
        :yuanxu/profile-composition/selection-syntax

        :yuanxu/profile-composition/profile-bundle
        (only-in :agentic-ai-lab/modules/workflow/profiles/human-ai-capability
                 HumanAICapabilityModule
                 HumanCapabilityScenarioProfile)
        :yuanxu/modules/funflow/bundle-v1)

(export human-capability)

;;; Composition boundary: human authority and evidence return are represented
;;; as declarative stages; no stage executes while this value is constructed.
(def human-capability
  (.new Scenario name: 'human-capability
        config: (compose profiles
    (use-module HumanAICapabilityModule as capability
      access understand compose qualify act learn)
    HumanCapabilityScenarioProfile)))

;;; Publication boundary: the example's only effect is the explicit bundle
;;; writer handoff after the complete composition value has been constructed.
(agentic-ai-lab-write-composition-bundle-v1/from-environment! human-capability)
