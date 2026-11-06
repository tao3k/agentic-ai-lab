;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :agentic-ai-lab/modules/services/opentofu/func agentic-ai-lab-opentofu-cty->schema))
(export opentofu-module-test)
(def opentofu-module-test
  (test-suite "OpenTofu selected public schema operation"
    (test-case "map of strings projects to the JSON Schema value"
      (check-equal? (agentic-ai-lab-opentofu-cty->schema '("map" "string"))
                    '((type . "object") (additionalProperties . ((type . "string"))))))))
