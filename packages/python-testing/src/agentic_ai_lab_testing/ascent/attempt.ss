;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Experiment-only process boundary. Python permits only a small ASCII
;;; S-expression alphabet before sending a candidate to this reader.
(import (only-in :gerbil-ascent/candidate/reasoning
                 reasoning-source-snapshot reasoning-attempt
                 reasoning-receipt-status reasoning-receipt-rows
                 reasoning-receipt-diagnostics reasoning-receipt-bound?
                 reasoning-receipt-snapshot-digest
                 reasoning-receipt-candidate-digest
                 reasoning-diagnostic-code reasoning-diagnostic-path))
(export main)

(def (emit label value)
  (display label)
  (display "\t")
  (write value)
  (newline))

(def (main . _)
  (let loop ()
   (let (candidate (read))
    (unless (eof-object? candidate)
    (let* ((snapshot
            (reasoning-source-snapshot
             'live-graph 1 '((edge 2 ((0 1) (1 2))))))
           (withdrawn
            (reasoning-source-snapshot
             'live-graph 2 '((edge 2 ((0 1))))))
           (receipt (reasoning-attempt snapshot candidate))
           (after (reasoning-attempt withdrawn candidate)))
      (emit "status" (reasoning-receipt-status receipt))
      (emit "rows" (reasoning-receipt-rows receipt))
      (emit "bound" (reasoning-receipt-bound? receipt snapshot candidate))
      (emit "snapshot-digest" (reasoning-receipt-snapshot-digest receipt))
      (emit "candidate-digest" (reasoning-receipt-candidate-digest receipt))
      (emit "diagnostics"
            (map (lambda (diagnostic)
                   (list (reasoning-diagnostic-code diagnostic)
                         (reasoning-diagnostic-path diagnostic)))
                 (reasoning-receipt-diagnostics receipt)))
      (emit "after-status" (reasoning-receipt-status after))
      (emit "after-rows" (reasoning-receipt-rows after))
      (emit "after-bound" (reasoning-receipt-bound? after withdrawn candidate))
      (emit "after-snapshot-digest"
            (reasoning-receipt-snapshot-digest after))
      (display "END\n")
      (force-output)
      (loop))))))
