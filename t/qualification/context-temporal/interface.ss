;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Native TestSuite publication. The Gerbil owns all discovery and execution.
(import (for-syntax (only-in :yuanxu/observability/testing-source install-test-source-observation!)))
(begin-syntax (install-test-source-observation!))
(import (only-in :yuanxu/observability/testing-source stop-test-source-observation!))
(export test-cleanup!)
(def (test-cleanup!) (stop-test-source-observation!))
(import :agentic-ai-lab/t/temporal-evaluator-test
        :agentic-ai-lab/t/ai-agentic-context-session-host-test
        :agentic-ai-lab/t/ai-agentic-context-delta-test
        :agentic-ai-lab/t/session-attempt-test
        :agentic-ai-lab/t/ai-agentic-context-org-anchors-test
        :agentic-ai-lab/t/query-orgize-source-test)
(export (import: :agentic-ai-lab/t/temporal-evaluator-test
                 :agentic-ai-lab/t/ai-agentic-context-session-host-test
                 :agentic-ai-lab/t/ai-agentic-context-delta-test
                 :agentic-ai-lab/t/session-attempt-test
                 :agentic-ai-lab/t/ai-agentic-context-org-anchors-test
                 :agentic-ai-lab/t/query-orgize-source-test))
