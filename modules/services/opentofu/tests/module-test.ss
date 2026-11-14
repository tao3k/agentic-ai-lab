;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(cond-expand
  (lab-deployment-test-import-timing
   (begin-syntax (displayln "LAB-DEPLOYMENT-IMPORT opentofu enter") (force-output)))
  (else (begin)))
(import :std/test
        (only-in :tao3k/agentic-ai-lab/modules/services/opentofu/cty agentic-ai-lab-opentofu-cty->schema))
(cond-expand
  (lab-deployment-test-import-timing
   (begin-syntax (displayln "LAB-DEPLOYMENT-IMPORT opentofu expanded") (force-output))
   (displayln "LAB-DEPLOYMENT-IMPORT opentofu initializing")
   (force-output))
  (else (begin)))
(export opentofu-module-test)
(def opentofu-module-test
  (test-suite "OpenTofu selected public schema operation"
    (test-case "map of strings projects to the JSON Schema value"
      (check-equal? (agentic-ai-lab-opentofu-cty->schema '("map" "string"))
                    '((type . "object") (additionalProperties . ((type . "string"))))))))
