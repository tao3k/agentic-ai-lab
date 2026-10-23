;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Native source controls using the installed std/test harness.
(import :std/test/base
        (only-in :agentic-ai-lab/t/control-plane-role-test control-plane-role-test)
        (only-in :agentic-ai-lab/t/feature-system-bundle-v1-composition-writer-test feature-system-bundle-v1-composition-writer-test)
        (only-in :agentic-ai-lab/t/funflow-public-module-test funflow-public-module-test)
        (only-in :agentic-ai-lab/t/funflow-native-publication-test funflow-native-publication-test)
        (only-in :agentic-ai-lab/t/json-schema-contract-bridge-test json-schema-contract-bridge-test)
        (only-in :agentic-ai-lab/t/json-schema-native-contract-test json-schema-native-contract-test)
        (only-in :agentic-ai-lab/t/funflow-github-ci-json-schema-contract-test funflow-github-ci-json-schema-contract-test))

(def results
  (map test-suite!
       (list control-plane-role-test
             feature-system-bundle-v1-composition-writer-test
             funflow-public-module-test
             funflow-native-publication-test
             json-schema-contract-bridge-test
             json-schema-native-contract-test
             funflow-github-ci-json-schema-contract-test)))
(when (member #f (map test-result-ok? results)) (exit 1))
(displayln "MODULE-OK t/qualification/module-ownership/run.ss")
(displayln "HARNESS-OK module-ownership 7 suites")
(displayln "OK")
