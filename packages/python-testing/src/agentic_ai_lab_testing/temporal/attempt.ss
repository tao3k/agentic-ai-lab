;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Two fixed, pre-registered causal-cut fixtures. This file does not
;;; interpret model output or grant event/clinical authority.
(import (only-in :clan/poo/object .ref)
        :agentic-ai-lab/modules/temporal-causality/interface)

(export main)

(def (emit label value)
  (display label)
  (display "\t")
  (write value)
  (newline))

(def (event identity position parents modality committed?)
  (agentic-ai-lab-causal-event
   identity "study-subject" 'study-event
   (agentic-ai-lab-temporal-observation
    (string-append identity "/time") 'logical-version position
    "study-ledger")
   (string-append identity "/payload")
   parents modality committed?))

(def (closed-cut)
  (let* ((graph
          (agentic-ai-lab-causal-event-graph
           "study-subject"
           (list
            (event "prescription" 1 '() 'observed #t)
            (event "administration" 2 '("prescription") 'observed #t)
            (event "observation" 3 '("administration") 'observed #t)
            (event "scheduled-dose" 5 '("prescription") 'declared #f)
            (event "corrected-prescription" 5 '("observation")
                   'counterfactual #f))))
         (cut (agentic-ai-lab-causal-cut graph 3))
         (receipt
          (agentic-ai-lab-temporal-causal-classify
           graph cut "prescription" 5)))
    (emit "closed.status" (.ref receipt 'status))
    (emit "closed.past" (.ref receipt 'past-event-ids))
    (emit "closed.current" (.ref receipt 'current-event-ids))
    (emit "closed.future" (.ref receipt 'future-event-ids))
    (emit "closed.counterfactual"
          (.ref receipt 'counterfactual-event-ids))
    (emit "closed.unknown" (.ref receipt 'unknown-frontier))
    (emit "closed.release-authorized?"
          (.ref receipt 'release-authorized?))))

(def (open-parent)
  (let* ((graph
          (agentic-ai-lab-causal-event-graph
           "study-subject"
           (list
            (event "observation" 2 '("missing-administration")
                   'observed #t))))
         (cut (agentic-ai-lab-causal-cut graph 2))
         (receipt
          (agentic-ai-lab-temporal-causal-classify
           graph cut "observation" 4)))
    (emit "open.status" (.ref receipt 'status))
    (emit "open.unknown" (.ref receipt 'unknown-frontier))
    (emit "open.release-authorized?"
          (.ref receipt 'release-authorized?))))

(def (main . _)
  (closed-cut)
  (open-parent))
