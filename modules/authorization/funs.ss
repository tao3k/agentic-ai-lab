;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Authorization has no in-process fallback evaluator. Provider execution is
;;; admitted only through its explicit runtime boundary.
(import (only-in :clan/poo/object .ref)
        (only-in :agentic-ai-lab/modules/authorization/types
                 agentic-ai-lab-authorization-provider?))

(export agentic-ai-lab-authorization-provider-engines)

(def (agentic-ai-lab-authorization-provider-engines provider)
  (unless (agentic-ai-lab-authorization-provider? provider)
    (error "invalid authorization Provider" provider))
  (.ref provider 'engines))
