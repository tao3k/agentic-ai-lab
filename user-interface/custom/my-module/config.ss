;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: lightweight configuration owned by this user module. Concrete
;;; Profiles and Scenario fixtures remain precise submodule imports.

(import (only-in :clan/poo/object .o)
        "types.ss")
(export agentic-ai-lab-custom-my-module-config)

(def agentic-ai-lab-custom-my-module-config
  (.o identity: +agentic-ai-lab-custom-my-module-identity+
      profile-source: 'profiles
      scenario-source: 'cases
      runtime-executed?: #f))
