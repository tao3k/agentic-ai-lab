;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Proof core declares the Lego stud and mandatory assurance slots. Concrete
;;; engines, artifacts and vertical claims are always supplied by contributors.
(import (only-in :clan/poo/object .o)
        (only-in :clan/poo/mop validate)
        "types.ss"
        "funs.ss")

(export AgenticAILabProofModule.
        agentic-ai-lab-proof-module)

(def AgenticAILabProofModule.
  (.o (:: self)
      kind: +agentic-ai-lab-proof-module-kind+
      identity: "agentic-ai-lab/modules/proof"
      required-slots: '(artifacts receipts refinements)
      optional-slots:
      '(documentation presentation-metadata reference-implementation)
      providers: (.o)
      .admit-assurance: agentic-ai-lab-proof-assurance))

(def (agentic-ai-lab-proof-module identity-value provider-values)
  (validate
   AgenticAILabProofModule
   (.o (:: @ AgenticAILabProofModule.)
       identity: identity-value
       providers: provider-values)))
