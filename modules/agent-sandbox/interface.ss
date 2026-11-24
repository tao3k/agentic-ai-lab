;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Public agent-sandbox module interface; all internal roles close through this file.

(import (only-in :clan/poo/object .def .o)
        "types.ss" "objects.ss" "func.ss" "config.ss"
        "profile-validation.ss"
        "policy-support/projection-syntax.ss"
        "policy-support/policy.ss")
(export AgentSandbox
        (import: "types.ss")
        (import: "objects.ss")
        (import: "func.ss")
        (import: "config.ss")
        (import: "profile-validation.ss")
        (import: "policy-support/projection-syntax.ss")
        (import: "policy-support/policy.ss"))

(.def AgentSandbox
  identity: 'agent-sandbox
  tags: '(sandbox agent policy)
  core: (.o scope-contract: AgentSandboxScope
            exports: (.o library: 'tao3k/agentic-ai-lab/modules/agent-sandbox/interface))
  features: (.o))
