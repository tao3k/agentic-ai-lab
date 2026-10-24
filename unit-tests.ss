#!/usr/bin/env gxi
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; The native ASP entry owns the project root; optional profiles live in dev.
(import (only-in :asp-gerbil-scheme/testing-runner-api init-profiled-test-environment!)
        (only-in :agentic-ai-lab/dev/testing-profiles +agentic-ai-lab-project-testing-interface+))
(export main)
(init-profiled-test-environment! +agentic-ai-lab-project-testing-interface+)
