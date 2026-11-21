#!/usr/bin/env gxi
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Example owner: a browser profile remains declarative until a downstream
;;; runtime chooses to realize its staged composition.

(import (only-in :tao3k/yuanxu/modules/funflow/scenario Scenario)
        (only-in :clan/poo/mop .new)
        :tao3k/yuanxu/profile-composition/selection-syntax

        :tao3k/yuanxu/profile-composition/profile-bundle
        (only-in :tao3k/agentic-ai-lab/modules/workflow/profiles/agentic-research
                 AgenticResearchModule
                 BrowserResearchScenarioProfile))

(export browser-profile-composition)

;;; Composition boundary: this example is a pure declarative value; runtime
;;; scheduling and evidence effects remain behind the selected runtime profile.
(def browser-profile-composition
  (.new Scenario name: 'browser-profile-composition
        config: (compose profiles
    (use-module AgenticResearchModule as research
      researcher evidence-curator runtime)
    BrowserResearchScenarioProfile)))
