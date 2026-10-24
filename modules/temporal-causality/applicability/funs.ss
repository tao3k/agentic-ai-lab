;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .ref)
        (only-in :agentic-ai-lab/modules/temporal-causality/admission/interface
                 agentic-ai-lab-temporal-family-admission-replay
                 agentic-ai-lab-temporal-source-snapshot-replay)
        (only-in :agentic-ai-lab/modules/temporal-causality/applicability/objects
                 agentic-ai-lab-temporal-family-applicability-value))
(export agentic-ai-lab-temporal-family-applicability)
;;; Pure comparison with an independently selected host snapshot. This does not
;;; fence a subsequent effect or erase a valid historical classification.
(def (agentic-ai-lab-temporal-family-applicability admission current-source)
  (let* ((original (agentic-ai-lab-temporal-family-admission-replay admission))
         (current (agentic-ai-lab-temporal-source-snapshot-replay current-source)))
    (unless (equal? (.ref (.ref original 'source) 'identity) (.ref current 'identity))
      (error "applicability requires the same logical source"))
    (agentic-ai-lab-temporal-family-applicability-value
     (.ref original 'semantic-digest) (.ref original 'source-digest)
     (.ref current 'semantic-digest)
     (if (equal? (.ref original 'source-digest) (.ref current 'semantic-digest))
       'current 'stale))))
