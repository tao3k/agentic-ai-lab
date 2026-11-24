;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Compatibility re-export from AgentSandbox public interface.
(import (except-in :tao3k/agentic-ai-lab/modules/agent-sandbox/interface AgentSandbox))
(export (import: :tao3k/agentic-ai-lab/modules/agent-sandbox/interface))
